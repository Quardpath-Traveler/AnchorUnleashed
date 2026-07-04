# 教学关卡（Tutorial Level）设计

## 背景

项目目前的核心玩法已经实现：船从斜坡滑下，玩家按住 `Space` 或鼠标左键进入瞄准/子弹时间，松开发射锚；锚勾住 `HookPoint` 后船会绕节点荡起；空中按 `A/D` 可旋转船体调整着陆角度；再次按下确认键可收回锚。关卡终点通过 `FinishArea` 触发完成。

GDD 中明确要求存在教程 UI，提示玩家如何发射、甩荡、松开锚、AD 调整角度。当前项目已有 `TutorialPrompt` UI 场景，但尚未接入任何实际关卡流程。

## 目标

- 新建一个独立的教学关卡 `TutorialLevel`，作为玩家首次进入游戏后的第一关。
- 以软引导方式逐步教授所有核心机制：瞄准/发射、荡锚、空中 AD 调整、收回锚、躲避障碍物、收集金币、救援河里的人、巨浪追赶。
- 教学提示不阻塞玩家前进，玩家失败后在最近检查点重置。
- 首次启动自动进入教程；教程内可按确认键跳过。
- 同步更新 GDD 文档：收集物从“罐子”改为“金币”，新增“救援河里的人”机制。

## 范围

本设计覆盖：

- `scenes/levels/TutorialLevel.tscn` 及对应脚本 `scripts/levels/tutorial_level.gd`
- `scripts/levels/tutorial_controller.gd`：控制教学提示的推进
- `scripts/items/rescuable_person.gd` + `scenes/items/RescuablePerson.tscn`：救援机制
- 复用并扩展现有 `TutorialPrompt.tscn` 的调用方式
- 将 `CanCollectible` 场景改名为 `CoinCollectible`
- 更新 Feishu GDD 文档内容

不覆盖：

- 主菜单 UI 的美术表现（只要求暴露入口逻辑）
- 新的音效/动画资源制作（复用现有或占位）

## 组件

### 1. 关卡场景 `TutorialLevel.tscn`

新建场景，结构参考现有 `Level.tscn`：

```
TutorialLevel (Node2D, script: tutorial_level.gd)
├── StartMarker (Marker2D)
├── CheckpointMarkers
│   ├── CheckpointMarker_01
│   ├── CheckpointMarker_02
│   └── ...
├── WaterSurface × N
├── SlopeWithWater × N
├── HookPointA/B/C...
├── Obstacle × 1-2
├── CoinCollectible × 2-3
├── RescuablePerson × 1
├── WaveChaser
├── FinishArea (Area2D)
└── TutorialAreas
    ├── AimArea (Area2D)
    ├── SwingArea (Area2D)
    ├── AirControlArea (Area2D)
    ├── RecallArea (Area2D)
    ├── ObstacleArea (Area2D)
    ├── CoinArea (Area2D)
    ├── RescueArea (Area2D)
    ├── WaveArea (Area2D)
    └── FinishArea (Area2D)
```

#### 关卡流程

1. 船从 `StartMarker` 沿斜坡滑下，进入 `AimArea`。
2. `AimArea` 提示“按住 Space / 鼠标左键瞄准”。
3. 玩家瞄准后进入 `SwingArea`，提示“松开按键发射锚，勾住节点荡起”。
4. 锚勾住 `HookPoint` 后荡起，到达顶点或玩家主动松开后进入空中。
5. 进入 `AirControlArea`，提示“按 A/D 调整船体角度，准备着陆”。
6. 船落地或入水后，进入 `RecallArea`，提示“再次按下 Space / 鼠标左键收回锚”。
7. 后续放置 `Obstacle`，进入 `ObstacleArea` 时提示“小心障碍物，碰撞会掉人”。
8. 放置 `CoinCollectible`，进入 `CoinArea` 时提示“收集金币获得分数”。
9. 放置 `RescuablePerson` 在水面上，进入 `RescueArea` 时提示“靠近河里的人救他们上船”。
10. `WaveChaser` 在远处出现，进入 `WaveArea` 时提示“巨浪在追你，保持前进”。
11. 到达 `FinishArea`，提示“到达终点！”并触发 `level_completed`。

### 2. 脚本 `tutorial_level.gd`

