# Markdown 子集转换为可粘贴到 Steam 描述中的 BBCode。
# 支持标题、段落、引用、无序/有序列表、粗体、斜体、删除线、行内代码和 HTTP(S) 链接/图片。

function Convert-MarkdownInlineToSteam {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    $result = $Text -replace '`([^`]+)`', '$1'
    $result = $result -replace '!\[([^\]]*)\]\((https?://[^)\s]+)\)', '[img]$2[/img]'
    $result = $result -replace '\[([^\]]+)\]\((https?://[^)\s]+)\)', '[url=$2]$1[/url]'
    $result = $result -replace '\*\*(.+?)\*\*', '[b]$1[/b]'
    $result = $result -replace '(?<!\*)\*([^*]+)\*(?!\*)', '[i]$1[/i]'
    $result = $result -replace '~~(.+?)~~', '[strike]$1[/strike]'
    return $result
}

function Convert-MarkdownBlockToSteam {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('paragraph', 'quote', 'unordered', 'ordered')]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string[]]$Lines
    )

    switch ($Type) {
        'paragraph' {
            return (Convert-MarkdownInlineToSteam -Text ($Lines -join ' '))
        }
        'quote' {
            $quote = ($Lines | ForEach-Object { Convert-MarkdownInlineToSteam -Text $_ }) -join "`n"
            return "[quote]`n$quote`n[/quote]"
        }
        'unordered' {
            $items = @($Lines | ForEach-Object { '[*]' + (Convert-MarkdownInlineToSteam -Text $_) })
            return "[list]`n$($items -join "`n")`n[/list]"
        }
        'ordered' {
            $items = @($Lines | ForEach-Object { '[*]' + (Convert-MarkdownInlineToSteam -Text $_) })
            return "[olist]`n$($items -join "`n")`n[/olist]"
        }
    }
}

function Convert-MarkdownToSteamMarkup {
    param([Parameter(Mandatory = $true)][string]$Markdown)

    $blocks = [System.Collections.Generic.List[string]]::new()
    $currentLines = [System.Collections.Generic.List[string]]::new()
    $currentType = $null

    foreach ($rawLine in ($Markdown -split '\r?\n')) {
        $line = $rawLine.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($currentType -ne $null -and $currentLines.Count -gt 0) {
                [void]$blocks.Add((Convert-MarkdownBlockToSteam -Type $currentType -Lines $currentLines.ToArray()))
                $currentLines.Clear()
                $currentType = $null
            }
            continue
        }

        if ($line -match '^(#{1,6})\s+(.+?)\s*#*\s*$') {
            if ($currentType -ne $null -and $currentLines.Count -gt 0) {
                [void]$blocks.Add((Convert-MarkdownBlockToSteam -Type $currentType -Lines $currentLines.ToArray()))
                $currentLines.Clear()
                $currentType = $null
            }
            $level = $Matches[1].Length
            $heading = Convert-MarkdownInlineToSteam -Text $Matches[2]
            [void]$blocks.Add("[h$level]$heading[/h$level]")
            continue
        }

        # Steam 描述忽略水平线；保留为段落间距即可。
        if ($line -match '^(?:-{3,}|\*{3,}|_{3,})$') {
            if ($currentType -ne $null -and $currentLines.Count -gt 0) {
                [void]$blocks.Add((Convert-MarkdownBlockToSteam -Type $currentType -Lines $currentLines.ToArray()))
                $currentLines.Clear()
                $currentType = $null
            }
            continue
        }

        $nextType = 'paragraph'
        $content = $line
        if ($line -match '^>\s?(.*)$') {
            $nextType = 'quote'
            $content = $Matches[1]
        }
        elseif ($line -match '^[-*+]\s+(.+)$') {
            $nextType = 'unordered'
            $content = $Matches[1]
        }
        elseif ($line -match '^\d+[.)]\s+(.+)$') {
            $nextType = 'ordered'
            $content = $Matches[1]
        }

        if ($currentType -ne $nextType) {
            if ($currentType -ne $null -and $currentLines.Count -gt 0) {
                [void]$blocks.Add((Convert-MarkdownBlockToSteam -Type $currentType -Lines $currentLines.ToArray()))
                $currentLines.Clear()
            }
            $currentType = $nextType
        }
        [void]$currentLines.Add($content)
    }

    if ($currentType -ne $null -and $currentLines.Count -gt 0) {
        [void]$blocks.Add((Convert-MarkdownBlockToSteam -Type $currentType -Lines $currentLines.ToArray()))
    }

    return ($blocks -join "`n`n").Trim()
}

function Convert-MarkdownToSteamFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MarkdownPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $MarkdownPath -PathType Leaf)) {
        throw "未找到 Steam 介绍 Markdown: $MarkdownPath"
    }

    $markdown = Get-Content -LiteralPath $MarkdownPath -Raw -Encoding UTF8
    $steamMarkup = Convert-MarkdownToSteamMarkup -Markdown $markdown
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($OutputPath, $steamMarkup + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "[完成] Steam 介绍已生成: $OutputPath"
}

function Invoke-SteamDescriptionConversion {
    param(
        [string]$MarkdownPath,
        [string]$OutputPath,
        [switch]$DryRun
    )

    if ([string]::IsNullOrWhiteSpace($MarkdownPath)) {
        Write-Host '[跳过] 未配置 Steam 介绍 Markdown'
        return
    }

    if (-not (Test-Path -LiteralPath $MarkdownPath -PathType Leaf)) {
        throw "已配置 Steam 介绍 Markdown，但文件不存在: $MarkdownPath"
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $directory = Split-Path -Parent $MarkdownPath
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($MarkdownPath)
        $OutputPath = Join-Path $directory "$stem-steam.txt"
    }

    if ($DryRun) {
        Write-Host "[试运行] 将把 Markdown 转为 Steam BBCode: $OutputPath"
        return
    }

    Convert-MarkdownToSteamFile -MarkdownPath $MarkdownPath -OutputPath $OutputPath
}
