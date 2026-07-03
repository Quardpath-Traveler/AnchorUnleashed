# Anchor Swing Design

## Goal

Implement the playable anchor loop from the GDD: hold the anchor button to aim, release to throw, hook a hook point, swing the boat around the hook, and recall the anchor so the boat keeps its momentum.

## Scope

- Use the existing `confirm` input action as the anchor button.
- `Anchor` owns aiming, launch flight, max throw length, hook detection, recall, and rope/head visuals.
- `Boat` owns player input, airborne-only AD rotation, and the rope constraint that keeps the boat within the hooked rope length while preserving tangential velocity.
- Hook points remain scene-authored `HookPoint` nodes in the `hook_points` group.

## Behavior

- Pressing `confirm` while the anchor is ready starts aiming and slows time.
- Releasing `confirm` launches the anchor toward the current mouse position.
- Pressing `confirm` while the anchor is flying or hooked recalls it.
- After the anchor returns to the socket, it is immediately ready to throw again.
- If the anchor reaches its maximum length without hooking, it recalls.
- When hooked, the boat is constrained to the hook radius and can swing with gravity and current velocity.
- When recalled, the boat is no longer constrained and continues along its existing linear velocity.
- AD rotation only applies while the boat has no active body contacts.

## Testing

Add scaffold tests for required script structure and run them before and after implementation. Run Godot headless to catch parse or scene-load errors.
