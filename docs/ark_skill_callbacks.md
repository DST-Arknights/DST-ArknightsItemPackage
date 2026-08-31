# 技能与天赋回调语义

技能和天赋共享 Hook、事件监听和生命周期清理基础设施，但二者的状态含义不同。

## 技能

技能具有锁定、充能、持续效果和弹药状态。

| 配置回调 | 触发时机 |
| --- | --- |
| `OnUnlocked` | 技能从锁定状态解锁 |
| `OnLocked` | 技能被锁定 |
| `OnActivate` | 消耗一次可激活次数并进入持续效果或弹药状态 |
| `OnActivateEffect` | 应用持续效果；正常激活和读档恢复激活态时都会触发 |
| `OnDeactivate` | 持续效果或弹药状态结束 |
| `OnRecast` | 已激活的持续型技能再次使用 |

运行时注册接口与配置名一致，例如 `SetOnActivate`、`SetOnDeactivate`、`SetOnUnlocked` 和 `SetOnLocked`。

需要读档后恢复的持续效果应放在 `OnActivateEffect`，首次施放行为放在 `OnActivate`。

## 天赋

天赋只有锁定和解锁两态，没有技能式的充能或持续状态。因此规范名称是：

| 配置回调 | 触发时机 |
| --- | --- |
| `OnUnlocked` | 天赋解锁并开始生效；读档恢复激活态时也会触发 |
| `OnLocked` | 天赋锁定并停止生效 |
| `OnLevelChange` | 天赋等级变化 |

运行时规范接口是：

```lua
talent:SetOnUnlocked(fn)
talent:UnsetOnUnlocked(fn)
talent:SetOnLocked(fn)
talent:UnsetOnLocked(fn)
```

旧的 `OnActivate`、`OnDeactivate`、`SetOnActivate` 和 `SetOnDeactivate` 继续作为兼容别名，分别等同于 Unlocked 和 Locked。新代码应使用规范名称；同一配置同时提供新旧名称时，新名称优先。

## 激活期间辅助接口

技能和天赋都可以使用：

```lua
item:HookFunctionWhileActivating(obj, funcName, fn)
item:ListenForEventWhileActivating(event, fn, source)
```

对技能，“Activating”表示 BUFFING 或 BULLETING；对天赋表示已解锁的 ACTIVE 状态。这些接口会在退出对应状态或 item 被移除时自动清理。
