# Changelog 管理（跨 DST mod 项目可复用）
#
# AI 辅助工作流:
#   [AI 步骤 - 放在最前面，失败率最高]
#   1. Get-CommitsSinceLastTag     → 提取原始 git 记录
#   2. Invoke-AIChangelog           → 调用 claude CLI 总结 → 写入 CHANGELOG.md
#      - 如果 claude CLI 不可用，输出 prompt 供手动处理并阻断
#   [确定性步骤 - 仅 AI 成功后才执行]
#   3. Test-ChangelogReady          → 验证条目存在且有内容
#   4. Get-VersionDescriptionBlock  → 读取条目用于 modinfo description 插入

# --------------------------------------------------
# AI Changelog 生成（流水线中第一个执行）
# --------------------------------------------------

function Invoke-AIChangelog {
    <#
    .SYNOPSIS
    调用 AI CLI 工具 (claude) 将 git 提交总结为 changelog 条目。
    此步骤放在发布流水线的最前面，因为：
      - AI 调用的失败概率最高
      - 如果失败，尚未对项目做任何修改

    输出直接写入 CHANGELOG.md，格式为 "## vX.Y.Z ($(Get-Date -Format 'yyyy-MM-dd'))"。

    如果 AI CLI 不可用，将 prompt 保存到文件供手动处理，并阻断流水线。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath,

        # AI CLI 工具。默认: 自动检测（先尝试 "claude"）
        [string]$AITool = "auto"
    )

    # --- 获取提交记录 ---
    $commits = Get-RawCommits -ProjectRoot $ProjectRoot
    if (-not $commits -or $commits.Count -eq 0) {
        # 检查是否有未提交的改动（用户可能忘记 commit）
        Push-Location $ProjectRoot
        $status = git status --porcelain 2>$null
        Pop-Location
        if ($status) {
            Write-Host "[警告]  自上次 tag 以来无新提交，但检测到未入库的改动:" -ForegroundColor Yellow
            ($status -split "`n") | Where-Object { $_ -match '\S' } | ForEach-Object { Write-Host "          $_" }
            throw "[阻断]  请先 commit 你的改动，再运行发布脚本。Changelog 需要从 git 提交中生成。"
        }

        Write-Warning "[跳过]  自上次 tag 以来无新提交（工作区干净），使用最小 changelog 条目。"
        $fallback = "## v$Version ($(Get-Date -Format 'yyyy-MM-dd'))`n`n- 版本发布`n"
        Write-ChangelogEntry -ChangelogPath $ChangelogPath -Version $Version -Content $fallback
        return
    }

    # --- 检测或解析 AI 工具 ---
    $toolCmd = $null
    if ($AITool -eq "auto") {
        $toolCmd = Get-Command claude -ErrorAction SilentlyContinue
        if (-not $toolCmd) {
            $toolCmd = Get-Command claude-code -ErrorAction SilentlyContinue
        }
    }
    else {
        $toolCmd = Get-Command $AITool -ErrorAction SilentlyContinue
    }

    # --- 构建双语 prompt ---
    $commitList = ($commits | ForEach-Object { "  $_" }) -join "`n"
    $prompt = @"
You are writing changelog entries for a DST character/mod version v$Version.

FORMAT (strict — every line must follow this):
- English description | 中文描述

RULES:
- Describe EVERY meaningful change visible in the commits below. Do NOT skip commits.
- Merge truly related changes into one line, but err on the side of keeping separate items.
- Project infrastructure changes (publish scripts, CI, config) are STILL worth mentioning — describe them concretely, e.g. "- Automated release pipeline | 自动化发布流程"
- Keep proper nouns (character names, item names, technical terms) in English.
- Output 1-10 lines. NO preamble, NO analysis, NO code blocks — just "- " bullet lines.

