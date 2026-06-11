---@class UGCGameMode_C:BP_UGCGameBase_C
--Edit Below--
local UGCGameMode = {}

local WeekdayNameMap = {
    [1] = "星期日",
    [2] = "星期一",
    [3] = "星期二",
    [4] = "星期三",
    [5] = "星期四",
    [6] = "星期五",
    [7] = "星期六",
}

local function GetCurrentWeekdayText()
    local ok, now = pcall(function()
        return os.date("*t")
    end)
    if not ok or now == nil then
        return "未知"
    end

    return WeekdayNameMap[now.wday] or ("未知(" .. tostring(now.wday) .. ")")
end

local function PrintCurrentDateTimeFields()
    local ok, now = pcall(function()
        return os.date("*t")
    end)
    if not ok or now == nil then
        ugcprint("[TimeDebug] os.date(\"*t\") 获取失败")
        return
    end

    local lines = {
        "[TimeDebug] ===== 当前时间字段开始 =====",
        string.format("[TimeDebug] year  = %s", tostring(now.year)),
        string.format("[TimeDebug] month = %s", tostring(now.month)),
        string.format("[TimeDebug] day   = %s", tostring(now.day)),
        string.format("[TimeDebug] hour  = %s", tostring(now.hour)),
        string.format("[TimeDebug] min   = %s", tostring(now.min)),
        string.format("[TimeDebug] sec   = %s", tostring(now.sec)),
        string.format("[TimeDebug] wday  = %s (%s)", tostring(now.wday), WeekdayNameMap[now.wday] or "未知"),
        string.format("[TimeDebug] yday  = %s", tostring(now.yday)),
        string.format("[TimeDebug] isdst = %s", tostring(now.isdst)),
        string.format(
            "[TimeDebug] format = %04d-%02d-%02d %02d:%02d:%02d",
            tonumber(now.year) or 0,
            tonumber(now.month) or 0,
            tonumber(now.day) or 0,
            tonumber(now.hour) or 0,
            tonumber(now.min) or 0,
            tonumber(now.sec) or 0
        ),
        "[TimeDebug] ===== 当前时间字段结束 =====",
    }

    for _, line in ipairs(lines) do
        ugcprint(line)
    end
end

local function TryGetPlayerKeyFromController(controller)
    if controller == nil then
        return nil
    end

    local pk = controller.PlayerKey
    if pk == nil then
        pk = controller.PlayerKeyInt64
    end
    if pk == nil then
        pk = controller.PlayerKeyString
    end
    pk = tonumber(pk)
    if pk ~= nil then
        return pk
    end

    local ps = controller.PlayerState
    if ps ~= nil and UGCPlayerStateSystem ~= nil and UGCPlayerStateSystem.GetPlayerKeyInt64 ~= nil then
        local ok, key = pcall(function()
            return UGCPlayerStateSystem.GetPlayerKeyInt64(ps)
        end)
        if ok then
            return tonumber(key)
        end
    end

    return nil
end

function UGCGameMode:ReceiveBeginPlay()
    UGCGameMode.SuperClass.ReceiveBeginPlay(self)

    local weekdayText = GetCurrentWeekdayText()
    ugcprint(string.format("[WeekdayTest] 当前星期：%s", weekdayText))
    PrintCurrentDateTimeFields()

    if self.PlayerRespawnComponent ~= nil and self.PlayerRespawnComponent.SetRespawnTime ~= nil then
        pcall(function()
            self.PlayerRespawnComponent:SetRespawnTime(0, 0)
        end)
    end
end

function UGCGameMode:UGC_PlayerKilledEvent(Killer, VictimPlayer, VictimPawn, DamageType)
    pcall(function()
        if UGCGameMode.SuperClass.UGC_PlayerKilledEvent ~= nil then
            UGCGameMode.SuperClass.UGC_PlayerKilledEvent(self, Killer, VictimPlayer, VictimPawn, DamageType)
        end
    end)

    local playerKey = TryGetPlayerKeyFromController(VictimPlayer)
    if playerKey == nil and VictimPawn ~= nil then
        playerKey = tonumber(VictimPawn.PlayerKey)
    end

    local killerKey = TryGetPlayerKeyFromController(Killer)

    if self.PlayerRespawnComponent ~= nil and self.PlayerRespawnComponent.OnPlayerKilled ~= nil and playerKey ~= nil then
        pcall(function()
            self.PlayerRespawnComponent:OnPlayerKilled(playerKey, tonumber(killerKey) or 0, false)
        end)
        return
    end

    if playerKey ~= nil and UGCPlayerPawnSystem ~= nil and UGCPlayerPawnSystem.RespawnPlayer ~= nil then
        pcall(function()
            UGCPlayerPawnSystem.RespawnPlayer(playerKey, 0, false, 0.01)
        end)
    end
end

-- function UGCGameMode:ReceiveTick(DeltaTime)
--
-- end
-- function UGCGameMode:ReceiveEndPlay()
--
-- end
return UGCGameMode
