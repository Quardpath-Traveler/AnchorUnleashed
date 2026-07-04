# Tutorial Level Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a first playable tutorial level that teaches the current Anchor loop through short prompt-triggered sections.

**Architecture:** Add a dedicated `TutorialLevel.tscn` with local prompt UI, authored hook points, authored terrain, tutorial trigger areas, a late wave chaser, and the existing finish signal pattern. `Game.tscn` will instantiate the tutorial level first, and `game.gd` will pass the active boat to levels that expose `setup(active_player)`.

**Tech Stack:** Godot 4.7, GDScript, text `.tscn` scenes, Python `unittest` scaffold tests, Godot headless smoke tests.

---

## Global Constraints

- Before gameplay testing, read `docs/testing/new-feature-testing.md`.
- Use the current worktree `/Volumes/takusan/projects/cgj-2026/.worktrees/design/tutorial-level`.
- Save and close Godot before committing scene changes.
- Stage `.gd.uid` with any new `.gd` script if Godot generates one.
- Stage files explicitly; do not use `git add .` or `git add -A`.
- Do not stage `.godot/` or `/android/`.
- Keep the first implementation scoped to the approved spec: no coin rename, no rescue mechanic, no tutorial skip, no save data, no level select.

## File Structure

- Create `scripts/levels/tutorial_trigger.gd`: one focused `Area2D` helper that stores prompt text and one-shot trigger state.
- Create `scripts/levels/tutorial_level.gd`: level-level wiring for start position, finish signal, prompt display, trigger connection, and optional player setup.
- Create `scenes/levels/TutorialLevel.tscn`: authored tutorial layout using existing scenes and trigger areas.
- Modify `scenes/game/Game.tscn`: switch the active level instance from `Level.tscn` to `TutorialLevel.tscn`.
- Modify `scripts/game/game.gd`: call `level.setup(player)` when the active level supports it.
- Modify `tests/scaffold/test_project_structure.py`: add structural tests for the tutorial level, trigger script, prompt wiring, and Game scene integration.

---

### Task 1: Add Failing Scaffold Coverage

**Files:**
- Modify: `tests/scaffold/test_project_structure.py`

**Interfaces:**
- Consumes: current project scene/script layout.
- Produces: failing tests that describe the tutorial level files and integration.

- [ ] **Step 1: Add tutorial files to required file checks**

In `test_required_scenes_and_scripts_exist`, add these entries to the existing `relative_path` list:

```python
            "scenes/levels/TutorialLevel.tscn",
            "scripts/levels/tutorial_level.gd",
            "scripts/levels/tutorial_trigger.gd",
```

- [ ] **Step 2: Add scene script reference checks**

In `test_scene_script_references_are_present`, add this entry to `expected_references`:

```python
            "scenes/levels/TutorialLevel.tscn": "res://scripts/levels/tutorial_level.gd",
```

- [ ] **Step 3: Update the active game level expectation**

In `test_game_scene_contains_player_hud_and_pause_menu`, change the active level assertion to expect the tutorial level:

```python
        self.assertIn("res://scenes/levels/TutorialLevel.tscn", scene)
```

Add this expected script snippet to the same test's `for expected in [...]` list:

```python
            "if level.has_method(\"setup\"):",
            "level.setup(player)",
```

- [ ] **Step 4: Add a focused tutorial level structure test**

Add this test method to `ProjectStructureTest`:

