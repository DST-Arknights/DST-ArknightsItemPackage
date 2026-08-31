# 目标选择器开发文档

目标选择器采用注册表模式。主客机只同步选择器 id，两端分别从注册表取得同一份配置。当前提供范围落点选择器 `AreaTargetSelector` 和地图坐标选择器 `MapTargetSelector`。

## 注册

使用 `RegisterTargetSelector(id, selector)` 注册选择器。注册代码必须在主客机都会执行的 modmain 环境中运行。

```lua
RegisterTargetSelector("my_skill_aoe", AreaTargetSelector {
  range = 12,
  deployradius = 2,
  reticuleprefab = "reticuleaoe_3",
  pingprefab = "reticuleaoeping_3",
  validcolour = { 0, 1, 0, 1 },
  invalidcolour = { 0.5, 0, 0, 1 },
})
```

`RegisterTargetSelector` 的 id 必须唯一，重复注册会触发断言。
可以通过 `GetTargetSelector(id)` 取回已注册的选择器实例。`TargetSelector` 只是类型基类，不直接提供选择行为。

## AreaTargetSelector 配置

| 配置项 | 类型 | 说明 | 默认值 |
| --- | --- | --- | --- |
| `range` | number | 最大施法距离和手柄初始瞄准距离 | `8` |
| `deployradius` | number | 落点通行性检测半径 | `1` |
| `reticuleprefab` | string | 瞄准指示器 prefab | `"reticule"` |
| `pingprefab` | string | 确认落点时的 ping prefab | `"reticuleping"` |
| `validcolour` | table | 合法落点的 RGBA 颜色 | `{ 1, 0.75, 0, 1 }` |
| `invalidcolour` | table | 非法落点的 RGBA 颜色 | `{ 0.5, 0, 0, 1 }` |
| `mouseenabled` | boolean | 是否允许鼠标驱动瞄准 | `true` |
| `ease` | boolean | 指示器是否平滑移动 | `true` |
| `twinstickmode` | number | 手柄双摇杆模式 | `1` |
| `twinstickrange` | number | 手柄瞄准最大偏移；未设置时跟随 `range` | `range` |
| `validfn` | function | 额外落点校验函数 | `nil` |

`validfn` 使用原版 reticule 签名：

```lua
function(selector_inst, reticule_inst, pos, alwayspassable, allowwater, deployradius)
  return true
end
```

## MapTargetSelector 配置

| 配置项 | 类型 | 说明 | 默认值 |
| --- | --- | --- | --- |
| `validfn` | function | 地图落点校验，客户端用于操作反馈，服务端会再次权威校验 | `nil` |
| `actionstring` | string/function | 地图动作显示文本；函数时签名为 `function(act)` | `nil` |

`validfn` 签名如下：

```lua
function(doer, pos, runtime)
  -- 前两个返回值为是否合法和失败原因。
  -- 可选返回 x、z，用于把最终落点修正到其他坐标。
  return true, nil, pos.x, pos.z
end
```

注册示例：

```lua
RegisterTargetSelector("my_skill_map", MapTargetSelector {
  actionstring = "Select",
  validfn = function(doer, pos, runtime)
    return TheWorld.Map:IsPassableAtPoint(pos.x, 0, pos.z, true)
  end,
})
```

## 直接使用

```lua
local selector = GetTargetSelector("my_skill_aoe")
selector:BeginSelecting(doer,
  function(owner, pos)
    -- 确认选择
  end,
  function(owner)
    -- ESC 或右键取消
  end)
```

使用当前选择器实例结束选择：

```lua
selector:StopSelecting(doer)
```

`BeginSelecting` 成功启动时返回 `true`，运行实体创建失败时返回 `false`。同一玩家开始新的选择时，选择器会先停止并移除上一次的运行实体。

## 技能系统集成

技能配置通过 `targetSelector` 引用已注册的选择器：

```lua
RegisterArkSkill {
  id = "my_aoe_skill",
  activationMode = "manual",
  targetSelector = "my_skill_aoe",
  levels = {
    {
      activationEnergy = 10,
      buffDuration = 5,
    },
  },
  ActivateSelectorTest = function(skill, payload)
    -- 开始瞄准前检查；此时没有 targetPos
    return true
  end,
  ActivateTest = function(skill, payload)
    -- 玩家确认落点后再次检查
    return payload.targetPos ~= nil
  end,
  OnActivate = function(skill, payload)
    local pos = payload.targetPos
    -- 执行技能效果
  end,
}
```

技能激活流程为：

```text
TrySelect
  -> ActivateSelectorTest
  -> BeginSelecting
  -> 玩家确认位置
  -> ActivateTest
  -> Activate
```

## 注意事项

1. 注册代码必须同时在服务端和客户端执行，且同一个 id 的配置应保持一致。
2. 选择器只负责交互和原版落点通行性检查；技能仍应在 `ActivateTest` 中完成业务校验。
3. `range` 会同时写入原版 `aoetargeting`，并用于手柄前向落点搜索；单独设置 `twinstickrange` 可覆盖手柄最大偏移。
4. `reticuleprefab` 和 `pingprefab` 必须是主客机均已加载的 prefab。
5. `BeginSelecting` 是异步流程，开始选择不会消耗技能次数，确认并通过 `ActivateTest` 后才会激活。
6. `MapTargetSelector.validfn` 会在客户端和服务端执行，不要在其中修改游戏状态；最终结果以服务端校验为准。
