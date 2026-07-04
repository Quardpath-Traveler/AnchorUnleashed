# NPC Water Floating and Drifting Design

## Purpose

Make NPCs float on animated water surfaces and drift slowly along the water flow direction, purely via kinematic animation without physics simulation.

## Context

- NPC scene: `scenes/characters/NPC.tscn` is currently a static `Node2D + Sprite2D` with no script or collider.
- Existing enemy NPC script: `scripts/enemies/npcs/enemy_npc.gd` extends `CharacterBody2D` but is not referenced by `NPC.tscn` and contains no movement logic.
- Water surface: `scenes/level_parts/WaterSurface.tscn` with `scripts/level_parts/water_surface.gd`.
  - Already animates waves and provides buoyancy/flow forces to `RigidBody2D` boats in the `boats` group.
  - Exposes `get_surface_depth_at_global_position()`, `get_water_flow_direction()`, `get_water_up_direction()`, `current_flow_speed`, and `surface_y`.
- Boat script: `scripts/player/boat.gd` is a `RigidBody2D` and uses the water's physics interface.

## Requirements

1. **Kinematic driving**: NPC movement is animation-based, not physics-based. No `RigidBody2D` or `CharacterBody2D` movement logic is required.
2. **Surface alignment**: NPC's vertical position matches the animated water surface height at its current horizontal position.
3. **Drift direction**: NPC drifts along the water flow direction defined by the `WaterSurface` it is floating on.
4. **Drift speed**: Uses a single global multiplier against the water's `current_flow_speed` so all NPCs drift at the same relative rate.
5. **Auto-detection**: Each NPC instance is an independent scene that automatically detects which `WaterSurface` it is inside.
6. **Stop on exit**: When NPC leaves the horizontal bounds of a water surface (no overlapping water area), it stops moving.
7. **No interaction in this task**: Collision, rescue, damage, or other gameplay interactions are handled in separate tasks.
8. **Visual facing**: Sprite flips horizontally to match the drift direction.

## Design

### Architecture

- `WaterSurface` remains unchanged except for adding one public helper to query animated surface height in world space.
- `FloatingNPC` is a new script attached to `scenes/characters/NPC.tscn`.
- `NPC.tscn` adds an `Area2D` child used only to detect overlapping `WaterSurface` areas.

```
NPC (Node2D) [FloatingNPC]
├── WaterDetector (Area2D)
│   └── CollisionShape2D
└── Sprite2D
```

### WaterSurface helper

Add to `scripts/level_parts/water_surface.gd`:

```gdscript
func get_surface_height_at_global_position(global_position: Vector2) -> float:
    var local_position := to_local(global_position)
    return to_global(Vector2(local_position.x, _sample_surface_y(local_position.x))).y
```

This converts the NPC's world X into the local wave height and back to world Y, keeping the existing wave sampling logic in one place.

### FloatingNPC script

Attach to `scenes/characters/NPC.tscn` root node.

#### Exported parameters

```gdscript
@export var drift_speed_multiplier: float = 0.6
@export var vertical_offset: float = 0.0
@export var detection_area: Area2D
@export var sprite: Sprite2D
```

- `drift_speed_multiplier`: scales the water's `current_flow_speed` for all NPCs.
- `vertical_offset`: fine-tunes how far the sprite's pivot sits above/below the surface.
- `detection_area`: `Area2D` whose collision mask only overlaps `WaterSurface`.
- `sprite`: used to flip horizontally based on drift direction.

#### Internal state

```gdscript
var _current_water: WaterSurface = null
```

#### Process flow in `_physics_process(delta)`

1. **Update water reference**
   - Query `detection_area.get_overlapping_areas()`.
   - Filter for `WaterSurface` and store the first match in `_current_water`.
   - If none found, set `_current_water = null` and return.

2. **Align to surface**
   - `var surface_height := _current_water.get_surface_height_at_global_position(global_position)`
   - `global_position.y = surface_height + vertical_offset`

3. **Drift along flow**
   - `var flow_direction := _current_water.get_water_flow_direction()`
   - `var drift_speed := _current_water.current_flow_speed * drift_speed_multiplier`
   - `global_position += flow_direction * drift_speed * delta`

4. **Update facing**
   - If `flow_direction.x < 0`: `sprite.flip_h = true`
   - Else: `sprite.flip_h = false`

### Scene structure changes

Modify `scenes/characters/NPC.tscn`:

1. Add `FloatingNPC` script to root `Node2D`.
2. Add `Area2D` child named `WaterDetector`.
3. Add a `CollisionShape2D` under `WaterDetector` with a small rectangle shape centered on the sprite's base.
4. Set `WaterDetector` collision mask to match `WaterSurface`'s collision layer.
5. Wire `detection_area` and `sprite` exports in the scene.

### Error handling

- **Multiple overlapping waters**: use the first detected `WaterSurface`. Future iterations could choose the highest surface if needed.
- **NPC placed outside water**: stops moving until it drifts into a water area or is moved by a level designer.
- **Missing exports**: `FloatingNPC._ready()` prints an error if `detection_area` or `sprite` is not assigned.
- **Rotated water surfaces**: `get_water_flow_direction()` and `get_surface_height_at_global_position()` already account for node rotation, so NPCs drift along the rotated flow automatically.

## Success criteria

- An NPC placed inside a `WaterSurface` bobs up and down with the animated waves.
- The NPC drifts slowly along the water's flow direction.
- Rotating the `WaterSurface` node changes the NPC drift direction accordingly.
- The NPC stops moving when it leaves the water area.
- Sprite flips to face the drift direction.
- Existing boat physics and water rendering behavior remain unchanged.

## Files to modify

- `scripts/level_parts/water_surface.gd` — add `get_surface_height_at_global_position()` helper.
- `scenes/characters/NPC.tscn` — attach `FloatingNPC`, add `WaterDetector` Area2D, wire exports.
- `scripts/characters/floating_npc.gd` — new script (create matching `.gd.uid`).

## Future extensions (out of scope)

- Per-NPC drift speed override.
- Collision/damage/rescue interactions with the player boat.
- NPC spawning and pooling.
- Support for overlapping water surfaces with priority rules.
