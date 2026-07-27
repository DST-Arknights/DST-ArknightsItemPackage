# 翻译完整性检查（跨 DST mod 项目可复用）
# 验证所有 PO 翻译文件的 msgctxt 条目对齐，且不存在遗漏的翻译。
# 这是硬性检查，放在 AI 步骤之前，因为它是快速、确定性的。

function Test-TranslationsComplete {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        # PO 文件所在目录，默认为 languages/
        [string]$LanguagesDir = 'languages'
    )

    $langDir = Join-Path $ProjectRoot $LanguagesDir

    if (-not (Test-Path $langDir)) {
        Write-Warning "[跳过]  未找到语言目录: $langDir"
        return
    }

    $poFiles = Get-ChildItem -Path $langDir -Filter '*.po' -File
    if ($poFiles.Count -lt 2) {
        Write-Host "[跳过]  仅找到 $($poFiles.Count) 个 PO 文件，无需对齐检查"
        return
    }

    Write-Host "        找到 $($poFiles.Count) 个 PO 文件: $($poFiles.Name -join ', ')"

    # 解析每个 PO 文件，提取 msgctxt → {msgid, msgstr} 映射
    $allEntries = @{}
    foreach ($poFile in $poFiles) {
        $entries = Read-POFile -Path $poFile.FullName
        $allEntries[$poFile.Name] = $entries
        Write-Host "        $($poFile.Name): $($entries.Count) 条 msgctxt"
    }

    $allOk = $true

    # --------------------------------------------------
    # 检查 1: msgctxt 对齐（所有文件应有完全相同的 msgctxt 集合）
    # --------------------------------------------------
    Write-Host "`n        --- msgctxt 对齐检查 ---"

    $referenceFile = $poFiles[0].Name
    # @() 强制展开 KeyCollection，避免 PowerShell 将其当作单一字符串拼接
    $referenceKeys = [System.Collections.Generic.HashSet[string]]@($allEntries[$referenceFile].Keys)

    foreach ($poFile in $poFiles) {
        $name = $poFile.Name
        $fileKeys = [System.Collections.Generic.HashSet[string]]@($allEntries[$name].Keys)

        # 参考文件有，此文件缺失的 key
        $missing = $referenceKeys | Where-Object { -not $fileKeys.Contains($_) }
        if ($missing) {
            Write-Error "[缺失]  $referenceFile 中存在但 $name 中缺失的条目 ($($missing.Count) 条):"
            $missing | Select-Object -First 10 | ForEach-Object { Write-Error "         $_" }
            if ($missing.Count -gt 10) { Write-Error "         ... 及其他 $($missing.Count - 10) 条" }
            $allOk = $false
        }

        # 此文件有多余的 key
        $extra = $fileKeys | Where-Object { -not $referenceKeys.Contains($_) }
        if ($extra) {
            Write-Error "[多余]  $name 中存在但 $referenceFile 中不存在的条目 ($($extra.Count) 条):"
            $extra | Select-Object -First 10 | ForEach-Object { Write-Error "         $_" }
            if ($extra.Count -gt 10) { Write-Error "         ... 及其他 $($extra.Count - 10) 条" }
            $allOk = $false
        }

        if (-not $missing -and -not $extra) {
            Write-Host "[就绪]  $name 与 $referenceFile 条目完全对齐"
        }
    }

    # --------------------------------------------------
    # 检查 2: 空翻译（msgstr 为空 且 msgid 也为空 → 完全无翻译）
    # --------------------------------------------------
    Write-Host "`n        --- 空翻译检查 ---"

    foreach ($poFile in $poFiles) {
        $name = $poFile.Name
        $entries = $allEntries[$name]
        $emptyCount = 0

        foreach ($key in $entries.Keys) {
            $entry = $entries[$key]
            if ([string]::IsNullOrWhiteSpace($entry.msgstr) -and [string]::IsNullOrWhiteSpace($entry.msgid)) {
                if ($emptyCount -lt 10) {
                    Write-Warning "[空翻译] $name : msgstr 和 msgid 均为空: $key"
                }
                $emptyCount++
            }
        }

        if ($emptyCount -gt 0) {
            Write-Warning "         $name : $emptyCount 条翻译的 msgstr 和 msgid 均为空（无任何文本）"
            if ($emptyCount -gt 10) { Write-Warning "         （仅显示前 10 条）" }
            # 空翻译不阻断发布（某些条目可能确实不需要文本），但值得关注
        }
        else {
            Write-Host "[就绪]  $name : 所有条目均有翻译或回退文本"
        }
    }

    # --------------------------------------------------
    # 结果
    # --------------------------------------------------
    if (-not $allOk) {
        throw "翻译文件条目未对齐。请补齐缺失的翻译条目后重试。"
    }

    Write-Host "[完成]  翻译完整性检查通过"
}

function Read-POFile {
    <#
    .SYNOPSIS
    解析 PO 文件，返回 msgctxt → @{msgid, msgstr} 的字典。
    #>
    param([string]$Path)

    $entries = @{}
    $lines = Get-Content $Path -Encoding UTF8

    $currentCtxt = $null
    $currentMsgid = $null
    $currentMsgstr = $null
    $inMsgid = $false
    $inMsgstr = $false

    foreach ($line in $lines) {
        if ($line -match '^msgctxt\s+"(.*)"') {
            # 保存上一条
            if ($currentCtxt) {
                $entries[$currentCtxt] = @{ msgid = $currentMsgid; msgstr = $currentMsgstr }
            }
            $currentCtxt = $matches[1]
            $currentMsgid = $null
            $currentMsgstr = $null
            $inMsgid = $false
            $inMsgstr = $false
        }
        elseif ($line -match '^msgid\s+"(.*)"') {
            $currentMsgid = $matches[1]
            $inMsgid = $true
            $inMsgstr = $false
        }
        elseif ($line -match '^msgstr\s+"(.*)"') {
            $currentMsgstr = $matches[1]
            $inMsgid = $false
            $inMsgstr = $true
        }
        elseif ($inMsgid -and $line -match '^"(.*)"') {
            # 多行 msgid 续行
            $currentMsgid += $matches[1]
        }
        elseif ($inMsgstr -and $line -match '^"(.*)"') {
            # 多行 msgstr 续行
            $currentMsgstr += $matches[1]
        }
    }

    # 保存最后一条
    if ($currentCtxt) {
        $entries[$currentCtxt] = @{ msgid = $currentMsgid; msgstr = $currentMsgstr }
    }

    return $entries
}
