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
    <#
    .SYNOPSIS
    将版本更新信息写入 modinfo.lua 的 description。
    保留最近 3 个版本（最新在上），超出自动删除。
    双语条目（"- English | 中文"）自动分离到对应语言块。

    .PARAMETER Anchors
    定位 description 中版本信息块的锚点字符串数组。
    默认: @('Feedback and suggestions:', '需求与建议反馈渠道:')
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModinfoPath,
        [Parameter(Mandatory = $true)]
        [string]$VersionInfo,
        [string[]]$Anchors = @('Feedback and suggestions:', '需求与建议反馈渠道:'),
        [int]$MaxVersions = 3
    )

    if (-not (Test-Path $ModinfoPath)) {
        throw "未找到 modinfo.lua: $ModinfoPath"
    }

    $content = Get-Content $ModinfoPath -Raw -Encoding UTF8

    # 解析 VersionInfo 中的版本号和条目
    # 格式: "vX.Y.Z (YYYY-MM-DD)\n- English | 中文\n- English | 中文"
    $versionHeader = ''
    $entries = @()
    foreach ($line in ($VersionInfo -split '\n')) {
        if ($line -match '^v([\d.]+)\s+\((\S+)\)') {
            $versionHeader = $matches[0]
        }
        elseif ($line -match '^[-*]\s+(.+)') {
            $entries += $matches[1]
        }
    }
    if (-not $versionHeader) { throw "无法从 VersionInfo 中解析版本标题" }

    # 构建当前版本的条目块（不含外层的 --- 包装）
    # 格式: "vX.Y.Z (date)\n- item1\n- item2"
    # 注意: $versionHeader 已包含 "v" 前缀，不要重复添加
    $newVersionBody = "$versionHeader`n" + (($entries | ForEach-Object { "- $_" }) -join "`n")

    # 双语分离：按 " | " 分割
    $enBullets = @()
    $zhBullets = @()
    foreach ($entry in $entries) {
        $parts = $entry -split '\s*\|\s*', 2
        if ($parts.Count -eq 2) { $enBullets += $parts[0]; $zhBullets += $parts[1] }
        else { $enBullets += $entry; $zhBullets += $entry }
    }
    $enBody = "$versionHeader`n" + (($enBullets | ForEach-Object { "- $_" }) -join "`n")
    $zhBody = "$versionHeader`n" + (($zhBullets | ForEach-Object { "- $_" }) -join "`n")

    # 依次处理每个锚点
    # 关键: 先定位锚点所在的 [[...]] 块，再在独立的块内容中匹配，
    # 避免正则跨越 en/zh 语言块边界导致串改。
    $modified = $content
    for ($i = 0; $i -lt $Anchors.Count; $i++) {
        $anchor = $Anchors[$i]
        $newBody = if ($i -eq 0) { $enBody } else { $zhBody }
        $escapedAnchor = [regex]::Escape($anchor)

        # 在 $modified 中定位锚点位置
        $anchorPos = $modified.IndexOf($anchor, [StringComparison]::Ordinal)
        if ($anchorPos -lt 0) {
            Write-Warning "[警告]  在 description 中未找到锚点 '$anchor'，跳过。"
            continue
        }

        # 找到包含此锚点的 [[...]] 块边界
        $beforeAnchor = $modified.Substring(0, $anchorPos)
        $afterAnchor  = $modified.Substring($anchorPos)

        $blockStart = $beforeAnchor.LastIndexOf('[[', [StringComparison]::Ordinal)
        $blockEnd   = $afterAnchor.IndexOf(']]', [StringComparison]::Ordinal)

        if ($blockStart -lt 0 -or $blockEnd -lt 0) {
            Write-Warning "[警告]  未找到锚点 '$anchor' 所在的 [[...]] 块边界，跳过。"
            continue
        }

        # 提取块内容（[[ 和 ]] 之间的部分）
        $blockContentStart = $blockStart + 2
        $blockContentEnd   = $anchorPos + $blockEnd
        $blockContent = $modified.Substring($blockContentStart, $blockContentEnd - $blockContentStart)

        # 在隔离的块内容中匹配已有版本块
        $innerBlockPattern = "(`n---`n)([\s\S]*?)(`n---`n$escapedAnchor)"
        $existingBlocks = @()

        if ($blockContent -match $innerBlockPattern) {
            $blockText = $matches[2].Trim()
            if ($blockText) {
                $existingBlocks = Split-VersionBlocks $blockText
            }
        }

        # 新版本在最上面，保留最近 MaxVersions 个
        $allBlocks = @($newBody) + $existingBlocks
        if ($allBlocks.Count -gt $MaxVersions) {
            $allBlocks = $allBlocks[0..($MaxVersions - 1)]
        }
        $combined = ($allBlocks -join "`n---`n")

        # 在块内容中执行替换
        if ($blockContent -match $innerBlockPattern) {
            $newSection = "`n---`n$combined`n---`n$anchor"
            $newBlockContent = $blockContent -replace $innerBlockPattern, $newSection
            Write-Host "[完成]  已更新 '$anchor' 前的版本信息（最新 $($allBlocks.Count)/$MaxVersions 条）"
        }
        else {
            $newSection = "`n---`n$newBody`n---`n$anchor"
            $newBlockContent = $blockContent -replace $escapedAnchor, $newSection
            Write-Host "[完成]  已在 '$anchor' 前插入版本信息块"
        }

        # 将修改后的块内容拼回完整文件
        $modified = $modified.Substring(0, $blockContentStart) + $newBlockContent + $modified.Substring($blockContentEnd)
    }

    $modified | Set-Content $ModinfoPath -Encoding UTF8 -NoNewline
}

function Split-VersionBlocks {
    <#
    .SYNOPSIS
    将版本块文本按 "\n---\n" 分割为独立版本条目数组。
    #>
    param([string]$Text)

    # 按 "\n---\n" 分割（版本块之间的分隔符）
    $parts = $Text -split '\n---\n' | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
    return @($parts)
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