```python
    def test_tutorial_level_contains_prompt_triggers_and_core_parts(self):
        scene = self.read("scenes/levels/TutorialLevel.tscn")
        script = self.read("scripts/levels/tutorial_level.gd")
        trigger_script = self.read("scripts/levels/tutorial_trigger.gd")

        for scene_path in [
            "res://scripts/levels/tutorial_trigger.gd",
            "res://scripts/levels/tutorial_level.gd",
            "res://scenes/mechanics/HookPoint.tscn",
            "res://scenes/level_parts/WaterSurface.tscn",
            "res://scenes/level_parts/WaveChaser.tscn",
            "res://scenes/level_parts/Obstacle.tscn",
            "res://scenes/items/CanCollectible.tscn",
            "res://scenes/ui/TutorialPrompt.tscn",
        ]:
            self.assertIn(scene_path, scene)

        for node_name in [
            "StartMarker",
            "FinishArea",
            "TutorialPrompt",
            "TutorialTriggers",
            "HookPointThrowIntro",
            "HookPointFinal",
            "WaveChaser",
            "CanCollectible",
            "Obstacle",
        ]:
            self.assertIn(f'name="{node_name}"', scene)

        for prompt_text in [
            "顺着坡道前进。",
            "按住鼠标左键瞄准。",
            "松开发射锚。",
            "勾住后让船甩起来。",
            "再次点击收回锚，借惯性飞出去。",
            "空中按 A / D 调整船体倾角。",
            "收集罐子，避开障碍。",
            "巨浪会追上来，继续向终点前进。",
            "到达终点。",
        ]:
            self.assertIn(prompt_text, scene)

        for expected in [
            "class_name TutorialLevel",
            "signal level_completed",
            "func setup(active_player: Node2D) -> void",
            "func get_start_position() -> Vector2",
            "func _connect_tutorial_triggers() -> void",
            "func _on_tutorial_trigger_body_entered(body: Node2D, trigger: TutorialTrigger) -> void",
            "tutorial_prompt.show_prompt(trigger.prompt_text)",
            "wave_chaser.target = active_player",
        ]:
            self.assertIn(expected, script)

        for expected in [
            "class_name TutorialTrigger",
            "@export_multiline var prompt_text",
            "@export var one_shot",
            "@export_range(0.0, 10.0, 0.1) var auto_hide_seconds",
            "func can_trigger(body: Node2D) -> bool",
            "func mark_triggered() -> void",
            "body.is_in_group(\"boats\")",
        ]:
            self.assertIn(expected, trigger_script)
```

- [ ] **Step 5: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests/scaffold/test_project_structure.py
```

Expected: FAIL because `TutorialLevel.tscn`, `tutorial_level.gd`, and `tutorial_trigger.gd` do not exist yet.

- [ ] **Step 6: Commit the failing test**

```bash
git add tests/scaffold/test_project_structure.py
git commit -m "test(level): cover tutorial level structure"
```

---

### Task 2: Add Tutorial Trigger Script

**Files:**
- Create: `scripts/levels/tutorial_trigger.gd`
- Track `scripts/levels/tutorial_trigger.gd.uid` when `test -f scripts/levels/tutorial_trigger.gd.uid` returns success after opening or importing the script in Godot.

**Interfaces:**
- Consumes: `Area2D.body_entered`.
- Produces: `TutorialTrigger` nodes with prompt text, one-shot gating, and boat filtering.

- [ ] **Step 1: Write minimal trigger script**

Create `scripts/levels/tutorial_trigger.gd`:

```gdscript
class_name TutorialTrigger
extends Area2D

@export_multiline var prompt_text: String = ""
@export var one_shot: bool = true
@export_range(0.0, 10.0, 0.1) var auto_hide_seconds: float = 0.0

var has_triggered: bool = false


func can_trigger(body: Node2D) -> bool:
	if one_shot and has_triggered:
		return false
	return body.is_in_group("boats")


func mark_triggered() -> void:
	has_triggered = true
```

- [ ] **Step 2: Run the scaffold test**

Run:

```bash
python3 -m unittest tests.scaffold.test_project_structure.ProjectStructureTest.test_tutorial_level_contains_prompt_triggers_and_core_parts
```

Expected: FAIL because `TutorialLevel.tscn` and `tutorial_level.gd` are still missing, but the trigger script expectations are now satisfied.

- [ ] **Step 3: Commit**

```bash
git add scripts/levels/tutorial_trigger.gd
if test -f scripts/levels/tutorial_trigger.gd.uid; then git add scripts/levels/tutorial_trigger.gd.uid; fi
git commit -m "feat(level): add tutorial trigger script"
```

---

### Task 3: Add Tutorial Level Script

**Files:**
- Create: `scripts/levels/tutorial_level.gd`
- Track `scripts/levels/tutorial_level.gd.uid` when `test -f scripts/levels/tutorial_level.gd.uid` returns success after opening or importing the script in Godot.

**Interfaces:**
- Consumes: `%StartMarker`, `%FinishArea`, `%TutorialPrompt`, `%TutorialTriggers`, `%WaveChaser`.
- Produces: `level_completed`, `get_start_position()`, optional `setup(active_player)`, prompt trigger behavior.

- [ ] **Step 1: Write the level script**

Create `scripts/levels/tutorial_level.gd`:

```gdscript
class_name TutorialLevel
extends Node2D

