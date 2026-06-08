# 和平精英 UGC · 御剑飞行功能迁移指南

> 本文档用于交给 **和平精英 UGC 编辑器 AI**，指导其在 Lua 环境下实现「御剑飞行」功能。  
> 原型参考：UE5 第三人称项目 BigJump（G 切换悬空、WASD 平飞、Q/E 升降、角色+剑 Mesh，非载具）。

---

## 一、背景与目标

在和平精英 UGC 编辑器里，实现 **御剑飞行** 功能，行为如下：

| 操作 | 效果 |
|------|------|
| **G** | 切换御剑：第一次 → 进入悬空飞行，剑出现；再按一次 → 退出飞行，角色下落 |
| **WASD** | 飞行时按 **相机/视角方向** 水平移动 |
| **Q** | 下降 |
| **E** | 上升 |
| **空格** | 地面正常跳跃；**飞行中禁用** |
| **F（可选）** | 若有其他技能，飞行中应禁用，避免冲突 |

**架构要求：不要做成载具 / 不要切换 Pawn。**  
采用：**同一玩家角色 + 脚下挂载剑模型 + 切换飞行移动模式**。

---

## 二、核心设计

```
PlayerCharacter（玩家角色）
├── 移动模式：Normal（走/跑/跳/落） ↔ Flying（御剑）
├── SwordMount（脚下挂点，略靠前）
│   └── SwordMesh（StaticMesh，平时隐藏，御剑时显示）
└── SwordFlyTrail（可选粒子/特效，挂剑上，御剑时播放）
```

### 状态机

```
Ground/Air ──[按 G]──> SwordFlying（悬空，Flying 或 UGC 等效飞行模式）
SwordFlying ──[按 G]──> Falling（退出飞行，恢复重力，自然下落）
SwordFlying ──[落地]──> Ground（隐藏剑，恢复 Normal）
```

### 手感目标（仙侠御剑，不要太空飘）

- **进入飞行**：速度在 **0.2 秒** 内缓到接近悬停，不要一切换就猛冲
- **水平**：跟手、能刹住；松开 WASD 应明显减速
- **垂直**：Q/E 有明确升降；松开 Q/E 后垂直速度回到 0
- **转向**：角色 **Yaw 跟随相机/视角**，不是纯按移动方向转（第三人称御剑感）
- **相机**：飞行时镜头略拉远（若有 API）
- **剑**：显示在脚底下略前方，略前倾，**不参与碰撞**

---

## 三、推荐参数（Lua 常量，可暴露给策划调）

```lua
-- 单位按 UGC/UE 常见 cm/s 理解；若 API 不同请换算
SWORD_FLY_MAX_SPEED = 1050          -- 水平最大速度
SWORD_FLY_CLIMB_SPEED = 700         -- Q/E 升降速度
SWORD_FLY_BRAKING = 1300            -- 松键制动
SWORD_FLY_ACCEL = 2200              -- 加速
SWORD_FLY_ENTER_BLEND = 0.22        -- 进入飞行速度归零时间（秒）
SWORD_FLY_CAMERA_DISTANCE = 520     -- 飞行相机距离（若有）

-- 剑挂点（相对角色，单位 cm）
SWORD_MOUNT_OFFSET = { X = 35, Y = 0, Z = -88 }
SWORD_MOUNT_ROT = { Pitch = -12, Yaw = 0, Roll = 0 }
SWORD_PLACEHOLDER_SCALE = { X = 2.2, Y = 0.18, Z = 0.45 }  -- 占位用
```

---

## 四、请 AI 实现的 Lua 逻辑

> **说明：** 和平精英 UGC 的具体 API 名称因版本而异。请先查当前项目/文档里的玩家控制、输入、移动模式、Attach、特效相关接口，再按下面结构落地；找不到的 API 用 `TODO_UGC_API("描述")` 标注并给出备选方案。

### 4.1 模块清单

1. `SwordFlyConfig` — 参数表
2. `SwordFlyState` — `bSwordFlying`、缓存的正常移动参数、进入混合计时
3. `SwordFlyInput` — 绑定 G / WASD / Q / E
4. `SwordFlyVisual` — 创建/显示/隐藏剑 Mesh、可选尾迹
5. `SwordFlyMovement` — 进入/退出飞行、Tick 里处理移动
6. `SwordFlyRules` — 飞行中禁跳、禁其他技能

### 4.2 伪代码骨架（需改写成真实 UGC Lua）

