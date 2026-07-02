# 2D Game Jam Project Structure Design

Date: 2026-07-02
Project: CGJ2026
Engine: Godot 4.7, 2D

## Goal

Create a lightweight Godot 2D project skeleton for a short game jam. The structure should run immediately, provide clear places for gameplay, UI, assets, and shared systems, and avoid overbuilding systems before the game concept is known.

## Scope

The scaffold will include:

- A runnable main scene.
- A game container scene.
- A simple movable 2D player prototype.
- A HUD scene.
- A pause menu scene.
- Three small autoload scripts for global state, event signals, and scene transitions.
- Basic input actions for movement, pause, confirm, and cancel.
- Directories for assets, scripts, debug helpers, and tests.

The scaffold will not include save/load, settings screens, inventory, dialogue, enemies, combat, level selection, or final art/audio pipelines.

## Architecture

### Scene Structure

- `scenes/main/Main.tscn`
  - Application entry scene.
  - Owns the high-level flow and instantiates the active game scene.

- `scenes/game/Game.tscn`
  - Main gameplay container.
  - Hosts the player, HUD, pause menu, and world placeholder.

- `scenes/player/Player.tscn`
  - `CharacterBody2D` prototype with a script-driven movement controller.
  - Uses simple placeholder visuals so the project can run without imported art.

- `scenes/ui/HUD.tscn`
  - Displays minimal jam-useful state, such as score or debug status.

- `scenes/ui/PauseMenu.tscn`
  - Starts hidden.
  - Toggles from the pause input action.

### Script Structure

- `scripts/autoload/GameState.gd`
  - Stores simple global game state such as score and paused status.
  - Emits state changes through direct signals where appropriate.

- `scripts/autoload/EventBus.gd`
  - Central signal hub for cross-scene events.
  - Keeps jam-time communication from becoming tightly coupled.

- `scripts/autoload/SceneLoader.gd`
  - Provides a single entry point for scene changes.
  - Starts simple and can be expanded later if transitions are needed.

- `scripts/player/player.gd`
  - Handles input-driven 2D movement for the player prototype.

- `scripts/ui/hud.gd`
  - Updates HUD labels from global state or events.

- `scripts/ui/pause_menu.gd`
  - Handles visibility and resume behavior.

Additional directories:

- `scripts/components/` for reusable gameplay behaviors.
- `scripts/resources/` for custom `Resource` classes.
- `assets/art/`, `assets/audio/`, `assets/fonts/`, and `assets/materials/` for imported content.
- `debug/` for temporary debug scenes or tools.
- `tests/` for future automated or manual test helpers.

## Data Flow

Input is configured in `project.godot`. The player reads movement actions directly. The game scene listens for pause input and delegates pause state to `GameState`. UI updates through `GameState` signals or `EventBus` signals rather than reaching into gameplay nodes.

Scene changes go through `SceneLoader`, even if the first version only wraps `change_scene_to_file`. This keeps later menu, restart, and level-transition work in one place.

## Error Handling

Scene-loading failures should print a clear `push_error` message instead of failing silently. Autoload scripts should keep their first version small and avoid assumptions about final game systems.

## Testing And Verification

Minimum verification:

- Godot project loads without parse errors.
- Main scene runs.
- Player moves with WASD and arrow keys.
- Pause toggles with Escape.
- HUD is visible.
- The scaffold has no missing script or scene references.

If a Godot executable is available in the environment, use it for a headless parse check. Otherwise, verify file references and project configuration manually.