signal level_completed

var player: Node2D
var _prompt_sequence_id: int = 0

@onready var start_marker: Marker2D = %StartMarker
@onready var finish_area: Area2D = %FinishArea
@onready var tutorial_prompt: TutorialPrompt = %TutorialPrompt
@onready var tutorial_triggers: Node2D = %TutorialTriggers
@onready var wave_chaser: WaveChaser = %WaveChaser


func _ready() -> void:
	finish_area.body_entered.connect(_on_finish_area_body_entered)
	_connect_tutorial_triggers()


func setup(active_player: Node2D) -> void:
	player = active_player
	wave_chaser.target = active_player


func get_start_position() -> Vector2:
	return start_marker.global_position


func _connect_tutorial_triggers() -> void:
	for child in tutorial_triggers.get_children():
		var trigger := child as TutorialTrigger
		if trigger == null:
			continue
		trigger.body_entered.connect(_on_tutorial_trigger_body_entered.bind(trigger))


func _on_tutorial_trigger_body_entered(body: Node2D, trigger: TutorialTrigger) -> void:
	if not trigger.can_trigger(body):
		return

	trigger.mark_triggered()
	tutorial_prompt.show_prompt(trigger.prompt_text)

	if trigger.auto_hide_seconds > 0.0:
		_hide_prompt_after(trigger.auto_hide_seconds)


func _hide_prompt_after(seconds: float) -> void:
	_prompt_sequence_id += 1
	var sequence_id := _prompt_sequence_id
	await get_tree().create_timer(seconds).timeout
	if sequence_id == _prompt_sequence_id:
		tutorial_prompt.hide_prompt()


func _on_finish_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("boats"):
		level_completed.emit()
```

- [ ] **Step 2: Run the focused scaffold test**

Run:

```bash
python3 -m unittest tests.scaffold.test_project_structure.ProjectStructureTest.test_tutorial_level_contains_prompt_triggers_and_core_parts
```

Expected: FAIL because `TutorialLevel.tscn` is still missing.

- [ ] **Step 3: Commit**

```bash
git add scripts/levels/tutorial_level.gd
if test -f scripts/levels/tutorial_level.gd.uid; then git add scripts/levels/tutorial_level.gd.uid; fi
git commit -m "feat(level): add tutorial level script"
```

---

### Task 4: Create TutorialLevel Scene

**Files:**
- Create: `scenes/levels/TutorialLevel.tscn`

**Interfaces:**
- Consumes: existing reusable scenes and scripts.
- Produces: a playable tutorial level scene with start marker, terrain, hooks, triggers, wave, collectible, obstacle, prompt UI, and finish area.

- [ ] **Step 1: Create the scene file**

Create `scenes/levels/TutorialLevel.tscn` with this first-pass layout:

```tscn
[gd_scene load_steps=15 format=3]

[ext_resource type="Script" path="res://scripts/levels/tutorial_level.gd" id="1_level"]
[ext_resource type="Script" path="res://scripts/levels/tutorial_trigger.gd" id="2_trigger"]
[ext_resource type="PackedScene" path="res://scenes/mechanics/HookPoint.tscn" id="3_hook"]
[ext_resource type="PackedScene" path="res://scenes/level_parts/WaterSurface.tscn" id="4_water"]
[ext_resource type="PackedScene" path="res://scenes/level_parts/WaveChaser.tscn" id="5_wave"]
[ext_resource type="PackedScene" path="res://scenes/level_parts/Obstacle.tscn" id="6_obstacle"]
[ext_resource type="PackedScene" path="res://scenes/items/CanCollectible.tscn" id="7_can"]
[ext_resource type="PackedScene" path="res://scenes/ui/TutorialPrompt.tscn" id="8_prompt"]

[sub_resource type="ConvexPolygonShape2D" id="ConvexPolygonShape2D_start_slope"]
points = PackedVector2Array(-260, -20, 320, 116, 320, 166, -260, 30)

[sub_resource type="ConvexPolygonShape2D" id="ConvexPolygonShape2D_landing_slope"]
points = PackedVector2Array(-220, -16, 360, 80, 360, 132, -220, 36)

