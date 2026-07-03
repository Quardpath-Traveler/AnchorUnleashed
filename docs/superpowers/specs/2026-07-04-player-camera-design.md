# Player Camera Design

## Overview
Add a reusable 2D camera scene and attach it to the player in `scenes/game/Game.tscn` so the view follows the boat as it moves.

## Approach
Use a child-of-player camera.

- Create `scenes/camera/GameCamera.tscn` containing a `Camera2D` root node.
- In `scenes/game/Game.tscn`, instance `GameCamera.tscn` as a child of the `玩家` (`Boat`) node.
- The camera automatically inherits the player’s movement because it is a child node, requiring no follow script.

## Files

### New
- `scenes/camera/GameCamera.tscn`

### Modified
- `scenes/game/Game.tscn`

## Camera settings
- `process_callback`: `Camera2D.CAMERA2D_PROCESS_IDLE` (default, matches game loop)
- `anchor_mode`: `Camera2D.ANCHOR_MODE_DRAG_CENTER` (default)
- `enabled`: `true`
- Position offset: `(0, 0)` relative to the boat (centered)

## Out of scope
- Camera smoothing / lerp
- Zoom level adjustments
- Camera bounds or limits
- Shake effects

## Testing
1. Open `scenes/game/Game.tscn` in Godot.
2. Run the scene.
3. Move the boat and verify the viewport follows it.
