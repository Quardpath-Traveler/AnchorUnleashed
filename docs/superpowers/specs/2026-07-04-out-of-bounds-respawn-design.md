# Out-of-Bounds Fountain Respawn Design

## Summary

When the boat enters a level-placed "death zone", it is immediately pulled back to a designated respawn point by a fountain launch. The boat loses one crew member (one life) in the process, unless it is already at zero crew. Control is disabled during the fountain animation and restored once the boat lands on a solid surface or water.

## Context

- The boat is a `RigidBody2D` controlled by `scripts/player/boat.gd`.
- `Boat` already tracks `crew_count` and exposes `lose_crew()`.
- Levels already use `StartMarker` for the initial spawn position, but there is no out-of-bounds detection or respawn system.
- The anchor system is part of `Boat`; active anchors must be recalled before a respawn teleport to avoid rope constraint glitches.

## Goals

- Prevent a single mistake from ending the run by giving the boat a second (or third) chance.
- Make each out-of-bounds area level-designable with its own respawn point.
- Keep the fountain respawn readable and brief so it does not break flow.
- Reuse the existing `crew_count` system as the penalty resource.

## Non-goals

- No new HUD display for crew count in this iteration.
- No particles, sound effects, or bespoke fountain art in this iteration.
- No AI or movement for dropped crew members.
- No game-over screen when crew reaches zero.

## Design

### Architecture

- `DeathZone` scene: a reusable `Area2D` trigger placed in levels. It knows which `Marker2D` the boat should respawn at.
- `Boat` script: owns the respawn state machine and the public `respawn_at(target_position)` entry point.
- Level scenes: place `DeathZone` instances where the boat can fall out of the world, and child `Marker2D` nodes for fountain launch positions.

### Components

#### `scripts/mechanics/death_zone.gd`

Extends `Area2D`.

Exports:
- `respawn_marker: Marker2D` — the position the boat is teleported to before the fountain launch.

Runtime:
- Connects `body_entered` in `_ready()`.
- On overlap, validates the body is in group `"boats"` and has method `respawn_at`.
- If `respawn_marker` is missing, logs a warning and returns early.
- Calls `body.respawn_at(respawn_marker.global_position)`.

#### `scripts/player/boat.gd`

New state:

```gdscript
enum RespawnState { NONE, RECALL, LAUNCH, RECOVER }
var _respawn_state: RespawnState = RespawnState.NONE
var _respawn_target: Vector2 = Vector2.ZERO
var _respawn_recovery_timer: float = 0.0
```

New exports:
- `@export var respawn_launch_force: float = 900.0` — upward impulse applied at the respawn point.
- `@export var respawn_recovery_grace: float = 0.5` — seconds of invulnerability after landing.

New public method:

```gdscript
func respawn_at(target_position: Vector2) -> void
```

- Returns early if `_respawn_state != RespawnState.NONE` or `_respawn_recovery_timer > 0.0` to avoid overlapping respawns or re-triggering during the grace period.
- Stores `_respawn_target` and transitions to `RespawnState.RECALL`.

State machine behavior:

1. **RECALL** (one physics frame)
   - If `anchor.is_active()` or `anchor.is_hooked()`, call `anchor.recall()`.
   - Call `_reset_anchor_swing_state()` to clear any residual rope state.
   - Transition to `LAUNCH`.

2. **LAUNCH** (one physics frame)
   - Teleport the boat to `_respawn_target` via `global_position`.
   - Zero `linear_velocity` and `angular_velocity`.
   - Apply central impulse `Vector2.UP * respawn_launch_force`.
   - If `crew_count > 0`, call `lose_crew(1)`.
   - Transition to `RECOVER`.

3. **RECOVER**
   - Skip player rotation input in `_physics_process`.
   - Skip anchor aim/launch input in `_unhandled_input`.
   - Wait until `is_in_water()` or `_contact_count > 0`.
   - On landing, set `_respawn_recovery_timer = respawn_recovery_grace` and transition to `NONE`.

4. **NONE**
   - Normal control.
   - In `_physics_process`, decrement `_respawn_recovery_timer` toward `0.0` each frame.
   - While `_respawn_recovery_timer > 0.0`, `respawn_at` will refuse new death-zone triggers.

`_integrate_forces` changes:
- While `_respawn_state != RespawnState.NONE`, skip the anchor rope constraint so the teleport and fountain impulse are not fighting an active swing.
- Rotation clamping and linear speed limit remain active during respawn.

