local Config = require("Script.SwordFly.Config")

local SwordFly = {}

--[[
御剑飞行核心逻辑（不切 Pawn、非载具）

设计要点：
1) 进入/退出：仅切换 CharacterMovement 的参数与 MovementMode（Flying/Falling），并负责剑挂载、镜头拉远/归位
2) 水平移动：完全使用引擎原生 WASD（MOVE_Flying），保证网络平滑
3) 垂直移动：由 Q/E 按住驱动 state.vertHoldAxis，并在 Tick 里 AddMovementInput(UpVector)

状态存储在 Pawn.__SwordFlyState：
- bFlying: 是否处于御剑状态
- enterBlendRemaining: 进入时速度衰减剩余时间（让起飞更柔和）
- vertHoldAxis: 垂直输入（-1/0/1）
- cached: 进入前缓存（MovementMode/MaxFlySpeed/.../CameraArmLength）
]]

local MOVE_FALLING = 3
local MOVE_FLYING = 5

local function _IsValid(obj)
    return obj ~= nil and (UE.IsValid == nil or UE.IsValid(obj))
end

local function _IsServer()
    return UGCGameSystem.IsServer ~= nil and UGCGameSystem.IsServer() == true
end

local function _GetCM(pawn)
    return pawn and pawn.CharacterMovement or nil
end

local function _GetObjName(obj)
    if obj == nil then
        return "nil"
    end
    local ok, name = pcall(function()
        if obj.GetName then
            return obj:GetName()
        end
        if obj.GetFName then
            return tostring(obj:GetFName())
        end
        return tostring(obj)
    end)
    if ok then
        return tostring(name)
    end
    return tostring(obj)
end

local function _FindSpringArmByScan(pawn)
    if pawn == nil or UE == nil or UE.LoadClass == nil then
        return nil
    end

    local cls = nil
    pcall(function()
        cls = UE.LoadClass("/Script/Engine.SpringArmComponent")
    end)
    if cls == nil then
        pcall(function()
            cls = UE.LoadClass("Class'/Script/Engine.SpringArmComponent'")
        end)
    end
    if cls == nil then
        return nil
    end

    local function _PickFirst(comps)
        if comps == nil then
            return nil
        end
        if comps[1] ~= nil and _IsValid(comps[1]) then
            return comps[1]
        end
        if comps[0] ~= nil and _IsValid(comps[0]) then
            return comps[0]
        end
        return nil
    end

    if pawn.K2_GetComponentsByClass then
        local ok, comps = pcall(function()
            return pawn:K2_GetComponentsByClass(cls)
        end)
        if ok then
            local arm = _PickFirst(comps)
            if arm ~= nil then
                return arm
            end
        end
    end

    if pawn.GetComponentsByClass then
        local ok, comps = pcall(function()
            return pawn:GetComponentsByClass(cls)
        end)
        if ok then
            local arm = _PickFirst(comps)
            if arm ~= nil then
                return arm
            end
        end
    end

    return nil
end

local function _FindSpringArm(pawn)
    if pawn == nil then
        return nil
    end
    local candidates = {
        pawn.SpringArm,
        pawn.CameraBoom,
        pawn.CameraArm,
        pawn.CameraSpringArm,
        pawn.CustomSpringArm,
        pawn.ShoulderCameraSpringArm,
        pawn.ThirdPersonSpringArm,
        pawn.TPSpringArm,
        pawn.TPSpringArm0,
        pawn.FollowCameraSpringArm,
    }
    for _, arm in ipairs(candidates) do
        if _IsValid(arm) then
            return arm
        end
    end

    local scanned = _FindSpringArmByScan(pawn)
    if _IsValid(scanned) then
        return scanned
    end

    return nil
end

local function _ApplyCameraEnter(pawn, state)
    if _IsServer() then
        return
    end
    local arm = _FindSpringArm(pawn)
    if arm == nil or arm.TargetArmLength == nil then
        ugcprint(string.format("[SwordFly] CameraEnter skipped: arm not found pawn=%s", _GetObjName(pawn)))
        return
    end
    state.cached.CameraArmLength = arm.TargetArmLength
    local delta = tonumber(Config.CameraArmLengthDelta) or 0
    if delta ~= 0 then
        arm.TargetArmLength = (tonumber(arm.TargetArmLength) or 0) + delta
    end
    ugcprint(string.format("[SwordFly] CameraEnter arm=%s prop=TargetArmLength len=%s->%s", _GetObjName(arm), tostring(state.cached.CameraArmLength), tostring(arm.TargetArmLength)))
end

