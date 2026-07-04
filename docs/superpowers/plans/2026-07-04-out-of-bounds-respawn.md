# Out-of-Bounds Fountain Respawn Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add reusable death-zone triggers that fountain-launch the boat back to a level-designated respawn point and cost one crew member.

**Architecture:** A reusable `DeathZone` Area2D detects boat entry and tells the boat where to respawn. The `Boat` class owns a short state machine that recalls the anchor, teleports the boat, launches it upward, and restores control after landing.

**Tech Stack:** Godot 4.7, GDScript, Godot Physics 2D

## Global Constraints

- Engine: Godot 4.7, Jolt Physics, Forward Plus renderer
- Main branch: `main`; feature branch prefix: `design/`
- All `main` pushes go through a Pull Request
- Smoke-test the project in Godot before marking a PR ready
- Save and close Godot before committing
- Stage `.import` files together with source assets; stage `.gd.uid` files together with `.gd` scripts
- Never stage `.godot/` or `/android/`

---

## File Structure

- `scripts/mechanics/death_zone.gd` (new): `DeathZone` class; Area2D trigger with exported respawn marker.
- `scenes/mechanics/DeathZone.tscn` (new): Scene containing the Area2D, CollisionShape2D, and default `RespawnMarker` child.
- `scripts/player/boat.gd` (modify): Add respawn state machine, public `respawn_at()` method, and `is_respawning()` helper.
- `debug/OutOfBoundsRespawnTest.tscn` + `debug/out_of_bounds_respawn_test.gd` (new): Automated regression test scene.
- `scenes/levels/TutorialLevel.tscn` (modify): Add a `DeathZone` below the level with a respawn marker above the first water surface.
- `scenes/levels/LevelPrototypeSlope.tscn` (modify): Add a `DeathZone` below the level with a respawn marker above the first water surface.

---

### Task 1: Create the DeathZone script

**Files:**
- Create: `scripts/mechanics/death_zone.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `DeathZone` class with exported `respawn_marker: Marker2D`; calls `body.respawn_at(global_position)` on boats in group `"boats"`.

- [ ] **Step 1: Write the script**

Create `scripts/mechanics/death_zone.gd`:

```gdscript
class_name DeathZone
extends Area2D


@export var respawn_marker: Marker2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("boats"):
		return
	if not body.has_method("respawn_at"):
		return
	if respawn_marker == null:
		push_warning("DeathZone '%s' has no respawn_marker assigned" % name)
		return

	body.respawn_at(respawn_marker.global_position)
```

- [ ] **Step 2: Verify GDScript syntax**

Open the project in Godot, select `scripts/mechanics/death_zone.gd` in the FileSystem dock, and check the Output panel for parser errors.

Expected: no red error lines; Godot generates `scripts/mechanics/death_zone.gd.uid`.

- [ ] **Step 3: Commit**

```bash
git add scripts/mechanics/death_zone.gd scripts/mechanics/death_zone.gd.uid
git commit -m "feat(mechanics): add DeathZone trigger script

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Create the DeathZone scene

**Files:**
- Create: `scenes/mechanics/DeathZone.tscn`

**Interfaces:**
- Consumes: `scripts/mechanics/death_zone.gd`
- Produces: A reusable scene with a default `RespawnMarker` child and a wide rectangular collision shape.

- [ ] **Step 1: Create the scene in Godot**

1. In Godot, choose **Scene > New Scene**.
2. Add root node **Area2D**, rename to `DeathZone`.
3. Attach `scripts/mechanics/death_zone.gd` to the root.
4. Add child **CollisionShape2D**.
   - Create a `RectangleShape2D` resource with `size = Vector2(800, 100)`.
5. Add child **Marker2D**, rename to `RespawnMarker`.
   - Set its position to `Vector2(0, -200)` so the default respawn point is above the death zone.
6. Save as `res://scenes/mechanics/DeathZone.tscn`.

Expected node tree:
```text
DeathZone (Area2D)
├── CollisionShape2D
└── RespawnMarker
```

- [ ] **Step 2: Verify the export field**

With `DeathZone` root selected, confirm the Inspector shows:
- `Script`: `death_zone.gd`
- `Respawn Marker`: points to `RespawnMarker`

