---@class test11_C:BP_UGC_DragonBoySpear_C
--Edit Below--
local test11 = {}
 
--[[
function test11:ReceiveBeginPlay()
    test11.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function test11:ReceiveTick(DeltaTime)
    test11.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function test11:ReceiveEndPlay()
    test11.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function test11:GetReplicatedProperties()
    return
end
--]]

--[[
function test11:GetAvailableServerRPCs()
    return
end
--]]

return test11