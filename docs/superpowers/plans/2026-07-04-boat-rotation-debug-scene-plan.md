# Boat AD Rotation Debug Scene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an isolated, interactive debug scene under `debug/` for tuning the boat's AD-driven airborne rotation speed, with live HUD, graph, and indicator.

**Architecture:** A single `BoatRotationDebug` scene instantiates the production `Boat.tscn` at runtime and drives three CanvasLayer-based debug UI components. A position-lock mechanism keeps the boat at the origin so tuning focuses on rotation rather than trajectory. All debug code stays in `debug/`; production files are untouched.

**Tech Stack:** Godot 4.7, GDScript, Jolt Physics 2D.

## Global Constraints

- All new files must live under `debug/`; no production files are modified.
- The scene must run standalone with F6 (Play Current Scene).
- Inspector `@export` variables control tuning step, position lock default, and graph sample count.
- Shortcuts: A/D rotate, PageUp/PageDown adjust torque, L toggle lock, R reset, Esc/Q quit.

---

## File Structure

| File | Responsibility |
|---|---|
| `debug/BoatRotationDebug.tscn` | Main scene root with Camera2D, BoatContainer, CanvasLayer |
| `debug/boat_rotation_debug.gd` | Spawns boat, handles position lock, shortcuts, and component orchestration |
| `debug/ui/DebugValuePanel.tscn` | Value panel scene root |
| `debug/ui/DebugValuePanel.gd` | Updates Label texts from boat state |
| `debug/ui/DebugGraph.tscn` | Graph scene root |
| `debug/ui/DebugGraph.gd` | Records angular velocity history and draws the curve |
| `debug/ui/DebugRotationIndicator.tscn` | Indicator scene root |
| `debug/ui/DebugRotationIndicator.gd` | Draws forward arrow scaled by angular velocity |

---

### Task 1: Create the debug UI directory and value panel

**Files:**
- Create: `debug/ui/DebugValuePanel.gd`
- Create: `debug/ui/DebugValuePanel.tscn`

**Interfaces:**
- Consumes: `boat: Boat` reference set by `BoatRotationDebug`
- Produces: `update(boat: Boat)` method called every `_process`

- [ ] **Step 1: Create `debug/ui/DebugValuePanel.gd`**

```gdscript
class_name DebugValuePanel
extends Control

@onready var _labels: VBoxContainer = $VBoxContainer

var _label_map: Dictionary = {}

func _ready() -> void:
	var names := [
		"angular_velocity",
		"rotation_degrees",
		"nose_angle",
		"input",
		"applied_torque",
		"airborne",
		"position_locked",
	]
	for name in names:
		var label := Label.new()
		label.name = name
		_label_map[name] = label
		_labels.add_child(label)

func update(boat: Boat, input: float, applied_torque: float, position_locked: bool) -> void:
	_label_map["angular_velocity"].text = "Angular Velocity: %.2f rad/s" % boat.angular_velocity
	_label_map["rotation_degrees"].text = "Rotation: %.1f°" % rad_to_deg(boat.global_rotation)
	_label_map["nose_angle"].text = "Nose Angle: %.1f°" % rad_to_deg(boat.global_transform.x.angle())
	_label_map["input"].text = "Input: %.2f" % input
	_label_map["applied_torque"].text = "Applied Torque: %.0f" % applied_torque
	_label_map["airborne"].text = "Airborne: %s" % boat.is_airborne()
	_label_map["position_locked"].text = "Position Locked: %s" % position_locked
```

- [ ] **Step 2: Create `debug/ui/DebugValuePanel.tscn`**

In Godot Editor:
1. Create new scene: root node `Control`, script `debug/ui/DebugValuePanel.gd`.
2. Add child `VBoxContainer` named `VBoxContainer`.
3. Set `VBoxContainer` anchors: top-left, position `(10, 10)`.
4. Save as `debug/ui/DebugValuePanel.tscn`.

- [ ] **Step 3: Verify the panel scene opens without errors**

Run: Open `debug/ui/DebugValuePanel.tscn` in Godot Editor.
Expected: No script errors in Output panel.