```lua
local SwordFly = {
    bSwordFlying = false,
    enterBlendRemaining = 0,
    cached = {},  -- 进入前缓存的移动/相机参数
    swordActor = nil,  -- 或 swordMeshComponent
    trailFx = nil,
}

-- ========== 输入 ==========
function SwordFly.OnKeyGPressed(player)
    if SwordFly.bSwordFlying then
        SwordFly.Exit(player)
    else
        SwordFly.Enter(player)
    end
end

function SwordFly.GetMoveInput(player)
    -- 返回 forward, right in [-1, 1]，来自 WASD
end

function SwordFly.GetVerticalAxis(player)
    local v = 0
    if IsKeyDown(player, "E") then v = v + 1 end
    if IsKeyDown(player, "Q") then v = v - 1 end
    return v
end

-- ========== 进入 / 退出 ==========
function SwordFly.Enter(player)
    local char = GetControlledCharacter(player)
    if not char then return end

    -- 1. 缓存 Normal 模式参数
    SwordFly.cached = {
        maxSpeed = GetMaxSpeed(char),
        gravity = GetGravityScale(char),
        cameraDist = GetCameraDistance(player),
    }

    -- 2. 切飞行模式（UGC 等效 SET MOVE_Flying）
    SetMovementMode(char, "Flying")  -- TODO_UGC_API

    -- 3. 应用飞行参数
    SetMaxFlySpeed(char, SWORD_FLY_MAX_SPEED)
    SetFlyBraking(char, SWORD_FLY_BRAKING)
    SetMaxAcceleration(char, SWORD_FLY_ACCEL)
    SetOrientRotationToMovement(char, false)

    -- 4. 进入混合：速度 Lerp 到 0
    SwordFly.enterBlendRemaining = SWORD_FLY_ENTER_BLEND
    local vel = GetVelocity(char)
    SetVelocity(char, ScaleVector(vel, 0.15))

    -- 5. 显示剑 + 尾迹
    SwordFly.ShowSword(char)
    SwordFly.StartTrail(char)

    -- 6. 相机拉远
    SetCameraDistance(player, SWORD_FLY_CAMERA_DISTANCE)

    SwordFly.bSwordFlying = true
end

function SwordFly.Exit(player)
    local char = GetControlledCharacter(player)
    if not char then return end

    RestoreFromCache(char, player, SwordFly.cached)
    SwordFly.HideSword(char)
    SwordFly.StopTrail()

    SetMovementMode(char, "Falling")
    local vel = GetVelocity(char)
    SetVelocity(char, { X = vel.X, Y = vel.Y, Z = math.min(vel.Z, 0) })

    SwordFly.bSwordFlying = false
    SwordFly.enterBlendRemaining = 0
end

-- ========== Tick（每帧 / OnUpdate） ==========
function SwordFly.Tick(player, dt)
    if not SwordFly.bSwordFlying then return end
    local char = GetControlledCharacter(player)
    if not char then return end

    if SwordFly.enterBlendRemaining > 0 then
        local vel = GetVelocity(char)
        SetVelocity(char, LerpVector(vel, {0,0,0}, dt / SwordFly.enterBlendRemaining))
        SwordFly.enterBlendRemaining = math.max(0, SwordFly.enterBlendRemaining - dt)
    end

    local yaw = GetControlYaw(player)
    SetActorRotation(char, { Pitch = 0, Yaw = yaw, Roll = 0 })

    local fwd, right = SwordFly.GetMoveInput(player)
    local forwardVec = GetYawForwardVector(yaw)
    local rightVec = GetYawRightVector(yaw)
    AddMovementInput(char, forwardVec, fwd)
    AddMovementInput(char, rightVec, right)

    local vert = SwordFly.GetVerticalAxis(player)
    local vel = GetVelocity(char)
    if math.abs(vert) > 0.01 then
        vel.Z = Lerp(vel.Z, vert * SWORD_FLY_CLIMB_SPEED, dt * 8)
    else
        vel.Z = Lerp(vel.Z, 0, dt * 6)
    end
    SetVelocity(char, vel)
end

-- ========== 规则 ==========
function SwordFly.CanJump(player)
    return not SwordFly.bSwordFlying
end

function SwordFly.OnLanded(player)
    if SwordFly.bSwordFlying then
        SwordFly.Exit(player)
    end
    SwordFly.HideSword(GetControlledCharacter(player))
end
```

### 4.3 剑模型（Visual 模块）

```lua
function SwordFly.ShowSword(char)
    if SwordFly.swordActor then
        SetHidden(SwordFly.swordActor, false)
        return
    end
    -- 方案 A：Attach StaticMesh 到角色 Socket/SceneComponent
    -- 方案 B：Spawn 子 Actor 并 Attach 到 char
    SwordFly.swordActor = SpawnAndAttachMesh(char, "SwordMeshAssetPath", SWORD_MOUNT_OFFSET, SWORD_MOUNT_ROT)
    SetCollisionEnabled(SwordFly.swordActor, false)
end
```

### 4.4 AI 交付物要求

请输出：

1. **完整 Lua 脚本**（含注册 Tick、输入、落地事件）
2. **API 对照表**：每个 `TODO_UGC_API` 对应查到的真实函数名
3. **挂载说明**：脚本挂在哪个 Actor / GameMode / PlayerController
4. **参数表**：哪些可在 UGC 面板里调
5. **已知限制**：UGC 不支持的能力及替代方案

