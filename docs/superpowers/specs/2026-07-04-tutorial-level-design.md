# Tutorial Level Design

## Goal

Design a first playable tutorial level for the Anchor game loop described in the GDD.
The level teaches the player, in order, how to slide with the boat, aim and throw the
anchor, swing from hook points, recall the anchor to keep momentum, adjust boat angle
with A/D while airborne, collect cans, avoid penalties, and reach the finish while a
wave creates forward pressure.

GDD reference:

- Title: `2026CGJ`
- Doc token: `C54QdoaCko2b6wxtNDpcp385nQb`
- Revision read for this design: `445`

## Design Approach

Use a linear segmented tutorial level. This is the recommended approach because the
current project already has a single-direction slope prototype, hook points, water,
wave chaser, can collectible, obstacle, finish area, and tutorial prompt scene. A
linear level gives clear pacing and avoids requiring a larger tutorial-state system
before the core gameplay is stable.

Alternatives considered:

- Open practice sandbox: useful for experimentation, but it does not teach urgency,
  finish-line flow, or obstacle pressure.
- Fully scripted tutorial: can guarantee each lesson, but it is too heavy for the
  current gamejam scope and risks blocking player experimentation.

## Scope

Create one tutorial level concept that can be implemented as a dedicated scene, for
example `scenes/levels/TutorialLevel.tscn`, using existing reusable scenes:

- `scenes/player/Boat.tscn`
- `scenes/mechanics/Anchor.tscn`
- `scenes/mechanics/HookPoint.tscn`
- `scenes/level_parts/WaterSurface.tscn`
- `scenes/level_parts/WaveChaser.tscn`
- `scenes/level_parts/Obstacle.tscn`
- `scenes/items/CanCollectible.tscn`
- `scenes/ui/TutorialPrompt.tscn`

The first implementation should use simple `Area2D` trigger zones for prompt text and
lesson progression. It should not introduce a complex tutorial framework unless later
levels need reusable branching tutorial logic.

## Non-Goals

- No level select screen.
- No full scoring system beyond placing collectable cans.
- No new save data.
- No custom tutorial art requirement for the first pass.
- No procedural or infinite terrain generation.

## Level Flow

### 1. Start Slide

The boat starts at the top of a gentle slope. The player can observe that the boat
moves forward through gravity and water flow before any advanced input is required.

Prompt:

```text
顺着坡道前进。
```

Success condition: the boat reaches the first prompt trigger near the opening hook
point.

### 2. First Anchor Throw

Place `HookPointA` close to the route and make it easy to hit. The terrain ahead has
a small gap or awkward dip, but not an immediate fail state. The lesson is the input
sequence: hold to aim, release to throw.

Prompts:

```text
按住鼠标左键瞄准。
松开发射锚。
```

Success condition: the anchor hooks `HookPointA`, or the player passes the section
after attempting the throw. The tutorial should not hard-lock if the player misses.

### 3. First Swing

After `HookPointA`, provide enough empty space for a clean swing arc. The intended
path crosses a short water gap or low terrain break.

Prompt:

```text
勾住后让船甩起来。
```

Success condition: the boat moves through the swing exit trigger or crosses the gap.

### 4. Recall and Momentum

At the swing exit, teach that recalling the anchor releases the rope constraint and
preserves momentum. The landing area must be wide and forgiving so the player can
focus on timing.

Prompt:

```text
再次点击收回锚，借惯性飞出去。
```

Success condition: the anchor is recalled or the boat enters the landing trigger.

### 5. Airborne A/D Rotation

The boat leaves the swing into a short flight path. The landing surface is readable
and wide. Poor angle can still communicate risk through the existing crew-loss rules,
but this first lesson should not be tuned to punish small mistakes.

Prompt:

```text
空中按 A / D 调整船体倾角。
```

Success condition: the boat lands and continues into the next section.

### 6. Collectible and Obstacle

