# 和平精英 UGC · MeCat 宠物跟随功能迁移指南

> **致 Trae（字节）：**  
> 你好 Trae，我是 UE5 原型侧（BigJump 项目）的协作 AI。  
> 玩家「御剑 / 大跳」已在《和平精英UGC_御剑飞行迁移指南.md》里做过一版迁移说明；**本文档是下一项：MeCat 宠物跟随**。  
> 请你在 **和平精英 UGC 编辑器（Lua / 可视化逻辑）** 里复刻同等 **玩法手感**，API 名称以你们项目文档为准，找不到的用 `TODO_UGC_API("描述")` 标注。  
> 有疑问先对照下文 **验收清单** 自测，仍不确定再向人类策划确认。

---

## 一、背景与目标

### 1.1 原型是什么

在 UE5 BigJump 里，MeCat 是一只 **跟着玩家跑的宠物**：

- 外观：**淡蓝色方块**（占位，后续可换模型）
- 逻辑：**行为树 AI**，根据玩家状态切换 4 种跟随模式
- 生成：**玩家开局时**在身旁自动生成 1 只（世界里已有则不再生成）

### 1.2 UGC 侧要做到什么

| 能力 | 说明 |
|------|------|
| **地面跟随** | 玩家走路/跑步时，宠物用 **寻路** 追到玩家附近（约 1.8m 内停下） |
| **空中跟随** | 玩家 **御剑（G）** 或处于飞行/空中时，宠物飞过去伴飞 |
| **闪现追赶** | 离玩家 **> 28m** 时，宠物 **瞬移到玩家身后**（不慢慢跑） |
| **贴身绕圈** | 玩家站定且距离 **≤ 1.5m** 时，宠物在脚边 **绕圈陪玩** |
| **心情表现** | 方块颜色/缩放/微动画随状态变化（平静/兴奋/空中/追赶） |

### 1.3 与玩家技能的耦合

宠物 Brain 需要读玩家这些 **布尔/数值状态**（请与御剑、大跳模块对齐）：

| 玩家状态 | 键名建议 | 来源 |
|----------|----------|------|
| 是否御剑飞行 | `bOwnerSwordFlying` | 御剑模块 `SwordFly.bSwordFlying` |
| 是否大跳进行中 | `bOwnerBigJumping` | 大跳模块（F 技能） |
| 是否在空中/飞行 | `bOwnerFlying` | 移动模式为 Flying **或** 御剑中 |
| 水平速度 | `OwnerSpeed` | 玩家 Velocity 水平长度 |

> **Trae：** 若 UGC 侧御剑/大跳尚未实现，可先用全局变量 stub，但 **接口形状请保持一致**，方便后续对接。

---

## 二、UE 原型架构（对照用，不必 1:1 搬 BT）

```
玩家 BigJumpCharacter
  └── BeginPlay → TrySpawnMeCatPet()  // 身旁生成 MeCat

MeCat（MeCatPetCharacter）
  ├── 视觉：StaticMesh 方块 + 动态颜色
  ├── AIController（MeCatPetAIController）
  │     ├── Blackboard：BB_MeCatPet
  │     └── BehaviorTree：BT_MeCatPet
  └── 移动：CharacterMovement（走/飞均可）

BT_MeCatPet 结构：
  Root → Selector（优先级从上到下）
    ├── [1] Sequence → BTTask_MeCatCatchUp      // 太远：闪现
    ├── [2] Sequence → BTTask_MeCatAirFollow    // 空中：伴飞
    ├── [3] Sequence → BTTask_MeCatFollowGround   // 地面：NavMesh MoveTo
    └── [4] BTTask_MeCatPlayIdle                  // 贴身：绕圈

  Selector 上挂 Service：BTService_MeCatBrain（每 ~0.08s 更新黑板 + 心情）
```

**UGC 没有行为树时：** 用 **单个 Lua `Tick` 状态机** 等价实现（见第六节），效果一致即可。

---

## 三、黑板 / 运行时变量（全部需在 UGC 侧维护）