If the marker reference is empty, drag `RespawnMarker` into the `respawn_marker` export slot.

- [ ] **Step 3: Commit**

```bash
git add scenes/mechanics/DeathZone.tscn scenes/mechanics/DeathZone.tscn.uid
git commit -m "feat(mechanics): add DeathZone scene

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Extend Boat with respawn state machine

**Files:**
- Modify: `scripts/player/boat.gd`

**Interfaces:**
- Consumes: `anchor.is_active()`, `anchor.is_hooked()`, `anchor.recall()`, `_reset_anchor_swing_state()`, `lose_crew()`, `enter_water()`/`exit_water()` helpers
- Produces:
  - `respawn_at(target_position: Vector2) -> void`
  - `is_respawning() -> bool`
  - `_respawn_state` enum used internally

- [ ] **Step 1: Add respawn state exports and variables**

In `scripts/player/boat.gd`, add the following block immediately after the existing `@export var max_linear_speed: float = 0.0` line:

```gdscript
@export var respawn_launch_velocity: float = 900.0
@export var respawn_recovery_grace: float = 0.5

enum RespawnState { NONE, RECALL, LAUNCH, RECOVER }

var _respawn_state: RespawnState = RespawnState.NONE
var _respawn_target: Vector2 = Vector2.ZERO
var _respawn_recovery_timer: float = 0.0
```

- [ ] **Step 2: Add public respawn API**

Add these two methods after the existing `lose_crew()` method:

```gdscript
func is_respawning() -> bool:
	return _respawn_state != RespawnState.NONE


func respawn_at(target_position: Vector2) -> void:
	if _respawn_state != RespawnState.NONE:
		return
	if _respawn_recovery_timer > 0.0:
		return
	_respawn_state = RespawnState.RECALL
	_respawn_target = target_position
```

- [ ] **Step 3: Wire the state machine into `_physics_process`**

Replace the current `_physics_process` body with this expanded version (keep the existing bullet-time update and posture log calls):

```gdscript
func _physics_process(delta: float) -> void:
	_update_manual_bullet_time(delta)
	_update_respawn_recovery_timer(delta)
	_update_respawn_state(delta)

	if _respawn_state != RespawnState.NONE:
		_update_posture_log(delta)
		return

	var rotation_input := Input.get_axis("move_left", "move_right")
	if is_airborne():
		if not anchor.is_hooked():
			_apply_airborne_nose_down()
		if not is_zero_approx(rotation_input):
			_update_counter_rotation_boost(rotation_input)
			var torque := airborne_rotation_torque
			if _is_counter_rotation_boost_active:
				torque *= counter_rotation_boost
			apply_torque(rotation_input * torque)

	_update_posture_log(delta)
```

- [ ] **Step 4: Add respawn helper methods**

Add the following private methods near the end of `scripts/player/boat.gd`, just before the existing `_vector_to_log_data` method:

```gdscript
func _update_respawn_recovery_timer(delta: float) -> void:
	if _respawn_recovery_timer > 0.0:
		_respawn_recovery_timer = maxf(_respawn_recovery_timer - delta, 0.0)


func _update_respawn_state(_delta: float) -> void:
	match _respawn_state:
		RespawnState.RECALL:
			_recall_anchor_for_respawn()
			_respawn_state = RespawnState.LAUNCH
		RespawnState.RECOVER:
			if is_in_water() or _contact_count > 0:
				_respawn_recovery_timer = respawn_recovery_grace
				_respawn_state = RespawnState.NONE


func _recall_anchor_for_respawn() -> void:
	if anchor.is_active() or anchor.is_hooked():
		anchor.recall()
	_reset_anchor_swing_state()


func _execute_respawn_launch(state: PhysicsDirectBodyState2D) -> void:
	state.transform.origin = _respawn_target
	state.linear_velocity = Vector2.UP * respawn_launch_velocity
	state.angular_velocity = 0.0
	if crew_count > 0:
		lose_crew(1)
