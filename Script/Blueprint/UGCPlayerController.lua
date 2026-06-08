---@class UGCPlayerController_C:BP_UGCPlayerController_C
---@field LotteryComponent LotteryComponent_C
--Edit Below--
local UGCPlayerController = {}

-- 通用提示通道：其他系统（例如御剑）可以直接调用 pc:ClientRPC_Tip / pc:ServerTip
function UGCPlayerController:ClientRPC_Tip(tip)
    if UGCWidgetManagerSystem and UGCWidgetManagerSystem.ShowTipsUI then
        UGCWidgetManagerSystem.ShowTipsUI(tostring(tip or ""))
    else
        ugcprint(tostring(tip or ""))
    end
end

function UGCPlayerController:ServerTip(tip)
    if self:HasAuthority() then
        if UnrealNetwork and UnrealNetwork.CallUnrealRPC then
            UnrealNetwork.CallUnrealRPC(self, self, "ClientRPC_Tip", tostring(tip or ""))
        else
            self:ClientRPC_Tip(tip)
        end
    else
        self:ClientRPC_Tip(tip)
    end
end

function UGCPlayerController:ReceiveBeginPlay()
    UGCPlayerController.SuperClass.ReceiveBeginPlay(self)

    local platform = UGCGameSystem.GetPlatformInfo()
    ugcprint(string.format("[UGCPC] BeginPlay platform=%s authority=%s", tostring(platform), tostring(self:HasAuthority())))

    if not self:HasAuthority() then
        local ok, err = pcall(function()
            local btnClass = UE.LoadClass(UGCGameSystem.GetUGCResourcesFullPath('ExtendResource/Lottery/OfficialPackage/Asset/Lottery/Blueprint/WBP_OpenLotteryButton.WBP_OpenLotteryButton_C'))
            local btnUI = UserWidget.NewWidgetObjectBP(self, btnClass)
            btnUI:AddToViewport(100)
        end)
        if not ok then
            ugcprint(string.format("[UGCPC] CreateLotteryButton failed: %s", tostring(err)))
        end
    end
end

function UGCPlayerController:ReceiveEndPlay()
    UGCPlayerController.SuperClass.ReceiveEndPlay(self) 
end

return UGCPlayerController