| 变量名 | 类型 | 默认值 | 含义 |
|--------|------|--------|------|
| `TargetActor` | 对象引用 | 玩家角色 | 跟随目标 |
| `TargetLocation` | Vector | — | 玩家位置（每帧更新） |
| `DistanceToOwner` | float | — | 与玩家距离（cm） |
| `AcceptableRadius` | float | **180** | 地面跟随「够近了」半径（cm） |
| `CatchUpDistance` | float | **2800** | 超过则闪现（cm，≈28m） |
| `IdleRadius` | float | **150** | 贴身绕圈半径（cm） |
| `bNeedsCatchUp` | bool | — | `Distance > CatchUpDistance` |
| `bOwnerFlying` | bool | — | 玩家在飞 |
| `bOwnerSwordFlying` | bool | — | 御剑中 |
| `bOwnerBigJumping` | bool | — | 大跳中 |
| `bShouldPlayIdle` | bool | — | `!CatchUp && !Flying && Distance <= IdleRadius` |
| `OwnerSpeed` | float | — | 玩家水平速度 |
| `PetMood` | enum | Calm | Calm / Excited / Airborne / CatchUp |

---

## 四、四种行为（优先级：上到下，命中即执行）

### 4.1 Catch Up — 闪现追赶（最高优先级）

**条件：** `bNeedsCatchUp == true`（距离 > 2800cm）

**行为：**

```
落点 = 玩家位置
     - 玩家朝向 * 130cm    // TeleportBehindDistance
     + (0, 0, 30cm)        // TeleportUpOffset
宠物.SetLocation(落点)
停止当前移动；若在飞行模式则切回行走
心情 = CatchUp（粉红）
```

**特点：** 一帧完成，**不寻路**。

---

### 4.2 Air Follow — 空中跟随

**条件：** `bOwnerFlying == true`（御剑或 Flying 移动模式）

**行为：**

```
宠物进入飞行/悬空移动模式
每帧目标点 = 玩家位置 + (0,0,-40cm) + 玩家速度 * 0.18   // FollowHeightOffset
朝目标点插值移动（MaxFlySpeed ≈ 980 cm/s，UE 原型值）
距离 < 220cm 且高度差 < 220cm → 悬停，任务结束
Abort/落地时：退出飞行，进入 Falling 或 Walking
心情 = Airborne（紫色，带旋转）
```

**特点：** **不用 NavMesh**，直接 3D 追点。

---

### 4.3 Follow Ground — 地面寻路跟随

**条件（全部满足）：**

- `NOT bNeedsCatchUp`
- `NOT bOwnerFlying`
- `NOT bShouldPlayIdle`
- `Distance > AcceptableRadius`（> 180cm）

**行为：**

```
目标 = 玩家位置 + 玩家速度 * 0.25秒   // LeadPredictionTime 预测
使用 NavMesh / UGC 寻路 API MoveTo(目标, 接受半径=180cm)
走到 Idle 或失败则结束
心情 = Calm；若 bOwnerBigJumping 或 OwnerSpeed>700 → Excited（橙色）
```

**特点：** **唯一依赖导航网格** 的分支。  
UGC 侧需：**烘焙 NavMesh** 或等效「AI 寻路层」；无 NavMesh 时 MoveTo 会失败，宠物可能站着不动。

---

### 4.4 Play Idle — 贴身绕圈

**条件：** `bShouldPlayIdle == true`（距离 ≤ 150cm，且不在飞、不用 CatchUp）

**行为：**

```
停止寻路
OrbitAngle += 85°/秒 * dt
偏移 = (cos(θ)*150, sin(θ)*150, 0)
位置 = 玩家位置 + 偏移 + Z 方向 sin 起伏 * 18cm
朝向 = 面向玩家
若 距离 > 180*1.35 或 玩家起飞 → 退出，交回跟随
心情 = Calm
```

**特点：** 每帧 **直接设位置**（绕圈），不寻路。

---

## 五、心情与视觉（MeCat 方块）

| 心情 | 颜色 RGB 约 | 触发 | 附加动画 |
|------|-------------|------|----------|
| **Calm** | (0.2, 0.85, 1.0) 淡蓝 | 默认 | 轻微缩放脉冲 |
| **Excited** | (1.0, 0.55, 0.15) 橙 | 大跳中 **或** 速度>700 | 左右微晃 Yaw ±8° |
| **Airborne** | (0.55, 0.35, 1.0) 紫 | 飞行/御剑 | 持续绕 Yaw 旋转 |
| **CatchUp** | (1.0, 0.2, 0.55) 粉红 | 闪现后 | 缩放 ×1.15 |

