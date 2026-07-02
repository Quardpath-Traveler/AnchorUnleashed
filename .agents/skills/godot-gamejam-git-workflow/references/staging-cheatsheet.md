# Staging Cheatsheet for Artists

## The Rule

**Every source asset you add must be staged with its `.import` file.**

Godot creates a `.import` file the first time it sees an asset. That file stores compression, filtering, mipmaps, looping, and other settings. If you commit only the image/audio/model, teammates will see the asset but with default settings — your custom settings will be lost.

## Common Asset Pairs

| Source file | Godot metadata file | Must stage together? |
|---|---|---|
| `.png` | `.png.import` | ✅ Yes |
| `.jpg` | `.jpg.import` | ✅ Yes |
| `.svg` | `.svg.import` | ✅ Yes |
| `.ogg` | `.ogg.import` | ✅ Yes |
| `.mp3` | `.mp3.import` | ✅ Yes |
| `.wav` | `.wav.import` | ✅ Yes |
| `.fbx` | `.fbx.import` | ✅ Yes |
| `.gltf` | `.gltf.import` | ✅ Yes |
| `.gd` script | `.gd.uid` | ✅ Yes |
| `.cs` script | no extra file | ✅ Just the script |

## What NOT to stage

These are generated or personal files:

- `.godot/`
- `/android/`
- `*.tmp`
- Editor backup files
- Downloaded zip files
- Build exports

## Quick Workflow

1. Save your work in Godot.
2. Close Godot (or save all scenes).
3. Run `git status`.
4. For every new asset, check that its `.import` file is also listed.
5. Stage both files:
   ```bash
   git add assets/player.png assets/player.png.import
   ```
6. Write a clear commit message:
   ```bash
   git commit -m "asset(player): import updated walk cycle sprites"
   ```
7. Pull before pushing:
   ```bash
   git pull --rebase origin main
   git push origin art/player-sprites-alex
   ```

## If You Forget the `.import`

1. Do not panic.
2. In Godot, select the asset in the FileSystem dock.
3. Set your import settings in the Import tab.
4. Click **Reimport**.
5. The `.import` file will be updated.
6. Stage and amend the commit:
   ```bash
   git add assets/player.png.import
   git commit --amend --no-edit
   ```

## Getting Help

- Ask a technical teammate before resolving any `.tscn` or `project.godot` conflict.
- Never delete someone else's scene file.
- When in doubt, back up the file first.