```

- [ ] **Step 5: Handle respawn in `_integrate_forces`**

Replace the current `_integrate_forces` body with:

```gdscript
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_contact_count = state.get_contact_count()

	if _respawn_state == RespawnState.LAUNCH:
		_execute_respawn_launch(state)
		_respawn_state = RespawnState.RECOVER

	if _respawn_state != RespawnState.NONE:
		state.angular_velocity = clampf(
			state.angular_velocity,
			-max_angular_velocity,
			max_angular_velocity
		)
		_limit_linear_speed(state)
		return

	_apply_anchor_constraint(state)
	state.angular_velocity = clampf(
		state.angular_velocity,
		-max_angular_velocity,
		max_angular_velocity
	)
	_limit_linear_speed(state)
```

- [ ] **Step 6: Ignore input while respawning**

Modify `_unhandled_input` to return early during respawn:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if _respawn_state != RespawnState.NONE:
		return

	if event.is_action_pressed("confirm"):
		if anchor.is_active():
			anchor.recall()
		else:
			anchor.start_aim()
	elif event.is_action_released("confirm") and anchor.is_aiming:
		anchor.launch(get_global_mouse_position())
```

- [ ] **Step 7: Verify GDScript syntax**

Open the project in Godot and check the Output panel for parser errors in `scripts/player/boat.gd`.

Expected: no errors; `scripts/player/boat.gd.uid` is updated if the file hash changed.

- [ ] **Step 8: Commit**

```bash
git add scripts/player/boat.gd scripts/player/boat.gd.uid
git commit -m "feat(player): add out-of-bounds respawn state machine

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Create automated debug test scene

**Files:**
- Create: `debug/OutOfBoundsRespawnTest.tscn`
- Create: `debug/out_of_bounds_respawn_test.gd`

**Interfaces:**
- Consumes: `Boat`, `DeathZone`, `WaterSurface`
- Produces: A self-running scene that exits with code 0 on success or 1 on failure.

- [ ] **Step 1: Write the test controller script**

Create `debug/out_of_bounds_respawn_test.gd`:

```gdscript
extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")
const DEATH_ZONE_SCENE := preload("res://scenes/mechanics/DeathZone.tscn")
const WATER_SURFACE_SCENE := preload("res://scenes/level_parts/WaterSurface.tscn")

enum Phase {
	SETUP,
	ASSERT_TRIGGER,
	ASSERT_RECOVER,
	DONE,
}

@export var launch_timeout_seconds: float = 0.5
@export var recover_timeout_seconds: float = 3.0
@export var position_tolerance: float = 10.0

var _phase: Phase = Phase.SETUP
var _phase_timer: float = 0.0
var _boat: Boat
var _death_zone: DeathZone
var _respawn_marker: Marker2D
var _failures: Array[String] = []
var _exit_code: int = 0


func _ready() -> void:
	# Water surface for the boat to land in.
	var water := WATER_SURFACE_SCENE.instantiate() as Node2D
	water.global_position = Vector2(400, 400)
	water.water_width = 600.0
	water.water_depth = 120.0
	water.enable_waterfall = false
	add_child(water)

	# Respawn marker above the water.
	_respawn_marker = Marker2D.new()
	_respawn_marker.global_position = Vector2(400, 300)
	add_child(_respawn_marker)

	# Death zone below the water.
	_death_zone = DEATH_ZONE_SCENE.instantiate() as DeathZone
	_death_zone.global_position = Vector2(400, 650)
	_death_zone.respawn_marker = _respawn_marker

	var collision_shape := _death_zone.get_node("CollisionShape2D") as CollisionShape2D
	var rect := RectangleShape2D.new()
	rect.size = Vector2(800, 100)
	collision_shape.shape = rect
	add_child(_death_zone)

	# Boat starts above the death zone.
	_boat = BOAT_SCENE.instantiate() as Boat
	_boat.global_position = Vector2(400, 600)
	add_child(_boat)


