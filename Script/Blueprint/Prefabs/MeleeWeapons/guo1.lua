---@class guo1_C:BP_UGC_MeleeWeap_Pan_C
---@field ParticleSystem UParticleSystemComponent
--Edit Below--
local guo1 = {}
 
--[[
function guo1:ReceiveBeginPlay()
    guo1.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function guo1:ReceiveTick(DeltaTime)
    guo1.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function guo1:ReceiveEndPlay()
    guo1.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function guo1:GetReplicatedProperties()
    return
end
--]]

--[[
function guo1:GetAvailableServerRPCs()
    return
end
--]]

return guo1