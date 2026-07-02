# CGJ2026 — Claude Code Project Notes

- **Engine:** Godot 4.7, Jolt Physics, Forward Plus renderer
- **Team:** 2 technical + 2 art members
- **Main branch:** `main`
- **Feature branch prefixes:** `art/`, `code/`, `design/`, `audio/`

## Git workflow

For every commit, push, pull, or conflict in this project, invoke the `godot-gamejam-git-workflow` skill.

Project-specific rules:

- **All `main` pushes go through a Pull Request.** Never push directly to `main`.
- **Art owns:** `.png`, `.svg`, `.fbx`, `.ogg`, `.mp3`, `.wav`, `.gltf`, and their `.import` settings.
- **Code owns:** `.gd`, `.cs`, `.tscn` node structure, and `project.godot`.
- **Smoke-test the project in Godot** before marking a PR ready.
- **No Git LFS currently configured.** Keep individual files under 100 MB.
- **Team chat:** use your normal group channel; mention when a push changes scenes, physics, renderer, or input settings.

## Useful reminders

- Save and close Godot before committing.
- Stage `.import` files together with their source assets.
- Stage `.gd.uid` files together with their `.gd` scripts.
- Never stage `.godot/` or `/android/`.
- Pull with rebase before pushing: `git pull --rebase origin main`.
