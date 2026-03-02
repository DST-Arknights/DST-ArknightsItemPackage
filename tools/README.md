# 工具集（Lua）

本目录用于放置以 Lua 为主的维护工具脚本。

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
