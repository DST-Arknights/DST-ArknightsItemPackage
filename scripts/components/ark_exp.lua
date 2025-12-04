local common = require "ark_common"

local ArkExp = Class(function(self, inst)
  self.inst = inst
  -- 根据rarity固定配置. 这个直接在这里写死.
  self.rarity = 1
  self.expRate = 1
  -- 基础属性
  self.data = {
    potential = 1, -- 潜能 1-6
    elite = 1, -- 精英化等级, 1-3
    level = 1, -- 当前等级
    leftExp = 0 -- 剩余经验
  }
  self.inst:DoTaskInTime(0, function()
    SendModRPCToClient(GetClientModRPC("arkExp", "SetupArkExpUi"), self.inst.userid)
  end)
end)

function ArkExp:CanNextElite()
  return common.canNextElite(self.rarity, self.data.elite, self.data.level)
end

-- 增加经验
function ArkExp:AddExp(value)
  self.data.exp = self.data.exp + value * self.expRate
end

function ArkExp:LevelUp()
  -- 检查有没有下一级
  local maxLevel = common.getMaxLevel(self.rarity, self.data.elite)
  if self.data.level >= maxLevel then
    return
  end
  -- 检查用户装没装货币系统
  if not self.inst.components.ark_currency then
    return
  end
  -- 找出升级需要多少经验和龙门币
  local expCost, goldCost = common.getExpAndGoldCost(self.data.elite, self.data.level)
  if not expCost or not goldCost then
    return
  end
  if self.inst.components.ark_currency:GetArkGold() < goldCost then
    return
  end
  -- 扣除龙门币
  self.inst.components.ark_currency:AddArkGold(-goldCost)
  -- 扣除经验
  self.data.leftExp = self.data.leftExp - expCost
  -- 增加等级
  self.data.level = self.data.level + 1
  self:SyncExpStatus()
end

function ArkExp:EliteUp()
  if not self:CanNextElite() then
    return
  end
  -- 等级重置
  self.data.level = 1
  -- 精英化等级
  self.data.elite = self.data.elite + 1
  self:SyncExpStatus()
end

function ArkExp:SyncExpStatus()
  if (self.inst.userid == '') then
    return
  end
  SendModRPCToClient(GetClientModRPC("arkExp", "SyncExpStatus"), self.inst.userid, self.rarity, self.data.potential, self.data.elite, self.data.level, self.data.leftExp)
end

return ArkExp
