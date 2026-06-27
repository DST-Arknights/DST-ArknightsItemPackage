local STATES = {
  SAD = "sad",
  ANGRY = "angry",
  CONFUSED = "confused",
  HAPPY = "happy",
}

local STATE_ORDER = {
  STATES.SAD,
  STATES.ANGRY,
  STATES.CONFUSED,
  STATES.HAPPY,
}

local CHECK_INTERVAL = 1
local SAD_MIN_DURATION = 30
local ANGRY_ENTER_ROUNDS = 8
local ANGRY_EXIT_ROUNDS = 8
local CONFUSED_ENTER_ROUNDS = 20
local CONFUSED_EXIT_ROUNDS = 1
local HAPPY_ENTER_ROUNDS = 1
local HAPPY_EXIT_ROUNDS = 1
local LOW_HEALTH_THRESHOLD = 30

local function GetNow()
  return GetTime()
end

local function EnsureStateRuntimeData(self, state)
  self.data.state_runtime = self.data.state_runtime or {}
  self.data.state_runtime[state] = self.data.state_runtime[state] or {
    enter_rounds = 0,
    exit_rounds = 0,
  }
  return self.data.state_runtime[state]
end

local function ResetStateRuntimeData(self, state)
  local runtime = EnsureStateRuntimeData(self, state)
  runtime.enter_rounds = 0
  runtime.exit_rounds = 0
end

local function IsPlayerDead(player)
  return player ~= nil
    and player.components ~= nil
    and player.components.health ~= nil
    and player.components.health:IsDead()
end

local function IsPlayerAlive(player)
  return player ~= nil and player:IsValid() and not IsPlayerDead(player)
end

local function BuildNearbyPlayers(self)
  local nearbyPlayerSet = {}
  local players = {}
  for item in pairs(self._equipped_items) do
    if item:IsValid() then
      for player in pairs(item.components.playerprox.closeplayers) do
        if player ~= self.inst and IsPlayerAlive(player) and not nearbyPlayerSet[player] then
          nearbyPlayerSet[player] = true
          table.insert(players, player)
        end
      end
    end
  end
  return players
end

local function GetHealth(player)
  if player == nil or player.components == nil or player.components.health == nil then
    return math.huge
  end
  return player.components.health.currenthealth or math.huge
end

local function HasOtherPlayerDead(self)
  for _, player in ipairs(AllPlayers) do
    if player ~= self.inst and IsPlayerDead(player) then
      return true
    end
  end
  return false
end

local function HasLowHealthNearbyPlayer(nearbyPlayers)
  for _, player in ipairs(nearbyPlayers) do
    if GetHealth(player) <= LOW_HEALTH_THRESHOLD then
      return true
    end
  end
  return false
end

local function IsSelfLowHealthAndNotInCombat(self)
  return GetHealth(self.inst) <= LOW_HEALTH_THRESHOLD and not self:IsInCombat()
end

local function BuildContext(self)
  local now = GetNow()
  local nearbyPlayers = BuildNearbyPlayers(self)
  local hasNearbyPlayer = #nearbyPlayers > 0
  local hasOtherPlayerDead = HasOtherPlayerDead(self)
  local hasLowHealthNearbyPlayer = HasLowHealthNearbyPlayer(nearbyPlayers)
  local isSelfLowHealthAndNotInCombat = IsSelfLowHealthAndNotInCombat(self)

  return {
    now = now,
    nearby_players = nearbyPlayers,
    has_nearby_player = hasNearbyPlayer,
    has_other_player_dead = hasOtherPlayerDead,
    has_low_health_nearby_player = hasLowHealthNearbyPlayer,
    is_self_low_health_and_not_in_combat = isSelfLowHealthAndNotInCombat,
    is_in_combat = self:IsInCombat(now),
    has_equipped_item = self:HasEquippedItem(),
  }
end

