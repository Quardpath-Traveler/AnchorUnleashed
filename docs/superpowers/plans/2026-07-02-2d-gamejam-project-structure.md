# 2D Game Jam Project Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable Godot 4.7 2D game jam scaffold with scenes, scripts, autoloads, input actions, and static verification.

**Architecture:** `Main.tscn` is the configured entry point and instantiates `Game.tscn`. `Game.tscn` owns the initial gameplay composition: a placeholder world, movable `Player`, visible `HUD`, and hidden `PauseMenu`. Small autoloads handle global state, cross-scene signals, and scene switching without adding final-game systems.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` scenes, Python `unittest` for static scaffold checks.

---

## File Structure

- Create `scenes/main/Main.tscn`: project entry scene.
- Create `scenes/game/Game.tscn`: playable scene composition.
- Create `scenes/player/Player.tscn`: `CharacterBody2D` player prototype.
- Create `scenes/ui/HUD.tscn`: visible score/status UI.
- Create `scenes/ui/PauseMenu.tscn`: pause overlay that starts hidden.
- Create `scripts/main/main.gd`: instantiates `Game.tscn` under `Main`.
- Create `scripts/game/game.gd`: handles pause input and keeps pause menu in sync.
- Create `scripts/player/player.gd`: reads movement input and moves the player.
- Create `scripts/ui/hud.gd`: updates HUD labels from `GameState`.
- Create `scripts/ui/pause_menu.gd`: emits resume requests and shows pause state.
- Create `scripts/autoload/GameState.gd`: score and paused-state source of truth.
- Create `scripts/autoload/EventBus.gd`: cross-scene signal hub.
- Create `scripts/autoload/SceneLoader.gd`: simple scene-changing wrapper.
- Create asset placeholder directories: `assets/art`, `assets/audio`, `assets/fonts`, `assets/materials`.
- Create support directories: `debug`, `tests/scaffold`.
- Modify `project.godot`: set main scene, autoloads, and input actions.
- Create `tests/scaffold/test_project_structure.py`: static tests for file references, autoloads, inputs, and scene contents.

---

### Task 1: Add Static Scaffold Tests

**Files:**
- Create: `tests/scaffold/test_project_structure.py`

- [ ] **Step 1: Write the failing test**

Create `tests/scaffold/test_project_structure.py`:

```python
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ProjectStructureTest(unittest.TestCase):
    def read(self, relative_path: str) -> str:
        return (ROOT / relative_path).read_text(encoding="utf-8")

    def test_project_has_main_scene_autoloads_and_input_actions(self):
        project = self.read("project.godot")

        self.assertIn('run/main_scene="res://scenes/main/Main.tscn"', project)
        self.assertIn('GameState="*res://scripts/autoload/GameState.gd"', project)
        self.assertIn('EventBus="*res://scripts/autoload/EventBus.gd"', project)
        self.assertIn('SceneLoader="*res://scripts/autoload/SceneLoader.gd"', project)

        for action in [
            "move_left",
            "move_right",
            "move_up",
            "move_down",
            "pause",
            "confirm",
            "cancel",
        ]:
            self.assertIn(f'{action}={{', project)

    def test_required_directories_exist(self):
        for relative_path in [
            "assets/art",
            "assets/audio",
            "assets/fonts",
            "assets/materials",
            "debug",
            "scenes/main",
            "scenes/game",
            "scenes/player",
            "scenes/ui",
            "scripts/autoload",
            "scripts/components",
            "scripts/resources",
            "scripts/main",
            "scripts/game",
            "scripts/player",
            "scripts/ui",
        ]:
            self.assertTrue((ROOT / relative_path).is_dir(), relative_path)

    def test_required_scenes_and_scripts_exist(self):
        for relative_path in [
            "scenes/main/Main.tscn",
            "scenes/game/Game.tscn",
            "scenes/player/Player.tscn",
            "scenes/ui/HUD.tscn",
            "scenes/ui/PauseMenu.tscn",
            "scripts/main/main.gd",
            "scripts/game/game.gd",
            "scripts/player/player.gd",
            "scripts/ui/hud.gd",
            "scripts/ui/pause_menu.gd",
            "scripts/autoload/GameState.gd",
            "scripts/autoload/EventBus.gd",
            "scripts/autoload/SceneLoader.gd",
        ]:
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)

    def test_scene_script_references_are_present(self):
        expected_references = {
            "scenes/main/Main.tscn": "res://scripts/main/main.gd",
            "scenes/game/Game.tscn": "res://scripts/game/game.gd",
            "scenes/player/Player.tscn": "res://scripts/player/player.gd",
            "scenes/ui/HUD.tscn": "res://scripts/ui/hud.gd",
            "scenes/ui/PauseMenu.tscn": "res://scripts/ui/pause_menu.gd",
        }

        for scene_path, script_path in expected_references.items():
            self.assertIn(script_path, self.read(scene_path))

    def test_game_scene_contains_player_hud_and_pause_menu(self):
        scene = self.read("scenes/game/Game.tscn")

        self.assertIn("res://scenes/player/Player.tscn", scene)
        self.assertIn("res://scenes/ui/HUD.tscn", scene)
        self.assertIn("res://scenes/ui/PauseMenu.tscn", scene)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests.scaffold.test_project_structure -v
