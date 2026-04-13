local function PlaySound(inst, sound)
    inst.SoundEmitter:PlaySound(sound)
end


-- t.loop: 是否循环播放动画，循环时不会自动消失
-- t.scale_with_parent_size: 是否按父实体的 combat fx 尺寸自适应缩放
local function MakeFx(t)
    local assets
    if t.build_is_skin then
        assets = {
            Asset("DYNAMIC_ANIM", "anim/dynamic/"..t.build..".zip"),
            Asset("PKGREF", "anim/dynamic/"..t.build..".dyn"),
        }
    else
        assets = {
            Asset("ANIM", "anim/"..t.build..".zip"),
        }
    end

    local function startfx(proxy)
        --print ("SPAWN", debugstack())
        local inst = CreateEntity(t.name)
        proxy.fx_ent = inst

        inst.entity:AddTransform()
        inst.entity:AddAnimState()

        local parent = proxy.entity:GetParent()
        if parent ~= nil then
            inst.entity:SetParent(parent.entity)
        end

        if t.nameoverride == nil and t.description == nil then
            inst:AddTag("FX")
        end
        --[[Non-networked entity]]
        inst.entity:SetCanSleep(false)
        inst.persists = false

        inst.Transform:SetFromProxy(proxy.GUID)

        if t.autorotate and parent ~= nil then
            inst.Transform:SetRotation(parent.Transform:GetRotation())
        end

        if t.sound ~= nil then
            inst.entity:AddSoundEmitter()
            if t.update_while_paused then
                inst:DoStaticTaskInTime(t.sounddelay or 0, PlaySound, t.sound)
            else
                inst:DoTaskInTime(t.sounddelay or 0, PlaySound, t.sound)
            end
        end

        if t.sound2 ~= nil then
            if inst.SoundEmitter == nil then
                inst.entity:AddSoundEmitter()
            end
            if t.update_while_paused then
                inst:DoStaticTaskInTime(t.sounddelay2 or 0, PlaySound, t.sound2)
            else
                inst:DoTaskInTime(t.sounddelay2 or 0, PlaySound, t.sound2)
            end
        end

        inst.AnimState:SetBank(t.bank)
        inst.AnimState:SetBuild(t.build)
        inst.AnimState:PlayAnimation(FunctionOrValue(t.anim), t.loop == true) -- 支持循环
        if t.update_while_paused then
            inst.AnimState:AnimateWhilePaused(true)
        end
        if t.tint ~= nil then
            inst.AnimState:SetMultColour(t.tint.x, t.tint.y, t.tint.z, t.tintalpha or 1)
        elseif t.tintalpha ~= nil then
            inst.AnimState:SetMultColour(1, 1, 1, t.tintalpha)
        end
        --print(inst.AnimState:GetMultColour())
        if t.transform ~= nil then
            inst.AnimState:SetScale(t.transform:Get())
        end

        if t.nameoverride ~= nil then
            if inst.components.inspectable == nil then
                inst:AddComponent("inspectable")
            end
            inst.components.inspectable.nameoverride = t.nameoverride
            inst.name = t.nameoverride
        end

        if t.description ~= nil then
            if inst.components.inspectable == nil then
                inst:AddComponent("inspectable")
            end
            inst.components.inspectable.descriptionfn = t.description
        end

        if t.bloom then
            inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        end

        -- loop 特效需要跟随 proxy 生命周期，但不能直接传 inst.Remove，
        -- 否则 onremove 回调会对 proxy 自身再次调用 Remove 导致递归。
        if t.loop then
            inst:ListenForEvent("onremove", function()
                if inst:IsValid() then
                    inst:Remove()
                    proxy.fx_ent = nil
                end
            end, proxy)
        else
            if t.animqueue then
                inst:ListenForEvent("animqueueover", inst.Remove)
            else
                inst:ListenForEvent("animover", inst.Remove)
            end
        end

        if t.fn ~= nil then
            if t.fntime ~= nil then
                if t.update_while_paused then
                    inst:DoStaticTaskInTime(t.fntime, t.fn, proxy)
                else
                    inst:DoTaskInTime(t.fntime, t.fn, proxy)
                end
            else
                t.fn(inst, proxy)
            end
        end

        if t.scale_with_parent_size and parent ~= nil then
            local r = GetCombatFxSize(parent)
            local scalex, scaley, scalez = parent.Transform:GetScale()
            local selfscalex, selfscaley, selfscalez = inst.Transform:GetScale()
            inst.Transform:SetScale(r / scalex * selfscalex, r / scaley * selfscaley, r / scalez * selfscalez)
        end

        if TheWorld then
            TheWorld:PushEvent("fx_spawned", inst)
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddNetwork()

        --Dedicated server does not need to spawn the local fx
        if not TheNet:IsDedicated() then
            --Delay one frame so that we are positioned properly before starting the effect
            --or in case we are about to be removed
            if t.update_while_paused then
                inst:DoStaticTaskInTime(0, startfx, inst)
            else
                inst:DoTaskInTime(0, startfx, inst)
            end
        end

        if t.twofaced then
            inst.Transform:SetTwoFaced()
        elseif t.eightfaced then
            inst.Transform:SetEightFaced()
        elseif t.sixfaced then
            inst.Transform:SetSixFaced()
        elseif not t.nofaced then
            inst.Transform:SetFourFaced()
        end

        inst:AddTag("FX")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false
        if not t.loop then
            inst:DoTaskInTime(1, inst.Remove)
        end

        return inst
    end

    return Prefab(t.name, fn, assets)
end

GLOBAL.ArkMakeFx = MakeFx
