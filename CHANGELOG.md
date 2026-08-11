# 版本更新记录
## v2.5.12 (2026-08-12)

- Updated M3 Cocoon Armor data and renamed its prefab | 修改M3茧甲数据, 预制体重命名
- Added armor_construct resource | 新增 armor_construct 资源

## v2.5.11 (2026-08-11)

- Changed the Construct Armor's tag from "body" to "armor" | 将构造盔甲的标签从 "body" 更改为 "armor"

## v2.5.10 (2026-08-11)

- Added "body" tag to Construct Armor (compatibility with 4/5/6 equipment slots) | 为构造盔甲添加 "body" 标签（兼容四五六格装备槽）
- Added "amulet" tag to Sympathetic Pendant (compatibility with 4/5/6 equipment slots) | 为同情挂件添加 "amulet" 标签（兼容四五六格装备槽）

## v2.5.9 (2026-08-11)

- Updated the sympathetic pendant atlas element coordinates and texture layout | 更新同情挂件的元素坐标和纹理信息

## v2.5.8 (2026-08-11)

- Updated Construct Armor description to note its durability loss ratio | 更新构造盔甲描述，添加耐久损失比例说明
- Added Construct Armor image resource | 添加构造盔甲图片资源

## v2.5.7 (2026-08-07)

- Added M3 Cocoon Armor and related item descriptions | 添加 M3 Cocoon Armor 及相关物品说明
- Updated the player gameplay guide | 更新玩家游玩指南
- Added construct armor resources | 添加构建护甲相关资源
- Updated development tools | 更新开发工具


## v2.5.6 (2026-07-28)

Based on the single commit, here's the changelog entry:

- Refactored language selection logic: non-English and Chinese languages now safely fall back to English instead of crashing | 重构语言选择逻辑：非英文和中文语言现在安全回退到英文，不再导致崩溃

## v2.5.5 (2026-07-28)

The commit is HEAD (sole change in v2.5.5). Based on the diff:

- **changelog.ps1**: Now checks `git status --porcelain` before generating changelog; if there are uncommitted changes but no commits since the last tag, it warns and throws instead of silently writing a placeholder entry.
- **CHANGELOG.md**: Replaced the v2.5.4 placeholder (`- 版本发布`) with three proper bilingual entries.

```
- Publish script now detects uncommitted changes before changelog generation, preventing placeholder entries from being written against a dirty working tree | 发布脚本在生成 changelog 前检测未提交改动，避免脏工作区写入占位条目
- Backfilled v2.5.4 changelog with detailed bilingual descriptions | 补填 v2.5.4 双语详细 changelog
```

## v2.5.4 (2026-07-28)

- Refactored modinfo description to use Lua variables (UPDATE_EN/UPDATE_ZH) for version notes, eliminating anchor-drift and cross-block regex bugs | 重构 modinfo description 使用 Lua 变量管理版本说明，根除锚点漂移和跨语言块串改问题
- Added automatic local-to-workshop dependency conversion in publish pipeline | 发布流程新增本地依赖自动转 workshop 依赖
- Fixed AI changelog summarization: fuller git log format, removed lazy fallback rule | 修复 AI changelog 总结：更完整的 git log 格式，移除偷懒 fallback 规则

## v2.5.3 (2026-07-28)

- Internal tooling and pipeline updates | 内部工具链更新

## v2.5.2 (2026-07-28)

- 版本发布

## v2.5.1 (2026-07-28)

- 版本发布


## v2.4.3 (Unreleased)

- 新增英文国际化支持（ark_english.po，273 条翻译）
- 简化 modmain.lua 语言加载逻辑

## v2.4.2 (2026-07-21)

- 修复 buff 图标同步导致的崩溃问题
- 添加朋友共鸣效果，优化共鸣相关的 buff 逻辑与描述
- 更新共鸣机制，增加共鸣层级阈值和乘数
- 添加玩家有效性检查，优化远离玩家处理逻辑
- 添加共鸣挂件效果，优化状态修改逻辑
- 添加共鸣机制，优化共享增益效果的计算与更新
- 添加同情挂件数据组件，支持玩家间共鸣数据的存储与获取

## v2.4.1 (2026-07-11)

- 优化 Talker 类 Play 方法，合并 talk_params 和 sound_params
- 重构 Talker 类语音数据解析逻辑，简化代码结构
- 修正情绪徽章描述，简化为"情绪徽章"

## v2.4.0 (2026-07-04)

- 添加共情项坠，支持动态颜色变化
- 更新情绪徽章描述，添加部分功能测试体验并调整配方
- 添加战斗事件管理与情感评估功能
- 更新 ark_workshop 原型定义，修正资源路径并添加制造站属性
- 添加共情项坠光效能及相关状态管理

## v2.3.1 (2026-07-01)

- 优化语言文件合并逻辑，支持按需覆盖翻译键
- 添加共情项坠组件及相关状态和增益效果
- 添加 group 字段到 ark_buff_icon 组件，支持按组显示 buff 图标
- 修复未挂载的 netstate 意外触发 ondetached 回调

## v2.3.0 (2026-06-20)

- 添加技能重铸功能，优化技能使用逻辑
- 添加 reticule AOE 功能，注册相关特效和动画
- 添加 AOE 选择器，支持技能激活和目标选择
- 增强角色材料系统，添加阶梯等级计算和 UI 通知
- 优化热键管理器，使用弱引用存储实例
- 添加 buff 生成器和前置模块加载标识

## v2.2.0 (2026-06-01)

- 添加属性修改器实现，整合战斗、生命、建筑、饥饿和理智组件
- 添加科技树工具，支持科技分支和原型树的管理
- 添加精英化相关提示信息和升级条件检查
- 重构覆盖等级管理，新增覆盖等级设置和恢复功能
- 优化 HookFunction 参数验证和 upvalue 处理逻辑

## v2.1.0 (2026-05-15)

- 添加天赋 OnActivate 和 OnDeactivate 回调，增强天赋状态管理
- 添加组件属性修改器，优化伤害、生命值和攻击范围的计算
- 添加 ArkUpValue 功能，支持获取和设置函数的 upvalue
- 添加徽章管理器，优化徽章显示与管理逻辑
- 添加自定义配方材料注册系统，支持与 DST 制作系统对接
- 添加全局函数 Hook 工具，优化技能和天赋的中间件管理
- 添加飞行支持及相关动画
- 重构攻击力和攻击范围的计算逻辑，添加新的修饰符支持

## v2.0.0 (2026-04-20)

- 技能系统大改版，支持热插拔技能
- 添加便携式补给站及其充能器功能
- 添加精英化图标资源
- 添加技能栏大小配置选项及 UI 缩放
- 支持角色私有技能限制声明
- 添加选择角色界面聊天框表情支持
- 添加 AI 编程指南和存档/读档处理方案文档

## v1.2.0 (2025-12-01)

- 添加全模组材料掉落选项，允许用户启用或禁用材料掉落
- 添加脚本扩展和技能组件的预移除处理
- 更新发布目录生成脚本，改用黑名单过滤

## v1.1.0 (2025-11-01)

- 添加内置表情支持及音效
- 添加聊天表情支持
- 添加护甲、生命值和事件回调优先级扩展
- 重构攻击速度更新逻辑，优化性能

## v1.0.12 (2025-10-01)

- 首次公开发布
