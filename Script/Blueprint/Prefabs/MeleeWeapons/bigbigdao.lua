---@class bigbigdao_C:BP_UGC_MeleeWeap_TangDao_C
--Edit Below--
local bigbigdao = {}
 
--[[
function bigbigdao:ReceiveBeginPlay()
    bigbigdao.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function bigbigdao:ReceiveTick(DeltaTime)
    bigbigdao.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function bigbigdao:ReceiveEndPlay()
    bigbigdao.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function bigbigdao:GetReplicatedProperties()
    return
end
--]]

--[[
function bigbigdao:GetAvailableServerRPCs()
    return
end
--]]

return bigbigdao