[sub_resource type="ConvexPolygonShape2D" id="ConvexPolygonShape2D_final_slope"]
points = PackedVector2Array(-240, -18, 380, 92, 380, 146, -240, 34)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_prompt"]
size = Vector2(180, 180)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_prompt_wide"]
size = Vector2(260, 200)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_finish"]
size = Vector2(90, 190)

[node name="TutorialLevel" type="Node2D"]
script = ExtResource("1_level")

[node name="StartMarker" type="Marker2D" parent="."]
unique_name_in_owner = true
position = Vector2(120, 130)

[node name="StartSlope" type="StaticBody2D" parent="."]
position = Vector2(250, 260)

[node name="CollisionShape2D" type="CollisionShape2D" parent="StartSlope"]
shape = SubResource("ConvexPolygonShape2D_start_slope")

[node name="Visual" type="Polygon2D" parent="StartSlope"]
color = Color(0.46, 0.38, 0.28, 1)
polygon = PackedVector2Array(-260, -20, 320, 116, 320, 166, -260, 30)

[node name="WaterSurface" parent="StartSlope" instance=ExtResource("4_water")]
position = Vector2(35, 44)
rotation = 0.230383
water_width = 580.0
water_depth = 74.0
surface_y = -36.0
current_flow_speed = 230.0
buoyancy_force = 5000.0
max_buoyancy_force = 11130.0

[node name="HookPointThrowIntro" parent="." instance=ExtResource("3_hook")]
position = Vector2(655, 275)

[node name="LandingSlope" type="StaticBody2D" parent="."]
position = Vector2(900, 318)

[node name="CollisionShape2D" type="CollisionShape2D" parent="LandingSlope"]
shape = SubResource("ConvexPolygonShape2D_landing_slope")

[node name="Visual" type="Polygon2D" parent="LandingSlope"]
color = Color(0.42, 0.36, 0.24, 1)
polygon = PackedVector2Array(-220, -16, 360, 80, 360, 132, -220, 36)

[node name="CanCollectible" parent="." instance=ExtResource("7_can")]
position = Vector2(1030, 185)

[node name="Obstacle" parent="." instance=ExtResource("6_obstacle")]
position = Vector2(1120, 278)

[node name="HookPointFinal" parent="." instance=ExtResource("3_hook")]
position = Vector2(1390, 250)

[node name="FinalSlope" type="StaticBody2D" parent="."]
position = Vector2(1660, 365)

[node name="CollisionShape2D" type="CollisionShape2D" parent="FinalSlope"]
shape = SubResource("ConvexPolygonShape2D_final_slope")

[node name="Visual" type="Polygon2D" parent="FinalSlope"]
color = Color(0.36, 0.40, 0.26, 1)
polygon = PackedVector2Array(-240, -18, 380, 92, 380, 146, -240, 34)

[node name="WaveChaser" parent="." instance=ExtResource("5_wave")]
unique_name_in_owner = true
position = Vector2(-520, 275)
chase_speed = 62.0
max_distance_from_target = 740.0

[node name="FinishArea" type="Area2D" parent="."]
unique_name_in_owner = true
position = Vector2(2050, 402)

[node name="CollisionShape2D" type="CollisionShape2D" parent="FinishArea"]
shape = SubResource("RectangleShape2D_finish")

[node name="Visual" type="Polygon2D" parent="FinishArea"]
color = Color(0.24, 0.76, 0.36, 0.35)
polygon = PackedVector2Array(-45, -95, 45, -95, 45, 95, -45, 95)

[node name="TutorialPrompt" parent="." instance=ExtResource("8_prompt")]
unique_name_in_owner = true

[node name="TutorialTriggers" type="Node2D" parent="."]
unique_name_in_owner = true