Commits to summarize:
$commitList
"@

    # --- 调用 AI 工具 ---
    if ($toolCmd) {
        Write-Host "[运行]  调用 $($toolCmd.Name) 总结 $($commits.Count) 条提交..."
        Write-Host "        （AI 步骤 - 可能需要一些时间，失败时会自动重试）"

        $result = Invoke-AITool -ToolPath $toolCmd.Source -Prompt $prompt
        if (-not $result -or $result.Trim() -eq '') {
            throw "[失败] AI 工具返回了空结果。请重试或手动更新 CHANGELOG.md。"
        }

        # 构建 changelog 段落
        $entry = "## v$Version ($(Get-Date -Format 'yyyy-MM-dd'))`n`n$($result.Trim())`n"
        Write-ChangelogEntry -ChangelogPath $ChangelogPath -Version $Version -Content $entry
        Write-Host "[完成]  AI 生成的 changelog 已写入 CHANGELOG.md"
    }
    else {
        # --- AI 工具不可用：保存 prompt 供手动处理 ---
        $promptFile = Join-Path $ProjectRoot 'temp' 'changelog_prompt.txt'
        $parentDir = Split-Path $promptFile -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        $prompt | Set-Content $promptFile -Encoding UTF8

        throw @"

[阻断] 未找到 AI CLI 工具（已尝试: claude, claude-code）。

手动生成 changelog 的步骤:
  1. 总结 prompt 已保存到:
     $promptFile
  2. 将此 prompt 提供给 AI 工具（Claude、ChatGPT 等）
  3. 将 AI 输出的条目写入 CHANGELOG.md，格式为:
     ## v$Version ($(Get-Date -Format 'yyyy-MM-dd'))
  4. 重新运行 publish.ps1

安装 Claude CLI 后可实现全自动化:
  https://docs.anthropic.com/en/docs/claude-code/overview
"@
    }
}

function Write-ChangelogEntry {
    <#
    .SYNOPSIS
    在 CHANGELOG.md 顶部写入新版本段落。
    如果文件不存在则创建。
    #>
    param(
        [string]$ChangelogPath,
        [string]$Version,
        [string]$Content
    )

    if (Test-Path $ChangelogPath) {
        $existing = Get-Content $ChangelogPath -Raw -Encoding UTF8

        # 检查此版本是否已有条目
        $escapedVersion = [regex]::Escape($Version)
        if ($existing -match "##\s+v$escapedVersion") {
            Write-Warning "版本 v$Version 在 CHANGELOG.md 中已存在，正在覆盖..."
            # 删除从 ## vX.Y.Z 到下一个 ## 或文件末尾的整个段落
            $existing = $existing -replace "##\s+v$escapedVersion[^\n]*\n([\s\S]*?)(?=\n##\s+v|`$)", ''
        }

        # 在标题行之后插入新条目
        if ($existing -match "^(#\s+[^\n]*\n\n?)") {
            $header = $matches[1]
            $rest = $existing.Substring($header.Length)
            $newContent = $header + $Content + "`n" + $rest
        }
        else {
            $newContent = $Content + "`n" + $existing
        }

        $newContent | Set-Content $ChangelogPath -Encoding UTF8 -NoNewline
    }
    else {
        $title = "# 版本更新记录`n`n本项目的所有重要变更。`n`n"
        $title + $Content | Set-Content $ChangelogPath -Encoding UTF8 -NoNewline
    }
}

function Invoke-AITool {
    <#
    .SYNOPSIS
    调用 AI CLI 工具，传入 prompt 并返回输出。
    支持失败重试。
    #>
    param(
        [string]$ToolPath,
        [string]$Prompt,
        [int]$MaxRetries = 2
    )

    $attempt = 0
    $lastError = $null

    while ($attempt -le $MaxRetries) {
        try {
            # 用临时文件传递 prompt，避免 shell 转义问题
            $tmpFile = [System.IO.Path]::GetTempFileName() + '.txt'
            $Prompt | Set-Content $tmpFile -Encoding UTF8

            # 确保 PowerShell 以 UTF-8 解码原生可执行文件的输出（避免中文乱码）
            $prevOutputEncoding = [Console]::OutputEncoding
            $prevPSOutputEncoding = $OutputEncoding
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $OutputEncoding = [System.Text.Encoding]::UTF8

            try {
                # 通过 stdin 管道传入 prompt + --session-id 新 UUID 确保完全无状态
                $sessionId = [Guid]::NewGuid().ToString()
                $output = Get-Content $tmpFile -Raw | & $ToolPath --session-id $sessionId -p 2>&1
                # 过滤 AI CLI 的诊断日志行(如 [claude-code:unrecognized_model] ...), 避免混入 changelog
                $output = @($output) | Where-Object { $_ -notmatch '^\s*\[claude-code:' }
            }
            finally {
                [Console]::OutputEncoding = $prevOutputEncoding
                $OutputEncoding = $prevPSOutputEncoding
            }

            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue

            if ($LASTEXITCODE -ne 0) {
                throw "AI 工具退出码 $LASTEXITCODE : $output"
            }

            return ($output | Out-String).Trim()
        }
        catch {
            $lastError = $_
            $attempt++
            if ($attempt -le $MaxRetries) {
                Write-Warning "[重试]  AI 工具调用失败（第 $attempt/$MaxRetries 次）: $lastError"
                Start-Sleep -Seconds 2
            }
        }
    }

    throw "AI 工具在 $MaxRetries 次重试后仍然失败。最后错误: $lastError"
}