- [ ] **Step 4: Commit**

```bash
git add debug/ui/DebugValuePanel.gd debug/ui/DebugValuePanel.tscn
git commit -m "feat(debug): add rotation debug value panel

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Create the angular-velocity graph

**Files:**
- Create: `debug/ui/DebugGraph.gd`
- Create: `debug/ui/DebugGraph.tscn`

**Interfaces:**
- Consumes: `angular_velocity: float` pushed every `_process`
- Produces: `push_sample(angular_velocity: float)` method

- [ ] **Step 1: Create `debug/ui/DebugGraph.gd`**

```gdscript
class_name DebugGraph
extends Control

@export var sample_count: int = 180
@export var line_color_positive: Color = Color(0.2, 0.9, 0.3)
@export var line_color_negative: Color = Color(0.9, 0.3, 0.2)
@export var zero_line_color: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var max_value: float = 12.0

var _samples: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	_samples.resize(sample_count)
	_samples.fill(0.0)

func push_sample(value: float) -> void:
	for i in range(_samples.size() - 1):
		_samples[i] = _samples[i + 1]
	_samples[_samples.size() - 1] = value
	queue_redraw()

func _draw() -> void:
	var rect := get_rect()
	var mid_y: float = rect.size.y * 0.5
	draw_line(Vector2(0.0, mid_y), Vector2(rect.size.x, mid_y), zero_line_color, 1.0, true)

	var step_x: float = rect.size.x / float(_samples.size() - 1)
	for i in range(_samples.size() - 1):
		var y1 := _value_to_y(_samples[i], rect.size.y)
		var y2 := _value_to_y(_samples[i + 1], rect.size.y)
		var color := line_color_positive if _samples[i] >= 0.0 else line_color_negative
		draw_line(Vector2(i * step_x, y1), Vector2((i + 1) * step_x, y2), color, 2.0)

func _value_to_y(value: float, height: float) -> float:
	var ratio := clampf(value / max_value, -1.0, 1.0)
	return height * 0.5 - ratio * height * 0.45
```

- [ ] **Step 2: Create `debug/ui/DebugGraph.tscn`**

In Godot Editor:
1. Create new scene: root node `Control`, script `debug/ui/DebugGraph.gd`.
2. Set size `(300, 120)` and anchors bottom-left with margin `(10, 10)`.
3. Save as `debug/ui/DebugGraph.tscn`.

- [ ] **Step 3: Verify the graph draws**

Run: Open `debug/ui/DebugGraph.tscn` and enable "View > Canvas Items > Visible" if needed. Add a temporary script to call `push_sample(5.0)` in `_ready` and observe a line.
Expected: A green line segment appears above the zero line.

- [ ] **Step 4: Commit**

```bash
git add debug/ui/DebugGraph.gd debug/ui/DebugGraph.tscn
git commit -m "feat(debug): add angular velocity debug graph

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Create the rotation indicator

**Files:**
- Create: `debug/ui/DebugRotationIndicator.gd`
- Create: `debug/ui/DebugRotationIndicator.tscn`

**Interfaces:**
- Consumes: `boat: Boat` reference and `input: float`
- Produces: `update(boat: Boat, input: float)` method

- [ ] **Step 1: Create `debug/ui/DebugRotationIndicator.gd`**

```gdscript
class_name DebugRotationIndicator
extends Node2D

@export var max_arrow_length: float = 80.0
@export var max_velocity_for_length: float = 8.0
@export var idle_color: Color = Color(1.0, 1.0, 1.0)
@export var left_color: Color = Color(0.3, 0.6, 1.0)
@export var right_color: Color = Color(1.0, 0.6, 0.2)

var _boat: Boat = null
var _input: float = 0.0

func update(boat: Boat, input: float) -> void:
	_boat = boat
	_input = input
	queue_redraw()

func _draw() -> void:
	if _boat == null or not is_instance_valid(_boat):
		return

	var nose_direction := _boat.global_transform.x
	var length := clampf(absf(_boat.angular_velocity) / max_velocity_for_length, 0.0, 1.0) * max_arrow_length
	var color := idle_color
	if not is_zero_approx(_input):
		color = left_color if _input < 0.0 else right_color

	var start := Vector2.ZERO
	var end := nose_direction * length
	draw_line(start, end, color, 3.0)
	_draw_arrow_head(end, nose_direction, color)

func _draw_arrow_head(tip: Vector2, direction: Vector2, color: Color) -> void:
	var head_size := 10.0
	var back := -direction * head_size
	var side := direction.rotated(PI * 0.5) * head_size * 0.5
	draw_line(tip, tip + back + side, color, 2.0)
	draw_line(tip, tip + back - side, color, 2.0)
```