```gdscript
class_name TutorialLevel
extends Node2D

signal level_completed

@export var wave_chaser_speed_multiplier: float = 0.5
@export var obstacle_damage: int = 0  # 教学关不掉人

@onready var start_marker: Marker2D = %StartMarker
@onready var finish_area: Area2D = %FinishArea
@onready var wave_chaser: Node2D = %WaveChaser
@onready var checkpoint_marker: Marker2D

var _current_checkpoint: Marker2D

func _ready() -> void:
    finish_area.body_entered.connect(_on_finish_area_body_entered)
    _current_checkpoint = start_marker
    if wave_chaser != null:
        _apply_tutorial_wave_speed()

func get_start_position() -> Vector2:
    return start_marker.global_position

func get_respawn_position() -> Vector2:
    return _current_checkpoint.global_position

func set_checkpoint(marker: Marker2D) -> void:
    _current_checkpoint = marker

func _apply_tutorial_wave_speed() -> void:
    # 假设 WaveChaser 有 speed 导出变量
    if "speed" in wave_chaser:
        wave_chaser.speed *= wave_chaser_speed_multiplier

func _on_finish_area_body_entered(body: Node2D) -> void:
    if body.is_in_group("boats"):
        level_completed.emit()
```

### 3. 脚本 `tutorial_controller.gd`

```gdscript
class_name TutorialController
extends Node

@export var prompt: TutorialPrompt
@export var boat: Boat
@export var level: TutorialLevel

var _current_area: String = ""
var _pending_prompt: String = ""
var _prompt_timer: float = 0.0

func _ready() -> void:
    _connect_areas()
    _connect_anchor_signals()
    _connect_boat_signals()

func _process(delta: float) -> void:
    if _pending_prompt.is_empty():
        return
    _prompt_timer -= delta
    if _prompt_timer <= 0.0:
        prompt.show_prompt(_pending_prompt)
        _pending_prompt = ""

func _connect_areas() -> void:
    for area in get_tree().get_nodes_in_group("tutorial_areas"):
        area.body_entered.connect(_on_tutorial_area_entered.bind(area.name))

func _connect_anchor_signals() -> void:
    boat.anchor.aim_started.connect(_on_aim_started)
    boat.anchor.hooked.connect(_on_hooked)
    boat.anchor.recalled.connect(_on_recalled)

func _connect_boat_signals() -> void:
    # 监听落水/碰撞以判断空中调整是否完成
    pass

func _on_tutorial_area_entered(body: Node2D, area_name: String) -> void:
    if not body.is_in_group("boats"):
        return
    _current_area = area_name
    match area_name:
        "AimArea":
            _show("按住 Space / 鼠标左键瞄准")
        "SwingArea":
            _show("松开按键发射锚，勾住节点荡起")
        "AirControlArea":
            _show("按 A/D 调整船体角度，准备着陆")
        "RecallArea":
            _show("再次按下 Space / 鼠标左键收回锚")
        "ObstacleArea":
            _show("小心障碍物，碰撞会掉人", 2.0)
        "CoinArea":
            _show("收集金币获得分数")
        "RescueArea":
            _show("靠近河里的人救他们上船")
        "WaveArea":
            _show("巨浪在追你，保持前进", 2.0)
        "FinishArea":
            _show("到达终点！", 2.0)

func _show(text: String, auto_hide_seconds: float = 0.0) -> void:
    _pending_prompt = text
    _prompt_timer = 0.05  # 延迟一帧显示，避免重复触发
    if auto_hide_seconds > 0.0:
        # 通过独立 Timer 或 await 实现自动隐藏
        pass

func _on_aim_started() -> void:
    if _current_area == "AimArea":
        prompt.hide_prompt()

func _on_hooked(_hook_point: Node2D) -> void:
    if _current_area == "SwingArea":
        prompt.hide_prompt()

func _on_recalled() -> void:
    if _current_area == "RecallArea":
        prompt.hide_prompt()
```

实际实现中，提示隐藏逻辑需要更精确：

- `AimArea`：玩家开始瞄准后隐藏。
- `SwingArea`：锚勾住节点后隐藏。
- `AirControlArea`：船接触地面/水面后隐藏。
- `RecallArea`：玩家成功收回锚后隐藏。
- `CoinArea`：任意金币被收集后隐藏。
- `RescueArea`：救援成功后隐藏。
- `ObstacleArea` / `WaveArea` / `FinishArea`：进入后 2 秒自动隐藏。

### 4. 救援机制 `RescuablePerson`

新建 `scenes/items/RescuablePerson.tscn`：

