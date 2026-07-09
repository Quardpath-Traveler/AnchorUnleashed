# CGJ2026 — Claude Code Project Notes

- **Engine:** Godot 4.7, Jolt Physics, Forward Plus renderer
- **Team:** 2 technical + 2 art members
- **Main branch:** `main`
- **Feature branch prefixes:** `art/`, `code/`, `design/`, `audio/`

## Game Design Document

- **GDD title:** `2026CGJ`
- **Feishu Wiki URL:** https://dcn3pzkld10i.feishu.cn/wiki/WrNrwgy1wiDO3Tk753QcpDJ8nUg
- **Wiki node token:** `WrNrwgy1wiDO3Tk753QcpDJ8nUg`
- **Resolved docx token:** `C54QdoaCko2b6wxtNDpcp385nQb`

Agents should read this GDD whenever implementing or reviewing gameplay, UI, scene ownership, or task-priority decisions. Refresh the latest content with:

```bash
lark-cli docs +fetch --doc C54QdoaCko2b6wxtNDpcp385nQb --format json
```

## Godot workflow

Use Godot MCP for Godot-related operations, including launching the editor, running the project or a specific scene, inspecting debug output, and editing scenes. Do not use the local `godot` command line to launch the editor unless MCP is unavailable and the user explicitly approves the fallback.

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
