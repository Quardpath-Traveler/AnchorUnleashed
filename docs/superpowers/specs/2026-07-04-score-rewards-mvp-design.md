# Score Rewards MVP Design

## Context

The current game already has `GameState` fields and signals for score, coin count, and rescued count. HUD, pause, and result screens read those values. NPC rescue already increases boat crew, and can collectibles already emit a `collected(value)` signal, but score rewards are not wired into those gameplay events. The GDD calls for a Ski Safari style loop where pickups, tricks, and rescues increase score during play.

## Scope

Implement the MVP reward loop:

- Collecting a coin or can increases the collected count and score.
- Rescuing an NPC increases rescued count and score when the rescue succeeds.
- Completing a 360-degree airborne boat rotation awards trick score only after a safe water landing.

Out of scope for this pass:

- Combo multipliers.
- Trick name popups or floating score text.
- Detailed settlement statistics beyond the existing score, coin, and rescued values.
- New authored level layout beyond any minimal debug scene needed for verification.

## Recommended Architecture

Use `GameState` as the central reward API because it already owns the score-related state and UI signals.

Add explicit reward methods:

- `award_coin_pickup(amount: int = 1)` increments `coin` and adds score.
- `award_rescue(amount: int = 1)` increments `rescued_count` and adds score.
- `award_trick(trick_name: String, amount: int)` adds score and can later emit a trick notification signal.

Keep existing primitive setters such as `add_score`, `add_coin`, and `add_rescued` for compatibility, but route gameplay reward events through the named reward methods so tuning stays centralized.

## Gameplay Rules

Suggested initial scoring values:

- Coin or can: `1` collected item and `10` score per value.
- Rescue: `1` rescued NPC and `100` score per rescue value.
- 360 trick: `250` score per completed full rotation.

`CanCollectible` should call the pickup reward directly when a boat enters its area, then free itself. If the collectible value is greater than one, both count and score scale by that value.

`NPCRescue` should award rescue only after all existing success conditions pass and `body.gain_crew(rescue_value)` is called. The rescue should not award if the area is re-entered after `_rescued` is set or if the boat cannot gain crew.

`Boat` should track airborne rotation while the boat is not in water and has no physical contacts. It should accumulate absolute wrapped rotation delta so rotations in either direction count. When accumulated rotation reaches `TAU`, it records one pending 360 trick. On safe landing, the boat awards pending trick score. On bad landing, respawn, or returning to ground without a safe water landing, pending trick progress is cleared.

## Integration Points

Safe and bad water landings already originate in `WaterSurface`. The cleanest integration is to connect water landing signals from the level script to the active boat if needed, or call boat methods from `WaterSurface` when the body exposes them. The implementation should choose the smallest change that follows existing patterns:

- `WaterSurface` already calls `body.on_bad_landing(...)`.
- Add a matching `body.on_safe_landing(...)` call for successful water landing.
- Keep the trick state inside `Boat`, where rotation and airborne state are already known.

HUD does not need new nodes for this MVP. Existing `score_changed`, `coin_changed`, and `rescued_changed` signals are enough.

## Error Handling

Reward methods should ignore non-positive amounts to avoid accidental score loss or duplicate zero-value events.

Collectible and rescue scripts should continue to check boat group membership before awarding. Rescue should keep `_rescued` as the duplicate guard.

Boat trick tracking should reset when respawning, entering water badly, or no longer airborne. The scoring method should not depend on frame-perfect physics contact order.

## Testing

Follow `docs/testing/new-feature-testing.md`.

Automated structure tests should cover:

- `GameState` exposes named reward methods and tunable constants.
- `CanCollectible` routes boat collection into `GameState.award_coin_pickup`.
- `NPCRescue` routes successful rescue into `GameState.award_rescue`.
- `Boat` contains 360 trick tracking and safe landing reward hooks.

Focused Godot/debug verification should cover:

- Pickup increments coin count and score once.
- Rescue increments rescued count, crew count, and score once.
- A full airborne rotation followed by safe water landing awards trick score.
- Partial rotation and bad landing do not award trick score.

## Open Decisions

The exact scores are intentionally initial tuning values. They should be exported or constant-backed so designers can adjust them after playtesting without changing the event flow.
