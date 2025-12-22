local function OnRemoveEntity(inst)
	ArkLogger:Trace('[net_state_classified]', 'OnRemoveEntity')
	if inst._state ~= nil then
		inst._state:DetachClassified()
	end
end

local function OnEntityReplicated(inst)
		local parent = inst.entity:GetParent()
		if parent == nil then
			ArkLogger:Trace('[net_state_classified]', 'OnEntityReplicated parent == nil')
			return
		end
		if not inst:IsValid() then
			return
		end
		-- 通过字符串 key（path#idx）在 parent 上查找对应的 NetState
		local key = inst._net_state_key:value()
		ArkLogger:Trace('[net_state_classified]', 'OnEntityReplicated', key)
		local state_by_key = parent._ns_state_by_key
		local state = state_by_key and state_by_key[key] or nil
		if state == nil then
			-- NetState 尚未在该 parent 上完成初始化，记录到 pending 表中，
			-- 等 NetStateInit 在客户端跑完后再由其主动完成 AttachClassified。
			ArkLogger:Trace('[net_state_classified]', 'OnEntityReplicated state == nil, push pending', key)
			parent._ns_pending_classified = parent._ns_pending_classified or {}
			parent._ns_pending_classified[key] = inst
		else
			inst._state = state
			state:AttachClassified(inst)
		end
	end

local function fn()
	local inst = CreateEntity()
	if TheWorld.ismastersim then
		inst.entity:AddTransform()
	end
	inst.entity:AddNetwork()
	inst.entity:Hide()
	inst:AddTag("CLASSIFIED")
	-- 使用字符串 key（path#idx）作为 NetState 身份标识
	inst._net_state_key = net_string(inst.GUID, "net_state_classified._net_state_key", "keydirty")
	inst.entity:SetPristine()
	
	if not TheWorld.ismastersim then
		inst:ListenForEvent("keydirty", function()
			OnEntityReplicated(inst)
		end)
		-- inst.OnEntityReplicated = OnEntityReplicated
		inst.OnRemoveEntity = OnRemoveEntity
		return inst
	end
	inst.persists = false
	return inst
end

return Prefab("net_state_classified", fn)
