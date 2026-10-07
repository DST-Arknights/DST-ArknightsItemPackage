# 充能站接入：ark_supply_rechargeable

其他 DST 模组可通过此组件接入便携式补给站，无需 `ark_character` 标签，也无需使用方舟技能系统。

接入方仅做可选兼容，无需声明物品包依赖，也不主动添加此组件。在服务端检查目标是否已有 `ark_supply_rechargeable`，有组件才注册，没有就跳过。物品包启用时会为所有玩家添加此组件。

## 两个回调接口

| 设置接口 | 回调签名 | 作用与返回值 |
| --- | --- | --- |
| `SetGetRechargeAmountFn(fn)` | `fn(target, charger, data)` | 查询当前需求，返回非负数；无需求返回 `0`。查询可能重复调用，不应修改资源或产生其他副作用。 |
| `SetRechargeFn(fn)` | `fn(target, charger, amount, data)` | 执行充能，返回实际接受量 `accepted`，范围为 `0` 到 `amount`；未充能返回 `0`。充能站按此值扣燃料。 |

- `target`：接收充能的实体；`charger`：充能站实体。
- 需求、`amount`、`accepted` 均以**充能站燃料单位**计量。自己的技能能量、耐久等资源如何换算，由接入方决定。
- `data.charger` 是充能站实体，`data.requested` 是本次报价；执行时以 `amount` 为准，它可能因其他处理器先接收充能而减少。
- 执行回调必须返回数值。返回 `nil`、`false` 或负数会按 `0` 处理；不要已经增加资源却漏掉返回值，否则充能站不会扣燃料。

## 推荐：成组注册，避免覆盖其他模组

上述 `Set...` 会替换同名接口此前设置的回调。多模组共存时，推荐用 `AddRechargeGroup(key, defs)` 同时注册两项回调；移除时调用 `RemoveRechargeGroup(key)`。`key` 使用包含自己模组名的唯一字符串，同一 `key` 重复注册会替换原分组。

以下示例放在接入方 `modmain.lua`，仅对已有 `ark_supply_rechargeable` 和 `fueled` 组件的实体生效，按 1 点供能换 1 点目标燃料；将 `your_prefab` 和分组名替换成自己的名称。

物品包通过 `AddPlayerPostInit` 添加玩家组件，其执行晚于指定角色的 `AddPrefabPostInit`。因此示例用 `DoTaskInTime(0, ...)` 等当前初始化结束后再检查，避免漏掉兼容注册。

```lua
local RECHARGE_GROUP = "your_mod:fuel_charge"

AddPrefabPostInit("your_prefab", function(inst)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    inst:DoTaskInTime(0, function()
        local rechargeable = inst.components.ark_supply_rechargeable
        if rechargeable == nil then
            return
        end

        rechargeable:AddRechargeGroup(RECHARGE_GROUP, {
            getrechargeamountfn = function(target, charger, data)
                local fuel = target.components.fueled
                return fuel ~= nil and math.max(0, fuel.maxfuel - fuel.currentfuel) or 0
            end,
            rechargefn = function(target, charger, amount, data)
                local fuel = target.components.fueled
                if fuel == nil then
                    return 0
                end
                local before = fuel.currentfuel
                local accepted = math.min(amount, math.max(0, fuel.maxfuel - before))
                if accepted > 0 then
                    fuel:DoDelta(accepted)
                end
                return math.max(0, fuel.currentfuel - before)
            end,
        })
    end)
end)

-- 停用自己的接入逻辑时，在对应实体上移除自己的分组：
-- local rechargeable = inst.components.ark_supply_rechargeable
-- if rechargeable ~= nil then
--     rechargeable:RemoveRechargeGroup(RECHARGE_GROUP)
-- end
```

多个分组共享本次供能预算，分组间执行顺序不保证；执行回调仍需检查资源是否已满、当前状态是否允许充能。组件不会保存这些回调，读档后通过初始化代码重新注册。

## 扫描条件

补给站部署且有燃料时才充能，当前每秒扫描半径 `16`，每个目标每次最多提供 `5` 单位。扫描排除带 `INLIMBO`、`FX`、`NOCLICK`、`DECOR`、`playerghost` 标签的实体；背包或装备中的物品不会直接被扫描，可在持有者的组件上注册回调，再操作其物品资源。配方的 `ark_character` 限制只影响制作资格。
