# 发布编排模块（跨 DST mod 项目可复用）
#
# 编排完整发布流程:
#   1. 检查依赖 (git)                              ← 确定性，快速
#   2. 检查翻译完整性                               ← 硬性要求，放在前面
#   3. AI: 从 git 提交生成 changelog               ← 高失败风险/高成本，翻译检查通过后才跑
#   4. 验证 changelog 条目存在且有内容
#   5. 运行项目特定发布前钩子
#   6. 更新 modinfo.lua 版本号
#   7. 读取 changelog → 更新 modinfo.lua description
#   8. Git 提交 + 打 tag（源代码保持本地依赖）
#   9. 拷贝到 dist/
#   10. 转换 dist/modinfo.lua 依赖为 workshop（只改编译产物，不改源代码）
#
# 用法 (通过 tools/publish.ps1 入口):
#   pwsh ./tools/publish.ps1 -Bump patch [-SkipChecks] [-DryRun]

function Publish-Mod {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [Parameter(Mandatory = $true)]
        [ValidateSet('patch', 'minor', 'major')]
        [string]$Bump,

        [switch]$SkipChecks,

        [switch]$DryRun
    )

    $ErrorActionPreference = 'Stop'

    # --- 加载项目配置（可选） ---
    $configPath = Join-Path $ProjectRoot 'tools/publish-config.ps1'
    $config = @{}
    if (Test-Path $configPath) {
        $config = & $configPath
        Write-Host "[配置]  已加载项目发布配置: $configPath"
    }

    # 默认值
    $gitFiles       = if ($config.GitFiles)       { $config.GitFiles }       else { @('modinfo.lua', 'CHANGELOG.md') }
    $languagesDir   = if ($config.LanguagesDir)   { $config.LanguagesDir }   else { 'languages' }
    $enVarName      = if ($config.EnVarName)      { $config.EnVarName }      else { 'UPDATE_EN' }
    $zhVarName      = if ($config.ZhVarName)      { $config.ZhVarName }      else { 'UPDATE_ZH' }
    $maxVersions    = if ($config.MaxVersions)    { $config.MaxVersions }    else { 2 }
    $workshopDeps   = if ($config.WorkshopDeps)   { $config.WorkshopDeps }   else { @{} }
    $prePublishHook = if ($config.PrePublishHook) { Join-Path $ProjectRoot $config.PrePublishHook } else { $null }

    # 解析路径（子模块与 publish.psm1 同目录）
    $modinfoPath    = Join-Path $ProjectRoot 'modinfo.lua'
    $changelogPath  = Join-Path $ProjectRoot 'CHANGELOG.md'
    $publishDir     = $PSScriptRoot

    # 加载可复用模块
    . (Join-Path $publishDir 'check-deps.ps1')
    . (Join-Path $publishDir 'translation-check.ps1')
    . (Join-Path $publishDir 'modinfo.ps1')
    . (Join-Path $publishDir 'changelog.ps1')
    . (Join-Path $publishDir 'git-ops.ps1')
    . (Join-Path $publishDir 'dist.ps1')

    # --------------------------------------------------
    # 步骤 0: 试运行横幅
    # --------------------------------------------------
    if ($DryRun) {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  试运行 (DRY RUN) - 不会做任何实际修改" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
    }

    # --------------------------------------------------
    # 步骤 1: 检查依赖（确定性，快速）
    # --------------------------------------------------
    Write-Host "`n[1/10] 检查依赖..." -ForegroundColor Yellow
    if (-not $SkipChecks) {
        if (-not $DryRun) {
            Test-RequiredTools -Required @('git')
        }
        else {
            Write-Host "[试运行]  将检查: git"
        }
    }
    else {
        Write-Host "[跳过]  依赖检查已跳过（--SkipChecks）"
    }

    # --------------------------------------------------
    # 步骤 2: 检查翻译完整性（硬性要求，放在 AI 之前）
    #    快速、确定性检查。如果翻译条目不对齐，不应浪费 AI 调用。
    #    验证所有 PO 文件的 msgctxt 完全对齐，无遗漏翻译。
    # --------------------------------------------------
    Write-Host "`n[2/10] 检查翻译完整性..." -ForegroundColor Yellow
    if (-not $DryRun) {
        Test-TranslationsComplete -ProjectRoot $ProjectRoot -LanguagesDir $languagesDir
    }
    else {
        Write-Host "[试运行]  将检查所有 PO 文件的 msgctxt 对齐情况"
    }

    # --------------------------------------------------
    # 步骤 3: AI 生成 Changelog（高失败风险/高成本 - 硬性检查通过后才跑）
    #    此步骤调用 claude CLI 总结 git 提交。
    #    如果失败，项目文件完全未被改动。
    # --------------------------------------------------
    Write-Host "`n[3/10] AI: 从 git 历史生成 changelog..." -ForegroundColor Yellow

    # 计算目标版本号（只读，仅供 changelog 标题使用）
    $oldVersion = Get-ModinfoVersion -ModinfoPath $modinfoPath
    $newVersion = Bump-SemVer -Version $oldVersion -BumpType $Bump
    Write-Host "        $oldVersion -> $newVersion (升级类型: $Bump)"

    if (-not $DryRun) {
        Invoke-AIChangelog -ProjectRoot $ProjectRoot -Version $newVersion -ChangelogPath $changelogPath
    }
    else {
        Write-Host "[试运行]  将调用 AI 工具总结 v$newVersion 的 git 提交"
    }

    # --------------------------------------------------
    # 步骤 4: 验证 AI 输出（CHANGELOG.md 就绪?）
    # --------------------------------------------------
    Write-Host "`n[4/10] 验证 v$newVersion 的 changelog 条目..." -ForegroundColor Yellow
    if (-not $DryRun) {
        Test-ChangelogReady -ChangelogPath $changelogPath -Version $newVersion
    }
    else {
        Write-Host "[试运行]  将验证: CHANGELOG.md 中存在 v$newVersion 条目"
    }

    # --------------------------------------------------
    # 步骤 5: 运行项目特定发布前钩子
    # --------------------------------------------------
    Write-Host "`n[5/10] 运行发布前钩子..." -ForegroundColor Yellow
    if ($prePublishHook -and (Test-Path $prePublishHook)) {
        if (-not $DryRun) {
            & $prePublishHook -ProjectRoot $ProjectRoot
        }
        else {
            Write-Host "[试运行]  将运行: $prePublishHook"
        }
    }
    else {
        Write-Host "[跳过]  未配置项目发布前钩子"
    }

    # --------------------------------------------------
    # 步骤 6: 更新 modinfo.lua 版本号
    # --------------------------------------------------
    Write-Host "`n[6/10] 更新 modinfo.lua 版本号..." -ForegroundColor Yellow
    if (-not $DryRun) {
        Set-ModinfoVersion -ModinfoPath $modinfoPath -NewVersion $newVersion
        Write-Host "[完成]  modinfo.lua 版本号已更新"
    }
    else {
        Write-Host "[试运行]  将更新 modinfo.lua: version = `"$newVersion`""
    }

    # --------------------------------------------------
    # 步骤 7: Changelog → modinfo description
    # --------------------------------------------------
    Write-Host "`n[7/10] 更新 description 中的版本信息..." -ForegroundColor Yellow

    if (-not $DryRun) {
        Set-ModinfoDescription -ModinfoPath $modinfoPath -ChangelogPath $changelogPath -EnVarName $enVarName -ZhVarName $zhVarName -MaxVersions $maxVersions
        Write-Host "[完成]  modinfo.lua description 已更新"
    }
    else {
        Write-Host "[试运行]  将更新 modinfo.lua description 中的版本信息"
    }

    # --------------------------------------------------
    # 步骤 8: Git 提交 + 打 tag
    #    源代码 modinfo.lua 保持本地依赖格式，直接入库。
    # --------------------------------------------------
    Write-Host "`n[8/10] Git 提交并打 tag..." -ForegroundColor Yellow
    if (-not $DryRun) {
        Publish-GitCommit -ProjectRoot $ProjectRoot -Version $newVersion -Files $gitFiles
        Write-Host "[完成]  已提交并打 tag v$newVersion"
    }
    else {
        Write-Host "[试运行]  将 git add: $($gitFiles -join ', ')"
        Write-Host "[试运行]  将 git commit -m 'release: $newVersion'"
        Write-Host "[试运行]  将 git tag '$newVersion'"
    }

    # --------------------------------------------------
    # 步骤 9: 拷贝到 dist
    # --------------------------------------------------
    Write-Host "`n[9/10] 拷贝发布文件到 dist/..." -ForegroundColor Yellow
    if (-not $DryRun) {
        Copy-ToDist -ProjectRoot $ProjectRoot
    }
    else {
        Write-Host "[试运行]  将清空并重建 dist/ 目录"
    }

    # --------------------------------------------------
    # 步骤 10: 转换 dist/modinfo.lua 依赖为 workshop
    #    只修改编译产物 dist/modinfo.lua，不改源代码 modinfo.lua。
    #    源代码保持本地依赖（开发时用），发布产物用工坊依赖。
    # --------------------------------------------------
    Write-Host "`n[10/10] 转换 dist/modinfo.lua 依赖为 workshop..." -ForegroundColor Yellow
    if (-not $DryRun) {
        $distModinfo = Join-Path $ProjectRoot 'dist/modinfo.lua'
        if (Test-Path $distModinfo) {
            Convert-LocalDepsToWorkshop -ModinfoPath $distModinfo -WorkshopDeps $workshopDeps
        }
        else {
            Write-Warning "[警告]  未找到 dist/modinfo.lua，跳过依赖转换"
        }
    }
    else {
        if ($workshopDeps.Count -gt 0) {
            foreach ($k in $workshopDeps.Keys) {
                Write-Host "[试运行]  将在 dist/modinfo.lua 中转换: {[`"$k`"] = false} → { workshop = `"$($workshopDeps[$k])`" }"
            }
        }
        else {
            Write-Host "[试运行]  未配置 WorkshopDeps，跳过"
        }
    }

    # --------------------------------------------------
    # 摘要
    # --------------------------------------------------
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  发布完成!" -ForegroundColor Green
    Write-Host "  版本: $oldVersion -> $newVersion" -ForegroundColor Green
    Write-Host "  升级: $Bump" -ForegroundColor Green
    if ($DryRun) {
        Write-Host "  （试运行 - 未做任何实际修改）" -ForegroundColor Cyan
    }
    Write-Host "========================================" -ForegroundColor Green
}
