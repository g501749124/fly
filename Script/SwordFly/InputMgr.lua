local InputMgr = {}

local SwordFly = require("Script.SwordFly.SwordFly")

--[[
输入绑定（按 WIKI 的 GameplayTag → InputName 映射）

需要在输入映射表里配置：
- Input.Action.SwordFlyToggle  → SwitchPMode（PC 默认 V）
- Input.Action.SwordFlyUp      → RightPeek（PC 默认 E）
- Input.Action.SwordFlyDown    → LeftPeek（PC 默认 Q）
]]

local function _IsValid(obj)
    return obj ~= nil and (UE.IsValid == nil or UE.IsValid(obj))
end

local function _IsServer()
    return UGCGameSystem.IsServer ~= nil and UGCGameSystem.IsServer() == true
end

local function _GetPC(pawn)
    if pawn == nil then
        return nil
    end
    return UGCGameSystem.GetPlayerControllerByPlayerPawn(pawn)
end

local function _CallServerRPC(pawn, rpcName, ...)
    if _IsServer() then
        return
    end
    local pc = _GetPC(pawn)
    if pc and UnrealNetwork and UnrealNetwork.CallUnrealRPC then
        UnrealNetwork.CallUnrealRPC(pc, pawn, rpcName, ...)
    end
end

function InputMgr:BindPlatformInput(PlayerPawn)
    if not _IsValid(PlayerPawn) then
        ugcprint("[SwordFlyInput] BindPlatformInput failed: PlayerPawn invalid")
        return
    end

    self:ClearInput(PlayerPawn)

    local tagToggle = UGCGameplayTagSystem.RequestGameplayTag("Input.Action.SwordFlyToggle")
    local tagUp = UGCGameplayTagSystem.RequestGameplayTag("Input.Action.SwordFlyUp")
    local tagDown = UGCGameplayTagSystem.RequestGameplayTag("Input.Action.SwordFlyDown")

    local handles = {}
    local function _Bind(name, tag, triggerEvent, fn)
        local h = UGCInputSystem.BindInputMapping(PlayerPawn, tag, triggerEvent, fn)
        if h == nil or h == -1 then
            ugcprint(string.format("[SwordFlyInput] BindInputMapping failed name=%s tag=%s", tostring(name), tostring(tag)))
            return
        end
        handles[name] = h
        UGCInputSystem.SetBindingConsumeInput(PlayerPawn, h, true)
    end

    _Bind("toggle", tagToggle, ETriggerEvent.Started, InputMgr.OnToggle)
    _Bind("upStarted", tagUp, ETriggerEvent.Started, InputMgr.OnUpStarted)
    _Bind("upReleased", tagUp, ETriggerEvent.Completed, InputMgr.OnUpReleased)
    _Bind("upCanceled", tagUp, ETriggerEvent.Canceled, InputMgr.OnUpReleased)
    _Bind("downStarted", tagDown, ETriggerEvent.Started, InputMgr.OnDownStarted)
    _Bind("downReleased", tagDown, ETriggerEvent.Completed, InputMgr.OnDownReleased)
    _Bind("downCanceled", tagDown, ETriggerEvent.Canceled, InputMgr.OnDownReleased)

    PlayerPawn.__SwordFlyInputHandles = handles

    ugcprint(string.format("[SwordFlyInput] Bind OK toggle=%s up=%s down=%s", tostring(tagToggle), tostring(tagUp), tostring(tagDown)))
end

function InputMgr:ClearInput(PlayerPawn)
    if not _IsValid(PlayerPawn) then
        return
    end
    UGCInputSystem.RemoveBindingToObject(PlayerPawn)
    PlayerPawn.__SwordFlyInputHandles = nil
end

function InputMgr.OnToggle(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.Toggle(PlayerPawn)
    _CallServerRPC(PlayerPawn, "Server_SwordFlyToggle")
    ugcprint(string.format("[SwordFlyInput] Toggle value=%s tag=%s", tostring(InputValue), tostring(InputTag)))
end

function InputMgr.OnUpStarted(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.SetVerticalHoldAxis(PlayerPawn, 1)
    local pc = _GetPC(PlayerPawn)
    if pc and pc.ClientRPC_Tip then
        pc:ClientRPC_Tip("御剑：上升")
    end
end

function InputMgr.OnUpReleased(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.SetVerticalHoldAxis(PlayerPawn, 0)
end

function InputMgr.OnDownStarted(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.SetVerticalHoldAxis(PlayerPawn, -1)
    local pc = _GetPC(PlayerPawn)
    if pc and pc.ClientRPC_Tip then
        pc:ClientRPC_Tip("御剑：下降")
    end
end

function InputMgr.OnDownReleased(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.SetVerticalHoldAxis(PlayerPawn, 0)
end

return InputMgr
