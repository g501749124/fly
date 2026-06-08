---@class Sword_C:AActor
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Sword = {}
 
--[[
function Sword:ReceiveBeginPlay()
    Sword.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Sword:ReceiveTick(DeltaTime)
    Sword.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Sword:ReceiveEndPlay()
    Sword.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Sword:GetReplicatedProperties()
    return
end
--]]

--[[
function Sword:GetAvailableServerRPCs()
    return
end
--]]

return Sword