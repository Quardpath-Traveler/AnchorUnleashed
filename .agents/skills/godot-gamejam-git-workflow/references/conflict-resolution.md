# Godot Conflict Resolution Recipes

Use this file when a `git pull --rebase` or `git merge` produces conflicts in Godot files.

## Golden Rules

1. **Never blindly accept `ours` or `theirs` for `.tscn`, `.tres`, or `.import`.**
2. **Always back up the conflicting file before editing.**
3. **Always open the resolved scene in Godot and run the project.** Text-level resolution is not enough.

## `.tscn` Conflict Recipe

A `.tscn` file contains:

- `[gd_scene ...]` header with load steps and UIDs
- `[ext_resource ...]` lines (external resources like scripts, textures, audio)
- `[sub_resource ...]` lines (built-in shapes, materials, animations)
- `[node ...]` lines with parent/owner relationships

### Step-by-step

1. **Stop and back up.**
   ```bash
   cp player.tscn player.tscn.backup
   ```

2. **Look at the conflict markers.** Identify which side added/removed:
   - New nodes
   - New `ext_resource` entries
   - New `sub_resource` entries
   - Changed node properties (`position`, `texture`, `script`, etc.)

3. **Preserve both sides' additions when possible.** If one side added a `HitBox` and the other added a `HurtBox`, keep **both** with distinct names. Do not discard a teammate's work just because it is not in your version.

4. **Merge manually.** Keep both additions when possible. Example:
   ```diff
   <<<<<<< HEAD
   [node name="HurtBox" type="Area2D" parent="."]
   =======
   [node name="HitBox" type="Area2D" parent="."]
   >>>>>>> origin/main
   ```
   If both nodes should exist, keep **both** with distinct names:
   ```ini
   [node name="HurtBox" type="Area2D" parent="."]
   [node name="HitBox" type="Area2D" parent="."]
   ```

5. **Check resource references.** Every `ExtResource("id_xxx")` and `SubResource("id_xxx")` must point to a line that still exists. If you removed a resource, remove all references to it.

6. **Remove conflict markers and save.**

7. **Open in Godot.** Load the scene. Read the Output panel. Fix red errors.

8. **Run the project.** Make sure the affected gameplay still works.

9. **Stage and commit:**
   ```bash
   git add player.tscn
   git rebase --continue
   ```

## `.import` Conflict Recipe

`.import` files store Godot's import settings for a source asset.

1. Back up: `cp asset.png.import asset.png.import.backup`
2. Look at the conflict. Usually one side changed compression/filter/mipmaps.
3. Decide which settings are correct. If unsure, ask the artist who owns the asset.
4. In Godot, select the source asset in the FileSystem dock.
5. Open the **Import** tab and apply the desired settings.
6. Click **Reimport**.
7. Stage the updated `.import` file.

## Binary Asset Conflict Recipe

Binary files (`.png`, `.ogg`, `.fbx`, etc.) cannot be merged textually.

1. Identify the asset owner (art/audio lead).
2. Ask which version is authoritative.
3. Replace the file with the authoritative version.
4. If both versions have unique value, rename one and add both.
5. **Never commit a file containing `<<<<<<<` markers.**

## `project.godot` Conflict Recipe

1. Back up: `cp project.godot project.godot.backup`
2. Keep intentional renderer/physics/input/autoload changes.
3. Never keep both values for the same setting.
4. If renderer or physics backend changed, discuss with the team before resolving.
5. Open the project in Godot to confirm it loads.
6. Stage and continue the rebase.

## When You Are Stuck

- If the scene is corrupted beyond quick repair, restore from backup and redo the merge more carefully.
- If two people edited the same node structure extensively, consider coordinating one person to redo the combined work manually.
- If UIDs are broken, Godot will print errors. Use Find in Files to locate stale UID references.
