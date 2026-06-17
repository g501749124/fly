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

local function _GetMesh(pawn)
    if pawn == nil then
        return nil
    end
    if _IsValid(pawn.Mesh) then
        return pawn.Mesh
    end
    return nil
end

local function _FindSpringArm(pawn)
    if pawn == nil then
        return nil
    end
    -- 当前项目实际生效的是 Pawn 上的 CustomSpringArm（SpringArmComponent）
    -- 如果你在蓝图里改了相机结构，需要同步调整这里的字段名
    if _IsValid(pawn.CustomSpringArm) then
        return pawn.CustomSpringArm
    end
    if _IsValid(pawn.SpringArm) then
        return pawn.SpringArm
    end
    return nil
end

local function _ApplyCameraEnter(pawn, state)
    if _IsServer() then
        return
    end
    local arm = _FindSpringArm(pawn)
    if arm == nil or arm.TargetArmLength == nil then
        return
    end
    state.cached.CameraArmLength = arm.TargetArmLength
    local delta = tonumber(Config.CameraArmLengthDelta) or 0
    if delta ~= 0 then
        arm.TargetArmLength = (tonumber(arm.TargetArmLength) or 0) + delta
    end
end

local function _ApplyCameraExit(pawn, state)
    if _IsServer() then
        return
    end
    local arm = _FindSpringArm(pawn)
    if arm == nil or arm.TargetArmLength == nil then
        return
    end
    if state.cached.CameraArmLength ~= nil then
        arm.TargetArmLength = state.cached.CameraArmLength
    end
end

local function _ApplyAnimFreezeEnter(pawn, state)
    if _IsServer() then
        return
    end
    local mesh = _GetMesh(pawn)
    if mesh == nil then
        return
    end
    state.cached.MeshPauseAnims = mesh.bPauseAnims
    state.cached.MeshGlobalAnimRateScale = mesh.GlobalAnimRateScale
    mesh.GlobalAnimRateScale = 0
    mesh.bPauseAnims = true
end

local function _ApplyAnimFreezeExit(pawn, state)
    if _IsServer() then
        return
    end
    local mesh = _GetMesh(pawn)
    if mesh == nil then
        return
    end
    mesh.bPauseAnims = state.cached.MeshPauseAnims or false
    if state.cached.MeshGlobalAnimRateScale ~= nil then
        mesh.GlobalAnimRateScale = state.cached.MeshGlobalAnimRateScale
    else
        mesh.GlobalAnimRateScale = 1
    end
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

local function _ReadVec(v)
    if v == nil then
        return nil
    end
    local x = v.X
    local y = v.Y
    local z = v.Z
    if x == nil and type(v) == "table" then
        x = v[1]
        y = v[2]
        z = v[3]
    end
    if x == nil then
        return nil
    end
    return tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
end

local function _GetArmForwardRight(arm)
    if arm == nil then
        return nil, nil
    end
    local ok1, fwd = pcall(function()
        if arm.GetForwardVector then
            return arm:GetForwardVector()
        end
        return arm.ForwardVector
    end)
    local ok2, rht = pcall(function()
        if arm.GetRightVector then
            return arm:GetRightVector()
        end
        return arm.RightVector
    end)
    if not ok1 then
        fwd = nil
    end
    if not ok2 then
        rht = nil
    end
    return fwd, rht
end

local function _MakeHorizontal(v)
    local x, y, z = _ReadVec(v)
    if x == nil then
        return nil
    end
    z = 0
    local len = math.sqrt((x * x) + (y * y))
    if len > 1e-6 then
        x = x / len
        y = y / len
    end
    return _NewVector(x, y, z)
end

local function _ClampAxis(axis)
    axis = tonumber(axis) or 0
    if axis > 1 then
        return 1
    end
    if axis < -1 then
        return -1
    end
    return axis
end

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
    if s.forwardAxis == nil then
        s.forwardAxis = 0
    end
    if s.rightAxis == nil then
        s.rightAxis = 0
    end
    if s.enterAutoLiftRemaining == nil then
        s.enterAutoLiftRemaining = 0
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