func _physics_process(delta: float) -> void:
	_phase_timer += delta

	match _phase:
		Phase.SETUP:
			if _boat.crew_count != 3:
				_fail("Initial crew count should be 3, got %d" % _boat.crew_count)
			# Force the boat into the death zone.
			_boat.global_position = Vector2(400, 650)
			_phase = Phase.ASSERT_TRIGGER
			_phase_timer = 0.0

		Phase.ASSERT_TRIGGER:
			if _phase_timer < launch_timeout_seconds:
				return
			if _boat.crew_count != 2:
				_fail("Crew count should drop to 2, got %d" % _boat.crew_count)
			if _boat.global_position.distance_to(_respawn_marker.global_position) > position_tolerance:
				_fail("Boat did not teleport near respawn marker (got %v)" % _boat.global_position)
			if not _boat.is_respawning():
				_fail("Boat should still be in respawn state immediately after launch")
			_phase = Phase.ASSERT_RECOVER
			_phase_timer = 0.0

		Phase.ASSERT_RECOVER:
			if _phase_timer > recover_timeout_seconds:
				_fail("Boat did not land and exit respawn state within timeout")
				_finish()
				return
			if not _boat.is_respawning():
				_phase = Phase.DONE
				_finish()
				return

		Phase.DONE:
			_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	_exit_code = 1


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Out-of-bounds respawn works.")
	else:
		print("FAIL: Out-of-bounds respawn test failed:")
		for message in _failures:
			print("  - %s" % message)
	get_tree().quit(_exit_code)
```

- [ ] **Step 2: Create the test scene in Godot**

1. Choose **Scene > New Scene**.
2. Add root node **Node2D**, rename to `OutOfBoundsRespawnTest`.
3. Attach `debug/out_of_bounds_respawn_test.gd`.
4. Save as `res://debug/OutOfBoundsRespawnTest.tscn`.

- [ ] **Step 3: Run the test**

Run the test scene headless from the project root:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://debug/OutOfBoundsRespawnTest.tscn
```

Expected output:
```text
PASS: Out-of-bounds respawn works.
```

If it prints `FAIL`, fix the relevant step in Task 3 and re-run.

- [ ] **Step 4: Commit**

```bash
git add debug/out_of_bounds_respawn_test.gd debug/OutOfBoundsRespawnTest.tscn debug/OutOfBoundsRespawnTest.tscn.uid
git commit -m "test(debug): add out-of-bounds respawn regression scene

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Add a DeathZone to TutorialLevel

**Files:**
- Modify: `scenes/levels/TutorialLevel.tscn`

**Interfaces:**
- Consumes: `scenes/mechanics/DeathZone.tscn`
- Produces: A death zone below the lowest water surface that respawns the boat near the start of the level.

- [ ] **Step 1: Open the level scene**

Open `scenes/levels/TutorialLevel.tscn` in Godot.

- [ ] **Step 2: Instance DeathZone**

1. Right-click `TutorialLevel` root, choose **Instance Child Scene**, select `scenes/mechanics/DeathZone.tscn`.
2. Rename to `DeathZone`.
3. Set `Position` to a point below the lowest water surface (e.g., `Vector2(1200, 850)`).
4. Adjust the `CollisionShape2D` size so it covers the full bottom width of the playable area (e.g., `size = Vector2(3000, 200)`).

- [ ] **Step 3: Set the respawn marker**

1. Select the `DeathZone` node.
2. In the Inspector, drag the existing `StartMarker` (or create a new `Marker2D` child of `TutorialLevel` named `RespawnMarker`) into the `respawn_marker` export slot.
3. If using a new marker, place it above the first water surface (e.g., `Vector2(120, 80)`).

Expected: falling off the tutorial level teleports the boat to the chosen marker and launches it upward.

- [ ] **Step 4: Playtest**

Run `TutorialLevel` from the Game scene, intentionally drive/fall into the death zone, and verify:
- The boat respawns at the marker.
- One crew is lost.
- Control returns after landing in water.

- [ ] **Step 5: Commit**