```
RescuablePerson (Node2D)
├── Area2D (rescue trigger)
│   └── CollisionShape2D
└── Visual (Sprite2D / AnimatedSprite2D placeholder)
```

脚本 `rescuable_person.gd`：

```gdscript
class_name RescuablePerson
extends Node2D

signal rescued

@export var rescue_score: int = 100

@onready var _area: Area2D = $Area2D

func _ready() -> void:
    _area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("boats"):
        return
    rescued.emit()
    # 通知 GameState / EventBus 增加人数和分数
    EventBus.person_rescued.emit(rescue_score)
    queue_free()
```

救援判定：船体任意碰撞区域进入 `RescuablePerson` 的 `Area2D` 即成功。教学关中救援无难度条件（如速度/角度限制），正式关卡可后续扩展。

### 5. 检查点与失败重置

- 沿关卡放置 `CheckpointMarker`（Marker2D）。
- `TutorialController` 监听船进入检查点区域的事件，更新 `TutorialLevel._current_checkpoint`。
- 当船掉出屏幕或沉没时，`GameState` 或 `Game` 脚本调用 `TutorialLevel.get_respawn_position()` 将船重置到最新检查点。
- 检查点位置应位于教学提示区域之前一点，避免重置后立刻触发已完成教学的提示。

### 6. 巨浪难度

教学关中 `WaveChaser` 速度为正式关的 50%，只作为背景提示，不形成实质威胁。玩家只要不长时间停滞就不会被追上。

### 7. 障碍物惩罚

教学关中障碍物碰撞不掉人（`obstacle_damage = 0`），但仍提示玩家碰撞会掉人。保留碰撞反馈（如屏幕震动、音效占位），让玩家建立预期。

### 8. 跳过教程

教程内按 `cancel`（Esc）键弹出确认提示：“是否跳过教程？”，确认后直接进入正式关卡 `Level.tscn`。跳过状态不持久化，仅本次游戏有效；主菜单后续可扩展为“开始教程 / 开始游戏”选项。

## 数据流

1. 游戏启动后，`Game` 或 `Main` 根据首次启动标志加载 `TutorialLevel.tscn`。
2. `TutorialLevel._ready()` 降低巨浪速度、初始化检查点为 `StartMarker`。
3. `TutorialController` 监听 `TutorialArea` 进入事件和玩家操作信号。
4. 玩家进入区域时，`TutorialController` 通过 `TutorialPrompt` 显示对应提示。
5. 玩家完成对应操作后，`TutorialController` 隐藏提示。
6. 船进入 `CheckpointMarker` 区域时，更新当前重生点。
7. 船到达 `FinishArea` 时，`TutorialLevel` 发出 `level_completed`，游戏切换到正式关卡。

## 错误处理

- 如果 `TutorialPrompt` 未指定，`TutorialController` 在 `_ready()` 中 `push_error` 并禁用自身。
- 如果 `boat` 或 `level` 未指定，同样 `push_error`。
- 如果 `WaveChaser` 没有 `speed` 属性，跳过速度调整并打印警告。
- 救援时若 `EventBus.person_rescued` 未连接，仍销毁节点避免重复触发。

## 测试

参考 `docs/testing/new-feature-testing.md`：

1. 搭建 `debug/TutorialLevelRegression.tscn`，单独运行教学关卡。
2. 验证每个 `TutorialArea` 进入后正确显示提示。
3. 验证完成对应操作后提示隐藏。
4. 验证掉出屏幕/沉水后在最近检查点重生。
5. 验证巨浪速度降低、障碍物不掉人。
6. 验证金币收集和救援人数正确更新 HUD。
7. 验证跳过教程可进入正式关卡。
8. 验证完成教程后可进入正式关卡。

## 后续扩展

- 主菜单增加“教程 / 开始游戏”选项，首次启动默认高亮教程。
- 救援机制可扩展为需要低速或正面接近才成功。
- 教学提示可扩展为支持键位图标/图片提示。
- 可记录玩家是否已完成教程，避免重复进入。

## GDD 同步更新

需要在 Feishu GDD 中更新以下内容：

1. 核心玩法 - 收集元素：将“罐子”改为“金币”。
2. 核心玩法 - 可交互环境：新增“救援河里漂着的人，增加船上人数”。
3. UI - 教程 UI：提示列表中“收集元素（罐子）数”改为“收集金币数”，并新增“救援人数”相关提示。
4. UI - 游玩过程中：HUD 显示金币数、船上人数；结算页面统计新增“救援人数”。