#### `scenes/mechanics/DeathZone.tscn`

```text
DeathZone (Area2D)
├── CollisionShape2D
└── RespawnMarker (Marker2D)  -- default child, referenced by the exported field
```

- Attach `scripts/mechanics/death_zone.gd` to the root `Area2D`.
- The exported `respawn_marker` can point to the default child `RespawnMarker` or to any other `Marker2D` in the level.
- Collision layer/mask should only detect the boat. Reuse the same mask as `CanCollectible` or `Obstacle` if appropriate, or add a dedicated `death_zone` physics layer.

#### Level scenes

- Add `DeathZone` instances below water surfaces / at the bottom of pits where the boat can fall out.
- Position `RespawnMarker` slightly above a safe water surface or ground so the fountain launch has somewhere to land.
- Update `TutorialLevel.tscn` and `LevelPrototypeSlope.tscn` with at least one death zone each.

### Data Flow

1. Boat `RigidBody2D` enters a `DeathZone` `Area2D`.
2. `death_zone.gd::_on_body_entered` validates the body and calls `boat.respawn_at(respawn_marker.global_position)`.
3. `Boat` enters `RECALL`, recalls the anchor, and clears swing state.
4. `Boat` enters `LAUNCH`, teleports to the marker, zeros velocity, applies upward impulse, and loses one crew.
5. `Boat` enters `RECOVER`, ignoring input until it lands in water or on ground.
6. `Boat` returns to `NONE` with a short grace timer.

### Edge Cases

- **Already respawning or in grace period**: `respawn_at` returns early while `_respawn_state != RespawnState.NONE` or `_respawn_recovery_timer > 0.0`.
- **Anchor hooked during death**: Anchor is recalled first, preventing the boat from being teleported while constrained by rope.
- **Zero crew**: `lose_crew(1)` is skipped when `crew_count == 0`; the boat still respawns.
- **Landing inside another death zone**: The grace timer (`_respawn_recovery_timer`) prevents `respawn_at` from accepting a new trigger immediately after landing.
- **Respawn marker in the air with no ground below**: Level design issue; `DeathZone` logs a warning but does not crash. Designers should place markers above reachable surfaces.
- **Multiple death zones**: Each has its own `respawn_marker`, so falling off different sides of a level can respawn at different fountains.

### Testing Plan

1. **Unit-style debug scene**
   - Create `debug/OutOfBoundsRespawnTest.tscn` with a `Boat`, a `DeathZone`, and a `RespawnMarker` above a `WaterSurface`.
   - Drag the boat into the death zone and verify:
     - Boat teleports to the marker.
     - Boat launches upward.
     - `crew_count` decreases from 3 to 2.
     - Input is ignored during launch and returns after landing.

2. **Crew exhaustion**
   - Repeatedly trigger the death zone until `crew_count` reaches 0.
   - Verify the boat still respawns and `crew_count` stays at 0.

3. **Level playtest**
   - Run `TutorialLevel` and intentionally fall off.
   - Verify the fountain launch feels natural and control returns cleanly.
   - Verify the anchor is recalled if it was active.

4. **Regression**
   - Confirm normal sailing, anchor throw/swing, and bullet time still work.
   - Confirm `WaveChaser` and finish area behavior are unchanged.

## Trade-offs Considered

- **DeathZone as Area2D vs. global Y-threshold**: Chose Area2D so designers can shape arbitrary out-of-bounds regions and bind each to a custom respawn point.
- **Respawn logic in `Boat` vs. a dedicated controller**: Chose Boat-integrated (方案 A) to minimize files and signal wiring for the jam timeline.
- **Control return on landing vs. fixed timer**: Chose landing detection to feel more physical; fixed timers could leave the player airborne and helpless.
- **No HUD crew display**: Per design choice; temporary feedback can be added later without changing the core mechanic.

## Files Changed

- `scripts/player/boat.gd`
- `scripts/mechanics/death_zone.gd` (new)
- `scenes/mechanics/DeathZone.tscn` (new)
- `scenes/levels/TutorialLevel.tscn`
- `scenes/levels/LevelPrototypeSlope.tscn`
- `debug/OutOfBoundsRespawnTest.tscn` (new)

## Related Documents

- `2026-07-04-out-of-bounds-respawn-design.md` (this document)
- `2026-07-04-boat-counter-rotation-boost-design.md`
- `2026-07-03-anchor-swing-design.md`
