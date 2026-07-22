# 项目特定发布前钩子（仅明日方舟物品包项目使用）
# 此脚本不会跨其他 DST mod 项目复用。
# 每个项目应提供自己的 pre-publish.ps1 及对应钩子。

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

Write-Host "`n--- 项目发布前钩子 ---"

# --------------------------------------------------
# 1. 检查 lua（项目特定依赖）
#    其他 DST 项目可能完全不需要 lua。
# --------------------------------------------------
$luaCmd = Get-Command lua -ErrorAction SilentlyContinue
if (-not $luaCmd) {
    throw @"
[错误] 未找到 lua 命令 - 生成物品表需要 lua。

安装方式:
  - Windows:  从 https://www.lua.org/download.html 下载
              或使用: winget install lua
  - 或使用 DSTmodutils 等工具包自带的 Lua 解释器
"@
}
Write-Host "[就绪]  lua 可用: $($luaCmd.Source)"

# --------------------------------------------------
# 2. 生成材料增强表文档
# --------------------------------------------------
$tableScript = Join-Path $ProjectRoot 'tools/generate_ark_item_table.lua'
if (Test-Path $tableScript) {
    Write-Host "[运行]  刷新 ark_item_enhanced_table.md..."
    & $luaCmd.Source $tableScript $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "tools/generate_ark_item_table.lua 执行失败"
    }
    Write-Host "[完成]  docs/ark_item_enhanced_table.md 已更新"
}
else {
    Write-Warning "[跳过]  未找到 generate_ark_item_table.lua，跳过物品表生成"
}

Write-Host "--- 项目钩子完成 ---`n"
