---@class UGCPlayerPawn_C:BP_UGCPlayerPawn_C
--Edit Below--
local UGCPlayerPawn = {}

local SwordFlyInputMgr = require("Script.SwordFly.InputMgr")
local SwordFly = require("Script.SwordFly.SwordFly")
 
function UGCPlayerPawn:ReceiveBeginPlay()
    UGCPlayerPawn.SuperClass.ReceiveBeginPlay(self)

    local isServer = UGCGameSystem.IsServer and UGCGameSystem.IsServer() or self:HasAuthority()
    ugcprint(string.format("[SwordFly] Pawn BeginPlay isServer=%s", tostring(isServer)))

    local ok = pcall(function()
        self.PrimaryActorTick.bCanEverTick = true
        self.bAllowBPReceiveTickEvent = true
        if self.SetActorTickEnabled then
            self:SetActorTickEnabled(true)
        end
    end)
    if ok then
        ugcprint("[SwordFly] Pawn Tick Enabled")
    end

    -- 输入只需要在客户端绑定；服务端通过 Toggle RPC 同步进入/退出御剑模式
    if not isServer then
        SwordFlyInputMgr:BindPlatformInput(self)
    end
end

function UGCPlayerPawn:ReceiveTick(DeltaTime)
    UGCPlayerPawn.SuperClass.ReceiveTick(self, DeltaTime)
    SwordFly.Tick(self, DeltaTime)
end

function UGCPlayerPawn:ReceiveEndPlay()
    UGCPlayerPawn.SuperClass.ReceiveEndPlay(self) 

    local ok, err = pcall(function()
        SwordFlyInputMgr:ClearInput(self)
    end)
    if not ok then
        ugcprint(string.format("[SwordFly] Pawn ClearInput failed: %s", tostring(err)))
    end

    SwordFly.Clear(self)
end

function UGCPlayerPawn:GetAvailableServerRPCs()
    return "Server_SwordFlyToggle"
end

function UGCPlayerPawn:Server_SwordFlyToggle()
    if self:HasAuthority() ~= true then
        return
    end
    SwordFly.Toggle(self)
end


function UGCPlayerPawn:GetReplicatedProperties()
    return {"__SubObjectRepList", "Lazy"}
end


return UGCPlayerPawn
