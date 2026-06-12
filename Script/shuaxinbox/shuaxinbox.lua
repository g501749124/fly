---@class shuaxinbox_C:AActor
---@field ParticleSystem UParticleSystemComponent
---@field Box UBoxComponent
--Edit Below--
local shuaxinbox = {}

local MONSTER_CLASS_PATH = "Asset/Blueprint/Prefabs/Monsters/small1.small1_C"
local SPAWN_COUNT = 10
local SPAWN_FORWARD_DISTANCE = 1000
local SPAWN_SIDE_SPACING = 150
local SPAWN_FORWARD_SPACING = 150

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

local function _GetForward(pawn)
    if pawn == nil then
        return _Vec(1, 0, 0)
    end
    local ok, v = pcall(function()
        if pawn.GetActorForwardVector then
            return pawn:GetActorForwardVector()
        end
        if pawn.K2_GetActorForwardVector then
            return pawn:K2_GetActorForwardVector()
        end
        return pawn.ForwardVector
    end)
    if ok and v ~= nil then
        return v
    end
    return _Vec(1, 0, 0)
end

local function _GetRight(pawn)
    if pawn == nil then
        return _Vec(0, 1, 0)
    end
    local ok, v = pcall(function()
        if pawn.GetActorRightVector then
            return pawn:GetActorRightVector()
        end
        if pawn.K2_GetActorRightVector then
            return pawn:K2_GetActorRightVector()
        end
        return pawn.RightVector
    end)
    if ok and v ~= nil then
        return v
    end
    return _Vec(0, 1, 0)
end

local function _ResolvePlayer(OtherActor)
    local playerPawn, PC, uid = nil, nil, nil
    if UGCOverlapHelper and UGCOverlapHelper.ResolvePlayerOverlap then
        playerPawn, PC, uid = UGCOverlapHelper.ResolvePlayerOverlap(OtherActor)
    elseif UGCOverlapHelper and UGCOverlapHelper.ResolvePlayerPawnAndController then
        playerPawn, PC = UGCOverlapHelper.ResolvePlayerPawnAndController(OtherActor)
        if PC and PC.GetInt64UID then
            uid = tonumber(PC:GetInt64UID()) or nil
        end
    end
    if uid == nil and playerPawn ~= nil and UGCPawnAttrSystem and UGCPawnAttrSystem.GetPlayerUID then
        local ok, v = pcall(function()
            return UGCPawnAttrSystem.GetPlayerUID(playerPawn)
        end)
        if ok then
            uid = tonumber(v) or nil
        end
    end
    return playerPawn, PC, uid
end

local function _ResolvePlayerFast(OtherActor)
    if OtherActor == nil then
        return nil, nil, nil
    end

    local playerPawn = OtherActor
    local PC = UGCGameSystem.GetPlayerControllerByPlayerPawn and UGCGameSystem.GetPlayerControllerByPlayerPawn(playerPawn) or nil
    local uid = nil
    if PC and PC.GetInt64UID then
        uid = tonumber(PC:GetInt64UID()) or nil
    end
    if PC ~= nil then
        return playerPawn, PC, uid
    end

    return _ResolvePlayer(OtherActor)
end

local function _SpawnMonsters(selfActor, playerPawn)
    local clsPath = UGCGameSystem.GetUGCResourcesFullPath(MONSTER_CLASS_PATH)
    local cls = UE.LoadClass(clsPath)
    if cls == nil then
        ugcprint(string.format("[shuaxinbox] LoadClass failed: %s", tostring(clsPath)))
        return {}
    end

    local loc = playerPawn:K2_GetActorLocation()
    local rot = playerPawn:K2_GetActorRotation()
    if rot ~= nil then
        local yaw = tonumber(rot.Yaw) or 0
        rot.Yaw = yaw + 180
    end
    local forward = _GetForward(playerPawn)
    local right = _GetRight(playerPawn)
    local base = _Add(loc, _Mul(forward, SPAWN_FORWARD_DISTANCE))

    local spawned = {}
    for i = 1, SPAWN_COUNT do
        local row = math.floor((i - 1) / 5)
        local col = (i - 1) % 5
        col = col - 2

        local offset = _Add(_Mul(right, col * SPAWN_SIDE_SPACING), _Mul(forward, row * SPAWN_FORWARD_SPACING))
        local spawnLoc = _Add(base, offset)

        local ok, actor = pcall(function()
            return ScriptGameplayStatics.SpawnActor(selfActor, cls, spawnLoc, rot, { X = 1, Y = 1, Z = 1 })
        end)
        if ok and _IsValid(actor) then
            table.insert(spawned, actor)
        end
    end

    return spawned
