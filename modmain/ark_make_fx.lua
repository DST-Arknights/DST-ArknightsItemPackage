local function PlaySound(inst, sound)
    inst.SoundEmitter:PlaySound(sound)
end

local PAD_DURATION = .1
local FLASH_TIME = .3

local function StartPing(inst, duration, scaleup, update_while_paused)
    if not inst:IsValid() then
        return
    end

    -- Cache after all visual initialization. Only the local Transform changes;
    -- changing the network proxy scale here would apply its scale twice.
    local scalex, scaley, scalez = inst.Transform:GetScale()
    local multcolour = { inst.AnimState:GetMultColour() }
    local addcolour = { inst.AnimState:GetAddColour() }
    local gettime = update_while_paused and GetStaticTime or GetTime
    local t0 = gettime()

    local function UpdatePing()
        local elapsed = gettime() - t0
        local progress = elapsed >= duration and 1
            or math.min(1, math.max(0, (elapsed - PAD_DURATION) / math.max(.001, duration - PAD_DURATION)))
        local k = 1 - (1 - progress) * (1 - progress)
        local scale = Lerp(1, scaleup, k)
        inst.Transform:SetScale(scalex * scale, scaley * scale, scalez * scale)
        inst.AnimState:SetMultColour(multcolour[1], multcolour[2], multcolour[3], (1 - k) * multcolour[4])

        local flash = math.min(1, elapsed / FLASH_TIME)
        local colour = math.max(0, 1 - flash * flash)
        inst.AnimState:SetAddColour(colour * addcolour[1], colour * addcolour[2], colour * addcolour[3], colour * addcolour[4])
    end

    local function FinishPing()
        UpdatePing()
        inst:Remove()
    end

    UpdatePing()
    if update_while_paused then
        inst:DoStaticPeriodicTask(0, UpdatePing)
        inst:DoStaticTaskInTime(duration, FinishPing)
    else
        inst:DoPeriodicTask(0, UpdatePing)
        inst:DoTaskInTime(duration, FinishPing)
    end
end

-- t.loop: 是否循环播放动画，循环时不会自动消失
-- t.scale_with_parent_size: 是否按父实体的 combat fx 尺寸自适应缩放
-- t.ping: true 或 { duration = .5, scaleup = 1.036 }，总寿命内扩散并淡出
local function MakeFx(t)
    local ping = t.ping == true and {} or t.ping
    local pingduration = ping and (ping.duration or .5)
    local pingscaleup = ping and (ping.scaleup or 1.036)
    if ping then
        assert(pingduration > 0, "ArkMakeFx ping duration must be positive")
    end
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

        -- loop/ping 特效需要跟随 proxy 生命周期，但不能直接传 inst.Remove，
        -- 否则 onremove 回调会对 proxy 自身再次调用 Remove 导致递归。
        if t.loop or ping then
            inst:ListenForEvent("onremove", function()
                if inst:IsValid() then
                    inst:Remove()
                    proxy.fx_ent = nil
                end
            end, proxy)
            if ping then
                inst:ListenForEvent("onremove", function()
                    proxy.fx_ent = nil
                end)
            end
        else
            if t.animqueue then
                inst:ListenForEvent("animqueueover", inst.Remove)
            else
                inst:ListenForEvent("animover", inst.Remove)
            end
        end

        if t.fn ~= nil then
            if t.fntime ~= nil then
                local callback = t.fn
                if ping then
                    callback = function(fx, fxproxy)
                        t.fn(fx, fxproxy)
                        StartPing(fx, pingduration, pingscaleup, t.update_while_paused)
                    end
                end
                if t.update_while_paused then
                    inst:DoStaticTaskInTime(t.fntime, callback, proxy)
                else
                    inst:DoTaskInTime(t.fntime, callback, proxy)
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

        if ping and (t.fn == nil or t.fntime == nil) then
            StartPing(inst, pingduration, pingscaleup, t.update_while_paused)
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
        if ping then
            local delay = t.fn ~= nil and math.max(0, t.fntime or 0) or 0
            local lifetime = delay + pingduration + FRAMES
            if t.update_while_paused then
                inst:DoStaticTaskInTime(lifetime, inst.Remove)
            else
                inst:DoTaskInTime(lifetime, inst.Remove)
            end
        elseif not t.loop then
            inst:DoTaskInTime(1, inst.Remove)
        end

        return inst
    end

    return Prefab(t.name, fn, assets)
end

GLOBAL.ArkMakeFx = MakeFx
