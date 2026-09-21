# 统一发布入口（所有 DST-Arknights mod 项目共用）
#
# 物品包项目可直接运行；其他 mod 通过各自的薄代理调用本入口。
#
# 用法:
#   pwsh ./tools/publish.ps1 -Bump patch
#   pwsh ./tools/publish.ps1 -Bump minor -DryRun
#   pwsh ./tools/publish.ps1 -Bump major -SkipChecks
#
# 参数:
#   -ProjectRoot 目标项目根目录（由其他 mod 的薄代理传入）
#   -ProjectConfig 目标项目内嵌的差异化配置（由薄代理传入）
#   -Bump       版本升级类型: patch（补丁）, minor（次版本）, major（主版本）
#   -SkipChecks 跳过依赖检查
#   -DryRun     试运行：仅显示将执行的操作，不做实际修改

param(
    [string]$ProjectRoot,

    [hashtable]$ProjectConfig = @{},

    [Parameter(ParameterSetName = 'Publish', Mandatory = $true)]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Bump,

    [Parameter(ParameterSetName = 'DistOnly', Mandatory = $true)]
    [switch]$DistOnly,

    [switch]$SkipChecks,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# 统一控制台与原生命令的编码为 UTF-8。
# Windows PowerShell 5.1 默认按系统 ANSI 代码页（中文系统为 936）解码原生命令输出，
# 会把 git 的 UTF-8 中文提交信息解码成乱码（例: 注释掉 -> 娉ㄩ噴鎺?）。
# 显式切到 UTF-8 后，脚本捕获与打印的中文都保持正常。
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try { [Console]::InputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

# 导入编排模块（始终从物品包自身的 tools/publish/ 目录加载）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$publishDir = Join-Path $scriptDir 'publish'
$modulePath = Join-Path $publishDir 'publish.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "未找到发布模块: $modulePath"
    exit 1
}

# 目标项目根目录
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Join-Path $scriptDir '..'
}
$projectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not (Test-Path (Join-Path $projectRoot 'modinfo.lua'))) {
    Write-Error "目标目录未找到 modinfo.lua，请指定 DST mod 项目根目录。"
    Write-Error "目标目录: $projectRoot"
    exit 1
}

Import-Module $modulePath -Force

# 物品包自身的差异化配置也直接放在唯一入口中。
$packageRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
if ($ProjectConfig.Count -eq 0 -and $projectRoot -eq $packageRoot) {
    $ProjectConfig = @{
        GitFiles       = @('modinfo.lua', 'CHANGELOG.md', 'docs/ark_item_enhanced_table.md')
        PrePublishHook = 'tools/publish-hook.ps1'
    }
}

# 执行
if ($DistOnly) {
    Publish-Mod -ProjectRoot $projectRoot -ProjectConfig $ProjectConfig -DistOnly -DryRun:$DryRun
}
else {
    Publish-Mod -ProjectRoot $projectRoot -ProjectConfig $ProjectConfig -Bump $Bump -SkipChecks:$SkipChecks -DryRun:$DryRun
}