[node name="StartSlidePrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(230, 155)
script = ExtResource("2_trigger")
prompt_text = "顺着坡道前进。"
auto_hide_seconds = 2.4

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/StartSlidePrompt"]
shape = SubResource("RectangleShape2D_prompt")

[node name="AimPrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(515, 205)
script = ExtResource("2_trigger")
prompt_text = "按住鼠标左键瞄准。"

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/AimPrompt"]
shape = SubResource("RectangleShape2D_prompt")

[node name="ThrowPrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(610, 215)
script = ExtResource("2_trigger")
prompt_text = "松开发射锚。"

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/ThrowPrompt"]
shape = SubResource("RectangleShape2D_prompt")

[node name="SwingPrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(705, 250)
script = ExtResource("2_trigger")
prompt_text = "勾住后让船甩起来。"

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/SwingPrompt"]
shape = SubResource("RectangleShape2D_prompt_wide")

[node name="RecallPrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(850, 250)
script = ExtResource("2_trigger")
prompt_text = "再次点击收回锚，借惯性飞出去。"

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/RecallPrompt"]
shape = SubResource("RectangleShape2D_prompt_wide")

[node name="AirControlPrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(980, 210)
script = ExtResource("2_trigger")
prompt_text = "空中按 A / D 调整船体倾角。"

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/AirControlPrompt"]
shape = SubResource("RectangleShape2D_prompt_wide")

[node name="CollectObstaclePrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(1120, 230)
script = ExtResource("2_trigger")
prompt_text = "收集罐子，避开障碍。"
auto_hide_seconds = 3.0

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/CollectObstaclePrompt"]
shape = SubResource("RectangleShape2D_prompt_wide")

[node name="WavePrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(1280, 255)
script = ExtResource("2_trigger")
prompt_text = "巨浪会追上来，继续向终点前进。"
auto_hide_seconds = 3.0

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/WavePrompt"]
shape = SubResource("RectangleShape2D_prompt_wide")

[node name="FinishPrompt" type="Area2D" parent="TutorialTriggers"]
position = Vector2(1880, 355)
script = ExtResource("2_trigger")
prompt_text = "到达终点。"
auto_hide_seconds = 2.4

[node name="CollisionShape2D" type="CollisionShape2D" parent="TutorialTriggers/FinishPrompt"]
shape = SubResource("RectangleShape2D_prompt_wide")
```

- [ ] **Step 2: Run the focused scaffold test**

Run:

```bash
python3 -m unittest tests.scaffold.test_project_structure.ProjectStructureTest.test_tutorial_level_contains_prompt_triggers_and_core_parts
```

Expected: PASS.

- [ ] **Step 3: Load the tutorial level headlessly**

Run:

```bash
/Users/macbook/.local/bin/godot --headless --path . scenes/levels/TutorialLevel.tscn --quit
```

Expected: Godot starts and exits without parse errors or missing resource errors.

- [ ] **Step 4: Commit**

```bash
git add scenes/levels/TutorialLevel.tscn
git commit -m "feat(level): add tutorial level scene"
```

---

### Task 5: Wire Game to the Tutorial Level

**Files:**
- Modify: `scenes/game/Game.tscn`
- Modify: `scripts/game/game.gd`

**Interfaces:**
- Consumes: `TutorialLevel.tscn` and its optional `setup(active_player)` method.
- Produces: `Game.tscn` starts with the tutorial level and passes the boat reference to it.

- [ ] **Step 1: Update Game scene level resource**

In `scenes/game/Game.tscn`, change the level external resource from:

```tscn
[ext_resource type="PackedScene" uid="uid://cjaqahgf6j4f5" path="res://scenes/levels/Level.tscn" id="2_level"]
```

to:

```tscn
[ext_resource type="PackedScene" path="res://scenes/levels/TutorialLevel.tscn" id="2_level"]
```

Leave this node unchanged so the existing `$世界/关卡` path still works:

```tscn
[node name="关卡" parent="世界" instance=ExtResource("2_level")]
```

- [ ] **Step 2: Update game setup handoff**

In `scripts/game/game.gd`, update `_ready()` to call `setup(player)` before start-position placement:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	GameState.pause_changed.connect(_on_pause_changed)
	pause_menu.resume_requested.connect(_on_resume_requested)
	if level.has_method("setup"):
		level.setup(player)
	if level.has_method("get_start_position"):
		player.global_position = level.get_start_position()
	_on_pause_changed(GameState.is_paused)
```

- [ ] **Step 3: Run all scaffold tests**

Run:

```bash
python3 -m unittest tests/scaffold/test_project_structure.py
```

Expected: all tests pass.

- [ ] **Step 4: Load Game headlessly**

Run:

```bash
/Users/macbook/.local/bin/godot --headless --path . scenes/game/Game.tscn --quit
```

Expected: Godot starts and exits without parse errors or missing resource errors.

- [ ] **Step 5: Commit**

```bash
git add scenes/game/Game.tscn scripts/game/game.gd
git commit -m "feat(game): start with tutorial level"
```

---

### Task 6: Manual Smoke Test and Tuning

**Files:**
- Modify if tuning is needed: `scenes/levels/TutorialLevel.tscn`

**Interfaces:**
- Consumes: completed tutorial scene.
- Produces: tuned first-pass tutorial spacing.

- [ ] **Step 1: Read gameplay testing workflow**

Run:

```bash
sed -n '1,220p' docs/testing/new-feature-testing.md
```

Expected: review the testing workflow before launching interactive gameplay.

- [ ] **Step 2: Run the game scene manually**

Run:

```bash
/Users/macbook/.local/bin/godot --path . scenes/game/Game.tscn
```

Expected: the game opens at the tutorial level, places the boat at `%StartMarker`, and shows prompts as the boat enters tutorial trigger areas.

- [ ] **Step 3: Verify the intended playthrough**

Manual checks:

```text
1. Boat starts on the first slope.
2. Start slide prompt appears and hides.
3. Aim and throw prompts appear before HookPointThrowIntro.
4. HookPointThrowIntro is reachable with normal mouse aim.
5. Recall prompt appears around the first swing exit.
6. A/D prompt appears during the intended airborne section.
7. CanCollectible can be collected.
8. Obstacle can be avoided.
9. WaveChaser follows the boat but does not catch it during the first lessons.
10. HookPointFinal is reachable.
11. Entering FinishArea completes the level.
```

- [ ] **Step 4: Tune only scene-authored positions when manual play shows a route defect**

If the first hook is too hard, move only these authored positions in `TutorialLevel.tscn`:

```tscn
[node name="HookPointThrowIntro" parent="." instance=ExtResource("3_hook")]
position = Vector2(655, 275)
```

If the wave catches up too early, tune only these properties:

```tscn
[node name="WaveChaser" parent="." instance=ExtResource("5_wave")]
position = Vector2(-520, 275)
chase_speed = 62.0
max_distance_from_target = 740.0
```

If the final hook is too hard, tune only this authored position:

```tscn
[node name="HookPointFinal" parent="." instance=ExtResource("3_hook")]
position = Vector2(1390, 250)
```

- [ ] **Step 5: Re-run automated verification after tuning**

Run:

```bash
python3 -m unittest tests/scaffold/test_project_structure.py
/Users/macbook/.local/bin/godot --headless --path . scenes/game/Game.tscn --quit
```

Expected: scaffold tests pass and Godot loads the game scene without errors.

- [ ] **Step 6: Commit tuning**

If `TutorialLevel.tscn` changed during manual tuning:

```bash
git add scenes/levels/TutorialLevel.tscn
git commit -m "fix(level): tune tutorial route spacing"
```

When `git diff --quiet -- scenes/levels/TutorialLevel.tscn` exits with status `0`, skip this commit because the scene has no tuning changes.

---

### Task 7: Final Verification and Handoff

**Files:**
- No planned file edits.

**Interfaces:**
- Consumes: all implementation commits.
- Produces: a clean branch ready for PR review.

- [ ] **Step 1: Confirm worktree state**

Run:

```bash
git status --short --branch
```

Expected: clean worktree on the feature branch, with no `.godot/` or `/android/` entries.

- [ ] **Step 2: Review recent commits**

Run:

```bash
git log --oneline -8
```

Expected: separate commits for tests, trigger script, level script, tutorial scene, game wiring, and optional tuning.

- [ ] **Step 3: Final automated verification**

Run:

```bash
python3 -m unittest tests/scaffold/test_project_structure.py
/Users/macbook/.local/bin/godot --headless --path . --quit
```

Expected: scaffold tests pass and Godot project loads headlessly.

- [ ] **Step 4: Final report**

Report:

```text
Implemented TutorialLevel first pass.
Verified:
- python3 -m unittest tests/scaffold/test_project_structure.py
- /Users/macbook/.local/bin/godot --headless --path . --quit
Manual smoke:
- Game starts at TutorialLevel.
- Prompts advance through the tutorial route.
- FinishArea completes the level.
```