- 方块基准缩放：**0.75**（相对 Engine 100cm 立方体 ≈ 75cm 边长）
- 脉冲：`scale = base * (1 + sin(t*6)*0.06)`

UGC 若无动态材质，可用 **换色 Mesh / 粒子 / UI 标记** 代替，但四种状态要能区分。

---

## 六、UGC 推荐实现：Lua 状态机（替代行为树）

> Trae：建议模块划分如下，与御剑文档风格一致。

### 6.1 模块清单

1. `MeCatConfig` — 上表所有默认参数  
2. `MeCatSpawn` — 玩家开局生成宠物  
3. `MeCatBrain` — 每 0.08s（或每帧）更新黑板变量 + 心情  
4. `MeCatBehavior` — 按优先级执行 CatchUp / Air / Ground / Idle  
5. `MeCatVisual` — 颜色、缩放、旋转  
6. `MeCatPlayerBridge` — 读 `SwordFly` / `BigJump` 状态  

### 6.2 主 Tick 伪代码

```lua
-- MeCatBehavior.Tick(pet, dt)
local bb = pet.Blackboard
MeCatBrain.Update(pet, bb, dt)   -- 距离、flags、心情

if bb.bNeedsCatchUp then
    MeCatBehavior.DoCatchUp(pet, bb)
    return
end

if bb.bOwnerFlying then
    MeCatBehavior.DoAirFollow(pet, bb, dt)
    return
end

if bb.bShouldPlayIdle then
    MeCatBehavior.DoIdleOrbit(pet, bb, dt)
    return
end

if bb.DistanceToOwner > bb.AcceptableRadius then
    MeCatBehavior.DoGroundFollow(pet, bb)  -- NavMesh MoveTo
    return
end

-- 150cm < 距离 <= 180cm 的空档：可站立或缓慢靠近，见第七节
MeCatVisual.Apply(pet, bb.PetMood, dt)
```

### 6.3 生成逻辑（等价 TrySpawnMeCatPet）

```lua
function MeCatSpawn.EnsureForPlayer(player)
    if MeCatSpawn.FindExistingPet(player) then return end
    local char = GetControlledCharacter(player)
    local offset = char:GetForwardVector() * 180 + char:GetRightVector() * 80
    local loc = char:GetLocation() + offset
    -- TODO_UGC_API("SpawnActor / 放置预设 MeCat 蓝图")
    SpawnMeCatPreset(loc, char)
end

-- 在玩家 OnBeginPlay / 进入对局时调用一次
```

### 6.4 地面寻路（UGC API 占位）

```lua
function MeCatBehavior.DoGroundFollow(pet, bb)
    local goal = bb.TargetLocation + bb.OwnerVelocity * 0.25
    -- TODO_UGC_API("AI MoveTo / NavMesh 寻路")
    -- 示例：AIMoveTo(pet, goal, { acceptanceRadius = bb.AcceptableRadius, useNavMesh = true })
    if not MoveToSucceeded then
        -- 备选：直线 MoveTo 无 NavMesh（体验差，仅调试）
    end
end
```

### 6.5 与御剑模块对接

```lua
function MeCatPlayerBridge.ReadOwnerFlags(player)
    return {
        bOwnerSwordFlying = SwordFly and SwordFly.bSwordFlying or false,
        bOwnerBigJumping = BigJump and BigJump.bInProgress or false,
        bOwnerFlying = IsFlyingMode(player) or SwordFly.bSwordFlying,
        OwnerSpeed = GetHorizontalSpeed(player),
    }
end
```

---

## 七、已知边界与建议

### 7.1 距离空档（150cm～180cm）

UE 原型里：Ground 认为「够近」失败，Idle 认为「还不够近」也失败 → 宠物可能 **短暂愣住**。  

**UGC 建议：** 合并阈值，或在此区间 **继续 Slow Follow / 保持 Idle**，避免无行为。

### 7.2 NavMesh 范围

地面跟随 **只在有 NavMesh 的区域有效**。关卡需放置 **NavMesh Bounds**（或 UGC 等效）并烘焙。

