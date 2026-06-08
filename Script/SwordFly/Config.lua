local Config = {}

-- 御剑飞行：参数配置（客户端/服务端都会读取）
-- 说明：
-- 1) 水平移动：使用角色原生 CharacterMovement（MOVE_Flying + WASD）
-- 2) 垂直移动：由 Q/E 按住驱动 AddMovementInput(UpVector)

Config.MaxFlySpeed = 4500
Config.BrakingDecelerationFlying = 1300
Config.MaxAcceleration = 2200
Config.EnterBlendTime = 0.22

-- 剑挂载到角色 Mesh 的相对偏移/旋转
Config.MountOffset = { X = 35, Y = 0, Z = -88 }
Config.MountRot = { Pitch = -12, Yaw = 90, Roll = 0 }

-- 剑蓝图资源（相对 UGC 资源根目录）
Config.SwordClassPath = "Asset/Sword/Sword.Sword_C"

-- 进入御剑时镜头拉远（SpringArm.TargetArmLength 增量）
Config.CameraArmLengthDelta = 160

return Config
