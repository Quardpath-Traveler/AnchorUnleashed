# Boat Bad Landing Righting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the boat enters water at a large angle relative to the water surface, lose one crew member and apply a short, strong torque to quickly right the boat parallel to the water.

**Architecture:** `WaterSurface` owns the relative-angle landing detection and notifies the boat via a direct method call plus a signal. `Boat` owns the consequence (crew loss) and the righting state, applying decaying torque inside `_integrate_forces`. This keeps detection and reaction decoupled.

**Tech Stack:** Godot 4.7, GDScript, Jolt Physics 2D, existing Python scaffold tests.

## Global Constraints

- Engine: Godot 4.7, Jolt Physics, Forward Plus renderer.
- All `main` pushes go through a Pull Request; never push directly to `main`.
- Code owns `.gd`, `.cs`, `.tscn` node structure, and `project.godot`.
- Smoke-test the project in Godot before marking a PR ready.
- Stage `.gd.uid` files together with their `.gd` scripts.
- Pull with rebase before pushing: `git pull --rebase origin main`.

---

## Files Changed

| File | Change |
|---|---|
| `scripts/level_parts/water_surface.gd` | Use relative angle for bad-landing detection; extend `boat_bad_landing` signal; remove direct `lose_crew` call and `unsafe_landing_crew_loss` export. |
| `scripts/player/boat.gd` | Add righting exports/state; add `on_bad_landing(...)`; apply decaying righting torque in `_integrate_forces`. |

## Task 1: Update WaterSurface landing detection

**Files:**
- Modify: `scripts/level_parts/water_surface.gd`

**Interfaces:**
- Consumes: `Boat.global_rotation`, `WaterSurface.get_boat_target_rotation()`
- Produces: `signal boat_bad_landing(boat, landing_angle_degrees, target_rotation, water_surface)`, direct call `body.on_bad_landing(angle_degrees, target_rotation, water_surface)` if present.

### Step 1: Update signal definition

In `scripts/level_parts/water_surface.gd`, change:

```gdscript
signal boat_bad_landing(boat: Node2D, landing_angle_degrees: float)
```

To:

```gdscript
signal boat_bad_landing(boat: Node2D, landing_angle_degrees: float, target_rotation: float, water_surface: Node2D)
```

### Step 2: Remove obsolete export

Remove this line from `scripts/level_parts/water_surface.gd`:

```gdscript
@export var unsafe_landing_crew_loss: int = 1
```

### Step 3: Make landing angle relative to water surface

Replace the existing `get_landing_angle_degrees` function with:

```gdscript
func get_landing_angle_degrees(body: Node2D) -> float:
    var relative_rotation := wrapf(body.global_rotation - get_boat_target_rotation(), -PI, PI)
    return absf(rad_to_deg(relative_rotation))
```

### Step 4: Update body_entered to notify boat and emit extended signal

Replace the body of `_on_body_entered` with:

```gdscript
func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("boats"):
        _track_boat_in_water(body)

        var landing_angle := get_landing_angle_degrees(body)
        boat_entered.emit(body)
        _apply_entry_impulse(body)

        if landing_angle > safe_landing_angle_degrees:
            var target_rotation := get_boat_target_rotation()
            if body.has_method("on_bad_landing"):
                body.on_bad_landing(landing_angle, target_rotation, self)
            boat_bad_landing.emit(body, landing_angle, target_rotation, self)
        else:
            boat_landed_safely.emit(body, landing_angle)
```

### Step 5: Verify no `unsafe_landing_crew_loss` remains

Run:

```bash
grep -n "unsafe_landing_crew_loss" scripts/level_parts/water_surface.gd
```

Expected: no output.

### Step 6: Commit

```bash
git add scripts/level_parts/water_surface.gd
git commit -m "feat(water): use relative angle for bad landing and notify boat"
```

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>

---

## Task 2: Implement Boat bad landing righting

**Files:**
- Modify: `scripts/player/boat.gd`

**Interfaces:**
- Consumes: `WaterSurface.on_bad_landing(angle_degrees, target_rotation, water_surface)` call.
- Produces: `func on_bad_landing(angle_degrees: float, target_rotation: float, water_surface: Node2D) -> void`, internal `_apply_bad_landing_righting(state)`.

### Step 1: Add righting exports

After the existing `@export var max_linear_speed: float = 0.0` line, add:

```gdscript
@export var bad_landing_righting_torque: float = 80000.0
@export var bad_landing_righting_duration: float = 0.5
@export var bad_landing_righting_damping: float = 3200.0
@export var bad_landing_min_trigger_interval: float = 0.3
```

### Step 2: Add righting state variables

After the existing `_is_counter_rotation_boost_active: bool = false` line, add:

```gdscript
var _righting_timer: float = 0.0
var _righting_target_rotation: float = 0.0
var _last_bad_landing_water: Node2D = null
var _last_bad_landing_time: float = -1000.0
```

### Step 3: Add public bad landing handler

Add this new method to `scripts/player/boat.gd`:

