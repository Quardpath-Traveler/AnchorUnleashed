# Anchor Swing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the core anchor throw, hook, swing, and recall loop for the prototype boat.

**Architecture:** `Anchor` remains a child scene under the boat socket and handles anchor-specific state. `Boat` drives input and rigid-body effects, using the hooked anchor point to enforce a simple rope constraint in `_integrate_forces`.

**Tech Stack:** Godot 4.7, GDScript, existing Python scaffold tests, Godot headless verification.

---

### Task 1: Anchor State and Flight

**Files:**
- Modify: `tests/scaffold/test_project_structure.py`
- Modify: `scripts/mechanics/anchor.gd`

- [ ] Add failing scaffold assertions for anchor state enum, launch speed, max length recall, rope/head updates, and hook signals.
- [ ] Run `python -m unittest tests/scaffold/test_project_structure.py` and confirm the new assertions fail.
- [ ] Implement `Anchor.State`, exported `launch_speed`, throw origin/velocity tracking, `_physics_process`, visual syncing, `is_active`, `is_hooked`, `get_rope_length`, and recall behavior.
- [ ] Run the scaffold tests and confirm they pass.

### Task 2: Boat Input and Rope Constraint

**Files:**
- Modify: `tests/scaffold/test_project_structure.py`
- Modify: `scripts/player/boat.gd`

- [ ] Add failing scaffold assertions for anchor input handling, time scale aim slowdown, `_integrate_forces`, hooked rope constraint, and airborne-only rotation.
- [ ] Run `python -m unittest tests/scaffold/test_project_structure.py` and confirm the new assertions fail.
- [ ] Implement boat anchor wiring, input handling, aim time scale transitions, active contact counting, and rope constraint velocity projection.
- [ ] Run the scaffold tests and confirm they pass.

### Task 3: Scene Verification

**Files:**
- Verify: `scenes/player/Boat.tscn`
- Verify: `scenes/mechanics/Anchor.tscn`
- Verify: `scenes/levels/LevelPrototypeSlope.tscn`

- [ ] Run Godot headless with the project path to catch syntax and scene-load errors.
- [ ] If headless loading reports script errors, fix them and re-run.
