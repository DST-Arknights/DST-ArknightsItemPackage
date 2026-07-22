# 工具集（Lua / PowerShell）

本目录用于放置以 Lua 和 PowerShell 为主的维护工具脚本。

## 发布工具

### publish.ps1 — 发布入口

一键发布新版本，包含版本号管理、changelog 更新、Git 提交/打 tag、dist 生成等功能。

```powershell
# 发布补丁版本 (2.4.2 → 2.4.3)
pwsh ./tools/publish.ps1 -Bump patch

# 发布次版本 (2.4.2 → 2.5.0)
pwsh ./tools/publish.ps1 -Bump minor

# 发布主版本 (2.4.2 → 3.0.0)
pwsh ./tools/publish.ps1 -Bump major

# 试运行（不实际修改任何内容）
pwsh ./tools/publish.ps1 -Bump patch -DryRun

# 跳过依赖检查
pwsh ./tools/publish.ps1 -Bump patch -SkipChecks
```

**发布流程（9 步）：**
1. 检查依赖工具（git）                         ← 确定性，快速
2. 检查翻译完整性（PO 文件 msgctxt 对齐）       ← 硬性要求，放前面
3. AI：从 git 提交总结生成 changelog            ← 高成本/高失败率，检查通过后才跑
4. 验证 changelog 条目存在且有内容
5. 运行项目特定的前置钩子（生成物品表等）
6. 更新 modinfo.lua 版本号
7. 从 CHANGELOG.md 读取更新内容，写入 description
8. Git 提交（`release: x.y.z`）并打 tag
9. 拷贝发布文件到 dist/

**脚本结构：**
```
tools/
├── publish.ps1                 ← 入口（跨项目可复用）
└── publish/                    ← 发布脚本模块
    ├── publish.psm1            ← 主编排模块（跨项目可复用）
    ├── check-deps.ps1          ← 依赖检查
    ├── translation-check.ps1   ← 翻译完整性检查
    ├── modinfo.ps1             ← modinfo.lua 操作（版本 + description）
    ├── changelog.ps1           ← CHANGELOG.md 读写 + AI 总结调用
    ├── git-ops.ps1             ← Git 提交 + 打 tag
    ├── dist.ps1                ← 拷贝到 dist（黑名单机制）
    └── project/                ← 项目特定钩子
        └── pre-publish.ps1     ← 本项目的发布前任务
```

其他 DST mod 项目复用：复制 `tools/publish.ps1` + `tools/publish/` 文件夹，替换 `project/pre-publish.ps1` 为自己的前置任务即可。

---

## 已有工具

### 1) 生成材料增强表文档

- 脚本：`tools/generate_ark_item_table.lua`
- 输入：`scripts/ark_item_declare.lua`
- 输出：`docs/ark_item_enhanced_table.md`

运行方式（在项目根目录）：

```bash
lua tools/generate_ark_item_table.lua
```

当你更新材料声明后，重新运行一次上面命令即可自动刷新文档。

> 注意：`publish.ps1` 发布流程中会自动调用此脚本，通常无需手动运行。