local function _DestroyOrbitSwords(state)
    if state == nil or type(state.orbitSwords) ~= "table" then
        state.orbitSwords = nil
        return
    end
    for _, a in ipairs(state.orbitSwords) do
        if _IsValid(a) then
            pcall(function()
                if a.K2_DetachFromActor then
                    a:K2_DetachFromActor()
                end
                if a.K2_DestroyActor then
                    a:K2_DestroyActor()
                end
            end)
        end
    end
    state.orbitSwords = nil
    state.orbitAngle = 0
end

local function _EnsureOrbitSwords(pawn, state)
    if state == nil then
        return
    end
    if _IsServer() then
        return
    end
    if type(state.orbitSwords) == "table" and #state.orbitSwords > 0 then
        return
    end

    local mesh = _GetMesh(pawn)
    if mesh == nil then
        return
    end

    local fullPath = UGCGameSystem.GetUGCResourcesFullPath(Config.SwordClassPath)
    local cls = UE.LoadClass(fullPath)
    if cls == nil then
        ugcprint(string.format("[SwordFly] EnsureOrbitSwords LoadClass failed path=%s", tostring(Config.SwordClassPath)))
        return
    end

    local count = math.max(1, math.floor(tonumber(Config.OrbitSwordCount) or 1))
    local list = {}
    for _ = 1, count do
        local ok, a = pcall(function()
            return ScriptGameplayStatics.SpawnActor(pawn, cls, { X = 0, Y = 0, Z = 0 }, { Roll = 0, Pitch = 0, Yaw = 0 }, { X = 1, Y = 1, Z = 1 })
        end)
        if ok and _IsValid(a) then
            pcall(function()
                a:SetActorEnableCollision(false)
                a:SetActorHiddenInGame(false)
                a:K2_AttachToComponent(mesh, "")
            end)
            table.insert(list, a)
        end
    end

    state.orbitSwords = list
    state.orbitAngle = tonumber(state.orbitAngle) or 0
end

