# pubgld-mcp 能力边界检测报告

- **项目**: bag
- **编辑器**: 和平精英 UGC / UE 4.18
- **MCP 版本**: `0.3.4-ugc-safe`
- **复测结果**: **32/32 通过**（2026-06-08 编辑器重启后）
- **测试时间**: 2026-06-08
- **测试目录**: `/bag/Asset/MCPTest`（编辑器内创建）
- **原始结果**: `tools/pubgld-mcp/capability_test_results.json`

> 图例：✅ 实测可用　⚠️ 部分可用/有边界　❌ 不可用或被拦截　⏭ 未测

---

## 一、桥接 / 状态

| 工具 | 状态 | 说明 |
|------|------|------|
| `pubgld_bridge_status` | ✅ | 桥接正常，`editor_world_available=true` |
| `pubgld_editor_info` | ⚠️ | 可读引擎版本、地图名 `UGCmap`、路径；`get_system_path` 报错；选中/viewport/事务 API 已禁用 |
| `pubgld_known_risks` | ✅ | 返回安全/风险清单 |

---

## 二、关卡 Actor

| 工具 | 状态 | 说明 |
|------|------|------|
| `pubgld_list_actors`（无 label） | ⚠️ | **按设计拒绝**批量列举，防崩溃 |
| `pubgld_list_actors`（有 label） | ✅ | `Codex_MCP_TestActor` 查找成功 |
| `pubgld_spawn_actor` | ✅ | 成功生成 `StaticMeshActor` |
| `pubgld_get_actor_details` | ✅ | 可读位置/旋转/缩放/类名 |
| `pubgld_set_actor_location` | ✅ | 位置修改成功 |
| `pubgld_set_actor_transform` | ✅ | 0.3.4 已修 |
| `pubgld_select_actor` | ✅ | 选中成功 |
| `pubgld_get_selected` | ⚠️ | 工具可调用，但固定返回空（选中 API 禁用） |
| `pubgld_deselect_actors` | ✅ | 取消选中成功 |
| `pubgld_destroy_actor` | ✅ | 测试 Actor 已删除 |

---

## 三、资产 / 蓝图（测试路径：`/bag/Asset/Blueprint/UGCPlayerPawn`）

| 工具 | 状态 | 说明 |
|------|------|------|
| `pubgld_find_asset` | ✅ | 精确路径查找成功 |
| `pubgld_load_object_summary` | ✅ | 支持 `path` / `asset_path` |
| `pubgld_blueprint_summary` | ✅ | 读到父类、GeneratedClass、图表列表 |
| `pubgld_compile_blueprint` | ✅ | `UGCPlayerPawn` 编译成功 |
| `pubgld_asset_references` | ✅ | 依赖/引用可读（带上限） |
| `pubgld_duplicate_asset` | ✅ | `MCPTest` 内 Widget 复制成功 |
| `pubgld_delete_asset` | ✅ | 仅允许 `Codex_MCP_*` 临时资产，复制体已删 |
| `pubgld_rename_asset` | ⏭ | 未测 |
| `pubgld_save_current_level` | ✅ | 保存当前关卡成功 |
| `pubgld_save_assets` | ✅ | `save_current_level` 通过；`save_all` 仍需 `confirm=true` |

---

## 四、UGC Widget 蓝图（测试目录 `/bag/Asset/MCPTest`）

| 工具 | 状态 | 说明 |
|------|------|------|
| `pubgld_create_ugc_widget_blueprint` | ✅ | 创建 `Codex_MCP_TestWidget`（含 CanvasPanel 根） |
| `pubgld_get_widget_blueprint_summary` | ✅ | 浅读 WidgetTree/Animations 成功 |

---

## 五、编辑器 / 视口 / 底层

| 工具 | 状态 | 说明 |
|------|------|------|
| `pubgld_editor_viewport` | ⚠️ | 工具不崩，但读不到 viewport 尺寸 |
| `pubgld_transaction` | ✅ | `status` 通过（不读 transaction name） |
| `pubgld_console_exec` | ✅ | `stat unit` 执行成功 |
| `pubgld_unreal_api_catalog` | ✅ | 0.3.4 精确拦截后可用 |
| `pubgld_describe_unreal_api` | ✅ | 同上 |
| `pubgld_call_unreal_function` | ✅ | `get_engine_version` 调用成功 |
| `pubgld_eval_python` | ✅ | 简单表达式 `1+1` 成功 |
| `pubgld_exec_python` | ✅ | 简单 `print` 成功；危险模式会被拦截 |

---

## 六、明确不可用（Peace Elite UGC 硬边界）

| 能力 | 状态 | 原因 |
|------|------|------|
| 批量 `world.all_actors()` | ❌ | 会崩/卡死 |
| `editor_get_selected_actors()` | ❌ | TArray 断言崩溃 |
| `editor_get_active_viewport_size()` | ❌ | 同类风险 |
| Content Browser 选中资产 | ❌ | 模块断言风险 |
| 全量资产扫描 `get_assets*` | ❌ | UObject 数组压力 |
| 直接改 UMG WidgetTree / Animation | ❌ | 已知致命崩溃 |

---

## 七、测试后残留

| 项 | 状态 |
|----|------|
| `/bag/Asset/MCPTest/Codex_MCP_TestWidget` | 保留（测试用 Widget 蓝图） |
| `Codex_MCP_TestWidgetCopy` | 已删除 |
| `Codex_MCP_TestActor` | 已删除 |

---

## 八、结论（能力边界）

**我可以稳定帮你做：**
- 查桥接/编辑器基础信息
- 按 **精确路径** 查/编译蓝图、查依赖
- 在 **MCPTest** 或指定包路径创建/复制/删除 `Codex_MCP_*` 测试资产
- 按 **label** 生成/移动/选中/删除关卡 Actor
- 保存关卡、跑简单控制台命令、执行受控 Python

**我暂时不能稳定做：**
- 扫全关卡 Actor 列表
- 读编辑器当前选中集
- 读 viewport 尺寸
- API 目录/通用 `ue.*` 调用（被安全拦截误伤）
- 批量改 UMG 控件树

**0.3.4 修复项（均已复测通过）：**
1. `set_actor_transform` — `null` → `None`
2. `load_object_summary` — 支持 `path` / `asset_path`
3. `save_assets` — 支持 `operation` / `mode`
4. 安全拦截改为精确匹配函数调用 `xxx()`
5. `transaction status` — 去掉 `get_transaction_name()`
