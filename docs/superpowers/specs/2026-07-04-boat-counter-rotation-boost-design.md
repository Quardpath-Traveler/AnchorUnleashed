# Boat Counter-Rotation Boost Design

## Purpose

Add a counter-rotation boost mechanism to the boat so that when the player reverses rotation direction (e.g. from D to A), the boat quickly overcomes its current angular momentum and starts turning the other way.

## Context

- Boat script: `scripts/player/boat.gd`
- Current rotation logic: `_physics_process()` lines 54-59 apply a fixed `airborne_rotation_torque` based on `Input.get_axis("move_left", "move_right")` while airborne and not anchored.
- Existing debug scene: `debug/BoatRotationDebug.tscn` with `DebugValuePanel`, `DebugGraph`, and `DebugRotationIndicator`.

## Requirements

1. **Trigger**: boost activates when the rotation input direction is opposite to the current `angular_velocity` direction.
2. **Boost magnitude**: torque is multiplied by a configurable factor (default 2.0).
3. **Release**: boost ends once `angular_velocity` has reversed and aligns with the input direction, or when input is released.
4. **Scope**: boost only applies while airborne, consistent with existing airborne rotation torque.
5. **Debug visibility**: the boost state and multiplier are shown in the debug value panel.
6. **Test coverage**: the automated harness asserts the boosted torque is applied during reverse input.

## Design

### State variable

Add to `Boat`:

```gdscript
var _is_counter_rotation_boost_active: bool = false
```

### Exported parameters

```gdscript
@export var counter_rotation_boost: float = 2.0
@export var counter_rotation_zero_threshold: float = 0.05  # rad/s
```

- `counter_rotation_boost`: torque multiplier while reversing rotation.
- `counter_rotation_zero_threshold`: angular velocities with absolute value below this are treated as zero to avoid sign-flipping noise near the crossing.

### State transitions

| From | To | Condition |
|---|---|---|
| inactive | active | Input is non-zero and `sign(input) != sign(angular_velocity)` and `abs(angular_velocity) > threshold` |
| active | inactive | `sign(angular_velocity) == sign(input)` or input is zero |
| active | inactive | Boat is no longer airborne or anchor is hooked |

### Torque application

In `_physics_process`, replace the fixed torque line with:

```gdscript
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
```

`_update_counter_rotation_boost(input)` updates `_is_counter_rotation_boost_active` based on the rules above.

### Debug UI update

- `DebugValuePanel` adds two labels:
  - `counter_boost_active`
  - `counter_boost_mult`
- `BoatRotationDebug._process` passes `_boat._is_counter_rotation_boost_active` and `_boat.counter_rotation_boost` to the panel.
- `BoatRotationDebug._compute_applied_torque` returns the boosted torque value so the panel shows the actual applied torque.

### Files to modify

- `scripts/player/boat.gd` — add state, parameters, and boost logic
- `debug/ui/DebugValuePanel.gd` — display boost state and multiplier
- `debug/ui/DebugValuePanel.tscn` — no structural change needed if labels are built dynamically
- `debug/boat_rotation_debug.gd` — pass boost values and actual torque to the panel
- `debug/boat_rotation_debug_test.gd` — add assertion for boosted torque during reverse input

## Success criteria

- Holding D then pressing A makes the angular velocity drop to zero and reverse faster than without boost.
- `DebugValuePanel` shows `Counter Boost Active: true` during the reversal and `false` afterwards.
- The automated test harness passes and reports boosted torque during reverse input.
- No behavior change when rotating in the same direction as current angular velocity.

## Future extensions (out of scope)

- Smooth interpolation of boost multiplier based on angular-velocity error.
- Applying the same boost logic to water-stabilized rotation.
- Per-direction asymmetric boost values.
