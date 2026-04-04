param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
} else {
    $ProjectRoot = (Resolve-Path $ProjectRoot).Path
}

$tableScriptPath = Join-Path $ProjectRoot 'tools/generate_ark_item_table.lua'
if (Test-Path $tableScriptPath) {
    $luaCommand = Get-Command lua -ErrorAction SilentlyContinue
    if (-not $luaCommand) {
        throw "未找到 lua 命令，无法生成 docs/ark_item_enhanced_table.md"
    }

    Write-Host "[run] 刷新材料增强表"
    & $luaCommand.Source $tableScriptPath $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "执行 tools/generate_ark_item_table.lua 失败"
    }
    Write-Host "[ok]   docs/ark_item_enhanced_table.md"
} else {
    Write-Host "[skip] tools/generate_ark_item_table.lua (not found)"
}

$distPath = Join-Path $ProjectRoot 'dist'

if (Test-Path $distPath) {
    Remove-Item -Path $distPath -Recurse -Force
}

New-Item -Path $distPath -ItemType Directory | Out-Null

$blacklist = @(
    'dist',
    'tools',
    '.git',
    '.gitignore',
    '.gitattributes',
    '.vscode',
    'docs',
    'animSource',
    'imageSource',
    'shaderSource',
    'soundSource',
    'ITEM_DESIGN.md'
)

function Copy-ReleaseItem {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]$Item
    )

    $sourcePath = $Item.FullName
    $targetPath = Join-Path $distPath $Item.Name

    if ($Item.PSIsContainer) {
        Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
    } else {
        Copy-Item -Path $sourcePath -Destination $targetPath -Force
    }

    Write-Host "[ok]   $($Item.Name)"
}

$releaseItems = Get-ChildItem -Path $ProjectRoot -Force | Where-Object {
    $_.Name -notin $blacklist
}

foreach ($item in $releaseItems) {
    Copy-ReleaseItem -Item $item
}

Write-Host "`n发布目录已生成: $distPath"