### 7.3 多玩家

原型只跟随 **本地玩家 0**。UGC 若为多人，请明确：每人一只宠物 **跟随各自 Owner**，`TargetActor` 绑对应 PlayerState。

### 7.4 性能

Brain 更新间隔 **0.08s** 即可，不必每帧重算距离；视觉 `Apply` 可每帧。

---

## 八、参数速查表（Lua 常量，可暴露给策划）

```lua
MeCatConfig = {
    AcceptableRadius      = 180,    -- cm，地面跟随停止距离
    CatchUpDistance       = 2800,   -- cm，触发闪现
    IdleRadius            = 150,    -- cm，绕圈半径
    TeleportBehindDistance = 130,
    TeleportUpOffset      = 30,
    FollowHeightOffset    = -40,    -- 空中跟随高度差
    AirAcceptanceRadius   = 220,
    LeadPredictionTime    = 0.25,   -- 秒
    OrbitSpeedDeg         = 85,
    BobAmplitude          = 18,
    ExcitedSpeedThreshold = 700,    -- cm/s
    BrainInterval         = 0.08,   -- 秒
    MaxWalkSpeed          = 620,    -- 宠物地面速度（可调）
    MaxFlySpeed           = 980,    -- 宠物飞行速度
    CubeBaseScale         = 0.75,
    SpawnOffsetForward    = 180,
    SpawnOffsetRight      = 80,
}
```

---

## 九、验收清单（Trae 自测用）

- [ ] 进入对局，玩家身旁 **自动生成** 1 只 MeCat（不重复生成）  
- [ ] 走路/跑步：宠物 **寻路跟随**，约 1.8m 内停下  
- [ ] 站定贴身：宠物 **绕圈**，面向玩家  
- [ ] 跑远 >28m：宠物 **闪到身后**（粉红）  
- [ ] 按 **G** 御剑：宠物 **空中伴飞**（紫色）  
- [ ] 按 **F** 大跳（若已实现）：宠物 **兴奋色** 且空中跟随  
- [ ] 无 NavMesh 区域：地面跟随有明确降级或日志，不 silent fail  
- [ ] 退出再进、多人（若支持）：行为仍正确  

---

## 十、UE 原型源文件索引（人类/Trae 查细节用）

| 内容 | 路径 |
|------|------|
| 宠物角色 + 方块视觉 | `Source/BigJump/Animals/MeCatPetCharacter.*` |
| AI 控制器 + BB/BT 引用 | `Source/BigJump/Animals/MeCatPetAIController.*` |
| Brain 服务 | `Source/BigJump/Animals/BTService_MeCatBrain.*` |
| 闪现 / 空中 / 地面 / 绕圈 Task | `Source/BigJump/Animals/BTTask_MeCat*.cpp` |
| 黑板键名 | `Source/BigJump/Animals/MeCatPetBlackboardKeys.h` |
| 玩家侧生成 + 御剑/大跳 API | `Source/BigJump/BigJumpCharacter.*` |
| 行为树资产 | `/Game/Animals/AI/BT_MeCatPet` |
| 黑板资产 | `/Game/Animals/AI/BB_MeCatPet` |
| 宠物蓝图 | `/Game/Animals/MeCat` |
| 御剑 UGC 前置文档 | `和平精英UGC_御剑飞行迁移指南.md`（同目录） |

---

## 十一、给 Trae 的执行顺序建议

1. 读《御剑飞行迁移指南》，确认 `bOwnerSwordFlying` / 飞行模式可读  
2. 做 **MeCat 预设**（方块模型 + 可改色）  
3. 实现 **MeCatSpawn** + **MeCatBrain**  
4. 实现四分支 **MeCatBehavior**（先 CatchUp + Air + Idle，最后 Ground+NavMesh）  
5. 接 **MeCatVisual**  
6. 跑 **第九节验收清单**  

---

**Trae，辛苦了。** 按本文档实现后，玩法应与 UE BigJump 里的 MeCat 一致；数值可在 `MeCatConfig` 里调，不必改结构。  
若 UGC API 与伪代码差异大，请在提交说明里列出 `TODO_UGC_API` 及你的替代方案。

— BigJump / UE5 原型协作 AI
