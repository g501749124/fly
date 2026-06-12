---@class AnimalController_C:BaseAIController
--Edit Below--
local AnimalController = {}

function AnimalController:GetBehaviorTreeObjectPath()
    return UGCGameSystem.GetUGCResourcesFullPath("Asset/AI/MyBT.MyBT")
end

function AnimalController:OnPossess(PossessedPawn)
    AnimalController.SuperClass.OnPossess(self, PossessedPawn)

    local BehaviorTree = UE.LoadObject(self:GetBehaviorTreeObjectPath())
    if BehaviorTree ~= nil then
        self:RunBehaviorTree(BehaviorTree)
    end
end

--[[
function AnimalController:OnUnpossess(UnpossessedPawn)
    AnimalController.SuperClass.OnUnpossess(self, UnpossessedPawn)
end
--]]

return AnimalController
