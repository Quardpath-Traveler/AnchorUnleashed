---
name: godot-gamejam-git-workflow
description: Use when committing, pushing, pulling, or resolving merge conflicts in a Godot 4 gamejam project, especially with mixed technical and art contributors. Use whenever a teammate asks to commit, push, sync, or fix a git conflict.
---

# Godot GameJam Git Workflow

## Overview

Gamejam teams ship fast, but a single bad commit can break every scene for the whole team. This skill enforces a safe, small-step git workflow for Godot 4 projects with both technical and artistic contributors.

**Core principle:** pull first, review what you stage, include Godot's metadata files, verify the project still opens, and never force-push shared history.

## When to Use

- A teammate asks to commit, push, pull, sync, or "save my work".
- A commit touches `.tscn`, `.tres`, `.gd`, `.cs`, `.import`, binary assets, or `project.godot`.
- You need to resolve a merge conflict in a Godot file.
- You are onboarding an art member to git.

**Do not use for:** generic git questions with no Godot/binary-asset angle, repository creation, CI setup, or code-only refactors that touch no `.tscn`/`.import`/binary files.

## Pre-commit Checklist

Run these steps in order before every commit:

1. **Save and close Godot** — or at least save every open scene (`Ctrl/Cmd+S`). Godot holds locks and rewrites `.import` files while scenes are open.
2. **Pull first** — `git fetch origin` then `git pull --rebase origin main`. Never commit on top of stale history.
3. **Inspect status** — `git status`. Reject any `.godot/`, `*.tmp`, editor backup, or untracked artifact (e.g., a bare repo, a downloaded zip, a build folder).
4. **Pair source assets with their `.import` files** — every `.png`, `.jpg`, `.svg`, `.ogg`, `.mp3`, `.wav`, `.fbx`, `.gltf` must be staged together with its matching `.import` file.
5. **Pair scripts with their `.uid` files** — every `.gd` must be staged with its matching `.gd.uid`.
6. **Review `.tscn`/`.tres` diffs** — look for huge unexplained line deltas, duplicate node names, or absolute paths.
7. **Smoke-test the project** — open it in Godot and load any affected scene. Fix errors before committing.
8. **Confirm `project.godot` changes** — if renderer, physics, input map, or autoload settings changed, make sure it was intentional and team-approved.

## Commit Message Format

Use lightweight conventional commits so the team can scan history quickly:

```
<type>(<scope>): <imperative summary, max 50 chars>

<body: what changed and why, optional>
```

**Types:**

- `feat` — new mechanic, scene, or gameplay system
- `fix` — bug fix
- `asset` — art, audio, or import-setting change
- `refactor` — code restructuring with no behavior change
- `docs` — documentation or comments
- `chore` — tooling, project settings, or cleanup

**Examples:**

- `feat(player): add dash state machine`
- `asset(enemy): import updated walk cycle sprites`
- `fix(physics): set Jolt collision layer for pickups`
- `chore(project): configure window stretch mode`

**Bad:** `update`, `fix`, `asdf`, `stuff`. If the summary is vague, the commit is too big — split it.

## Staging Rules

- **Never run `git add -A` or `git add .`** in a Godot project. Stage files explicitly.
- **Always stage `.import` with its source asset.** Godot stores import settings (filter, mipmaps, compression) there. Missing `.import` files reset those settings for teammates.
- **Always stage `.gd.uid` with its `.gd` script.** UIDs are how Godot references scripts in scenes.
- **Never stage `.godot/` or `/android/`.** These are in `.gitignore` for a reason.
- **Review binary assets.** If a file is over ~100 MB, stop and discuss Git LFS or a source-control-friendly format.
- **Keep asset and logic commits separate** when possible. This makes rollback safer.

Use `git add -p` only when you are 100% sure every hunk belongs in the same commit. Mixed changes are a sign the commit should be split.

## Push Workflow