```gdscript
func on_bad_landing(angle_degrees: float, target_rotation: float, water_surface: Node2D) -> void:
    if water_surface == _last_bad_landing_water:
        if Time.get_ticks_msec() / 1000.0 - _last_bad_landing_time < bad_landing_min_trigger_interval:
            return

    lose_crew(1)
    _righting_timer = bad_landing_righting_duration
    _righting_target_rotation = target_rotation
    _last_bad_landing_water = water_surface
    _last_bad_landing_time = Time.get_ticks_msec() / 1000.0
```

### Step 4: Add righting torque application

Add this new method to `scripts/player/boat.gd`:

```gdscript
func _apply_bad_landing_righting(state: PhysicsDirectBodyState2D) -> void:
    if _righting_timer <= 0.0:
        return

    _righting_timer -= state.step
    var decay := clampf(_righting_timer / bad_landing_righting_duration, 0.0, 1.0)

    var rotation_error := wrapf(state.transform.get_rotation() - _righting_target_rotation, -PI, PI)
    var righting_torque := (
        -rotation_error * bad_landing_righting_torque * decay
        - state.angular_velocity * bad_landing_righting_damping * decay
    )
    state.apply_torque(righting_torque)
```

### Step 5: Wire righting into integrate_forces

In `func _integrate_forces(state: PhysicsDirectBodyState2D) -> void`, add the righting call after the anchor constraint:

```gdscript
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    _contact_count = state.get_contact_count()
    _apply_anchor_constraint(state)
    _apply_bad_landing_righting(state)
    state.angular_velocity = clampf(
        state.angular_velocity,
        -max_angular_velocity,
        max_angular_velocity
    )
    _limit_linear_speed(state)
```

### Step 6: Commit

```bash
git add scripts/player/boat.gd
git commit -m "feat(player): add bad landing righting torque and crew loss"
```

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>

---

## Task 3: Verify existing scaffold tests still pass

**Files:**
- Test: `tests/scaffold/test_project_structure.py`

### Step 1: Run Python tests

```bash
python -m unittest tests/scaffold/test_project_structure.py
```

Expected: all tests pass with `OK`.

### Step 2: If tests fail, fix regressions

Likely issues:
- `test_water_surface_is_animated_and_gameplay_ready` checks for `signal boat_bad_landing`, `lose_crew`, `get_boat_target_rotation() -> float` — keep these.
- It does **not** check for `unsafe_landing_crew_loss`, so removal is safe.

### Step 3: Commit

No new files to add; tests are already tracked. If you fixed anything:

```bash
git add tests/scaffold/test_project_structure.py
```

---

## Task 4: Godot smoke test

**Files:**
- Test scene: `debug/DebugLevel.tscn` or `scenes/levels/LevelPrototypeSlope.tscn`

### Step 1: Headless parse check

```bash
godot --headless --path . --quit
```

Expected: Godot loads the project and exits without script parse errors or crashes. Any parse error must be fixed before continuing.

### Step 2: Manual in-editor test

1. Open Godot 4.7 editor.
2. Run `debug/DebugLevel.tscn` (or `scenes/levels/LevelPrototypeSlope.tscn`).
3. Drive the boat into the water at a shallow angle (< 35° relative to the water surface).
   - Expected: `boat_landed_safely` behavior; crew count unchanged; boat floats normally.
4. Reset the scene (`R` by default for `debug_reset`) and drive the boat into the water at a steep angle (> 35° relative to the water surface), or flip the boat in the air first.
   - Expected: crew count decreases by 1, boat quickly rotates to align with the water surface.
5. Rapidly bounce the boat in and out of the water edge.
   - Expected: crew loss does not happen more than once within ~0.3 s for the same water surface.

### Step 3: Optional posture log check

If `posture_logging_enabled` is true on the boat, watch the editor output for `BOAT_POSTURE` lines after a bad landing. Verify `rotation_degrees` converges toward the water surface angle within a few frames.

### Step 4: Commit

No new files. If you created a temporary debug scene, do not commit it unless it is intended as a regression test.

---

## Self-Review Checklist

1. **Spec coverage**
   - Relative angle detection: Task 1, Step 3.
   - Boat rights itself to water surface angle: Task 2, Steps 3–5.
   - Crew loss of 1: Task 2, Step 3.
   - Debounce for same water surface: Task 2, Step 3.
   - Decoupled detection/reaction: Task 1 removes direct `lose_crew`; Task 2 adds `on_bad_landing`.

2. **Placeholder scan**
   - No TBD/TODO left in the plan.
   - All code blocks contain concrete GDScript.
   - All commands include expected output.

3. **Type consistency**
   - `boat_bad_landing` signal: `(Node2D, float, float, Node2D)`.
   - `on_bad_landing` method: `(float, float, Node2D) -> void`.
   - `_apply_bad_landing_righting`: `(PhysicsDirectBodyState2D) -> void`.

## Execution Handoff

After this plan is saved, choose one of the following execution approaches:

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration. Required skill: `superpowers:subagent-driven-development`.
2. **Inline Execution** — execute tasks in the current session using `superpowers:executing-plans`, batch execution with checkpoints.
