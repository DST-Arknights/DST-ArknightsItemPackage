# 发布入口（跨 DST mod 项目可复用）
#
# 薄封装层：解析项目根目录并从共享位置加载 Publish-Mod。
# 共享脚本集中存放于 DST-Arknights-AICoding/tools/publish/。
#
# 用法:
#   pwsh ./tools/publish.ps1 -Bump patch
#   pwsh ./tools/publish.ps1 -Bump minor -DryRun
#   pwsh ./tools/publish.ps1 -Bump major -SkipChecks
#
# 参数:
#   -Bump       版本升级类型: patch（补丁）, minor（次版本）, major（主版本）
#   -SkipChecks 跳过依赖检查
#   -DryRun     试运行：仅显示将执行的操作，不做实际修改

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Bump,

    [switch]$SkipChecks,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# 项目根目录 = 当前工作目录（在哪个项目下执行就发布哪个项目）
$projectRoot = Resolve-Path (Get-Location)
if (-not (Test-Path (Join-Path $projectRoot 'modinfo.lua'))) {
    Write-Error "当前目录未找到 modinfo.lua，请在 DST mod 项目根目录执行此脚本。"
    Write-Error "当前目录: $projectRoot"
    exit 1
}

# 导入编排模块（始终从脚本自身的 tools/publish/ 目录加载）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$publishDir = Join-Path $scriptDir 'publish'
$modulePath = Join-Path $publishDir 'publish.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "未找到发布模块: $modulePath"
    exit 1
}

Import-Module $modulePath -Force

# 执行
Publish-Mod -ProjectRoot $projectRoot -Bump $Bump -SkipChecks:$SkipChecks -DryRun:$DryRun
