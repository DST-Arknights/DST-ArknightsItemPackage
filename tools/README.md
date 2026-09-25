# 工具集（Lua / PowerShell）

本目录用于放置以 Lua 和 PowerShell 为主的维护工具脚本。

## 发布工具

### publish.ps1 — 统一发布入口

所有 DST-Arknights mod 共用这一份发布实现。其他 mod 的 `tools/publish.ps1` 只保留项目配置和转发逻辑。

```powershell
# 发布补丁版本 (2.4.2 → 2.4.3)
pwsh ./tools/publish.ps1 -Bump patch

# 在其他 mod 根目录执行该项目唯一的发布脚本
Push-Location C:\path\to\mod
pwsh ./tools/publish.ps1 -Bump patch
Pop-Location

# 发布次版本 (2.4.2 → 2.5.0)
pwsh ./tools/publish.ps1 -Bump minor

# 发布主版本 (2.4.2 → 3.0.0)
pwsh ./tools/publish.ps1 -Bump major

# 试运行（不实际修改任何内容）
pwsh ./tools/publish.ps1 -Bump patch -DryRun

# 跳过依赖检查
pwsh ./tools/publish.ps1 -Bump patch -SkipChecks

# 只生成当前项目的本地内测 dist，不改版本、changelog、Git 或 Workshop 依赖
pwsh ./tools/publish.ps1 -DistOnly
```

其他 mod 目录中的 `tools/publish.ps1` 只是转发代理，并在脚本内嵌入该项目的差异化配置。新增公共参数时只需修改本项目的统一入口。

**发布流程（10 步）：**
1. 检查依赖工具（git）                         ← 确定性，快速
2. 检查翻译完整性（PO 文件 msgctxt 对齐）       ← 硬性要求，放前面
3. AI：通过 OpenAI 兼容 HTTP API 总结 git 提交   ← 配置检查通过后才请求
4. 验证 changelog 条目存在且有内容
5. 运行项目特定的前置钩子（生成物品表等）
6. 更新 modinfo.lua 版本号
7. 从 CHANGELOG.md 读取更新内容，写入 description
8. Git 提交（`release: x.y.z`）并打 tag        ← 源代码保持本地依赖
9. 拷贝发布文件到 dist/
10. 转换 dist/modinfo.lua 依赖为 workshop       ← 只改编译产物，不改源代码

**依赖转换约定：** 源代码 `modinfo.lua` 始终写本地依赖 `{["LocalName"] = false}`（开发时依赖本地仓库），发布时步骤 10 只对 `dist/modinfo.lua` 转换为 workshop 依赖 `{ workshop = "workshop-xxxxx" }`。各模组在自己的 `tools/publish.ps1` 中提供 `WorkshopDeps` 配置。

**脚本结构：**
```
tools/
├── publish.ps1                 ← 入口（跨项目可复用）
└── publish/                    ← 发布脚本模块
    ├── publish.psm1            ← 主编排模块（跨项目可复用）
    ├── check-deps.ps1          ← 依赖检查
    ├── translation-check.ps1   ← 翻译完整性检查
    ├── modinfo.ps1             ← modinfo.lua 操作（版本 + description）
    ├── changelog.ps1           ← CHANGELOG.md 读写 + AI 总结编排
    ├── ai-quick-request.ps1    ← OpenAI 兼容非流式请求
    ├── git-ops.ps1             ← Git 提交 + 打 tag
    ├── dist.ps1                ← 拷贝到 dist（黑名单机制）
    └── project/                ← 项目特定钩子
        └── pre-publish.ps1     ← 本项目的发布前任务
```

其他 DST mod 不再复制 `tools/publish/` 公共脚本，也不再维护单独的 config 文件；每个项目尽可能只保留一个 `tools/publish.ps1`。公共流程、检查、changelog、dist 拷贝和 Workshop 转换均由本项目维护。

### AI changelog 请求配置

发布时需要生成 changelog 的情况下，脚本优先读取被 `.gitignore` 忽略的项目根目录文件 `.ai.env`，缺少的字段再读取同名环境变量。API Key 不应写入仓库。

```text
OPENAI_API_KEY=你的 API Key
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=模型名称
```

也可以设置 `OPENAI_API_KEY`、`OPENAI_BASE_URL` 和 `OPENAI_MODEL` 环境变量。`OPENAI_BASE_URL` 未配置时默认使用 `https://api.openai.com/v1`。请求使用非流式 `chat/completions` 接口。

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
