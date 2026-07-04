# Rescue Mechanic Design

## Summary

When the boat touches a rescue NPC, the NPC is pulled aboard and the boat gains one crew member (one extra life). Crew count is capped at a configurable maximum and displayed on the HUD.

## Context

- Boat already tracks `crew_count` and exposes `lose_crew()` for obstacles and bad water landings.
- `NPC.tscn` is currently a decorative Node2D with no collision or script.
- HUD currently only shows score; crew count is not visible to the player.

## Goals

- Make rescue NPCs a clear source of extra lives.
- Keep implementation consistent with existing collectible/obstacle patterns.
- Give the player immediate feedback through HUD.

## Non-goals

- NPC movement/AI behavior is out of scope; this task only adds the rescue trigger and effect.
- No animations, particles, or sound effects for this iteration.

## Design

### Architecture

- `NPCRescue` script on an `Area2D` child of `NPC.tscn` detects boat overlap.
- `Boat.gain_crew(amount)` increments `crew_count` up to `max_crew_count`.
- HUD listens to `Boat.crew_count_changed` and displays current/max crew.

### Components

#### `scripts/characters/npc_rescue.gd`

Extends `Area2D`.

Exports:
- `rescue_value: int = 1` — crew gained when rescued.

Runtime:
- Connects `body_entered` in `_ready()`.
- On overlap, if the body is in group `"boats"` and has method `gain_crew`, calls it and then `queue_free()`.
- Uses a local `_rescued` flag to prevent double triggers.

#### `scripts/player/boat.gd`

New exports:
- `@export var max_crew_count: int = 5`

New signal:
- `crew_gained(count: int)`

Modified setter for `crew_count`:
- `crew_count = clamp(value, 0, max_crew_count)`

New method:
- `func gain_crew(amount: int = 1) -> void`
  - Stores previous count.
  - Increments `crew_count` (clamped by setter).
  - Emits `crew_gained` and `crew_count_changed` if the value changed.

#### `scripts/ui/hud.gd` and `scenes/ui/HUD.tscn`

- Add `CrewLabel` to the HUD scene.
- In `hud.gd`, locate the current `Boat` (via EventBus `player_spawned` or by group `"boats"`), connect to `crew_count_changed`, and update label text like `Crew: %d/%d`.

#### `scenes/characters/NPC.tscn`

- Add child `Area2D` named `RescueArea`.
- Add `CollisionShape2D` with a circle shape (radius ~32 px) sized to the NPC sprite.
- Attach `npc_rescue.gd` to `RescueArea`.

#### `scenes/levels/Level.tscn`

- Place one `NPC` instance near the first water surface for playtesting in `DebugLevel`.

### Data Flow

1. Boat RigidBody2D enters `NPC.RescueArea`.
2. `npc_rescue.gd::_on_body_entered` validates the body and marks `_rescued = true`.
3. `boat.gain_crew(1)` increments `crew_count` (capped at 5).
4. `boat` emits `crew_count_changed` and `crew_gained`.
5. `npc_rescue.gd` calls `queue_free()`.
6. HUD updates `CrewLabel`.

### Edge Cases

- **At max crew**: `gain_crew` does not increase count, but the NPC is still consumed so the player does not try to rescue it repeatedly. (Alternative: leave NPC in place; chosen alternative is to consume it to keep the level clean.)
- **Body destroyed mid-trigger**: `is_instance_valid(body)` checks prevent crashes.
- **Multiple overlaps in one frame**: `_rescued` flag prevents duplicate calls.

### Testing Plan

1. Open `DebugLevel.tscn`.
2. Run the scene.
3. Sail into the placed NPC.
4. Verify:
   - `crew_count` increases from 3 to 4.
   - HUD shows `Crew: 4/5`.
   - NPC disappears.
5. Lose crew by hitting an obstacle or landing badly.
6. Rescue again until crew reaches 5; verify it does not exceed 5.

## Trade-offs Considered

- **Area2D on NPC vs. shared RescueTarget component**: Chose Area2D on NPC because it mirrors the existing `CanCollectible` pattern and is level-designer friendly.
- **Max crew cap**: Chose 5 to give players a small buffer without making the game trivial.
- **Consume NPC at max crew**: Keeps the level state clean; can be revisited if designers want NPCs to persist when the player is full.

## Files Changed

- `scripts/player/boat.gd`
- `scripts/ui/hud.gd`
- `scenes/ui/HUD.tscn`
- `scenes/characters/NPC.tscn`
- `scripts/characters/npc_rescue.gd` (new)
- `scenes/levels/Level.tscn`

## Related Documents

- `2026-07-04-boat-counter-rotation-boost-design.md`
- `2026-07-03-slope-with-water-design.md`
