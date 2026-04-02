-- modmain.lua

local WINDOW = 1.2
local DEAD_ZONE = 0.001
local STEP_MORE = 0.010
local STEP_MOST = 0.025

local function DeltaToAnim(delta)
    local abs_delta = math.abs(delta)
    if abs_delta <= DEAD_ZONE then
        return "neutral"
    end

    local suffix = (abs_delta >= STEP_MOST and "_most")
        or (abs_delta >= STEP_MORE and "_more")
        or ""

    return (delta > 0 and "arrow_loop_increase" or "arrow_loop_decrease") .. suffix
end

AddClassPostConstruct("widgets/healthbadge", function(self)
    local old_OnUpdate = self.OnUpdate

    self._extra_arrow_anim = nil
    self._extra_arrow_time = GetTime()
    self._extra_arrow_pct = self.owner.replica.health:GetPercent()

    self.OnUpdate = function(inst, dt)
        old_OnUpdate(inst, dt)

        if inst.arrowdir ~= "neutral" then
            inst._extra_arrow_anim = nil
            inst._extra_arrow_time = GetTime()
            inst._extra_arrow_pct = inst.owner.replica.health:GetPercent()
            return
        end

        local now = GetTime()
        local pct = inst.owner.replica.health:GetPercent()
        local delta = pct - inst._extra_arrow_pct
        local anim = DeltaToAnim(delta)

        if anim ~= "neutral" then
            if anim ~= inst._extra_arrow_anim then
                inst.sanityarrow:GetAnimState():PlayAnimation(anim, true)
                inst._extra_arrow_anim = anim
            end
        elseif inst._extra_arrow_anim ~= nil then
            inst.sanityarrow:GetAnimState():PlayAnimation("neutral", true)
            inst._extra_arrow_anim = nil
        end

        if now - inst._extra_arrow_time >= WINDOW then
            inst._extra_arrow_time = now
            inst._extra_arrow_pct = pct
        end
    end
end)