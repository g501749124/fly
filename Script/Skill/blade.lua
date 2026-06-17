---@class blade_C:AActor
---@field ProjectileMovement UProjectileMovementComponent
---@field ParticleSystem UParticleSystemComponent
---@field Box UBoxComponent
--Edit Below--
local blade = {}
 
--[[
function blade:ReceiveBeginPlay()
    blade.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function blade:ReceiveTick(DeltaTime)
    blade.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function blade:ReceiveEndPlay()
    blade.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function blade:GetReplicatedProperties()
    return
end
--]]

--[[
function blade:GetAvailableServerRPCs()
    return
end
--]]

return blade