```bash
git add scenes/levels/TutorialLevel.tscn scenes/levels/TutorialLevel.tscn.uid
git commit -m "feat(levels): add out-of-bounds death zone to TutorialLevel

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Add a DeathZone to LevelPrototypeSlope

**Files:**
- Modify: `scenes/levels/LevelPrototypeSlope.tscn`

**Interfaces:**
- Consumes: `scenes/mechanics/DeathZone.tscn`
- Produces: A death zone below the prototype slope level.

- [ ] **Step 1: Open the level scene**

Open `scenes/levels/LevelPrototypeSlope.tscn` in Godot.

- [ ] **Step 2: Instance DeathZone**

1. Instance `scenes/mechanics/DeathZone.tscn` as a child of `LevelPrototypeSlope`.
2. Rename to `DeathZone`.
3. Set `Position` below the lowest water surface (e.g., `Vector2(1000, 800)`).
4. Adjust `CollisionShape2D` size to cover the bottom width (e.g., `size = Vector2(2600, 200)`).

- [ ] **Step 3: Set the respawn marker**

Use the existing `StartMarker` or create a new `Marker2D` named `RespawnMarker` above the first water surface (e.g., `Vector2(120, 100)`), and assign it to the `DeathZone.respawn_marker` export.

- [ ] **Step 4: Playtest**

Run `LevelPrototypeSlope` from the Game scene, fall into the death zone, and verify the respawn sequence works end-to-end.

- [ ] **Step 5: Commit**

```bash
git add scenes/levels/LevelPrototypeSlope.tscn scenes/levels/LevelPrototypeSlope.tscn.uid
git commit -m "feat(levels): add out-of-bounds death zone to LevelPrototypeSlope

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Final smoke test and PR prep

**Files:**
- None (verification only)

- [ ] **Step 1: Run the automated test again**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://debug/OutOfBoundsRespawnTest.tscn
```

Expected: `PASS: Out-of-bounds respawn works.`

- [ ] **Step 2: Manual playtest in TutorialLevel**

1. Open `scenes/game/Game.tscn`.
2. Press F6 or the Play button.
3. Play through the tutorial and intentionally fall off.
4. Confirm the fountain launch, crew loss, and control return feel correct.

- [ ] **Step 3: Regression checks**

In the same play session, verify:
- Anchor throw, swing, and recall still work.
- Bullet time still works.
- Collecting cans and finishing the level still work.
- `WaveChaser` behavior is unchanged.

- [ ] **Step 4: Close Godot and review the diff**

```bash
git status
git diff --stat
```

Expected changed files:
- `scripts/mechanics/death_zone.gd`
- `scripts/mechanics/death_zone.gd.uid`
- `scenes/mechanics/DeathZone.tscn`
- `scenes/mechanics/DeathZone.tscn.uid`
- `scripts/player/boat.gd`
- `scripts/player/boat.gd.uid`
- `debug/out_of_bounds_respawn_test.gd`
- `debug/out_of_bounds_respawn_test.gd.uid`
- `debug/OutOfBoundsRespawnTest.tscn`
- `debug/OutOfBoundsRespawnTest.tscn.uid`
- `scenes/levels/TutorialLevel.tscn`
- `scenes/levels/LevelPrototypeSlope.tscn`

- [ ] **Step 5: Push the branch and open a draft PR**

```bash
git pull --rebase origin main
git push origin design/main-level
gh pr create --draft --title "feat: out-of-bounds fountain respawn" --body "Adds reusable DeathZone triggers that respawn the boat at a fountain point and cost one crew member."
```

Expected: PR is created as a draft against `main`.

---

## Self-Review

### Spec coverage

| Spec requirement | Implementing task |
|---|---|
| Death zones as Area2D triggers | Task 1, Task 2 |
| Each death zone has its own respawn point | Task 2 export, Task 5/6 setup |
| On death: recall anchor | Task 3 Step 4 `_recall_anchor_for_respawn` |
| On death: lose 1 crew unless at 0 | Task 3 Step 4 `_execute_respawn_launch` |
| Fountain launch (uncontrollable) | Task 3 Step 5 `_integrate_forces` launch |
| Control restored on landing | Task 3 Step 4 `_update_respawn_state` RECOVER |
| Grace period after landing | Task 3 Step 4/5 `_respawn_recovery_timer` |
| No HUD crew display | No HUD task included |
| Levels updated | Task 5, Task 6 |
| Testing/debug scene | Task 4 |

### Placeholder scan

- No `TBD`, `TODO`, or "implement later" lines.
- No vague "add error handling" steps; exact checks are shown in code.
- No "write tests for the above"; Task 4 contains the full test script.

### Type consistency

- `respawn_at(target_position: Vector2) -> void` used by `DeathZone` and defined in `Boat`.
- `is_respawning() -> bool` used by the test controller and defined in `Boat`.
- `_respawn_state` enum values (`NONE`, `RECALL`, `LAUNCH`, `RECOVER`) match across all code blocks.
- `DeathZone.respawn_marker: Marker2D` is referenced consistently.

No unresolved issues.