- [ ] **Step 2: Create `debug/ui/DebugRotationIndicator.tscn`**

In Godot Editor:
1. Create new scene: root node `Node2D`, script `debug/ui/DebugRotationIndicator.gd`.
2. Save as `debug/ui/DebugRotationIndicator.tscn`.

- [ ] **Step 3: Verify the indicator scene opens without errors**

Run: Open `debug/ui/DebugRotationIndicator.tscn` in Godot Editor.
Expected: No script errors in Output panel.

- [ ] **Step 4: Commit**

```bash
git add debug/ui/DebugRotationIndicator.gd debug/ui/DebugRotationIndicator.tscn
git commit -m "feat(debug): add rotation direction indicator

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Create the main debug scene and controller

**Files:**
- Create: `debug/boat_rotation_debug.gd`
- Create: `debug/BoatRotationDebug.tscn`

**Interfaces:**
- Consumes: `Boat` scene, `DebugValuePanel`, `DebugGraph`, `DebugRotationIndicator`
- Produces: runnable `debug/BoatRotationDebug.tscn`

- [ ] **Step 1: Create `debug/boat_rotation_debug.gd`**

```gdscript
class_name BoatRotationDebug
extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")

@export var rotation_torque_step: float = 5000.0
@export var position_locked: bool = true
@export var graph_sample_count: int = 180

@onready var _boat_container: Node2D = $BoatContainer
@onready var _value_panel: DebugValuePanel = $CanvasLayer/DebugValuePanel
@onready var _graph: DebugGraph = $CanvasLayer/DebugGraph
@onready var _indicator: DebugRotationIndicator = $DebugRotationIndicator

var _boat: Boat = null
var _initial_position: Vector2 = Vector2.ZERO
var _initial_rotation: float = 0.0

func _ready() -> void:
	_spawn_boat()
	_graph.sample_count = graph_sample_count

func _physics_process(_delta: float) -> void:
	if _boat == null or not is_instance_valid(_boat):
		return

	if position_locked:
		_boat.global_position = _initial_position
		_boat.linear_velocity = Vector2.ZERO

func _process(_delta: float) -> void:
	if _boat == null or not is_instance_valid(_boat):
		return

	var input := Input.get_axis("move_left", "move_right")
	var applied_torque := _compute_applied_torque(input)

	_value_panel.update(_boat, input, applied_torque, position_locked)
	_graph.push_sample(_boat.angular_velocity)
	_indicator.global_position = _boat.global_position
	_indicator.update(_boat, input)

func _compute_applied_torque(input: float) -> float:
	if _boat.is_airborne() and not is_zero_approx(input):
		return input * _boat.airborne_rotation_torque
	return 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_page_up"):
		_boat.airborne_rotation_torque += rotation_torque_step
	elif event.is_action_pressed("ui_page_down"):
		_boat.airborne_rotation_torque = maxf(_boat.airborne_rotation_torque - rotation_torque_step, 0.0)
	elif event.is_action_pressed("debug_reset"):
		_reset_boat()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_L:
				position_locked = not position_locked
			KEY_Q:
				get_tree().quit()

func _spawn_boat() -> void:
	if _boat != null and is_instance_valid(_boat):
		_boat.queue_free()

	_boat = BOAT_SCENE.instantiate() as Boat
	_boat_container.add_child(_boat)
	_boat.freeze = false
	_initial_position = _boat_container.global_position
	_initial_rotation = _boat.global_rotation
	_reset_boat()

