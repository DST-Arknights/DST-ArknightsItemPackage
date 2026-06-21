# AOE 选择器配置文档

## API

### StartAoeSelect(doer, opts)

启动 AOE 选择器，让玩家选择目标位置。

**参数：**
- `doer`: 执行者实体
- `opts`: 配置选项表
  - `OnSelected`: function(doer, pos) - 选择确认回调（必选）
  - `config`: table - 传递给 prefab 的配置（可选，用于覆盖默认 reticule/aoetargeting 配置）

### StopAoeSelect(doer)

停止当前 AOE 选择器。

## 配置结构

配置分为两个部分：`reticule`（视觉与交互）和 `aoetargeting`（行为）。

### 1. 视觉与交互配置（reticule 表）

| 配置项 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| `reticuleprefab` | string | 指示器预制体名 | `"reticuleaoesmall"` |
| `pingprefab` | string | 点击确认特效 | `"reticuleaoesmallping"` |
| `validcolour` | table | 有效状态 RGBA | `{1, .75, 0, 1}` (橙黄) |
| `invalidcolour` | table | 无效状态 RGBA | `{.5, 0, 0, 1}` (暗红) |
| `ease` | bool | 平滑移动插值 | `true` |
| `smoothing` | number | 平滑系数 | `6.66` (引擎默认) |
| `mouseenabled` | bool | 鼠标驱动 | `true` |
| `twinstickmode` | number | 双摇杆模式 | `1` (自由移动) |
| `twinstickrange` | number | 双摇杆最大偏移 | `8` |
| `targetfn` | function | 目标坐标计算 | 内置 `ReticuleTargetAllowWaterFn` |
| `mousetargetfn` | function | 鼠标坐标修正 | 可选，用于吸附/锁定距离 |
| `validfn` | function | 自定义验证 | 可选，覆盖默认地形检测 |
| `ispassableatallpoints` | bool | 跳过碰撞检测 | `false` |

### 2. 行为配置（aoetargeting 组件）

| 配置项 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| `allowWater` | bool | 允许水面施法 | `false` |
| `deployRadius` | number | 检测半径 | `3` |
| `range` | number | 最大施法距离 | `8` (引擎默认) |
| `alwaysValid` | bool | 永远有效 | `false` |
| `allowRiding` | bool | 骑行时可用 | `true` |
| `targetFX` | string | 选中点常驻 FX | 可选 |

## 使用示例

### 基础用法

```lua
StartAoeSelect(doer, {
  OnSelected = function(doer, pos)
    -- 在 pos 位置生成技能效果
    print("选择了位置:", pos.x, pos.y, pos.z)
  end,
})
```

### 自定义配置

```lua
StartAoeSelect(doer, {
  OnSelected = function(doer, pos)
    -- 技能逻辑
  end,
  config = {
    reticule = {
      reticuleprefab = "reticuleaoe_3",  -- 使用更大的范围圈
      pingprefab = "reticuleaoeping_3",
      twinstickrange = 12,  -- 增加双摇杆范围
      validcolour = {0, 1, 0, 1},  -- 绿色表示有效
    },
    aoetargeting = {
      allowWater = true,  -- 允许水面
      deployRadius = 2,  -- 更大的检测半径
    },
  },
})
```

### 技能系统集成

在技能配置中使用 `targeting` 字段：

```lua
{
  id = "my_aoe_skill",
  activationMode = "manual",
  targeting = {
    mode = "aoe",
    config = {
      reticule = {
        reticuleprefab = "reticuleaoe_3",
        twinstickrange = 12,
      },
      aoetargeting = {
        deployRadius = 3,
      },
    },
  },
  OnActivate = function(skill, payload)
    -- payload.targetPos 包含选择的位置
    local pos = payload.targetPos
    -- 技能效果逻辑
  end,
}
```

## 注意事项

1. **网络同步**：配置通过 `net_string` 网络变量传递，确保主客机一致
2. **异步校验**：选择器是异步过程，`TryActivate` 会在选择完成后再次校验技能状态
3. **预制体选择**：`reticuleprefab` 和 `pingprefab` 必须是游戏中已存在的预制体
4. **颜色格式**：RGBA 格式，每个分量范围 0-1
