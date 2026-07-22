# modinfo.lua 操作（跨 DST mod 项目可复用）
# 更新版本号字段，在 description 中插入版本信息块。

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

function Set-ModinfoDescription {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModinfoPath,
        [Parameter(Mandatory = $true)]
        [string]$VersionInfo
    )

    if (-not (Test-Path $ModinfoPath)) {
        throw "未找到 modinfo.lua: $ModinfoPath"
    }

    $content = Get-Content $ModinfoPath -Raw -Encoding UTF8

    # 构建版本信息块
    $block = "`n`n---`n`n$VersionInfo`n`n---`n"

    # 英文和中文描述的锚点
    $anchors = @(
        'Feedback and suggestions:',
        '需求与建议反馈渠道:'
    )

    $modified = $content
    foreach ($anchor in $anchors) {
        $escapedAnchor = [regex]::Escape($anchor)

        # 检查锚点前是否已有版本信息块
        $blockPattern = "`n`n---`n`nv\d+\.\d+\.\d+[^`n]*`n(?:[-*]\s+[^`n]*`n)*`n---`n`n$escapedAnchor"

        if ($modified -match $blockPattern) {
            # 替换已有版本信息块
            $modified = $modified -replace $blockPattern, ($block.TrimEnd("`n") + "`n`n$anchor")
            Write-Host "[完成]  已更新 '$anchor' 前的版本信息块"
        }
        else {
            # 在锚点前插入新版本信息块
            if ($modified -match $escapedAnchor) {
                $modified = $modified -replace $escapedAnchor, ($block.TrimEnd("`n") + "$anchor")
                Write-Host "[完成]  已在 '$anchor' 前插入版本信息块"
            }
            else {
                Write-Warning "[警告]  在 description 中未找到锚点 '$anchor'，跳过。"
            }
        }
    }

    $modified | Set-Content $ModinfoPath -Encoding UTF8 -NoNewline
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
