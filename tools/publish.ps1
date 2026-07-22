# 发布入口（跨 DST mod 项目可复用）
#
# 薄封装层：解析项目根目录并调用 Publish-Mod。
# 此文件可按原样拷贝到其他 DST mod 项目；
# 各项目只需提供自己的 tools/publish/project/pre-publish.ps1 钩子。
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

# 解析项目根目录（脚本所在目录的上级）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir '..')

# 导入编排模块
$modulePath = Join-Path $scriptDir 'publish/publish.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "未找到发布模块: $modulePath"
    Write-Error "预期的目录结构:"
    Write-Error "  tools/"
    Write-Error "    publish.ps1        <- 你在这里"
    Write-Error "    publish/"
    Write-Error "      publish.psm1      <- 编排模块"
    Write-Error "      ..."
    exit 1
}

Import-Module $modulePath -Force

# 执行
Publish-Mod -ProjectRoot $projectRoot -Bump $Bump -SkipChecks:$SkipChecks -DryRun:$DryRun
