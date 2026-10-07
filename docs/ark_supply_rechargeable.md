# 充能站接入：ark_supply_rechargeable

其他 DST 模组可在被充能实体上添加 `ark_supply_rechargeable`，接入便携式补给站。通过检查组件文件实现可选兼容，无需声明物品包依赖。

## 注册与移除

```lua
-- 匿名注册，返回的 key 可按需保存。
local key = inst.components.ark_supply_rechargeable:AddRechargeHandler(fn)
-- 指定 key 注册，同 key 再次注册会覆盖回调。
inst.components.ark_supply_rechargeable:AddRechargeHandler("my_mod:charge", fn)
-- 按 key 移除。
inst.components.ark_supply_rechargeable:RemoveRechargeHandler(key)
```

`fn` 必填，`key` 可选。省略 `key` 时自动生成独立 key，每次匿名注册互不覆盖；接口返回传入或生成的 key，可按需保存用于移除。

各回调按首次注册顺序执行；同 `key` 覆盖时保留原位置，移除后重新注册则排到末尾。

只需提供一个执行回调：

```lua
fn(inst, charger, availableCharge) -- 返回 consumedCharge
```

| 参数 / 返回值 | 含义 |
| --- | --- |
| `inst` | 被充能实体，即组件所属实体。 |
| `charger` | 提供充能的充能站实体。 |
| `availableCharge` | 轮到本组时，充能站本次还能提供的额度。 |
| `consumedCharge` | 本组实际使用的额度，返回 `0` 到 `availableCharge`；未充能返回 `0`。 |

额度和返回值均以**充能站燃料单位**计量。回调自行检查需求、补充自己的资源，并返回实际使用的额度；无需充能时返回 `0`。

## 触发流程

充电桩部署且有燃料时，会定期扫描附近实体；发现已接入的实体后，按注册顺序执行其充能回调。每个回调收到的是本轮剩余可提供额度。

充电桩累计该实体各回调返回的实际使用量，统一扣除燃料，并在实体头顶显示一次 `+总量`。燃料扣除和数值提示由充电桩负责。

## 可选兼容示例

以下是被充能实体的最简完整 prefab。回调定义在顶层，供各实体共用；外观与自身资源由接入方补充，示例回调仅展示参数和处理步骤。

```lua
local function OnRecharge(inst, charger, availableCharge)
    -- inst：当前被充能实体；charger：提供充能的实体。
    -- availableCharge：本次还能提供的额度。
    -- 根据自身需求，在额度内补充技能能量、耐久等资源。
    -- 返回实际使用的额度（0 到 availableCharge），无需充能返回 0。
    return 0
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end
    -- 接受充能站充能. 由充能站调用回调函数
    if softresolvefilepath("scripts/components/ark_supply_rechargeable.lua", true) ~= nil then
        inst:AddComponent("ark_supply_rechargeable")
        inst.components.ark_supply_rechargeable:AddRechargeHandler(OnRecharge)
    end

    return inst
end

return Prefab("xxx", fn)
```
