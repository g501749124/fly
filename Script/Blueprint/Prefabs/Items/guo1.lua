---@class guo1_C:Template_Melee_Pan_Handle_C
--Edit Below--
local guo1 = {} 

--[[经典背包事件]]--
--[[
--- func 处理物品的拾取(服务端生效)
---@return bool @是否拾取该物品, 返回true才能拾取进背包
-- function guo1:HandlePickup(ItemContainer, PickupInfo, Reason)
--    return guo1.SuperClass.HandlePickup(self, ItemContainer, PickupInfo, Reason)
-- end

--- func 处理物品的丢弃(服务端生效)
---@return bool @是否丢弃该物品, 返回true才会丢弃
-- function guo1:HandleDrop(InCount, Reason)
--    return guo1.SuperClass.HandleDrop(self, InCount, Reason)
-- end

--- func 处理物品的取出(服务端生效)
---@return number @可取出物品数量
-- function guo1:HandleTake(TakeCount, TotalCount)
--    return guo1.SuperClass.HandleTake(self, TakeCount, TotalCount)
-- end

--- func 处理物品的使用(服务端生效)
---@return bool @使用是否成功
-- function guo1:HandleUse(Target, Reason)
--    return guo1.SuperClass.HandleUse(self, Target, Reason) 
-- end

--- func 处理物品的取消使用(服务端生效)
---@return bool @取消使用是否成功
-- function guo1:HandleDisuse(Reason)
--    return guo1.SuperClass.HandleDisuse(self, Reason) 
-- end

--- func 尝试取消使用物品，仅尝试(服务端生效)
---@return bool @物品能否取消使用
-- function guo1:HandleTryDisuse(Reason)
--    return guo1.SuperClass.HandleTryDisuse(self, Reason)
-- end

--- func 处理物品的有效性(服务端生效)
-- function guo1:HandleEnable(bEnable)
--    guo1.SuperClass.HandleEnable(self, bEnable)
-- end

--- func 处理物品的清除(服务端生效)
---@return bool @清除物品是否成功
-- function guo1:HanldeCleared()
--    return guo1.SuperClass.HanldeCleared(self)
-- end
]]--


return guo1