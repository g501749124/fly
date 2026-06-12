---@class AnimalTest_C:Character
--Edit Below--
local AnimalTest = {}
 
--[[
function AnimalTest:ReceiveBeginPlay()
    AnimalTest.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function AnimalTest:ReceiveTick(DeltaTime)
    AnimalTest.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function AnimalTest:ReceiveEndPlay()
    AnimalTest.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function AnimalTest:GetReplicatedProperties()
    return
end
--]]

--[[
function AnimalTest:GetAvailableServerRPCs()
    return
end
--]]

return AnimalTest