---

## 五、必须由人类完成的辅助工作

> 以下步骤 AI 通常无法代劳。请 AI 在对应位置留 **配置项/占位符**，并列出我需要填写的资源 ID。

### 5.1 资源准备（必做）

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 在 UGC 资源库找 **剑 StaticMesh** | 搜 sword / blade / weapon；没有就用 **细长 Cube** 当占位 |
| 2 | 导入或选用 **飞行尾迹粒子** | 可复用「拖尾/灵气」类特效；挂剑 Mount 点 |
| 3 | 确认 **角色蓝图/预制体** 路径 | 脚本要 Attach 到这个角色上 |
| 4 | （可选）御剑 **音效**：起剑、飞行循环、收剑 | 增强手感 |

### 5.2 输入绑定（必做）

| 步骤 | 操作 |
|------|------|
| 1 | 在 UGC **输入/按键映射** 里确认 **G、Q、E** 未被占用 |
| 2 | 若 UGC 只支持「技能槽」不支持裸键，把御剑绑到 **空技能键** 并告诉 AI 键位 ID |
| 3 | **WASD** 一般已有；确认飞行时不会和载具/游泳模式冲突 |
| 4 | 真机测一遍：**G 是否触发**（模拟器与手机可能不同） |

### 5.3 编辑器内挂载（必做）

| 步骤 | 操作 |
|------|------|
| 1 | 把 AI 生成的 Lua 挂到 **玩家控制器 / 角色逻辑 / GameMode**（按 AI 说明选一种） |
| 2 | 在面板填：**剑模型资源 ID、挂点偏移、速度参数** |
| 3 | **发布前编译/校验** UGC 工程，修 Lua 报错 |
| 4 | **本地试玩** → **真机试玩** 各测一轮 |

### 5.4 移动模式与权限（重点排查）

和平精英 UGC 可能没有完整 `MOVE_Flying`，需要配合 AI 确认：

- [ ] 是否有官方 **飞行 / 悬浮 / 无重力移动** 模块
- [ ] 若无：是否允许 **每帧 SetLocation / SetVelocity**（注意性能与反作弊）
- [ ] 飞行高度是否有 **地图上限 / 空气墙**
- [ ] 是否有 **禁飞区**（室内、毒圈外等）需要在脚本里加判断

**若找不到 Flying 模式：**  
请 AI 改用「关闭重力 + Tick 里手动位移」方案，并实现 **`ApplyManualFlightVelocity`** 备选。

### 5.5 表现与碰撞（建议人工微调）

| 项目 | 建议 |
|------|------|
| 剑位置 | 脚底下、略往前；角色别穿模进剑 |
| 剑碰撞 | **必须关**，否则卡墙 |
| 相机 | 飞行时拉远；室内自动缩短（可选） |
| 动画 | 第一版可不改；第二版加「站剑」姿势（若 UGC 支持） |

### 5.6 测试清单（人工勾选）

- [ ] 地面按 G → 悬空，剑出现
- [ ] 空中按 G → 也能进入飞行
- [ ] 再按 G → 下落，剑隐藏
- [ ] WASD 方向跟视角一致
- [ ] Q 降、E 升，松开能停住
- [ ] 飞行中空格无效
- [ ] 贴地/撞墙不穿模、不卡死
- [ ] 多人：其他玩家能否看见剑和尾迹（若不支持，记录为已知问题）

---

## 六、约束与禁止项

1. **不要** 新建载具、不要 Possess 新 Pawn
2. **不要** 飞行中叠加跳跃或原有大跳逻辑
3. **不要** 给剑开碰撞
4. **必须** G 为 Toggle，不是长按
5. **必须** 进入飞行有短过渡，避免瞬移感
6. **必须** 标注所有依赖的 UGC API 版本假设
7. 若 API 不确定，**先输出探测脚本**（打印可用移动/输入接口），再写完整逻辑

---

## 七、验收标准

功能与 BigJump 原型一致：

1. G 开 / G 关御剑
2. 御剑时悬空，WASD + Q/E 可控
3. 剑模型可见，位置合理
4. 退出后正常下落、落地后可走路跳跃
5. 参数可在 UGC 面板调整，无需改代码即可微调速度

---

## 八、给 AI 的一句话任务

> 请按本文档实现和平精英 UGC Lua 版「御剑飞行」：G 切换悬空飞行，WASD 相机方向移动，Q/E 升降，角色+剑 Mesh 挂载，非载具。先查本项目真实 API 再写完整脚本，并列出第五节中需要我手动完成的配置项清单。

---

*文档生成自 BigJump 御剑飞行原型（UE5 / CMC MOVE_Flying + SwordMesh）。*
