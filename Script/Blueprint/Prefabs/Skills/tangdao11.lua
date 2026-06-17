---@class tangdao11_C:PESkillTemplate_Base_C
--Edit Below--
local tangdao11 = {}

local EFFECT_PATH = 'Asset/Skill/blade.blade_C'
local EFFECT_FORWARD_DISTANCE = 150
local EFFECT_UP_OFFSET = 50
local EFFECT_SPEED_UNITS = 3000

local function _IsValid(obj)
    return obj ~= nil and (UE.IsValid == nil or UE.IsValid(obj))
end

local function _Vec(x, y, z)
    return { X = x or 0, Y = y or 0, Z = z or 0 }
end

local function _ReadVec(v)
    if v == nil then
        return 0, 0, 0
    end
    local x = v.X
    local y = v.Y
    local z = v.Z
    if x == nil and type(v) == "table" then
        x = v[1]
        y = v[2]
        z = v[3]
    end
    return tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
end

local function _Add(a, b)
    local ax, ay, az = _ReadVec(a)
    local bx, by, bz = _ReadVec(b)
    return _Vec(ax + bx, ay + by, az + bz)
end

local function _Mul(v, s)
    local x, y, z = _ReadVec(v)
    s = tonumber(s) or 0
    return _Vec(x * s, y * s, z * s)
end

local function _GetForward(actor)
    if actor == nil then
        return _Vec(1, 0, 0)
    end
    local ok, v = pcall(function()
        if actor.GetActorForwardVector then
            return actor:GetActorForwardVector()
        end
        if actor.K2_GetActorForwardVector then
            return actor:K2_GetActorForwardVector()
        end
        return actor.ForwardVector
    end)
    if ok and v ~= nil then
        return v
    end
    return _Vec(1, 0, 0)
end

local function _GetLocation(actor)
    if actor == nil then
        return _Vec(0, 0, 0)
    end
    local ok, v = pcall(function()
        if actor.K2_GetActorLocation then
            return actor:K2_GetActorLocation()
        end
        if actor.GetActorLocation then
            return actor:GetActorLocation()
        end
        return actor.ActorLocation
    end)
    if ok and v ~= nil then
        return v
    end
    return _Vec(0, 0, 0)
end

local function _GetRotation(actor)
    if actor == nil then
        return { Roll = 0, Pitch = 0, Yaw = 0 }
    end
    local ok, r = pcall(function()
        if actor.K2_GetActorRotation then
            return actor:K2_GetActorRotation()
        end
        if actor.GetActorRotation then
            return actor:GetActorRotation()
        end
        return actor.ActorRotation
    end)
    if ok and r ~= nil then
        return r
    end
    return { Roll = 0, Pitch = 0, Yaw = 0 }
end

local function _TryGetOwnerActor(selfObj)
    if selfObj == nil then
        return nil
    end

    local ok, owner = pcall(function()
        if selfObj.GetOwner then
            return selfObj:GetOwner()
        end
        if selfObj.GetOwnerActor then
            return selfObj:GetOwnerActor()
        end
        if selfObj.GetInstigator then
            return selfObj:GetInstigator()
        end
        if selfObj.GetInstigatorPawn then
            return selfObj:GetInstigatorPawn()
        end
        return selfObj.Owner
    end)
    if ok and _IsValid(owner) then
        return owner
    end
    return nil
end

local function _LoadEffectClass(effectPath)
    local fullPath = UGCGameSystem.GetUGCResourcesFullPath(effectPath)
    local cls = nil
    if UGCObjectUtility ~= nil and UGCObjectUtility.LoadClass ~= nil then
        local ok, r = pcall(function()
            return UGCObjectUtility.LoadClass(fullPath)
        end)
        if ok and _IsValid(r) then
            cls = r
        end
    end
    if cls == nil and UE ~= nil and UE.LoadClass ~= nil then
        local ok, r = pcall(function()
            return UE.LoadClass(fullPath)
        end)
        if ok and _IsValid(r) then
            cls = r
        end
    end
    return cls
end

local function _SpawnEffectActor(worldContext, cls, loc, rot, owner)
    if not _IsValid(cls) then
        return nil
    end

    local scale = { X = 1, Y = 1, Z = 1 }

    if UGCActorComponentUtility ~= nil and UGCActorComponentUtility.SpawnActor ~= nil then
        local ok, actor = pcall(function()
            return UGCActorComponentUtility.SpawnActor(worldContext, cls, loc, rot, scale, owner or worldContext)
        end)
        if ok and _IsValid(actor) then
            return actor
        end
    end

    if ScriptGameplayStatics ~= nil and ScriptGameplayStatics.SpawnActor ~= nil then
        local ok, actor = pcall(function()
            return ScriptGameplayStatics.SpawnActor(worldContext, cls, loc, rot, scale)
        end)
        if ok and _IsValid(actor) then
            return actor
        end
    end

    return nil