```

Expected: FAIL or ERROR because the scaffold scenes, scripts, autoloads, and input mappings do not exist yet.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/scaffold/test_project_structure.py
git commit -m "test: add 2D scaffold checks"
```

---

### Task 2: Add Directories, Project Settings, And Autoloads

**Files:**
- Modify: `project.godot`
- Create: `scripts/autoload/GameState.gd`
- Create: `scripts/autoload/EventBus.gd`
- Create: `scripts/autoload/SceneLoader.gd`
- Create: `.gitkeep` files under empty scaffold directories

- [ ] **Step 1: Create scaffold directories**

Create directories:

```bash
mkdir -p assets/art assets/audio assets/fonts assets/materials debug scenes/main scenes/game scenes/player scenes/ui scripts/autoload scripts/components scripts/resources scripts/main scripts/game scripts/player scripts/ui
touch assets/art/.gitkeep assets/audio/.gitkeep assets/fonts/.gitkeep assets/materials/.gitkeep debug/.gitkeep scripts/components/.gitkeep scripts/resources/.gitkeep
```

- [ ] **Step 2: Update `project.godot`**

Add these sections and keys while preserving existing settings:

```ini
[application]

config/name="CGJ2026"
run/main_scene="res://scenes/main/Main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[autoload]

GameState="*res://scripts/autoload/GameState.gd"
EventBus="*res://scripts/autoload/EventBus.gd"
SceneLoader="*res://scripts/autoload/SceneLoader.gd"

[input]

move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194319,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194321,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194322,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
pause={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
confirm={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194309,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
cancel={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 3: Create `GameState.gd`**

```gdscript
extends Node

signal score_changed(score: int)
signal pause_changed(is_paused: bool)

var score: int = 0
var is_paused: bool = false


func reset() -> void:
	score = 0
	set_paused(false)
	score_changed.emit(score)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func set_paused(value: bool) -> void:
	if is_paused == value:
		return

	is_paused = value
	get_tree().paused = is_paused
	pause_changed.emit(is_paused)
```

- [ ] **Step 4: Create `EventBus.gd`**

```gdscript
extends Node

signal player_spawned(player: Node)
signal player_died
signal scene_transition_requested(scene_path: String)
```

- [ ] **Step 5: Create `SceneLoader.gd`**

```gdscript
extends Node


func change_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s: %s" % [scene_path, error])
```

- [ ] **Step 6: Run static tests**

Run:

```bash
python3 -m unittest tests.scaffold.test_project_structure -v
```

Expected: still FAIL because scenes and non-autoload scripts do not exist yet.

- [ ] **Step 7: Commit project settings and autoloads**

```bash
git add project.godot assets debug scripts
git commit -m "feat: add 2D project settings and autoloads"
```

---

### Task 3: Add Main, Game, Player, HUD, And Pause Scenes

**Files:**
- Create: `scripts/main/main.gd`
- Create: `scripts/game/game.gd`
- Create: `scripts/player/player.gd`
- Create: `scripts/ui/hud.gd`
- Create: `scripts/ui/pause_menu.gd`
- Create: `scenes/main/Main.tscn`
- Create: `scenes/game/Game.tscn`
- Create: `scenes/player/Player.tscn`
- Create: `scenes/ui/HUD.tscn`
- Create: `scenes/ui/PauseMenu.tscn`

- [ ] **Step 1: Create `scripts/main/main.gd`**

```gdscript
extends Node

const GAME_SCENE := preload("res://scenes/game/Game.tscn")


func _ready() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
```

- [ ] **Step 2: Create `scripts/game/game.gd`**

```gdscript
extends Node2D