# --------------------------------------------------
# 原始 Git 提交提取（AI 输入源）
# --------------------------------------------------

function Get-RawCommits {
    <#
    .SYNOPSIS
    提取自上次 tag 以来的原始 git 提交。
    返回提交字符串数组（静默 - 不输出到控制台）。
    用作 AI changelog 总结的输入。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    Push-Location $ProjectRoot
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
        # 使用 fuller 格式（主题 + 正文），给 AI 更多上下文
        $range = if (-not $lastTag) { "HEAD" } else { "$lastTag..HEAD" }
        $log = git log --no-merges --pretty=format:"%s%n%b%n---" $range 2>$null

        if (-not $log) {
            return @()
        }

        # 按 "---" 分割每条提交，清理空白
        $rawCommits = $log -split '---' | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
        return @($rawCommits)
    }
    finally {
        Pop-Location
    }
}

function Get-CommitsSinceLastTag {
    <#
    .SYNOPSIS
    提取自上次 tag 以来的 git 提交并打印到控制台。
    用于人工检查 / 调试。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    Push-Location $ProjectRoot
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
        $range = if (-not $lastTag) { "所有提交（尚无 tag）" } else { "$lastTag..HEAD" }
        $commits = Get-RawCommits -ProjectRoot $ProjectRoot

        Write-Host "`n=== Git 提交 ($range) ==="
        Write-Host "（将这些提供给 AI 工具进行总结）`n"

        if ($commits.Count -eq 0) {
            Write-Host "（自上次 tag 以来无新提交）"
            return @()
        }

        foreach ($c in $commits) {
            Write-Host "  $c"
        }
        Write-Host "`n=== Git 记录结束（共 $($commits.Count) 条提交）==="

        return $commits
    }
    finally {
        Pop-Location
    }
}

# --------------------------------------------------
# Changelog 验证与读取
# --------------------------------------------------

