---@class test_C:PESkillTemplate_Base_C
---@field UpDirection FVector
--Edit Below--
---@class Skill_FloatingAttack_C:PESkillTemplate_Base_C
---@
local test = {}

function test:SelectUpDirection()
    self:SetSelectDirection(self.UpDirection)
end

function test:SetGravityScaleZero()
    -- ugcprint("IndicateSkill_Float:SetGravityScale()")
    ---@type UGCPlayerPawn_C
    local OwnerCharacter =  self.Owner.Owner
    ---@type USTCharacterMovementComponent
    local MoveComp = OwnerCharacter:GetCharacterMovementComponent()
    if MoveComp then
        self.OriginGravityScale = MoveComp.GravityScale
        MoveComp.GravityScale = 0
    end
    
end

-- 恢复重力系数
function test:RestoreGravityScale()
    ---@type UGCPlayerPawn_C
    local OwnerCharacter =  self:GetNetOwnerActor()
    ---@type USTCharacterMovementComponent
    local MoveComp = OwnerCharacter:GetCharacterMovementComponent()
    if MoveComp then
        MoveComp.GravityScale = self.OriginGravityScale
    end
end

function test:ForceCast_Entry()
    self:RestoreGravityScale()
end

--function test:ForceCast_Entry()
    --self:RestoreGravityScale()
--end

function test:TriggerFunction()
end

function test:DeactivateFunction()
end

function test:ActivateFunction()
end

return test