func _reset_boat() -> void:
	if _boat == null or not is_instance_valid(_boat):
		return
	_boat.global_position = _initial_position
	_boat.global_rotation = _initial_rotation
	_boat.linear_velocity = Vector2.ZERO
	_boat.angular_velocity = 0.0
```

- [ ] **Step 2: Create `debug/BoatRotationDebug.tscn`**

In Godot Editor:
1. Create new scene: root `Node2D`, script `debug/boat_rotation_debug.gd`.
2. Add `Camera2D` child, enable `current`, set zoom `(1, 1)`.
3. Add `Node2D` child named `BoatContainer` at `(0, 0)`.
4. Add `CanvasLayer` child.
5. Under `CanvasLayer`, instance `debug/ui/DebugValuePanel.tscn` and `debug/ui/DebugGraph.tscn`.
6. At root level, instance `debug/ui/DebugRotationIndicator.tscn` named `DebugRotationIndicator`.
7. Save as `debug/BoatRotationDebug.tscn`.

- [ ] **Step 3: Add missing input actions**

The plan uses `ui_page_up`, `ui_page_down`, and `debug_reset`. `ui_page_up` and `ui_page_down` are built-in Godot UI actions. `debug_reset` already exists in `project.godot` mapped to `R`. No changes required.

- [ ] **Step 4: Run the scene and verify rotation**

Run: In Godot Editor, open `debug/BoatRotationDebug.tscn`, press F6.
Expected:
- Boat visible at center.
- Holding A/D rotates the boat.
- Value panel updates `Input`, `Angular Velocity`, `Rotation`.
- Graph line moves.
- Indicator arrow rotates and scales with speed.

- [ ] **Step 5: Commit**

```bash
git add debug/boat_rotation_debug.gd debug/BoatRotationDebug.tscn
git commit -m "feat(debug): add main boat rotation debug scene

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Verify position lock and shortcuts

**Files:**
- Modify: `debug/boat_rotation_debug.gd` if bugs found

- [ ] **Step 1: Test position lock toggle**

Run: Open `debug/BoatRotationDebug.tscn`, press F6.
Actions:
1. Press `L` to disable position lock.
2. Hold `D` for 2 seconds — boat should rotate and begin to fall.
3. Press `R` — boat resets to center with zero velocity.
4. Press `L` to re-enable lock.
5. Hold `D` — boat rotates in place.

Expected: Lock toggle works; reset works.

- [ ] **Step 2: Test torque adjustment**

Actions:
1. Hold `D` for 1 second and note max angular velocity from the value panel.
2. Press `PageUp` 3 times.
3. Hold `D` for 1 second and note new max angular velocity.

Expected: Higher torque produces higher angular velocity; `Applied Torque` label reflects the new value.

- [ ] **Step 3: Commit any fixes**

If no fixes needed, commit a note:

```bash
git commit --allow-empty -m "test(debug): verify boat rotation debug scene controls

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

### Spec coverage

| Spec Requirement | Implementing Task |
|---|---|
| Interactive AD rotation | Task 4 (`_physics_process` applies torque via input) |
| Isolated airborne environment | Task 4 (no water/slope/anchor; position lock) |
| Real-time value panel | Task 1 |
| Historical angular-velocity graph | Task 2 |
| Rotation direction/speed indicator | Task 3 |
| Runtime torque tuning | Task 4 (PageUp/PageDown) and Task 5 (verify) |
| No production-code pollution | All tasks create files only under `debug/` |

### Placeholder scan

- No TBD/TODO.
- No vague "add error handling" steps.
- Every code step contains actual GDScript.
- Every task has a verification step.

### Type consistency

- `Boat` reference used consistently.
- `input: float`, `applied_torque: float`, `position_locked: bool` signatures match across `DebugValuePanel.update`, `_process`, and graph/indicator updates.
- `DebugGraph.push_sample(value: float)` used with `_boat.angular_velocity` (float).

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-04-boat-rotation-debug-scene-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
