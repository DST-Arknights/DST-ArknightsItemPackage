# DST-ArknightsItemPackage AI 编程指南

## 项目定位

本项目通常作为其他模组的依赖模组使用，提供可复用的 API、组件扩展和 UI/网络工具。

在新增功能或修复逻辑时，优先复用本仓库已经安装的扩展，不要直接覆写底层组件字段，尤其是战斗、生命、防御相关属性。

## 属性修改器总规则

1. 临时加成、装备加成、Buff 加成都应优先使用 modifier，而不是直接改写组件当前字段。
2. 每个 modifier 必须使用稳定且唯一的 key，移除效果时必须用同一个 key 清理。
3. 只有在设置基础值时才直接写原始属性；需要可叠加、可回滚、可与其他模组共存的效果时，一律走 modifier。
4. 本仓库的 combat_extension、health_extension 基于 modifier_installer 和 SourceModifierList 叠加，不要绕过这套管线。

## Combat 修改器

实现位置：modmain/combat_extension.lua

### 默认攻击力

combat.defaultdamage 已接入两套 modifier：

1. combat.defaultdamageaddmodifiers：加法叠加，默认值为 0
2. combat.defaultdamagemultmodifiers：乘法叠加，默认值为 1

计算顺序为：

((base defaultdamage) + 加法总和) * 乘法总和

推荐写法：

```lua
local combat = inst.components.combat
combat.defaultdamageaddmodifiers:SetModifier("my_mod_damage_bonus", 12)
combat.defaultdamagemultmodifiers:SetModifier("my_mod_damage_mult", 1.25)

combat.defaultdamageaddmodifiers:RemoveModifier("my_mod_damage_bonus")
combat.defaultdamagemultmodifiers:RemoveModifier("my_mod_damage_mult")
```

禁止做法：

1. 不要把 Buff、天赋、装备效果直接写进 combat.defaultdamage。
2. 不要为了临时增伤反复覆盖基础攻击力，这会和其他模组或本模组自己的加成互相踩写。

现有参考：scripts/components/ark_elite.lua 使用 combat.defaultdamageaddmodifiers 管理精英等级攻击奖励。

### 攻击速度

combat.attackspeedmodifiers 是攻速修改器容器，封装接口为：

1. combat:SetAttackSpeed(speed)
2. combat:GetAttackSpeed()

其中 SetAttackSpeed 会写入 key 为 ark_attack_speed 的 modifier，并同步动画时间轴与 replica。

如果你只是设置单一最终攻速，直接调用 combat:SetAttackSpeed(speed)。
如果你要做多来源叠加，优先扩展 attackspeedmodifiers，而不是直接改写 min_attack_period。

禁止做法：

1. 不要把临时攻速效果直接写进 combat.min_attack_period。
2. 不要在外部重复缩放动画时间轴，combat_extension 已处理攻击动画和客户端同步。

### 真实伤害

它也存在一个乘法修改器, truedamagemultipliers. 使用它优于使用下面的接口.

combat:EnableTrueDamage(value) 用于启用真实伤害转换，value 取 0 到 1。
combat:DisableTrueDamage() 用于移除该效果。

它的语义不是“额外附加固定真伤”，而是“把原伤害中的一部分按比例转换为 true_damage 类型”，并在 GetAttacked 流程中重写 damage 与 spdamage。

推荐写法：

```lua
inst.components.combat:EnableTrueDamage(0.35)
inst.components.combat:DisableTrueDamage()
```

## Health 修改器

实现位置：modmain/health_extension.lua

### 最大生命

health.maxhealth 已接入两套 modifier：

1. health.maxhealthaddmodifiers：加法叠加，默认值为 0
2. health.maxhealthmultmodifiers：乘法叠加，默认值为 1

推荐写法：

```lua
local health = inst.components.health
health.maxhealthaddmodifiers:SetModifier("my_mod_health_bonus", 50)
health.maxhealthmultmodifiers:SetModifier("my_mod_health_mult", 1.2)

health.maxhealthaddmodifiers:RemoveModifier("my_mod_health_bonus")
health.maxhealthmultmodifiers:RemoveModifier("my_mod_health_mult")
```

禁止做法：

1. 不要把常驻 Buff、装备词条、成长奖励直接写进 health.maxhealth。
2. 不要手动刷新 HUD；health_extension 已在 maxhealth modifier 变化时调用 ForceUpdateHUD(true)。

现有参考：scripts/components/ark_elite.lua 使用 health.maxhealthaddmodifiers 管理精英等级生命奖励。

### 最小生命

health.minhealth 已接入 health.minhealthmodifiers。

它按最大值规则合并，适合“不低于 X 点生命”的下限保护类效果：

