local InputMgr = {}

local SwordFly = require("Script.SwordFly.SwordFly")

--[[
输入绑定（按 WIKI 的 GameplayTag → InputName 映射）

需要在输入映射表里配置：
- Input.Action.SwordFlyToggle  → SwitchPMode（PC 默认 V）
- Input.Action.SwordFlyUp      → RightPeek（PC 默认 E）
- Input.Action.SwordFlyDown    → LeftPeek（PC 默认 Q）

“看向哪飞哪”（高级飞行）需要额外配置轴映射：
- Input.Move.MoveForward       → MoveForwardWin
- Input.Move.MoveRight         → MoveRightWin

说明：
- MoveForward/MoveRight 这两条映射不要在编辑器里勾 ConsumeInput（否则会影响地面走路）
- 代码会在进入御剑时才 Consume，从而只在飞行状态接管 WASD
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

local function _SetConsume(PlayerPawn, handle, consume)
    if handle == nil or handle == -1 then
        return
    end
    UGCInputSystem.SetBindingConsumeInput(PlayerPawn, handle, consume == true)
end

function InputMgr.SetFlyMoveConsume(PlayerPawn, consume)
    if PlayerPawn == nil then
        return
    end
    local handles = PlayerPawn.__SwordFlyInputHandles
    if handles == nil then
        return
    end
    _SetConsume(PlayerPawn, handles.moveForwardTriggered, consume)
    _SetConsume(PlayerPawn, handles.moveForwardStarted, consume)
    _SetConsume(PlayerPawn, handles.moveRightTriggered, consume)
    _SetConsume(PlayerPawn, handles.moveRightStarted, consume)
end

local function _ToAxis(v)
    local n = tonumber(v)
    if n == nil then
        return 0
    end
    if n > 1 then
        return 1
    end
    if n < -1 then
        return -1
    end
    return n
end

function InputMgr:BindPlatformInput(PlayerPawn)
    if not _IsValid(PlayerPawn) then
        return
    end

    self:ClearInput(PlayerPawn)

    local tagToggle = UGCGameplayTagSystem.RequestGameplayTag("Input.Action.SwordFlyToggle")
    local tagUp = UGCGameplayTagSystem.RequestGameplayTag("Input.Action.SwordFlyUp")
    local tagDown = UGCGameplayTagSystem.RequestGameplayTag("Input.Action.SwordFlyDown")
    local tagMoveForward = UGCGameplayTagSystem.RequestGameplayTag("Input.Move.MoveForward")
    local tagMoveRight = UGCGameplayTagSystem.RequestGameplayTag("Input.Move.MoveRight")

    local handles = {}
    local function _Bind(name, tag, triggerEvent, fn, consume)
        local h = UGCInputSystem.BindInputMapping(PlayerPawn, tag, triggerEvent, fn)
        if h == nil or h == -1 then
            ugcprint(string.format("[SwordFlyInput] BindInputMapping failed name=%s tag=%s", tostring(name), tostring(tag)))
            return
        end
        handles[name] = h
        if consume == true then
            UGCInputSystem.SetBindingConsumeInput(PlayerPawn, h, true)
        end
    end

    _Bind("toggle", tagToggle, ETriggerEvent.Started, InputMgr.OnToggle, true)
    _Bind("upStarted", tagUp, ETriggerEvent.Started, InputMgr.OnUpStarted, true)
    _Bind("upReleased", tagUp, ETriggerEvent.Completed, InputMgr.OnUpReleased, true)
    _Bind("upCanceled", tagUp, ETriggerEvent.Canceled, InputMgr.OnUpReleased, true)
    _Bind("downStarted", tagDown, ETriggerEvent.Started, InputMgr.OnDownStarted, true)
    _Bind("downReleased", tagDown, ETriggerEvent.Completed, InputMgr.OnDownReleased, true)
    _Bind("downCanceled", tagDown, ETriggerEvent.Canceled, InputMgr.OnDownReleased, true)

    -- MoveForward/MoveRight 默认不 Consume，避免影响地面走路
    -- 进入御剑时再通过 SetFlyMoveConsume(true) 接管 WASD
    _Bind("moveForwardTriggered", tagMoveForward, ETriggerEvent.Triggered, InputMgr.OnMoveForward, false)
    _Bind("moveForwardStarted", tagMoveForward, ETriggerEvent.Started, InputMgr.OnMoveForward, false)
    _Bind("moveForwardCompleted", tagMoveForward, ETriggerEvent.Completed, InputMgr.OnMoveForwardReleased, false)
    _Bind("moveForwardCanceled", tagMoveForward, ETriggerEvent.Canceled, InputMgr.OnMoveForwardReleased, false)
    _Bind("moveRightTriggered", tagMoveRight, ETriggerEvent.Triggered, InputMgr.OnMoveRight, false)
    _Bind("moveRightStarted", tagMoveRight, ETriggerEvent.Started, InputMgr.OnMoveRight, false)
    _Bind("moveRightCompleted", tagMoveRight, ETriggerEvent.Completed, InputMgr.OnMoveRightReleased, false)
    _Bind("moveRightCanceled", tagMoveRight, ETriggerEvent.Canceled, InputMgr.OnMoveRightReleased, false)

    PlayerPawn.__SwordFlyInputHandles = handles
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

    local flying = SwordFly.IsFlying(PlayerPawn)
    local canUse = (not flying) or SwordFly.HasCameraArm(PlayerPawn)
    InputMgr.SetFlyMoveConsume(PlayerPawn, flying and canUse)
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

function InputMgr.OnMoveForward(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.SetMoveForwardAxis(PlayerPawn, _ToAxis(InputValue))
end

function InputMgr.OnMoveForwardReleased(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.SetMoveForwardAxis(PlayerPawn, 0)
end

function InputMgr.OnMoveRight(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.SetMoveRightAxis(PlayerPawn, _ToAxis(InputValue))
end

function InputMgr.OnMoveRightReleased(PlayerPawn, InputValue, ElapsedTime, TriggeredTime, InputTag)
    SwordFly.SetMoveRightAxis(PlayerPawn, 0)
end

return InputMgr