end

local function _SetupEffectActor(actor, bServer)
    if not _IsValid(actor) then
        return
    end

    pcall(function()
        if actor.SetActorEnableCollision then
            actor:SetActorEnableCollision(false)
        end
        if bServer ~= true then
            if actor.SetReplicates then
                actor:SetReplicates(false)
            end
            if actor.SetReplicateMovement then
                actor:SetReplicateMovement(false)
            end
        end
    end)
end

local function _TryInitProjectileMovement(actor, forward, speed)
    if not _IsValid(actor) then
        return
    end
    local s = tonumber(speed) or 0
    if s <= 0 then
        return
    end

    local pm = actor.ProjectileMovement or actor.ProjectileMovementComponent or actor.ProjectileMovementComp
    if pm == nil then
        return
    end

    pcall(function()
        if pm.ProjectileGravityScale ~= nil then
            pm.ProjectileGravityScale = 0
        elseif pm.GravityScale ~= nil then
            pm.GravityScale = 0
        end
        if pm.InitialSpeed ~= nil then
            pm.InitialSpeed = s
        end
        if pm.MaxSpeed ~= nil then
            pm.MaxSpeed = s
        end
        if pm.SetVelocityInLocalSpace ~= nil then
            pm:SetVelocityInLocalSpace({ X = s, Y = 0, Z = 0 })
        end
        local fx, fy, fz = _ReadVec(forward)
        pm.Velocity = { X = fx * s, Y = fy * s, Z = fz * s }
        if pm.Activate ~= nil then
            pm:Activate(true)
        end
    end)
end
 
function tangdao11:OnEnableSkill_BP()
    tangdao11.SuperClass.OnEnableSkill_BP(self)
end

function tangdao11:OnDisableSkill_BP()
    tangdao11.SuperClass.OnDisableSkill_BP(self)
end

function tangdao11:OnActivateSkill_BP()
    tangdao11.SuperClass.OnActivateSkill_BP(self)
end

function tangdao11:OnDeActivateSkill_BP()
    tangdao11.SuperClass.OnDeActivateSkill_BP(self)
end

function tangdao11:CanActivateSkill_BP()
    return tangdao11.SuperClass.CanActivateSkill_BP(self)
end

function tangdao11:Combo1_Entry()
end

function tangdao11:Combo1_Exit()
end

function tangdao11:ActivateFunction()
    local bServer = (UGCGameSystem ~= nil and UGCGameSystem.IsServer ~= nil and UGCGameSystem.IsServer() == true)

    local ownerActor = _TryGetOwnerActor(self)
    local caster = ownerActor or self

    local bAuthority = false
    if caster ~= nil and caster.HasAuthority ~= nil then
        local ok, r = pcall(function()
            return caster:HasAuthority()
        end)
        bAuthority = (ok and r == true) or false
    end

    if bServer == true or bAuthority == true then
    else
        return
    end

    local pc = nil
    if UGCGameSystem ~= nil and UGCGameSystem.GetPlayerControllerByPlayerPawn ~= nil and caster ~= self then
        pc = UGCGameSystem.GetPlayerControllerByPlayerPawn(caster)
    end
    local worldContext = pc or caster

    local loc = _GetLocation(caster)
    local rot = _GetRotation(caster)
    local forward = _GetForward(caster)
    local spawnLoc = _Add(loc, _Mul(forward, EFFECT_FORWARD_DISTANCE))
    spawnLoc.Z = (tonumber(spawnLoc.Z) or 0) + EFFECT_UP_OFFSET

    local effectClass = _LoadEffectClass(EFFECT_PATH)
    if effectClass == nil then
        ugcprint(string.format("[tangdao11] LoadClass failed path=%s", tostring(EFFECT_PATH)))
        return
    end

    local yaw = tonumber(rot.Yaw) or 0
    local pitch = tonumber(rot.Pitch) or 0
    local roll = tonumber(rot.Roll) or 0
    local spawnRot = { Pitch = pitch, Yaw = yaw, Roll = roll, X = pitch, Y = yaw, Z = roll }

    local spawned = _SpawnEffectActor(worldContext, effectClass, spawnLoc, spawnRot, caster)
    if _IsValid(spawned) then
        _SetupEffectActor(spawned, bServer)
        _TryInitProjectileMovement(spawned, forward, EFFECT_SPEED_UNITS)
    else
        ugcprint(string.format("[tangdao11] SpawnActor failed path=%s", tostring(EFFECT_PATH)))
    end

end