1. `git fetch origin`
2. `git pull --rebase origin main`
3. If the rebase touched Godot files, re-run the pre-commit checklist and smoke-test.
4. `git push origin <branch>` — push your feature branch, **not** directly to `main`. This applies even if you are resolving a conflict; finish the rebase on your feature branch and open a PR.
5. Open a Pull/Merge Request and notify the team channel with a one-line summary of affected scenes/systems/assets.
6. Wait for a teammate to review before merging to `main`.

**Never force-push to a shared branch** (`main`, `develop`, or anyone else's branch). Force-push is only acceptable on a personal feature branch that no one else has checked out, and only after warning the team.

## Conflict Resolution

Godot files are text, but they are not human-friendly. Never blindly accept `ours` or `theirs` for `.tscn`, `.tres`, or `.import` files.

**Brief process:**

1. Back up the conflicting file: `cp file.tscn file.tscn.backup`.
2. Open the file in a text editor and resolve conflict markers manually, or use a merge tool.
3. **Preserve both sides' additions when possible.** If one side added a `HitBox` and the other added a `HurtBox`, keep both with distinct names. Do not discard a teammate's nodes just because they are not in your version.
4. Ensure no duplicate node names and no broken UID references.
5. Open the scene in Godot and run the project. Fix any errors in the Output panel.
6. Save and stage the resolved file.
7. For `.import` conflicts, open the Import dock, reconcile settings, reimport, then stage the updated `.import`.
8. For binary asset conflicts, ask the asset owner which version is authoritative. Do not commit conflict markers.

For the full step-by-step recipe, read `references/conflict-resolution.md`.

## Team Communication Rules

- **Announce before touching a scene or asset someone else is working on.**
- **Coordinate before editing `project.godot`.** Renderer, physics, input, and autoload changes affect everyone.
- **Notify before large asset imports** (>10 MB or many files).
- **Use branch prefixes:** `art/`, `code/`, `design/`, `audio/`, e.g., `art/player-sprite-alex`.
- **Keep commits small and single-purpose.** If a commit "does a bunch of stuff," split it.
- **Flag temporary breakage in the commit body** (`BREAKS: player animation is placeholder`), but never push a knowingly broken `main`.

## Red Flags — STOP and Start Over

- You are about to run `git add -A` or `git add .`.
- `git status` shows `.godot/`, `remote.git/`, build artifacts, or other untracked junk.
- A `.tscn` diff has hundreds of unexplained lines.
- The commit message is `fix`, `update`, `stuff`, or `asdf`.
- You are about to run `git push -f` on a shared branch.
- You are about to push directly to `main` from your local machine.
- You resolved a `.tscn` conflict without opening Godot.
- You resolved a conflict by keeping only one side when both sides added value.
- You are staging a binary asset without its `.import` file.
- You are staging a `.gd` script without its `.gd.uid` file.
- You have not pulled before pushing.

## Common Mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Forgetting `.import` files | Teammates get reimport dialogs and lose custom settings | Stage source + `.import` together |
| Staging `.godot/` | Bloated repo, merge conflicts, non-deterministic cache | Keep it gitignored |
| Blind `git add -A` | Commits build artifacts, remote repos, personal files | Stage files explicitly |
| Vague commit messages | History is useless during crunch rollback | Use `type(scope): summary` |
| Force-pushing `main` | Overwrites teammates' work | Push feature branches, open PRs |
| Resolving `.tscn` by picking one side | Loses nodes, breaks signals, corrupts scenes | Back up, merge manually, test in Godot |
| Pushing `project.godot` renderer/physics changes silently | Breaks everyone else's project | Discuss first, mention in commit body |
| Committing unsaved scenes | Changes never make it into the commit | Save and close Godot first |

## References

- `references/conflict-resolution.md` — step-by-step `.tscn`/`.import` conflict repair
- `references/staging-cheatsheet.md` — one-page staging table for artists
