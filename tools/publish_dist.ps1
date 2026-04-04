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

$rootFiles = @(
    'modicon.tex',
    'modicon.xml',
    'modinfo.lua',
    'modmain.lua',
    'LICENSE.md'
)

$rootDirs = @(
    'anim',
    'fonts',
    'images',
    'languages',
    'modmain',
    'scripts',
    'shaders',
    'sound'
)

function Copy-ReleasePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $sourcePath = Join-Path $ProjectRoot $RelativePath
    if (-not (Test-Path $sourcePath)) {
        Write-Host "[skip] $RelativePath (not found)"
        return
    }

    $targetPath = Join-Path $distPath $RelativePath
    $targetParent = Split-Path -Parent $targetPath
    if ($targetParent -and -not (Test-Path $targetParent)) {
        New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
    Write-Host "[ok]   $RelativePath"
}

foreach ($file in $rootFiles) {
    Copy-ReleasePath -RelativePath $file
}

foreach ($dir in $rootDirs) {
    Copy-ReleasePath -RelativePath $dir
}

Write-Host "`n发布目录已生成: $distPath"
