# modinfo.lua 操作（跨 DST mod 项目可复用）
# 更新版本号字段，通过 Lua 变量更新 description 中的版本信息。

function Get-ModinfoVersion {
    param([string]$ModinfoPath)
    $content = Get-Content $ModinfoPath -Raw -Encoding UTF8
    if ($content -match 'version\s*=\s*"([^"]*)"') {
        return $matches[1]
    }
    throw "无法从 modinfo.lua 中解析版本号"
}

function Set-ModinfoVersion {
    param(
        [string]$ModinfoPath,
        [string]$NewVersion
    )
    $content = Get-Content $ModinfoPath -Raw -Encoding UTF8
    $oldVersion = Get-ModinfoVersion -ModinfoPath $ModinfoPath
    $newContent = $content -replace ('version\s*=\s*"' + [regex]::Escape($oldVersion) + '"'), ('version = "' + $NewVersion + '"')
    if ($newContent -eq $content) { throw "更新 modinfo.lua 版本号失败（未检测到变化）" }
    $newContent | Set-Content $ModinfoPath -Encoding UTF8 -NoNewline
}

function Set-LuaStringVariable {
    <#
    .SYNOPSIS
    替换 Lua 文件中指定 long-string 变量的内容。
    变量格式: local VAR_NAME = [[...]]

    通过精确位置（字符串索引）替换，不依赖正则 backreference，
    避免 $NewValue 中包含 $1 等字符时被误解为捕获组引用。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$VarName,

        [Parameter(Mandatory = $true)]
        [string]$NewValue
    )

    $escapedName = [regex]::Escape($VarName)
    $pattern = "(local\s+$escapedName\s*=\s*\[\[)[\s\S]*?(\]\])"

    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        Write-Warning "未找到变量 local $VarName = [[...]]，跳过更新。"
        return $Content
    }

    $prefix = $match.Groups[1].Value                  # "local VARNAME = [["
    $before = $Content.Substring(0, $match.Index)
    $after  = $Content.Substring($match.Index + $match.Length)
    $clean  = $NewValue.Trim()

    return "$before${prefix}`n${clean}`n]]$after"
}

function Set-ModinfoDescription {
    <#
    .SYNOPSIS
    从 CHANGELOG.md 读取版本条目，写入 modinfo.lua 中指定的 Lua 变量。
    变量内容为纯版本信息块（不含外层 --- 包装）。

    变量命名约定:
      local UPDATE_EN = [[...]]   ← 英文版本条目
      local UPDATE_ZH = [[...]]   ← 中文版本条目

    modinfo.lua 的 description 通过字符串拼接引用:
      en = [[静态描述...]] .. UPDATE_EN .. [[锚点及联系方式...]]
      zh = [[静态描述...]] .. UPDATE_ZH .. [[锚点及联系方式...]]

    脚本只编辑变量内容，不触碰 description 其余部分。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModinfoPath,

        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath,

        [string]$EnVarName = 'UPDATE_EN',
        [string]$ZhVarName = 'UPDATE_ZH',
        [int]$MaxVersions = 3
    )

    if (-not (Test-Path $ModinfoPath)) {
        throw "未找到 modinfo.lua: $ModinfoPath"
    }

    # --- 从 CHANGELOG.md 读取最近 N 个版本条目 ---
    $versionEntries = Get-ChangelogVersionEntries -ChangelogPath $ChangelogPath -MaxCount $MaxVersions
    if ($versionEntries.Count -eq 0) {
        Write-Warning "[跳过]  CHANGELOG.md 中无版本条目，不更新 description。"
        return
    }
    Write-Host "        从 CHANGELOG.md 读取到 $($versionEntries.Count) 个版本条目"

    # --- 按双语分离构建 en / zh 版本块 ---
    $enBlocks = @()
    $zhBlocks = @()
    foreach ($v in $versionEntries) {
        $enBullets = @()
        $zhBullets = @()
        foreach ($item in $v.Items) {
            $parts = $item -split '\s*\|\s*', 2
            if ($parts.Count -eq 2) {
                $enBullets += $parts[0]
                $zhBullets += $parts[1]
            }
            else {
                $enBullets += $item
                $zhBullets += $item
            }
        }
        $header = "v$($v.Version) ($($v.Date))"
        $enBlocks += "$header`n" + (($enBullets | ForEach-Object { "- $_" }) -join "`n")
        $zhBlocks += "$header`n" + (($zhBullets | ForEach-Object { "- $_" }) -join "`n")
    }
    $enVersionText = ($enBlocks -join "`n---`n")
    $zhVersionText = ($zhBlocks -join "`n---`n")

    # --- 写入 Lua 变量 ---
    $content = Get-Content $ModinfoPath -Raw -Encoding UTF8
    $content = Set-LuaStringVariable -Content $content -VarName $EnVarName -NewValue $enVersionText
    $content = Set-LuaStringVariable -Content $content -VarName $ZhVarName -NewValue $zhVersionText
    $content | Set-Content $ModinfoPath -Encoding UTF8 -NoNewline

    Write-Host "[完成]  已更新 local $EnVarName / $ZhVarName（$($versionEntries.Count) 个版本）"
}

function Bump-SemVer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [ValidateSet('patch', 'minor', 'major')]
        [string]$BumpType
    )

    $parts = $Version -split '\.'
    if ($parts.Length -lt 3) {
        throw "无效的语义化版本号格式: $Version（应为 X.Y.Z）"
    }

    switch ($BumpType) {
        'patch' { $parts[2] = [int]$parts[2] + 1 }
        'minor' { $parts[1] = [int]$parts[1] + 1; $parts[2] = 0 }
        'major' { $parts[0] = [int]$parts[0] + 1; $parts[1] = 0; $parts[2] = 0 }
    }

    return "$($parts[0]).$($parts[1]).$($parts[2])"
}