local function _ApplyCameraExit(pawn, state)
    if _IsServer() then
        return
    end
    local arm = _FindSpringArm(pawn)
    if arm == nil or arm.TargetArmLength == nil then
        ugcprint(string.format("[SwordFly] CameraExit skipped: arm not found pawn=%s", _GetObjName(pawn)))
        return
    end
    if state.cached.CameraArmLength ~= nil then
        arm.TargetArmLength = state.cached.CameraArmLength
    end
    ugcprint(string.format("[SwordFly] CameraExit arm=%s prop=TargetArmLength len=%s", _GetObjName(arm), tostring(arm.TargetArmLength)))
end

local function _SetMovementMode(cm, mode)
    if cm == nil then
        return
    end
    local ok = pcall(function()
        if cm.SetMovementMode then
            cm:SetMovementMode(mode)
        else
            cm.MovementMode = mode
        end
    end)
    return ok
end

local function _NewVector(x, y, z)
    if Vector and Vector.New then
        local v = Vector.New()
        v.X = x
        v.Y = y
        v.Z = z
        return v
    end
    return { X = x, Y = y, Z = z }
end

local _UpVector = _NewVector(0, 0, 1)

local function _GetOrCreateState(pawn)
    pawn.__SwordFlyState = pawn.__SwordFlyState or {}
    local s = pawn.__SwordFlyState
    if s.cached == nil then
        s.cached = {}
    end
    if s.bFlying == nil then
        s.bFlying = false
    end
    if s.enterBlendRemaining == nil then
        s.enterBlendRemaining = 0
    end
    if s.vertHoldAxis == nil then
        s.vertHoldAxis = 0
    end
    return s
end

local function _EnsureSwordActor(pawn, state)
    if _IsValid(state.swordActor) then
        return state.swordActor
    end

    if _IsServer() then
        return nil
    end

    local ok, swordActor = pcall(function()
        local fullPath = UGCGameSystem.GetUGCResourcesFullPath(Config.SwordClassPath)
        local cls = UE.LoadClass(fullPath)
        if cls == nil then
            return nil
        end
        local actor = ScriptGameplayStatics.SpawnActor(pawn, cls, { X = 0, Y = 0, Z = 0 }, { Roll = 0, Pitch = 0, Yaw = 0 }, { X = 1, Y = 1, Z = 1 })
        if actor == nil then
            return nil
        end
        actor:SetActorEnableCollision(false)
        actor:K2_AttachToComponent(pawn.Mesh, "")
        actor:K2_SetActorRelativeLocation(Config.MountOffset)
        actor:K2_SetActorRelativeRotation(Config.MountRot)
        return actor
    end)

    if ok and _IsValid(swordActor) then
        state.swordActor = swordActor
        return swordActor
    end

    ugcprint(string.format("[SwordFly] EnsureSwordActor failed ok=%s path=%s", tostring(ok), tostring(Config.SwordClassPath)))
    return nil
end

function SwordFly.Enter(pawn)
    if not _IsValid(pawn) then
        return
    end

    local state = _GetOrCreateState(pawn)
    if state.bFlying then
        return
    end

    local cm = _GetCM(pawn)
    if cm == nil then
        return
    end

    state.cached.MovementMode = cm.MovementMode
    state.cached.MaxFlySpeed = cm.MaxFlySpeed
    state.cached.MaxAcceleration = cm.MaxAcceleration
    state.cached.BrakingDecelerationFlying = cm.BrakingDecelerationFlying
    state.cached.GravityScale = cm.GravityScale
    state.cached.JumpZVelocity = cm.JumpZVelocity
    state.cached.CameraArmLength = nil

    if cm.JumpZVelocity ~= nil then
        cm.JumpZVelocity = 0
    end

    if cm.MaxFlySpeed ~= nil then
        cm.MaxFlySpeed = tonumber(Config.MaxFlySpeed) or cm.MaxFlySpeed
    end
    if cm.MaxAcceleration ~= nil then
        cm.MaxAcceleration = tonumber(Config.MaxAcceleration) or cm.MaxAcceleration
    end
    if cm.BrakingDecelerationFlying ~= nil then
        cm.BrakingDecelerationFlying = tonumber(Config.BrakingDecelerationFlying) or cm.BrakingDecelerationFlying
    end
    if cm.GravityScale ~= nil then
        cm.GravityScale = 0
    end

    _SetMovementMode(cm, MOVE_FLYING)

    if cm.Velocity ~= nil then
        local v = cm.Velocity
        cm.Velocity = { X = (v.X or 0) * 0.15, Y = (v.Y or 0) * 0.15, Z = 0 }
    end

    state.enterBlendRemaining = tonumber(Config.EnterBlendTime) or 0
    state.bFlying = true
    state.vertHoldAxis = 0

    _ApplyCameraEnter(pawn, state)

    local swordActor = _EnsureSwordActor(pawn, state)
    if _IsValid(swordActor) then
        swordActor:SetActorHiddenInGame(false)
    end

    local pc = UGCGameSystem.GetPlayerControllerByPlayerPawn(pawn)
    if pc and pc.ClientRPC_Tip then
        pc:ClientRPC_Tip("御剑飞行：开启")
    end

    ugcprint("[SwordFly] Enter")