end

local function _DestroyMonsters(list)
    if type(list) ~= "table" then
        return
    end
    for _, actor in ipairs(list) do
        if _IsValid(actor) then
            pcall(function()
                actor:K2_DestroyActor()
            end)
        end
    end
end

function shuaxinbox:ReceiveBeginPlay()
    shuaxinbox.SuperClass.ReceiveBeginPlay(self)
    self.__SpawnedByUID = self.__SpawnedByUID or {}
    ugcprint(string.format("[shuaxinbox] BeginPlay authority=%s", tostring(self:HasAuthority() == true)))
    if self.Box ~= nil then
        pcall(function()
            if self.Box.SetGenerateOverlapEvents then
                self.Box:SetGenerateOverlapEvents(true)
            end
        end)
    end
    if self.Box and self.Box.OnComponentBeginOverlap then
        self.Box.OnComponentBeginOverlap:Add(self.OnBeginOverlap, self)
    end
    if self.Box and self.Box.OnComponentEndOverlap then
        self.Box.OnComponentEndOverlap:Add(self.OnEndOverlap, self)
    end
end

function shuaxinbox:OnBeginOverlap(OverlappedComponent, OtherActor)
    local playerPawn, _, uid = _ResolvePlayerFast(OtherActor)
    if not _IsValid(playerPawn) then
        return
    end

    local key = uid
    if key == nil then
        key = tostring(playerPawn)
    end

    self.__SpawnedByUID = self.__SpawnedByUID or {}
    if self.__SpawnedByUID[key] ~= nil then
        return
    end

    ugcprint(string.format("[shuaxinbox] BeginOverlap authority=%s key=%s", tostring(self:HasAuthority() == true), tostring(key)))
    if self:HasAuthority() then
        local spawned = _SpawnMonsters(self, playerPawn)
        self.__SpawnedByUID[key] = spawned
    end
end

function shuaxinbox:OnEndOverlap(OverlappedComponent, OtherActor)
    local playerPawn, _, uid = _ResolvePlayerFast(OtherActor)
    if not _IsValid(playerPawn) then
        return
    end

    local key = uid
    if key == nil then
        key = tostring(playerPawn)
    end

    ugcprint(string.format("[shuaxinbox] EndOverlap authority=%s key=%s", tostring(self:HasAuthority() == true), tostring(key)))
    if not self:HasAuthority() then
        return
    end

    local map = self.__SpawnedByUID
    local list = map and map[key] or nil
    if list ~= nil then
        _DestroyMonsters(list)
        map[key] = nil
    end
end

--[[
function shuaxinbox:ReceiveTick(DeltaTime)
    shuaxinbox.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

function shuaxinbox:ReceiveEndPlay()
    shuaxinbox.SuperClass.ReceiveEndPlay(self) 
    if self:HasAuthority() then
        if self.__SpawnedByUID then
            for _, list in pairs(self.__SpawnedByUID) do
                _DestroyMonsters(list)
            end
        end
        self.__SpawnedByUID = nil
    end
end

--[[
function shuaxinbox:GetReplicatedProperties()
    return
end
--]]

--[[
function shuaxinbox:GetAvailableServerRPCs()
    return
end
--]]

return shuaxinbox
