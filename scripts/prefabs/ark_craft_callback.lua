-- 隐形制造回调载体
-- 专用于"制作物品仅触发回调、不需要真正产物"的配方（如精英/技能升级）：
-- 配方把 product 指向本预制体，并在 recipe 上挂 OnBuiltFn 回调（对外接口）。
-- builder.DoBuild 生成本预制体后：
--   onPreBuilt 仅记录回调（此时材料尚未扣除）
--   OnBuiltFn  触发回调并删除自身（此时材料已扣除、产物已落地）
-- 配方需设置 dropitem=true：产物直接掉落在地，不会进入玩家物品栏。
local GHOST_LIFETIME = 1

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")
    -- 必须有 inventoryitem，builder 才会调用 onPreBuilt（builder.lua:725）
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.nobounce = true

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    -- 兜底：任何途径生成的幽灵（含命令行 c_spawn）到时自删，避免残留
    inst:DoTaskInTime(GHOST_LIFETIME, function(ghost)
        if ghost ~= nil and ghost:IsValid() then
            ghost:Remove()
        end
    end)

    inst.onPreBuilt = function(ghost, builder, materials, recipe)
        -- 内部暂存用下划线，避免与上方原版 inst.OnBuiltFn 方法同名冲突
        ghost._onBuiltFn = recipe ~= nil and recipe.OnBuiltFn or nil
    end

    inst.OnBuiltFn = function(ghost, builder)
        local cb = ghost._onBuiltFn
        ghost._onBuiltFn = nil
        if cb ~= nil then
            cb(ghost, builder)
        end
        ghost:Remove()
    end

    return inst
end

return Prefab("ark_craft_callback", fn)