end

function SwordFly.Exit(pawn)
    if not _IsValid(pawn) then
        return
    end

    local state = _GetOrCreateState(pawn)
    if not state.bFlying then
        return
    end

    local cm = _GetCM(pawn)
    if cm ~= nil then
        if state.cached.MaxFlySpeed ~= nil and cm.MaxFlySpeed ~= nil then
            cm.MaxFlySpeed = state.cached.MaxFlySpeed
        end
        if state.cached.MaxAcceleration ~= nil and cm.MaxAcceleration ~= nil then
            cm.MaxAcceleration = state.cached.MaxAcceleration
        end
        if state.cached.BrakingDecelerationFlying ~= nil and cm.BrakingDecelerationFlying ~= nil then
            cm.BrakingDecelerationFlying = state.cached.BrakingDecelerationFlying
        end
        if state.cached.GravityScale ~= nil and cm.GravityScale ~= nil then
            cm.GravityScale = state.cached.GravityScale
        end
        if state.cached.JumpZVelocity ~= nil and cm.JumpZVelocity ~= nil then
            cm.JumpZVelocity = state.cached.JumpZVelocity
        end

        local restoreMode = state.cached.MovementMode
        if restoreMode == nil then
            restoreMode = MOVE_FALLING
        end
        _SetMovementMode(cm, restoreMode)

        if cm.Velocity ~= nil then
            local v = cm.Velocity
            cm.Velocity = { X = v.X or 0, Y = v.Y or 0, Z = math.min(v.Z or 0, 0) }
        end
    end

    if _IsValid(state.swordActor) then
        state.swordActor:SetActorHiddenInGame(true)
    end

    _ApplyCameraExit(pawn, state)

    state.bFlying = false
    state.enterBlendRemaining = 0
    state.vertHoldAxis = 0

    local pc = UGCGameSystem.GetPlayerControllerByPlayerPawn(pawn)
    if pc and pc.ClientRPC_Tip then
        pc:ClientRPC_Tip("御剑飞行：结束")
    end

    ugcprint("[SwordFly] Exit")
end

function SwordFly.Toggle(pawn)
    local state = _GetOrCreateState(pawn)
    if state.bFlying then
        SwordFly.Exit(pawn)
    else
        SwordFly.Enter(pawn)
    end
end

function SwordFly.Tick(pawn, dt)
    if not _IsValid(pawn) then
        return
    end

    local state = pawn.__SwordFlyState
    if state == nil or not state.bFlying then
        return
    end

    local cm = _GetCM(pawn)
    if cm == nil then
        return
    end

    -- 垂直 AddMovementInput 只需要在本地控制端执行；DedicatedServer 没有输入
    if _IsServer() then
        return
    end

    if state.enterBlendRemaining ~= nil and state.enterBlendRemaining > 0 and cm.Velocity ~= nil then
        local v = cm.Velocity
        local t = math.max(0.0, math.min(1.0, dt / state.enterBlendRemaining))
        cm.Velocity = { X = (v.X or 0) * (1.0 - t), Y = (v.Y or 0) * (1.0 - t), Z = 0 }
        state.enterBlendRemaining = math.max(0, state.enterBlendRemaining - dt)
    end

    local vert = state.vertHoldAxis or 0
    if math.abs(vert) > 0.01 and pawn.AddMovementInput then
        pawn:AddMovementInput(_UpVector, vert, false)
    end
end

function SwordFly.SetVerticalHoldAxis(pawn, axis)
    if not _IsValid(pawn) then
        return
    end
    local state = _GetOrCreateState(pawn)
    if not state.bFlying then
        return
    end
    axis = tonumber(axis) or 0
    if axis > 0 then
        axis = 1
    elseif axis < 0 then
        axis = -1
    else
        axis = 0
    end
    state.vertHoldAxis = axis
end

function SwordFly.IsFlying(pawn)
    if not _IsValid(pawn) then
        return false
    end
    local state = pawn.__SwordFlyState
    return state ~= nil and state.bFlying == true
end

function SwordFly.Clear(pawn)
    if not _IsValid(pawn) then
        return
    end
    local state = pawn.__SwordFlyState
    if state == nil then
        return
    end
    if _IsValid(state.swordActor) then
        state.swordActor:K2_DetachFromActor()
        state.swordActor:K2_DestroyActor()
    end
    pawn.__SwordFlyState = nil
end

return SwordFly