@onready var pause_menu: CanvasLayer = $PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	GameState.pause_changed.connect(_on_pause_changed)
	pause_menu.resume_requested.connect(_on_resume_requested)
	_on_pause_changed(GameState.is_paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.set_paused(not GameState.is_paused)
		get_viewport().set_input_as_handled()


func _on_pause_changed(is_paused: bool) -> void:
	pause_menu.visible = is_paused


func _on_resume_requested() -> void:
	GameState.set_paused(false)
```

- [ ] **Step 3: Create `scripts/player/player.gd`**

```gdscript
extends CharacterBody2D

@export var speed: float = 220.0


func _ready() -> void:
	EventBus.player_spawned.emit(self)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
```

- [ ] **Step 4: Create `scripts/ui/hud.gd`**

```gdscript
extends CanvasLayer

@onready var score_label: Label = %ScoreLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.pause_changed.connect(_on_pause_changed)
	_on_score_changed(GameState.score)
	_on_pause_changed(GameState.is_paused)


func _on_score_changed(score: int) -> void:
	score_label.text = "Score: %s" % score


func _on_pause_changed(is_paused: bool) -> void:
	status_label.text = "Paused" if is_paused else "Running"
```

- [ ] **Step 5: Create `scripts/ui/pause_menu.gd`**

```gdscript
extends CanvasLayer

signal resume_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%ResumeButton.pressed.connect(_on_resume_button_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _on_resume_button_pressed() -> void:
	resume_requested.emit()
```

- [ ] **Step 6: Create `scenes/main/Main.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main/main.gd" id="1_main"]

[node name="Main" type="Node"]
script = ExtResource("1_main")
```

- [ ] **Step 7: Create `scenes/game/Game.tscn`**

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/game/game.gd" id="1_game"]
[ext_resource type="PackedScene" path="res://scenes/player/Player.tscn" id="2_player"]
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="3_hud"]
[ext_resource type="PackedScene" path="res://scenes/ui/PauseMenu.tscn" id="4_pause"]

[node name="Game" type="Node2D"]
script = ExtResource("1_game")

[node name="World" type="Node2D" parent="."]

[node name="Player" parent="." instance=ExtResource("2_player")]
position = Vector2(320, 180)

[node name="HUD" parent="." instance=ExtResource("3_hud")]

[node name="PauseMenu" parent="." instance=ExtResource("4_pause")]
```

- [ ] **Step 8: Create `scenes/player/Player.tscn`**

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/player/player.gd" id="1_player"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(32, 32)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_player")

[node name="Body" type="ColorRect" parent="."]
offset_left = -16.0
offset_top = -16.0
offset_right = 16.0
offset_bottom = 16.0
color = Color(0.1, 0.55, 0.9, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_player")
```

- [ ] **Step 9: Create `scenes/ui/HUD.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1_hud"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1_hud")

[node name="MarginContainer" type="MarginContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 16.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = -16.0

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]
offset_right = 160.0
offset_bottom = 48.0

[node name="ScoreLabel" type="Label" parent="MarginContainer/VBoxContainer"]
unique_name_in_owner = true
text = "Score: 0"

[node name="StatusLabel" type="Label" parent="MarginContainer/VBoxContainer"]
unique_name_in_owner = true
text = "Running"
```

- [ ] **Step 10: Create `scenes/ui/PauseMenu.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/pause_menu.gd" id="1_pause"]

[node name="PauseMenu" type="CanvasLayer"]
visible = false
script = ExtResource("1_pause")

[node name="Dim" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.55)

[node name="CenterContainer" type="CenterContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="PanelContainer" type="PanelContainer" parent="CenterContainer"]
offset_left = 272.0
offset_top = 144.0
offset_right = 368.0
offset_bottom = 216.0

[node name="VBoxContainer" type="VBoxContainer" parent="CenterContainer/PanelContainer"]
offset_left = 8.0
offset_top = 8.0
offset_right = 88.0
offset_bottom = 64.0

[node name="TitleLabel" type="Label" parent="CenterContainer/PanelContainer/VBoxContainer"]
text = "Paused"
horizontal_alignment = 1

[node name="ResumeButton" type="Button" parent="CenterContainer/PanelContainer/VBoxContainer"]
unique_name_in_owner = true
text = "Resume"
```

- [ ] **Step 11: Run static tests**

Run:

```bash
python3 -m unittest tests.scaffold.test_project_structure -v
```

Expected: PASS.

- [ ] **Step 12: Commit scenes and gameplay skeleton**

```bash
git add scenes scripts tests/scaffold/test_project_structure.py
git commit -m "feat: add runnable 2D scene scaffold"
```

---

### Task 4: Verify Godot Parse And Final State

**Files:**
- No planned source edits unless verification finds broken references.

- [ ] **Step 1: Run static tests**

Run:

```bash
python3 -m unittest tests.scaffold.test_project_structure -v
```

Expected: all tests PASS.

- [ ] **Step 2: Check for a Godot CLI**

Run:

```bash
command -v godot || command -v godot4 || command -v Godot
```

Expected: prints a Godot executable path, or exits non-zero if Godot is not installed on `PATH`.

- [ ] **Step 3: Run Godot headless validation when available**

If Step 2 prints a path, run one of these commands with the detected executable:

```bash
godot --headless --path . --quit
```

or:

```bash
godot4 --headless --path . --quit
```

Expected: exit code 0 with no script parse errors.

- [ ] **Step 4: Inspect Git state**

Run:

```bash
git status --short
```

Expected: clean working tree after commits, or only intentional uncommitted files if the user requested no commits.
