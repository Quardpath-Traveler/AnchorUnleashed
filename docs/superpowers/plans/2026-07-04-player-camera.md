# Player Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a reusable 2D camera scene and attach it to the player in `scenes/game/Game.tscn` so the camera follows the boat automatically.

**Architecture:** A standalone `Camera2D` scene will be created under `scenes/camera/GameCamera.tscn`. It will be instanced as a child of the `玩家` (Boat) node inside `scenes/game/Game.tscn`, leveraging Godot's scene tree hierarchy to follow the player without a separate script.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` text scene format.

## Global Constraints
- Worktree must be created from `main` branch using `using-git-worktrees`.
- Branch name prefix: `code/`.
- Save and close Godot before committing.
- Stage `.gd.uid` files with `.gd` scripts; stage `.import` files with source assets.
- Never stage `.godot/` or `/android/`.
- Smoke-test the project in Godot before marking work ready.
- Push only to a feature branch; never push directly to `main`.

---

### Task 1: Create reusable GameCamera scene

**Files:**
- Create: `scenes/camera/GameCamera.tscn`

**Interfaces:**
- Consumes: none
- Produces: `GameCamera` scene with a root `Camera2D` node.

- [ ] **Step 1: Write the scene file**

```tscn
[gd_scene format=3 uid="uid://b1vag8n54dels"]

[node name="GameCamera" type="Camera2D"]
```

- [ ] **Step 2: Verify the file path and content**

The file must be located at `scenes/camera/GameCamera.tscn` and contain exactly one root `Camera2D` node named `GameCamera`.

- [ ] **Step 3: Commit**

```bash
git add scenes/camera/GameCamera.tscn
git commit -m "feat(camera): add reusable GameCamera scene"
```

---

### Task 2: Instance GameCamera under the player in Game.tscn

**Files:**
- Modify: `scenes/game/Game.tscn`

**Interfaces:**
- Consumes: `scenes/camera/GameCamera.tscn` (PackedScene)
- Produces: `Game.tscn` with `GameCamera` instantiated as a child of `玩家`.

- [ ] **Step 1: Open `scenes/game/Game.tscn` and add the ext_resource**

Add the new external resource reference after the existing `4_pause` ext_resource:

```tscn
[ext_resource type="PackedScene" path="res://scenes/camera/GameCamera.tscn" id="5_camera"]
```

- [ ] **Step 2: Add GameCamera as child of the 玩家 node**

Add a camera instance under the `玩家` node:

```tscn
[node name="玩家" parent="." instance=ExtResource("3_boat")]
position = Vector2(120, 130)

[node name="GameCamera" parent="玩家" instance=ExtResource("5_camera")]
```

- [ ] **Step 3: Save the file and inspect diff**

Expected diff:
- One new `[ext_resource]` line.
- One new `[node name="GameCamera" ...]` line under `玩家`.

- [ ] **Step 4: Smoke-test in Godot**

1. Open the project in Godot.
2. Open `scenes/game/Game.tscn`.
3. Run the scene (F6).
4. Move the boat and confirm the camera follows it.

- [ ] **Step 5: Commit**

```bash
git add scenes/game/Game.tscn
git commit -m "feat(game): attach GameCamera to player"
```

---

### Task 3: Final verification and worktree handoff

**Files:**
- None

**Interfaces:**
- Consumes: previous tasks
- Produces: a clean feature branch ready for push/PR.

- [ ] **Step 1: Verify git status**

```bash
git status
```

Expected: no unstaged changes, no untracked `.godot/` files.

- [ ] **Step 2: Verify log**

```bash
git log --oneline -5
```

Expected: commits for GameCamera scene and Game.tscn modification on branch `code/player-camera`.

- [ ] **Step 3: Report completion**

Report the worktree path and branch name, and note that the project has been smoke-tested.