local function GetStateDefs(self)
  return {
    [STATES.SAD] = {
      priority = 100,
      min_duration = SAD_MIN_DURATION,
      enter_rounds = 1,
      exit_rounds = 1,
      can_enter = function(component, context)
        return context.has_other_player_dead
          or context.has_low_health_nearby_player
          or context.is_self_low_health_and_not_in_combat
      end,
      can_exit = function(component, context)
        return not (context.has_other_player_dead
          or context.has_low_health_nearby_player
          or context.is_self_low_health_and_not_in_combat)
      end,
    },
    [STATES.ANGRY] = {
      priority = 80,
      min_duration = 0,
      enter_rounds = ANGRY_ENTER_ROUNDS,
      exit_rounds = ANGRY_EXIT_ROUNDS,
      can_enter = function(component, context)
        return context.is_in_combat
      end,
      can_exit = function(component, context)
        return not context.is_in_combat
      end,
    },
    [STATES.CONFUSED] = {
      priority = 10,
      min_duration = 0,
      enter_rounds = CONFUSED_ENTER_ROUNDS,
      exit_rounds = CONFUSED_EXIT_ROUNDS,
      can_enter = function(component, context)
        return not context.has_nearby_player
      end,
      can_exit = function(component, context)
        return context.has_nearby_player
      end,
    },
    [STATES.HAPPY] = {
      priority = 20,
      min_duration = 0,
      enter_rounds = HAPPY_ENTER_ROUNDS,
      exit_rounds = HAPPY_EXIT_ROUNDS,
      can_enter = function(component, context)
        return context.has_nearby_player
      end,
      can_exit = function(component, context)
        return not context.has_nearby_player
      end,
    },
  }
end

local SympatheticPendant = Class(function(self, inst)
  self.inst = inst
  self.data = {
    state = STATES.CONFUSED,
    state_since = 0,
    state_runtime = {},
    private = {
      equipped = false,
      last_attack_time = nil,
      last_attacked_time = nil,
    },
    playerdata = {},
  }

  self._equipped_items = {}
  self._state_defs = GetStateDefs(self)
  self._enter_callbacks = {}
  self._exit_callbacks = {}
  self._change_callbacks = {}
  self._task = nil

  self:_ListenCombatEvents()
end)

function SympatheticPendant:_ListenCombatEvents()
  self.inst:ListenForEvent("onattackother", function()
    self.data.private.last_attack_time = GetNow()
  end)

  self.inst:ListenForEvent("attacked", function()
    self.data.private.last_attacked_time = GetNow()
  end)
end

function SympatheticPendant:HasEquippedItem()
  return next(self._equipped_items) ~= nil
end

function SympatheticPendant:IsInCombat(now)
  now = now or GetNow()
  local lastAttackTime = self.data.private.last_attack_time
  local lastAttackedTime = self.data.private.last_attacked_time

  if lastAttackTime ~= nil and now - lastAttackTime < ANGRY_EXIT_ROUNDS then
    return true
  end

  if lastAttackedTime ~= nil and now - lastAttackedTime < ANGRY_EXIT_ROUNDS then
    return true
  end

  return false
end

function SympatheticPendant:SetEquippedItem(item)
  if item == nil then
    return
  end
  self._equipped_items[item] = true
  self.data.private.equipped = true
  self:_StartTask()
  self:EvaluateState(true)
end

function SympatheticPendant:RemoveEquippedItem(item)
  if item == nil then
    return
  end
  self._equipped_items[item] = nil
  self.data.private.equipped = self:HasEquippedItem()
  if not self.data.private.equipped then
    self:_StopTask()
  else
    self:EvaluateState(true)
  end
end

function SympatheticPendant:OnNearbyPlayersChanged()
  self:EvaluateState(true)
end

function SympatheticPendant:_StartTask()
  if self._task ~= nil then
    return
  end
  self._task = self.inst:DoPeriodicTask(CHECK_INTERVAL, function()
    self:EvaluateState()
  end)
end

function SympatheticPendant:_StopTask()
  if self._task ~= nil then
    self._task:Cancel()
    self._task = nil
  end
end

function SympatheticPendant:GetState()
  return self.data.state or STATES.CONFUSED
end

function SympatheticPendant:GetStateDuration(now)
  now = now or GetNow()
  return math.max(0, now - (self.data.state_since or 0))
end

function SympatheticPendant:SetOnEnterState(state, fn)
  self._enter_callbacks[state] = fn
end

function SympatheticPendant:SetOnExitState(state, fn)
  self._exit_callbacks[state] = fn
end

function SympatheticPendant:SetOnStateChanged(fn)
  table.insert(self._change_callbacks, fn)
end