```lua
inst.components.health.minhealthmodifiers:SetModifier("my_mod_min_health", 1)
inst.components.health.minhealthmodifiers:RemoveModifier("my_mod_min_health")
```

## Armor / 防御相关修改器

实现位置：modmain/armor_extension.lua

### 当前 armor_extension 提供的能力

armor_extension 目前扩展的是“免疫受击硬直”能力，不是通用防御数值 modifier 容器。

可用接口：

```lua
local armor = inst.components.armor
armor:SetImmuneStun(true)

if armor:IsImmuneStun() then
  -- 当前护甲可免受击硬直
end
```

该能力会在玩家受击时扫描已装备护甲，只要存在耐久大于 0 且 IsImmuneStun() 为 true 的护甲，就跳过受击硬直。

### 防御比例不要写到 armor 组件里

如果你要做“减伤比例”“防御加成”“伤害吸收”这类数值效果，当前项目内的正确入口仍然是 health.externalabsorbmodifiers，而不是 armor_extension。

推荐写法：

```lua
local health = inst.components.health
health.externalabsorbmodifiers:SetModifier(inst, 0.2, "my_mod_defense")
health.externalabsorbmodifiers:RemoveModifier(inst, "my_mod_defense")
```

现有参考：scripts/components/ark_elite.lua 使用 health.externalabsorbmodifiers:SetModifier(self.inst, bonus, "ark_elite_defense") 处理防御奖励。

禁止做法：

1. 不要假设 armor_extension 已经提供 armor.defensemodifiers 一类接口。
2. 不要为了减伤效果新增对 armor 当前字段的直接覆写，除非你先确认调用链和兼容性要求。

## 写法约定

1. modifier key 使用稳定字符串，例如 my_system_damage_bonus，不要用临时随机值。
2. 同一来源的 SetModifier 与 RemoveModifier 必须使用同一个 key。
3. source 型 modifier（例如 externalabsorbmodifiers）应保持 source 和 key 都稳定，便于覆盖与清理。
4. 需要新增属性修改器时，优先参考 modmain/modifier_installer.lua 的现有模式，不要另起一套叠加逻辑。

## 技能系统 State 管理

实现位置：scripts/components/ark_skill.lua

### 背景

DST 有存档读档机制，技能运行时数据（如闭包变量、局部状态）在读档后会丢失。
技能系统提供了 `state` 持久化存储，随 `data` 一起序列化，读档自动恢复。

### 接口

```lua
local skill = inst.components.ark_skill:GetSkill("my_skill_id")

skill:SetState("key", value)      -- 设置状态值
skill:GetState("key")             -- 获取状态值
skill:HasState("key")             -- 检查状态是否存在
skill:RemoveState("key")          -- 移除单个状态
skill:ClearState()                -- 清空所有状态
skill:GetAllState()               -- 获取状态副本（浅拷贝）
```

### 生命周期

| 时机 | state 行为 |
|------|-----------|
| 技能创建 | 初始化为空表 `{}` |
| 读档恢复 | 自动恢复（随 `data` 序列化） |
| `Lock()` | 清空（技能完全重置） |
| 技能移除 | 清空 |
| 其他 | **完全由开发者控制** |

### 推荐写法

**激活模式**：在 `OnActivate` 中手动清空，确保每次激活都是干净状态。

```lua
skill:SetOnActivate(function(skill, payload)
  skill:ClearState()
  skill:SetState("target", payload.target)
  skill:SetState("customData", someValue)
end)

skill:SetOnActivateEffect(function(skill, payload)
  local target = skill:GetState("target")  -- 正常激活或读档都能拿到
end)
```

**持续/引导模式**：在 Update 中累积状态，不清空。

```lua
skill:SetOnActivate(function(skill, payload)
  skill:ClearState()
  skill:SetState("elapsed", 0)
  skill:SetState("tickCount", 0)
end)

skill:SetOnUpdate(function(skill, dt)
  local elapsed = skill:GetState("elapsed") or 0
  skill:SetState("elapsed", elapsed + dt)
end)
```

**被动模式**：没有 Activate/Deactivate 边界，state 一直保留。

```lua
skill:SetOnEvent("onattack", function(skill, payload)
  local count = skill:GetState("attackCount") or 0
  skill:SetState("attackCount", count + 1)
end)
```

### 禁止做法

1. 不要用闭包变量或局部表保存技能运行状态，读档后会丢失。
2. 不要在 `OnActivate` 中忘记 `ClearState()`，可能导致上次激活的残留数据影响本次逻辑。
3. 不要直接读写 `skill.data.state`，始终使用 `SetState/GetState` 等封装接口。