local function _UpdateOrbitSwords(pawn, state, dt)
    if state == nil or type(state.orbitSwords) ~= "table" or #state.orbitSwords == 0 then
        return
    end
    local mesh = _GetMesh(pawn)
    if mesh == nil then
        return
    end

    local radius = tonumber(Config.OrbitRadius) or 0
    local height = tonumber(Config.OrbitHeight) or 0
    local speed = tonumber(Config.OrbitSpeedDeg) or 0
    local pitch = tonumber(Config.OrbitSwordPitch) or 0
    local roll = tonumber(Config.OrbitSwordRoll) or 0

    state.orbitAngle = (tonumber(state.orbitAngle) or 0) + speed * (tonumber(dt) or 0)
    local base = tonumber(state.orbitAngle) or 0
    local count = #state.orbitSwords
    local step = 360 / math.max(1, count)

    for i = 1, count do
        local a = state.orbitSwords[i]
        if _IsValid(a) then
            local deg = base + step * (i - 1)
            local rad = deg * math.pi / 180
            local loc = { X = math.cos(rad) * radius, Y = math.sin(rad) * radius, Z = height }
            local rot = { Pitch = pitch, Yaw = deg, Roll = roll }
            pcall(function()
                if a.K2_SetActorRelativeLocation then
                    a:K2_SetActorRelativeLocation(loc, false, nil, false)
                end
                if a.K2_SetActorRelativeRotation then
                    a:K2_SetActorRelativeRotation(rot, false, nil, false)
                end
            end)
        end
    end
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
    state.cached.MeshPauseAnims = nil
    state.cached.MeshGlobalAnimRateScale = nil

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
    state.enterAutoLiftRemaining = tonumber(Config.EnterAutoLiftTime) or 0
    state.bFlying = true
    state.vertHoldAxis = 0
    state.forwardAxis = 0
    state.rightAxis = 0
    state.animFreezePending = true

    _ApplyCameraEnter(pawn, state)

    local swordActor = _EnsureSwordActor(pawn, state)
    if _IsValid(swordActor) then
        swordActor:SetActorHiddenInGame(false)
    end

    _EnsureOrbitSwords(pawn, state)

    local pc = UGCGameSystem.GetPlayerControllerByPlayerPawn(pawn)
    if pc and pc.ClientRPC_Tip then
        pc:ClientRPC_Tip("御剑飞行：开启")
    end
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

    _DestroyOrbitSwords(state)

    _ApplyCameraExit(pawn, state)
    _ApplyAnimFreezeExit(pawn, state)

    state.bFlying = false
    state.enterBlendRemaining = 0
    state.enterAutoLiftRemaining = 0
    state.vertHoldAxis = 0
    state.forwardAxis = 0
    state.rightAxis = 0
    state.animFreezePending = false

    local pc = UGCGameSystem.GetPlayerControllerByPlayerPawn(pawn)
    if pc and pc.ClientRPC_Tip then
        pc:ClientRPC_Tip("御剑飞行：结束")
    end
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

    _EnsureOrbitSwords(pawn, state)
    _UpdateOrbitSwords(pawn, state, dt)

    if state.enterBlendRemaining ~= nil and state.enterBlendRemaining > 0 and cm.Velocity ~= nil then
        local v = cm.Velocity
        local t = math.max(0.0, math.min(1.0, dt / state.enterBlendRemaining))
        cm.Velocity = { X = (v.X or 0) * (1.0 - t), Y = (v.Y or 0) * (1.0 - t), Z = 0 }
        state.enterBlendRemaining = math.max(0, state.enterBlendRemaining - dt)
    end

    if state.animFreezePending and (state.enterBlendRemaining == nil or state.enterBlendRemaining <= 0) then
        _ApplyAnimFreezeEnter(pawn, state)
        state.animFreezePending = false
    end

    -- 进入御剑后的轻抬升：按 V 后先向上“起一小下”，避免原地开始飞的突兀感
    if state.enterAutoLiftRemaining ~= nil and state.enterAutoLiftRemaining > 0 and pawn.AddMovementInput then
        local axis = tonumber(Config.EnterAutoLiftAxis) or 0
        if axis > 0.01 then
            pawn:AddMovementInput(_UpVector, _ClampAxis(axis), false)
        end
        state.enterAutoLiftRemaining = math.max(0, state.enterAutoLiftRemaining - dt)
    end

    -- “看向哪飞哪”的前进：W/S 使用相机 Forward（带 Pitch）
    -- 左右平移：A/D 只使用水平 Right（不带 Pitch），避免侧移导致上下漂
    local forwardAxis = _ClampAxis(state.forwardAxis)
    local rightAxis = _ClampAxis(state.rightAxis)
    if (math.abs(forwardAxis) > 0.01 or math.abs(rightAxis) > 0.01) and pawn.AddMovementInput then
        local arm = _FindSpringArm(pawn)
        local fwd, rht = _GetArmForwardRight(arm)
        if fwd ~= nil and math.abs(forwardAxis) > 0.01 then
            pawn:AddMovementInput(fwd, forwardAxis, false)
        end
        if rht ~= nil and math.abs(rightAxis) > 0.01 then
            local horizRight = _MakeHorizontal(rht)
            if horizRight ~= nil then
                pawn:AddMovementInput(horizRight, rightAxis, false)
            else
                pawn:AddMovementInput(rht, rightAxis, false)
            end
        end
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

function SwordFly.SetMoveAxis(pawn, forwardAxis, rightAxis)
    if not _IsValid(pawn) then
        return
    end
    local state = _GetOrCreateState(pawn)
    state.forwardAxis = _ClampAxis(forwardAxis)
    state.rightAxis = _ClampAxis(rightAxis)
end

function SwordFly.SetMoveForwardAxis(pawn, axis)
    if not _IsValid(pawn) then
        return
    end
    local state = _GetOrCreateState(pawn)
    state.forwardAxis = _ClampAxis(axis)
end

function SwordFly.SetMoveRightAxis(pawn, axis)
    if not _IsValid(pawn) then
        return
    end
    local state = _GetOrCreateState(pawn)
    state.rightAxis = _ClampAxis(axis)
end

function SwordFly.HasCameraArm(pawn)
    return _IsValid(_FindSpringArm(pawn))
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
    _DestroyOrbitSwords(state)
    if _IsValid(state.swordActor) then
        state.swordActor:K2_DetachFromActor()
        state.swordActor:K2_DestroyActor()
    end
    pawn.__SwordFlyState = nil
end

return SwordFly
