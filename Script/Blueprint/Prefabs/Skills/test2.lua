---@class PassiveSkill_MovingReplyHP_C:PESkillTemplate_Base_C
--Edit Below--

--require('UGCDebugSystem')

local test2 = {
    OriginJumpCountLimit = 0
}

function test2:OnApply_BP()
    -- 修改跳跃属性值 +2次空中跳跃
    local Owner = self:GetNetOwnerActor()
    if not UE.IsValid(Owner) then
        print("test2:OnApply_BP Owner Is not Valid")
        return 
    end
    self.OriginJumpCountLimit = GameAttributeSystem.GetGameAttributeValue(Owner, NativeGameAttributeType.Character_JumpCountLimit)
    GameAttributeSystem.SetGameAttributeValue(Owner, NativeGameAttributeType.Character_JumpCountLimit,  self.OriginJumpCountLimit + self.AddJumpNumber);
end




function test2:OnUnApply_BP()
    local Owner = self:GetNetOwnerActor()
    if not UE.IsValid(Owner) then
        print("test2:OnUnApply_BP Owner Is not Valid")
        return 
    end
    GameAttributeSystem.SetGameAttributeValue(Owner, NativeGameAttributeType.Character_JumpCountLimit,  self.OriginJumpCountLimit );
end

return test2