function Test-ChangelogReady {
    <#
    .SYNOPSIS
    验证 CHANGELOG.md 中目标版本的条目存在且非空。
    在 AI 生成之后调用，确认写入正确。
    就绪返回 $true，否则抛出描述性错误。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath,
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    if (-not (Test-Path $ChangelogPath)) {
        throw "[阻断] 未找到 CHANGELOG.md: $ChangelogPath。AI 生成可能静默失败了。"
    }

    $content = Get-Content $ChangelogPath -Raw -Encoding UTF8
    $escapedVersion = [regex]::Escape($Version)

    if ($content -notmatch "##\s+v$escapedVersion") {
        throw "[阻断] CHANGELOG.md 中未找到 v$Version 的条目。AI 生成可能失败了。"
    }

    # 定位版本段落（从 ## vX.Y.Z 到下一个 ## 或文件末尾）
    $escapedHeader = "##\s+v$escapedVersion"
    $sectionPattern = "($escapedHeader[^\n]*\n)([\s\S]*?)(?=\n##\s+v|`$)"
    if ($content -match $sectionPattern) {
        $sectionBody = $matches[2]
        # 从段落中提取所有符合 "- ..." 或 "* ..." 格式的要点行
        $bulletLines = [regex]::Matches($sectionBody, '^[-*]\s+.+', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($bulletLines.Count -eq 0) {
            throw "[阻断] v$Version 的 changelog 条目中未找到任何 '- ' 格式的更新要点。AI 输出格式可能有问题。请检查 CHANGELOG.md。"
        }
        $changes = ($bulletLines | ForEach-Object { $_.Value.Trim() }) -join "`n"
        Write-Host "[完成]  v$Version 的 changelog 条目就绪（$($bulletLines.Count) 条要点）"
        return $true
    }

    throw "读取 v$Version changelog 条目时发生意外错误。"
}

function Get-VersionDescriptionBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath,
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    if (-not (Test-Path $ChangelogPath)) {
        throw "未找到 CHANGELOG.md: $ChangelogPath。"
    }

    $content = Get-Content $ChangelogPath -Raw -Encoding UTF8
    $escapedVersion = [regex]::Escape($Version)

    # 定位版本段落（从 ## vX.Y.Z 到下一个 ## 或文件末尾）
    $escapedHeader = "##\s+v$escapedVersion"
    $sectionPattern = "($escapedHeader[^\n]*\n)([\s\S]*?)(?=\n##\s+v|`$)"
    if ($content -match $sectionPattern) {
        $headerLine = $matches[1]
        $sectionBody = $matches[2]
        # 提取日期标签
        $date = if ($headerLine -match '\((\S+)\)') { $matches[1] } else { 'Unreleased' }
        # 从段落中提取所有符合 "- ..." 或 "* ..." 格式的要点行
        $bulletLines = [regex]::Matches($sectionBody, '^[-*]\s+.+', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($bulletLines.Count -gt 0) {
            $changes = ($bulletLines | ForEach-Object { $_.Value.Trim() }) -join "`n"
            return "v$Version ($date)`n$changes"
        }
        throw "v$Version 的 changelog 条目中未找到任何更新要点。"
    }

    throw "CHANGELOG.md 中未找到 v$Version。"
}

function Get-ChangelogVersionEntries {
    <#
    .SYNOPSIS
    从 CHANGELOG.md 读取最近 N 个版本的条目，返回结构化数组。
    用于 Set-ModinfoDescription 整体重建版本信息块（而非就地编辑）。

    返回: @(@{Version='2.5.2'; Date='2026-07-28'; Items=@('en item | zh item', ...)}, ...)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath,
        [int]$MaxCount = 3
    )

    if (-not (Test-Path $ChangelogPath)) {
        Write-Warning "未找到 CHANGELOG.md，无版本信息可用。"
        return @()
    }

    $content = Get-Content $ChangelogPath -Raw -Encoding UTF8

    # 匹配所有版本段落: ## vX.Y.Z (date) \n\n - bullets...
    $versionPattern = '##\s+v([\d.]+)\s+\((\S+)\)[\s\S]*?\n([\s\S]*?)(?=\n##\s+v|$)'
    $allMatches = [regex]::Matches($content, $versionPattern)

    $entries = @()
    foreach ($m in $allMatches) {
        if ($entries.Count -ge $MaxCount) { break }

        $version = $m.Groups[1].Value
        $date    = $m.Groups[2].Value
        $body    = $m.Groups[3].Value

        # 提取所有 - 或 * 开头的条目行
        $bulletMatches = [regex]::Matches($body, '^[-*]\s+(.+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        $items = @($bulletMatches | ForEach-Object { $_.Groups[1].Value.Trim() })

        if ($items.Count -gt 0) {
            $entries += @{
                Version = $version
                Date    = $date
                Items   = $items
            }
        }
    }

    return $entries
}

function Get-LatestChangelogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath
    )

    if (-not (Test-Path $ChangelogPath)) {
        return $null
    }

    $content = Get-Content $ChangelogPath -Raw -Encoding UTF8

    # 定位首个版本段落（从 ## vX.Y.Z 到下一个 ## 或文件末尾）
    if ($content -match '##\s+v(\S+)\s+\((\S+)\)\s*\n([\s\S]*?)(?=\n##\s+v|$)') {
        $version = $matches[1]
        $date = $matches[2]
        $sectionBody = $matches[3]
        $bulletLines = [regex]::Matches($sectionBody, '^[-*]\s+.+', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        $description = if ($bulletLines.Count -gt 0) {
            ($bulletLines | ForEach-Object { $_.Value.Trim() }) -join "`n"
        } else { $sectionBody.Trim() }
        return @{
            Version     = $version
            Date        = $date
            Description = $description
            Raw         = $matches[0].Trim()
        }
    }
    return $null
}