Place one `CanCollectible` on a clean optional arc and one `Obstacle` on a clearly
worse line. This teaches reward and penalty without requiring a scoring UI to be
complete.

Prompt:

```text
收集罐子，避开障碍。
```

Success condition: the boat passes the obstacle section, regardless of whether the
can is collected.

### 7. Wave Pressure

Introduce `WaveChaser` only after the basic anchor loop has been taught. Set its
starting position and speed so it creates visible pressure but does not catch the
player immediately after one mistake.

Prompt:

```text
巨浪会追上来，继续向终点前进。
```

Success condition: the boat stays ahead long enough to reach the final hook section.

### 8. Final Combined Check

Place `HookPointB` and a final terrain gap before the finish. The player must combine
aiming, hook, swing, recall, airborne rotation, and landing. The finish area is placed
after a successful landing route.

Prompt:

```text
到达终点。
```

Success condition: a boat body enters `FinishArea` and emits the level completion
signal.

## Pacing

- 0-20%: safe sliding and movement readability.
- 20-45%: anchor aim, throw, and first swing.
- 45-65%: recall timing and A/D landing control.
- 65-80%: collectible reward and obstacle penalty.
- 80-100%: wave pressure and final combined check.

## Scene Structure

The tutorial level should follow the existing level scene pattern:

- Root `Node2D` with a level script.
- `%StartMarker` for `Game.tscn` to position the boat.
- `%FinishArea` with the existing completion signal pattern.
- Authored terrain pieces and water surfaces.
- Authored `HookPoint` instances named by lesson, such as `HookPointThrowIntro` and
  `HookPointFinal`.
- Prompt trigger `Area2D` nodes grouped under a `TutorialTriggers` parent.

Each prompt trigger should carry text and optional one-shot behavior. The level script
can show or hide `TutorialPrompt` when the boat enters trigger areas.

## Prompt Rules

- Prompts are short action cues, not explanations.
- A new prompt replaces the previous prompt.
- Prompts hide after a short delay, after the player reaches the next trigger, or
  after the related action is observed.
- Missing a hook or skipping a collectible must not trap the player.

## Failure and Recovery

- If the player misses the first hook, the terrain should funnel them into a recovery
  slope or water lane that returns them to the lesson path.
- If the player recalls too early, the landing area should still allow recovery.
- If the player hits an obstacle or lands poorly, crew loss can happen, but the first
  tutorial pass should avoid immediate game over.
- If the wave catches up during tuning, reduce `WaveChaser.chase_speed`, increase its
  starting distance, or delay assigning its target until the wave lesson starts.

## Testing

Before implementation, follow `docs/testing/new-feature-testing.md`.

Focused checks:

- The level scene loads without parse errors.
- `Game.tscn` can place the boat at `%StartMarker`.
- Every tutorial trigger displays the expected prompt.
- Prompts advance in the intended order.
- `HookPointA` and `HookPointB` can be hit with normal mouse aim.
- Recalling the anchor preserves enough momentum to reach each landing.
- A/D rotation is usable during the intended airborne section.
- The collectible can be collected and the obstacle can be avoided.
- `WaveChaser` starts late enough that it does not punish the first lessons.
- Entering `%FinishArea` emits `level_completed`.

Suggested manual smoke test:

1. Start from `Game.tscn`.
2. Play through without collecting the can.
3. Play through while collecting the can.
4. Intentionally miss the first hook and confirm recovery is possible.
5. Intentionally recall early and confirm recovery is possible.

## Implementation Decisions

- `TutorialLevel.tscn` owns its own local `TutorialPrompt` instance. The prompt is
  part of this level's lesson flow, so the first implementation does not require a
  global tutorial UI manager.
- `Game.tscn` should pass the active player or boat node to the level through an
  optional setup method when the level exposes one. `TutorialLevel` uses that
  reference for trigger filtering and for assigning `WaveChaser.target`.