function SympatheticPendant:_CanSwitchFromCurrent(context, targetState)
  local currentState = self:GetState()
  if currentState == nil or currentState == targetState then
    return true
  end

  local currentDef = self._state_defs[currentState]
  if currentDef == nil then
    return true
  end

  local targetDef = self._state_defs[targetState]
  if targetDef == nil then
    return true
  end

  -- 高优先级状态可以强制打断低优先级状态
  if targetDef.priority > currentDef.priority then
    return true
  end

  -- 最小持续时间保护
  if currentDef.min_duration ~= nil and self:GetStateDuration(context.now) < currentDef.min_duration then
    return false
  end

  -- 同优先级或低优先级需要检查退出条件
  local currentRuntime = EnsureStateRuntimeData(self, currentState)
  local canExit = currentDef.can_exit == nil or currentDef.can_exit(self, context)
  currentRuntime.exit_rounds = canExit and (currentRuntime.exit_rounds + 1) or 0
  return currentRuntime.exit_rounds >= (currentDef.exit_rounds or 1)
end

function SympatheticPendant:_GetCandidateState(context)
  local chosenState = nil
  local chosenPriority = -math.huge

  for _, state in ipairs(STATE_ORDER) do
    local def = self._state_defs[state]
    local runtime = EnsureStateRuntimeData(self, state)
    local canEnter = def.can_enter ~= nil and def.can_enter(self, context) or false
    runtime.enter_rounds = canEnter and (runtime.enter_rounds + 1) or 0
    if canEnter and runtime.enter_rounds >= (def.enter_rounds or 1) and def.priority > chosenPriority then
      chosenState = state
      chosenPriority = def.priority
    end
  end

  return chosenState
end

function SympatheticPendant:_RunStateCallbacks(previousState, nextState, context)
  local exitCallback = previousState ~= nil and self._exit_callbacks[previousState] or nil
  if exitCallback ~= nil then
    exitCallback(self, previousState, nextState, context)
  end

  local enterCallback = nextState ~= nil and self._enter_callbacks[nextState] or nil
  if enterCallback ~= nil then
    enterCallback(self, previousState, nextState, context)
  end

  for _, callback in ipairs(self._change_callbacks) do
    callback(self, previousState, nextState, context)
  end
end

function SympatheticPendant:ChangeState(nextState, context)
  local previousState = self:GetState()
  if previousState == nextState then
    return false
  end

  self.data.state = nextState
  self.data.state_since = context.now
  for _, state in ipairs(STATE_ORDER) do
    ResetStateRuntimeData(self, state)
  end

  self.inst:PushEvent("sympathetic_pendant_state_dirty", {
    previous_state = previousState,
    state = nextState,
  })
  self:_RunStateCallbacks(previousState, nextState, context)
  return true
end

function SympatheticPendant:EvaluateState(force)
  if not force and not self:HasEquippedItem() then
    return
  end

  local context = BuildContext(self)
  if not context.has_equipped_item then
    return
  end

  local candidateState = self:_GetCandidateState(context)
  local currentState = self:GetState()
  if candidateState == nil or candidateState == currentState then
    return
  end

  if not self:_CanSwitchFromCurrent(context, candidateState) then
    return
  end

  self:ChangeState(candidateState, context)
end

function SympatheticPendant:SetPlayerData(inst, data)
  if not inst or not inst.userid then
    return
  end
  self.data.playerdata = self.data.playerdata or {}
  local userData = self.data.playerdata[inst.userid] or {}
  userData = MergeMaps(userData, data)
  self.data.playerdata[inst.userid] = userData
end

function SympatheticPendant:GetPlayerData(inst)
  if not inst or not inst.userid then
    return nil
  end
  self.data.playerdata = self.data.playerdata or {}
  return self.data.playerdata[inst.userid]
end

function SympatheticPendant:SetData(data)
  self.data = data or {}
  self.data.private = self.data.private or {
    equipped = false,
    last_attack_time = nil,
    last_attacked_time = nil,
  }
  self.data.playerdata = self.data.playerdata or self.data.players or {}
  self.data.players = nil
  self.data.state = self.data.state or STATES.CONFUSED
  self.data.state_since = self.data.state_since or 0
  self.data.state_runtime = self.data.state_runtime or {}
end

function SympatheticPendant:GetData()
  return self.data
end

function SympatheticPendant:OnSave()
  local data = shallowcopy(self.data)
  data.private = shallowcopy(self.data.private or {})
  data.private.equipped = nil
  return data
end

function SympatheticPendant:OnLoad(data)
  self:SetData(data)
end

return SympatheticPendant
