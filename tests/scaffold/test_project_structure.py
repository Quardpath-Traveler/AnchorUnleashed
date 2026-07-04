from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ProjectStructureTest(unittest.TestCase):
    def read(self, relative_path: str) -> str:
        return (ROOT / relative_path).read_text(encoding="utf-8")

    def test_project_has_main_scene_autoloads_and_input_actions(self):
        project = self.read("project.godot")

        self.assertIn('GameState="*res://scripts/autoload/GameState.gd"', project)
        self.assertIn('EventBus="*res://scripts/autoload/EventBus.gd"', project)
        self.assertIn('SceneLoader="*res://scripts/autoload/SceneLoader.gd"', project)

        # Main scene can be referenced by path or UID (Godot 4.7 supports both)
        main_scene_line = next(line for line in project.splitlines() if line.startswith('run/main_scene='))
        self.assertTrue(
            'run/main_scene="res://scenes/main/Main.tscn"' in main_scene_line or
            'run/main_scene="uid://' in main_scene_line,
            f"Unexpected main scene reference: {main_scene_line}"
        )

        for action in [
            "move_left",
            "move_right",
            "move_up",
            "move_down",
            "pause",
            "debug_reset",
            "confirm",
            "bullet_time",
            "cancel",
        ]:
            self.assertIn(f'{action}={{', project)

        debug_reset_mapping = project[project.index("debug_reset={"):project.index("confirm={")]
        self.assertIn("InputEventKey", debug_reset_mapping)
        self.assertIn('"keycode":82', debug_reset_mapping)

        confirm_mapping = project[project.index("confirm={"):project.index("bullet_time={")]
        self.assertIn("InputEventMouseButton", confirm_mapping)
        self.assertIn('"button_index":1', confirm_mapping)
        self.assertIn('"keycode":4194309', confirm_mapping)
        self.assertNotIn('"keycode":32', confirm_mapping)

        bullet_time_mapping = project[project.index("bullet_time={"):project.index("cancel={")]
        self.assertIn("InputEventKey", bullet_time_mapping)
        self.assertIn('"keycode":32', bullet_time_mapping)
        self.assertNotIn("InputEventMouseButton", bullet_time_mapping)

    def test_required_directories_exist(self):
        for relative_path in [
            "assets/art",
            "assets/audio",
            "assets/fonts",
            "assets/materials",
            "debug",
            "debug/screenshots",
            "scenes/main",
            "scenes/game",
            "scenes/items",
            "scenes/level_parts",
            "scenes/levels",
            "scenes/mechanics",
            "scenes/player",
            "scenes/ui",
            "scripts/autoload",
            "scripts/characters",
            "scripts/components",
            "scripts/resources",
            "scripts/items",
            "scripts/level_parts",
            "scripts/levels",
            "scripts/main",
            "scripts/mechanics",
            "scripts/game",
            "scripts/player",
            "scripts/ui",
        ]:
            self.assertTrue((ROOT / relative_path).is_dir(), relative_path)

    def test_required_scenes_and_scripts_exist(self):
        for relative_path in [
            "scenes/main/Main.tscn",
            "scenes/game/Game.tscn",
            "scenes/items/CanCollectible.tscn",
            "scenes/level_parts/Obstacle.tscn",
            "scenes/level_parts/WaterSurface.tscn",
            "scenes/level_parts/WaveChaser.tscn",
            "scenes/levels/LevelPrototypeSlope.tscn",
            "scenes/levels/TutorialLevel.tscn",
            "scenes/mechanics/Anchor.tscn",
            "scenes/mechanics/DeathZone.tscn",
            "scenes/mechanics/HookPoint.tscn",
            "scenes/characters/BoatCrewNPC.tscn",
            "scenes/player/Boat.tscn",
            "scenes/player/Player.tscn",
            "scenes/ui/HUD.tscn",
            "scenes/ui/PauseMenu.tscn",
            "scenes/ui/ResultScreen.tscn",
            "scenes/ui/TutorialPrompt.tscn",
            "scripts/items/can_collectible.gd",
            "scripts/level_parts/obstacle.gd",
            "scripts/level_parts/water_surface.gd",
            "scripts/level_parts/wave_chaser.gd",
            "scripts/levels/level_prototype_slope.gd",
            "scripts/levels/tutorial_level.gd",
            "scripts/levels/tutorial_trigger.gd",
            "scripts/main/main.gd",
            "scripts/mechanics/anchor.gd",
            "scripts/mechanics/death_zone.gd",
            "scripts/mechanics/hook_point.gd",
            "scripts/characters/floating_npc.gd",
            "scripts/characters/npc_rescue.gd",
            "scripts/game/game.gd",
            "scripts/player/boat.gd",
            "scripts/player/player.gd",
            "scripts/ui/hud.gd",
            "scripts/ui/pause_menu.gd",
            "scripts/ui/result_screen.gd",
            "scripts/ui/tutorial_prompt.gd",
            "scripts/autoload/GameState.gd",
            "scripts/autoload/EventBus.gd",
            "scripts/autoload/SceneLoader.gd",
            "debug/AnchorThrowRegression.tscn",
            "debug/AnchorRelativeLaunchVelocityRegression.tscn",
            "debug/AnchorBulletTimeRegression.tscn",
            "debug/TutorialLevelRegression.tscn",
            "debug/TutorialLevelPlaytest.tscn",
            "debug/DebugLevel.tscn",
            "debug/OutOfBoundsRespawnTest.tscn",
            "debug/NPCRescueRegression.tscn",
            "debug/CrewVisualRegression.tscn",
            "debug/ScoreRewardsRegression.tscn",
            "debug/anchor_throw_regression.gd",
            "debug/anchor_throw_regression.gd.uid",
            "debug/anchor_relative_launch_velocity_regression.gd",
            "debug/anchor_relative_launch_velocity_regression.gd.uid",
            "debug/anchor_bullet_time_regression.gd",
            "debug/anchor_bullet_time_regression.gd.uid",
            "debug/tutorial_level_regression.gd",
            "debug/tutorial_level_regression.gd.uid",
            "debug/tutorial_level_playtest.gd",
            "debug/tutorial_level_playtest.gd.uid",
            "debug/debug_level.gd",
            "debug/debug_level.gd.uid",
            "debug/out_of_bounds_respawn_test.gd",
            "debug/out_of_bounds_respawn_test.gd.uid",
            "debug/npc_rescue_regression.gd",
            "debug/npc_rescue_regression.gd.uid",
            "debug/crew_visual_regression.gd",
            "debug/crew_visual_regression.gd.uid",
            "debug/score_rewards_regression.gd",
        ]:
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)

    def test_game_state_has_central_reward_api(self):
        script = self.read("scripts/autoload/GameState.gd")

        for expected in [
            "const COIN_SCORE_VALUE: int = 10",
            "const RESCUE_SCORE_VALUE: int = 100",
            "const TRICK_360_SCORE_VALUE: int = 250",
            "func award_coin_pickup(amount: int = 1) -> void:",
            "if amount <= 0:",
            "add_coin(amount)",
            "add_score(amount * COIN_SCORE_VALUE)",
            "func award_rescue(amount: int = 1) -> void:",
            "add_rescued(amount)",
            "add_score(amount * RESCUE_SCORE_VALUE)",
            "func award_trick(trick_name: String, amount: int) -> void:",
            "if trick_name.is_empty():",
            "add_score(amount)",
        ]:
            self.assertIn(expected, script)

    def test_pickups_and_rescues_award_score_rewards(self):
        can_script = self.read("scripts/items/can_collectible.gd")
        rescue_script = self.read("scripts/characters/npc_rescue.gd")

        for expected in [
            "GameState.award_coin_pickup(value)",
            "queue_free()",
        ]:
            self.assertIn(expected, can_script)

        for expected in [
            "body.gain_crew(rescue_value)",
            "GameState.award_rescue(rescue_value)",
            "_rescued = true",
        ]:
            self.assertIn(expected, rescue_script)

    def test_boat_tracks_and_awards_safe_landed_360_trick(self):
        boat_script = self.read("scripts/player/boat.gd")
        water_script = self.read("scripts/level_parts/water_surface.gd")

        for expected in [
            "const TRICK_FULL_ROTATION_RADIANS: float = TAU",
            "const TRICK_360_NAME: String = \"360\"",
            "var _airborne_rotation_total: float = 0.0",
            "var _last_trick_rotation: float = 0.0",
            "var _pending_360_tricks: int = 0",
            "var _was_tracking_airborne_trick: bool = false",
            "_update_airborne_trick_tracking()",
            "func on_safe_landing(landing_angle_degrees: float, water_surface: Node2D) -> void:",
            "GameState.award_trick(TRICK_360_NAME, GameState.TRICK_360_SCORE_VALUE)",
            "func _reset_trick_tracking() -> void:",
        ]:
            self.assertIn(expected, boat_script)

        for expected in [
            "if body.has_method(\"on_safe_landing\"):",
            "body.on_safe_landing(landing_angle, self)",
        ]:
            self.assertIn(expected, water_script)

        bad_landing_start = boat_script.index("func on_bad_landing")
        bad_landing_end = boat_script.index("func on_safe_landing", bad_landing_start)
        bad_landing_section = boat_script[bad_landing_start:bad_landing_end]
        self.assertLess(
            bad_landing_section.index("\t_reset_trick_tracking()"),
            bad_landing_section.index("if water_surface == _last_bad_landing_water:"),
        )

    def test_scene_script_references_are_present(self):
        expected_references = {
            "scenes/main/Main.tscn": "res://scripts/main/main.gd",
            "scenes/game/Game.tscn": "res://scripts/game/game.gd",
            "scenes/items/CanCollectible.tscn": "res://scripts/items/can_collectible.gd",
            "scenes/level_parts/Obstacle.tscn": "res://scripts/level_parts/obstacle.gd",
            "scenes/level_parts/WaterSurface.tscn": "res://scripts/level_parts/water_surface.gd",
            "scenes/level_parts/WaveChaser.tscn": "res://scripts/level_parts/wave_chaser.gd",
            "scenes/levels/LevelPrototypeSlope.tscn": "res://scripts/levels/level_prototype_slope.gd",
            "scenes/levels/TutorialLevel.tscn": "res://scripts/levels/tutorial_level.gd",
            "scenes/mechanics/Anchor.tscn": "res://scripts/mechanics/anchor.gd",
            "scenes/mechanics/HookPoint.tscn": "res://scripts/mechanics/hook_point.gd",
            "scenes/player/Boat.tscn": "res://scripts/player/boat.gd",
            "scenes/player/Player.tscn": "res://scripts/player/player.gd",
            "scenes/ui/HUD.tscn": "res://scripts/ui/hud.gd",
            "scenes/ui/PauseMenu.tscn": "res://scripts/ui/pause_menu.gd",
            "scenes/ui/ResultScreen.tscn": "res://scripts/ui/result_screen.gd",
            "scenes/ui/TutorialPrompt.tscn": "res://scripts/ui/tutorial_prompt.gd",
            "debug/AnchorThrowRegression.tscn": "res://debug/anchor_throw_regression.gd",
            "debug/AnchorRelativeLaunchVelocityRegression.tscn": "res://debug/anchor_relative_launch_velocity_regression.gd",
            "debug/AnchorBulletTimeRegression.tscn": "res://debug/anchor_bullet_time_regression.gd",
            "debug/TutorialLevelRegression.tscn": "res://debug/tutorial_level_regression.gd",
            "debug/TutorialLevelPlaytest.tscn": "res://debug/tutorial_level_playtest.gd",
            "debug/DebugLevel.tscn": "res://debug/debug_level.gd",
            "debug/OutOfBoundsRespawnTest.tscn": "res://debug/out_of_bounds_respawn_test.gd",
            "debug/NPCRescueRegression.tscn": "res://debug/npc_rescue_regression.gd",
            "debug/CrewVisualRegression.tscn": "res://debug/crew_visual_regression.gd",
            "debug/ScoreRewardsRegression.tscn": "res://debug/score_rewards_regression.gd",
        }

        for scene_path, script_path in expected_references.items():
            self.assertIn(script_path, self.read(scene_path))

    def test_character_prop_art_is_bound_to_gameplay_scenes(self):
        anchor_scene = self.read("scenes/mechanics/Anchor.tscn")
        boat_scene = self.read("scenes/player/Boat.tscn")
        crew_scene = self.read("scenes/characters/BoatCrewNPC.tscn")

        self.assertIn("res://assets/art/Character Prop Assets/anchor.png", anchor_scene)
        self.assertIn('[node name="AnchorSprite" type="Sprite2D" parent="Head"]', anchor_scene)
        self.assertIn("res://assets/art/Character Prop Assets/kayak.png", boat_scene)
        self.assertIn('[node name="KayakSprite" type="Sprite2D" parent="."', boat_scene)
        self.assertIn('[node name="CrewVisuals" type="Node2D" parent="."', boat_scene)
        self.assertIn("res://assets/art/Character Art Assets/Protagonist Assets/npc.png", crew_scene)
        self.assertIn('[node name="BoatCrewNPC" type="Node2D"]', crew_scene)
        self.assertIn('[node name="Sprite2D" type="Sprite2D" parent="."]', crew_scene)
        self.assertNotIn("Area2D", crew_scene)
        self.assertNotIn("res://assets/art/Character Art Assets/Protagonist Assets/sailor.png", crew_scene)

    def test_environment_art_has_reusable_scenes(self):
        mountain_scene = self.read("scenes/environment/Mountain.tscn")
        sky_scene = self.read("scenes/environment/SkyBackground.tscn")

        self.assertIn("res://assets/art/Scene Assets/mountain1.png", mountain_scene)
        self.assertIn('[node name="MountainSprite" type="Sprite2D" parent="."]', mountain_scene)
        self.assertIn("res://assets/art/Scene Assets/sky.png", sky_scene)
        self.assertIn('[node name="SkySprite" type="Sprite2D" parent="."]', sky_scene)

    def test_game_scene_contains_player_hud_and_pause_menu(self):
        scene = self.read("scenes/game/Game.tscn")
        script = self.read("scripts/game/game.gd")

        self.assertIn("res://scenes/levels/TutorialLevel.tscn", scene)
        self.assertIn("res://scenes/player/Boat.tscn", scene)
        self.assertIn("res://scenes/ui/HUD.tscn", scene)
        self.assertIn("res://scenes/ui/PauseMenu.tscn", scene)
        for expected in [
            "event.is_action_pressed(\"debug_reset\")",
            "func _reset_current_scene() -> void",
            "SceneLoader.reload_scene()",
            "get_viewport().set_input_as_handled()",
            "if level.has_method(\"setup\"):",
            "level.setup(player)",
        ]:
            self.assertIn(expected, script)
        self.assertNotIn("resume_requested", script)
        debug_reset_branch = script[script.index("event.is_action_pressed(\"debug_reset\")"):]
        self.assertLess(
            debug_reset_branch.index("get_viewport().set_input_as_handled()"),
            debug_reset_branch.index("_reset_current_scene()"),
        )

    def test_scene_transition_overlay_exists(self):
        self.assertTrue((ROOT / "scenes/ui/TransitionOverlay.tscn").is_file())
        self.assertTrue((ROOT / "scripts/ui/transition_overlay.gd").is_file())
        self.assertTrue((ROOT / "assets/art/ui/transition/water_ripple.png").is_file())

        scene = self.read("scenes/ui/TransitionOverlay.tscn")
        self.assertIn('res://scripts/ui/transition_overlay.gd', scene)
        self.assertIn('res://assets/art/ui/transition/water_ripple.png', scene)
        self.assertIn('type="TextureRect"', scene)
        self.assertIn('layer = 100', scene)
        self.assertIn('process_mode = 3', scene)

        script = self.read("scripts/ui/transition_overlay.gd")
        for expected in [
            "extends CanvasLayer",
            "signal enter_complete",
            "signal exit_complete",
            "@export var enter_duration: float = 0.6",
            "@export var exit_duration: float = 0.6",
            "func play_enter()",
            "func play_exit()",
            "Tween.TWEEN_PAUSE_PROCESS",
            "visible = false",
        ]:
            self.assertIn(expected, script)

    def test_scene_loader_uses_transition_overlay(self):
        script = self.read("scripts/autoload/SceneLoader.gd")
        for expected in [
            "res://scenes/ui/TransitionOverlay.tscn",
            "_transition_overlay",
            "func reload_scene()",
            "get_tree().paused = true",
            "get_tree().paused = false",
            "Engine.time_scale = 1.0",
            "_transition_overlay.play_enter()",
            "_transition_overlay.play_exit()",
            "_is_transitioning",
        ]:
            self.assertIn(expected, script)

    def test_tutorial_level_contains_prompt_triggers_and_core_parts(self):
        scene = self.read("scenes/levels/TutorialLevel.tscn")
        script = self.read("scripts/levels/tutorial_level.gd")
        trigger_script = self.read("scripts/levels/tutorial_trigger.gd")

        for scene_path in [
            "res://scripts/levels/tutorial_trigger.gd",
            "res://scripts/levels/tutorial_level.gd",
            "res://scenes/mechanics/HookPoint.tscn",
            "res://scenes/level_parts/WaterSurface.tscn",
            "res://scenes/level_parts/WaveChaser.tscn",
            "res://scenes/level_parts/Obstacle.tscn",
            "res://scenes/items/CanCollectible.tscn",
            "res://scenes/ui/TutorialPrompt.tscn",
        ]:
            self.assertIn(scene_path, scene)

        for node_name in [
            "StartMarker",
            "FinishArea",
            "TutorialPrompt",
            "TutorialTriggers",
            "HookPointThrowIntro",
            "HookPointFinal",
            "WaveChaser",
            "CanCollectible",
            "Obstacle",
        ]:
            self.assertIn(f'name="{node_name}"', scene)

        for prompt_text in [
            "顺着坡道前进。",
            "按住鼠标左键瞄准。",
            "松开发射锚。",
            "勾住后让船甩起来。",
            "再次点击收回锚，借惯性飞出去。",
            "空中按 A / D 调整船体倾角。",
            "收集罐子，避开障碍。",
            "巨浪会追上来，继续向终点前进。",
            "到达终点。",
        ]:
            self.assertIn(prompt_text, scene)

        for expected in [
            "class_name TutorialLevel",
            "signal level_completed",
            "func setup(active_player: Node2D) -> void",
            "func get_start_position() -> Vector2",
            "func _connect_tutorial_triggers() -> void",
            "func _on_tutorial_trigger_body_entered(body: Node2D, trigger: TutorialTrigger) -> void",
            "tutorial_prompt.show_prompt(trigger.prompt_text)",
            "wave_chaser.target = active_player",
        ]:
            self.assertIn(expected, script)

        for expected in [
            "class_name TutorialTrigger",
            "@export_multiline var prompt_text",
            "@export var one_shot",
            "@export_range(0.0, 10.0, 0.1) var auto_hide_seconds",
            "func can_trigger(body: Node2D) -> bool",
            "func mark_triggered() -> void",
            "body.is_in_group(\"boats\")",
        ]:
            self.assertIn(expected, trigger_script)

    def test_tutorial_level_playtest_scene_is_directly_playable(self):
        scene = self.read("debug/TutorialLevelPlaytest.tscn")
        script = self.read("debug/tutorial_level_playtest.gd")

        for scene_path in [
            "res://debug/tutorial_level_playtest.gd",
            "res://scenes/levels/TutorialLevel.tscn",
            "res://scenes/player/Boat.tscn",
            "res://scenes/camera/GameCamera.tscn",
            "res://scenes/ui/HUD.tscn",
            "res://scenes/ui/PauseMenu.tscn",
        ]:
            self.assertIn(scene_path, scene)

        for node_name in [
            "World",
            "TutorialLevel",
            "Player",
            "GameCamera",
            "HUD",
            "PauseMenu",
        ]:
            self.assertIn(f'name="{node_name}"', scene)

        for expected in [
            "level.setup(player)",
            "player.global_position = level.get_start_position()",
            "event.is_action_pressed(\"pause\")",
            "event.is_action_pressed(\"debug_reset\")",
            "get_tree().reload_current_scene()",
        ]:
            self.assertIn(expected, script)
        self.assertNotIn("resume_requested", script)

    def test_debug_level_scene_runs_level_with_minimal_game_environment(self):
        scene = self.read("debug/DebugLevel.tscn")
        script = self.read("debug/debug_level.gd")

        for scene_path in [
            "res://debug/debug_level.gd",
            "res://scenes/levels/Level.tscn",
            "res://scenes/player/Boat.tscn",
            "res://scenes/camera/GameCamera.tscn",
            "res://scenes/ui/HUD.tscn",
            "res://scenes/ui/PauseMenu.tscn",
        ]:
            self.assertIn(scene_path, scene)

        for node_name in [
            "DebugLevel",
            "World",
            "Level",
            "Player",
            "GameCamera",
            "HUD",
            "PauseMenu",
        ]:
            self.assertIn(f'name="{node_name}"', scene)

        for expected in [
            "var level: Node2D = $World/Level",
            "var player: Boat = $Player",
            "GameState.reset()",
            "level.setup(player)",
            "player.global_position = level.get_start_position()",
            "event.is_action_pressed(\"pause\")",
            "event.is_action_pressed(\"debug_reset\")",
            "get_tree().reload_current_scene()",
            "func _on_pause_changed(is_paused: bool) -> void",
        ]:
            self.assertIn(expected, script)
        self.assertNotIn("resume_requested", script)

    def test_prototype_level_contains_core_gameplay_parts(self):
        scene = self.read("scenes/levels/LevelPrototypeSlope.tscn")

        for scene_path in [
            "res://scenes/mechanics/HookPoint.tscn",
            "res://scenes/level_parts/WaterSurface.tscn",
            "res://scenes/level_parts/WaveChaser.tscn",
            "res://scenes/level_parts/Obstacle.tscn",
            "res://scenes/items/CanCollectible.tscn",
        ]:
            self.assertIn(scene_path, scene)

        self.assertIn('[node name="WaterSurface" parent="Slope"', scene)
        self.assertIn('instance=ExtResource("3_water")', scene)
        self.assertIn("rotation = 0.244979", scene)
        self.assertIn("water_width = 560.0", scene)

    def test_water_surface_is_animated_and_gameplay_ready(self):
        scene = self.read("scenes/level_parts/WaterSurface.tscn")
        script = self.read("scripts/level_parts/water_surface.gd")
        boat_scene = self.read("scenes/player/Boat.tscn")

        self.assertNotIn('type="Polygon2D" parent="."', scene)
        self.assertIn("mass = 10.0", boat_scene)
        for expected in [
            "signal boat_landed_safely",
            "signal boat_bad_landing",
            "reference_boat_mass",
            "current_flow_speed",
            "fountain_impulse",
            "buoyancy_force",
            "target_float_depth",
            "max_buoyancy_force",
            "buoyancy_damping",
            "enable_waterfall",
            "waterfall_side",
            "waterfall_width",
            "waterfall_height",
            "waterfall_down_force",
            "waterfall_lip_length",
            "angular_stability_torque",
            "angular_damping_torque",
            "max_water_angular_velocity",
            "angular_stability_blend",
            "water_stability_min_submerged_ratio",
            "func _process(delta: float)",
            "func _physics_process(_delta: float)",
            "func _draw()",
            "func _draw_water_body_gradient(surface_points: PackedVector2Array) -> void",
            "func get_surface_depth_at_global_position(global_position: Vector2) -> float",
            "func get_water_up_direction() -> Vector2",
            "func get_water_flow_direction() -> Vector2",
            "func get_waterfall_drop_direction() -> Vector2",
            "func get_boat_target_rotation() -> float",
            "func _apply_buoyancy_to_boat(boat: Node2D)",
            "func _apply_stability_to_boat",
            "func _refresh_overlapping_boats()",
            "func _is_in_waterfall_edge(local_position: Vector2) -> bool",
            "func _draw_waterfall()",
            "func _build_waterfall_lip_points(edge_point: Vector2, lip_end: Vector2) -> PackedVector2Array",
            "func _draw_waterfall_splash(center: Vector2)",
            "basis_xform_inv(Vector2.DOWN)",
            "edge_point + water_flow_direction * waterfall_lip_length",
            "get_overlapping_bodies()",
            "queue_redraw()",
            "draw_polygon(fill_points, PackedColorArray",
            "water_color",
            "deep_water_color",
            "draw_polyline",
            "draw_arc",
            "apply_central_force",
            "get_mass_force_scale",
            "rigid_body.mass / reference_boat_mass",
            "float_force * mass_force_scale",
            "current_force * mass_force_scale",
            "waterfall_down_force * mass_force_scale",
            "linear_velocity.dot(water_up_direction)",
            "rigid_boat.apply_torque(stability_torque)",
            "rigid_boat.angular_velocity = lerpf",
            "clampf(-rotation_error * angular_recovery_speed",
            "if submerged_ratio < water_stability_min_submerged_ratio",
            "body.enter_water()",
            "body.exit_water()",
            "body.on_bad_landing(landing_angle, target_rotation, self)",
            "boat_bad_landing.emit(body, landing_angle, target_rotation, self)",
            "func get_landing_angle_degrees(body: Node2D) -> float",
            "wrapf(body.global_rotation - get_boat_target_rotation(), -PI, PI)",
            "func get_surface_height_at_global_position(global_position: Vector2) -> float",
        ]:
            self.assertIn(expected, script)

        boat_script = self.read("scripts/player/boat.gd")
        for expected in [
            "func on_bad_landing(angle_degrees: float, target_rotation: float, water_surface: Node2D) -> void:",
            "lose_crew(1)",
            "_righting_timer = bad_landing_righting_duration",
            "_righting_target_rotation = target_rotation",
            "func _apply_bad_landing_righting(state: PhysicsDirectBodyState2D) -> void:",
            "state.apply_torque(righting_torque)",
        ]:
            self.assertIn(expected, boat_script)

    def test_anchor_supports_launch_hook_recall_and_rope_state(self):
        script = self.read("scripts/mechanics/anchor.gd")

        for expected in [
            "enum State",
            "State.READY",
            "State.AIMING",
            "State.FLYING",
            "State.HOOKED",
            "@export var launch_speed",
            "var throw_origin_global",
            "var launch_velocity",
            "var launch_carrier_velocity",
            "func _physics_process(delta: float)",
            "func is_active() -> bool",
            "func is_hooked() -> bool",
            "func get_rope_length() -> float",
            "func get_hook_global_position() -> Vector2",
            "func _update_rope_visual()",
            "global_position.distance_to(throw_origin_global)",
            "recall()",
            "attached_hook_point.global_position",
            "head.global_position",
        ]:
            self.assertIn(expected, script)

        for removed_cooldown in [
            "COOLDOWN",
            "cooldown_seconds",
            "_start_cooldown",
            "create_timer",
        ]:
            self.assertNotIn(removed_cooldown, script)

        self.assertIn("state = State.READY", script)
        self.assertIn("is_ready = true", script)

    def test_anchor_throw_uses_parabola_slack_chain_and_debug_logs(self):
        script = self.read("scripts/mechanics/anchor.gd")
        anchor_scene = self.read("scenes/mechanics/Anchor.tscn")
        debug_scene = self.read("debug/AnchorThrowRegression.tscn")
        debug_script = self.read("debug/anchor_throw_regression.gd")

        for expected in [
            "@export var launch_gravity_scale",
            "@export var rope_visual_segments",
            "@export var rope_slack_pixels",
            "@export var debug_logging_enabled",
            "@export var anchor_log_prefix",
            "var launch_elapsed_seconds",
            "var launch_initial_velocity",
            "launch_carrier_velocity",
            "func _get_launch_carrier_velocity() -> Vector2",
            "direction * launch_speed + carrier_velocity",
            "func launch(target_position: Vector2)",
            "func get_anchor_log_data() -> Dictionary",
            "func emit_anchor_log() -> void",
            "func _get_parabolic_flight_position(delta: float) -> Vector2",
            "func _build_slack_rope_points",
            "func _get_rope_slack_offset",
            "JSON.stringify(get_anchor_log_data())",
            "rope_line.points = _build_slack_rope_points",
            "@export var aim_indicator_length",
            "@export var aim_indicator_head_length",
            "@onready var aim_direction_line: Line2D = %AimDirectionLine",
            "@onready var aim_direction_head: Line2D = %AimDirectionHead",
            "func update_aim_target(target_position: Vector2) -> void",
            "func _update_aim_indicator(target_position: Vector2) -> void",
            "func _hide_aim_indicator() -> void",
            "aim_direction_line.points = PackedVector2Array",
            "aim_direction_head.points = PackedVector2Array",
        ]:
            self.assertIn(expected, script)

        for expected in [
            '[node name="AimDirectionLine" type="Line2D" parent="."]',
            '[node name="AimDirectionHead" type="Line2D" parent="."]',
            "visible = false",
        ]:
            self.assertIn(expected, anchor_scene)

        self.assertNotIn("global_position += launch_velocity * delta", script)
        for removed_charge in [
            "min_launch_speed",
            "launch_charge_ratio",
            "charge_ratio",
            "_get_charged_launch_speed",
            "charged_launch_speed",
        ]:
            self.assertNotIn(removed_charge, script)

        for expected in [
            "res://debug/anchor_throw_regression.gd",
            "fail_on_regression = true",
        ]:
            self.assertIn(expected, debug_scene)

        for expected in [
            "ANCHOR_THROW_RESULT",
            "min_arc_deviation",
            "min_apex_recovery",
            "min_upward_travel",
            "min_chain_points",
            "min_chain_slack",
            "max_sampled_speed",
            "get_anchor_log_data",
            "emit_anchor_log",
            "rope_line.points.size()",
            "_get_max_line_deviation",
            "_has_parabolic_apex",
            "_get_max_upward_travel",
            "_get_max_gravity_slack",
        ]:
            self.assertIn(expected, debug_script)

        relative_debug_scene = self.read("debug/AnchorRelativeLaunchVelocityRegression.tscn")
        relative_debug_script = self.read("debug/anchor_relative_launch_velocity_regression.gd")
        for expected in [
            "res://debug/anchor_relative_launch_velocity_regression.gd",
            "fail_on_regression = true",
        ]:
            self.assertIn(expected, relative_debug_scene)

        for expected in [
            "ANCHOR_RELATIVE_LAUNCH_RESULT",
            "boat_velocity",
            "relative_velocity",
            "expected_velocity",
            "launch_initial_velocity",
            "velocity_error",
        ]:
            self.assertIn(expected, relative_debug_script)

    def test_boat_drives_anchor_input_swing_constraint_and_airborne_rotation(self):
        script = self.read("scripts/player/boat.gd")

        for expected in [
            "posture_logging_enabled",
            "posture_log_interval_seconds",
            "posture_log_prefix",
            "airborne_nose_down_torque",
            "airborne_nose_down_damping",
            "var aim_time_scale",
            "var bullet_time_slowdown_seconds",
            "var bullet_time_recover_seconds",
            "var rope_pull_stiffness",
            "var swing_turnaround_speed",
            "var anchor_swing_alignment_torque",
            "var anchor_swing_alignment_damping",
            "var anchor_swing_alignment_max_angular_velocity",
            "var anchor_swing_target_turn_speed",
            "var max_linear_speed",
            "var crew_visual_origin",
            "var crew_visual_spacing",
            "var crew_visual_scale",
            "const CREW_MEMBER_SCENE := preload(\"res://scenes/characters/BoatCrewNPC.tscn\")",
            "@onready var crew_visuals: Node2D = %CrewVisuals",
            "func _sync_crew_visuals() -> void",
            "CREW_MEMBER_SCENE.instantiate()",
            "var _swing_locked_energy",
            "var _swing_tangent_sign",
            "var _anchor_swing_target_rotation",
            "@onready var anchor: Variant = %Anchor",
            "func _unhandled_input(event: InputEvent)",
            "func _update_anchor_aim_target() -> void",
            "anchor.update_aim_target(get_global_mouse_position())",
            "event.is_action_pressed(\"confirm\")",
            "event.is_action_released(\"confirm\")",
            "anchor.start_aim()",
            "anchor.launch(get_global_mouse_position())",
            "anchor.recall()",
            "func _integrate_forces(state: PhysicsDirectBodyState2D)",
            "state.get_contact_count()",
            "func _apply_anchor_constraint(state: PhysicsDirectBodyState2D)",
            "func _limit_linear_speed(state: PhysicsDirectBodyState2D)",
            "if max_linear_speed <= 0.0:",
            "if state.linear_velocity.length() > max_linear_speed:",
            "state.linear_velocity = state.linear_velocity.normalized() * max_linear_speed",
            "anchor.is_hooked()",
            "anchor.get_hook_global_position()",
            "anchor.get_rope_length()",
            "state.linear_velocity",
            "_reset_anchor_swing_state()",
            "_capture_anchor_swing_state",
            "_get_tangent_direction",
            "_align_bow_to_anchor_swing",
            "_update_anchor_swing_target_rotation",
            "_update_swing_direction_from_gravity",
            "sqrt(2.0 * maxf(_swing_locked_energy - potential_energy, 0.0))",
            "state.linear_velocity = tangent_direction * target_tangent_speed * _swing_tangent_sign",
            "_update_anchor_swing_target_rotation(state.linear_velocity.angle(), state)",
            "state.angular_velocity = desired_angular_velocity",
            "is_airborne()",
            "func _apply_airborne_nose_down",
            "Vector2.DOWN.angle()",
            "wrapf(global_rotation - nose_down_rotation, -PI, PI)",
            "apply_torque(nose_down_torque)",
            "is_in_water()",
            "enter_water()",
            "exit_water()",
            "_water_contact_count > 0",
            "_contact_count == 0 and not is_in_water()",
            "func get_posture_log_data() -> Dictionary",
            "func emit_posture_log() -> void",
            "JSON.stringify(get_posture_log_data())",
            "rotation_degrees",
            "nose_angle_degrees",
            "anchor_swing_target_degrees",
            "anchor_swing_alignment_error_degrees",
            "angular_velocity",
            "linear_velocity",
            "contact_count",
            "water_contact_count",
            "in_water",
            "airborne",
            "Input.is_action_pressed(\"bullet_time\")",
            "func _update_manual_bullet_time(delta: float) -> void",
            "func _get_unscaled_delta(delta: float) -> float",
            "smoothstep",
            "Engine.time_scale = lerpf",
        ]:
            self.assertIn(expected, script)

        integrate_forces_body = script[
            script.index("func _integrate_forces(state: PhysicsDirectBodyState2D)"):
            script.index("func is_airborne() -> bool")
        ]
        normal_physics_branch = integrate_forces_body[
            integrate_forces_body.index("_apply_anchor_constraint(state)"):]
        self.assertLess(
            normal_physics_branch.index("_apply_anchor_constraint(state)"),
            normal_physics_branch.index("_limit_linear_speed(state)"),
        )

        for removed_charge in [
            "max_anchor_charge_seconds",
            "_anchor_charge",
            "_get_anchor_charge_ratio",
            "_update_anchor_charge",
            "_reset_anchor_charge",
        ]:
            self.assertNotIn(removed_charge, script)

    def test_space_controls_bullet_time_smoothly(self):
        script = self.read("scripts/player/boat.gd")
        debug_scene = self.read("debug/AnchorBulletTimeRegression.tscn")
        debug_script = self.read("debug/anchor_bullet_time_regression.gd")

        for expected in [
            "@export_range(0.01, 2.0, 0.01) var bullet_time_slowdown_seconds",
            "@export_range(0.01, 2.0, 0.01) var bullet_time_recover_seconds",
            "func _update_manual_bullet_time(delta: float) -> void",
            "func _get_manual_bullet_time_target_scale() -> float",
            "func _get_unscaled_delta(delta: float) -> float",
            "Input.is_action_pressed(\"bullet_time\")",
            "smoothstep",
            "Engine.time_scale = lerpf",
        ]:
            self.assertIn(expected, script)

        for removed_auto_bullet_time in [
            "_bullet_time_target_hook_point",
            "_bullet_time_launch_x_direction",
            "_bullet_time_start_hook_distance_x",
            "_find_nearest_anchor_bullet_time_hook_point",
            "get_nodes_in_group(\"hook_points\")",
            "anchor.launch_initial_velocity.x",
        ]:
            self.assertNotIn(removed_auto_bullet_time, script)

        for expected in [
            "res://debug/anchor_bullet_time_regression.gd",
            "fail_on_regression = true",
        ]:
            self.assertIn(expected, debug_scene)

        for expected in [
            "ANCHOR_BULLET_TIME_RESULT",
            "space: halfway through slowdown",
            "space: held reaches bullet time",
            "space: halfway through release",
            "anchor: launch no longer changes time scale",
        ]:
            self.assertIn(expected, debug_script)

    def test_gameplay_tempo_is_slightly_slower(self):
        boat_script = self.read("scripts/player/boat.gd")
        boat_scene = self.read("scenes/player/Boat.tscn")
        anchor_script = self.read("scripts/mechanics/anchor.gd")
        wave_script = self.read("scripts/level_parts/wave_chaser.gd")
        slope_script = self.read("scripts/level_parts/slope_with_water.gd")
        slope_scene = self.read("scenes/level_parts/SlopeWithWater.tscn")
        level_scene = self.read("scenes/levels/Level.tscn")
        auto_finish_scene = self.read("scenes/levels/LevelAutoFinish.tscn")
        prototype_scene = self.read("scenes/levels/LevelPrototypeSlope.tscn")
        tutorial_scene = self.read("scenes/levels/TutorialLevel.tscn")

        for expected in [
            "@export var airborne_rotation_torque: float = 78000.0",
            "@export var airborne_nose_down_torque: float = 15000.0",
            "@export var anchor_swing_alignment_max_angular_velocity: float = 9.0",
            "@export var max_angular_velocity: float = 9.0",
            "@export var anchor_swing_target_turn_speed: float = 10.0",
        ]:
            self.assertIn(expected, boat_script)

        for expected in [
            "gravity_scale = 1.2",
            "max_linear_speed = 880.0",
        ]:
            self.assertIn(expected, boat_scene)

        self.assertIn("@export var launch_speed: float = 500.0", anchor_script)
        self.assertIn("@export var chase_speed: float = 76.0", wave_script)

        self.assertIn("current_flow_speed: float = 220.0", slope_script)
        self.assertIn("current_force: float = 220.0", slope_script)

        for text in [slope_scene, level_scene, auto_finish_scene, prototype_scene]:
            self.assertIn("current_flow_speed = 220.0", text)
            self.assertIn("current_force = 220.0", text)

        self.assertIn("current_flow_speed = 195.0", tutorial_scene)
        self.assertIn("current_force = 220.0", tutorial_scene)
        self.assertIn("chase_speed = 52.0", tutorial_scene)

    def test_rescue_mechanic_adds_crew_caps_and_hud_display(self):
        boat_script = self.read("scripts/player/boat.gd")
        rescue_script = self.read("scripts/characters/npc_rescue.gd")
        npc_scene = self.read("scenes/characters/NPC.tscn")
        hud_scene = self.read("scenes/ui/HUD.tscn")
        hud_script = self.read("scripts/ui/hud.gd")
        level_scene = self.read("scenes/levels/Level.tscn")

        for expected in [
            "signal crew_gained(count: int)",
            "@export var max_crew_count: int = 5",
            "crew_count = clampi(value, 0, max_crew_count)",
            "func gain_crew(amount: int = 1) -> void:",
            "crew_gained.emit(crew_count)",
        ]:
            self.assertIn(expected, boat_script)

        for expected in [
            "class_name NPCRescue",
            "extends Area2D",
            "@export var rescue_value: int = 1",
            "body_entered.connect(_on_body_entered)",
            "body.is_in_group(\"boats\")",
            "body.has_method(\"gain_crew\")",
            "body.gain_crew(rescue_value)",
            "var rescued_npc := get_parent()",
            "rescued_npc.queue_free()",
        ]:
            self.assertIn(expected, rescue_script)

        for expected in [
            "res://scripts/characters/floating_npc.gd",
            "res://scripts/characters/npc_rescue.gd",
            "name=\"WaterDetector\"",
            "name=\"RescueArea\"",
            "type=\"CircleShape2D\"",
            "radius = 32.0",
        ]:
            self.assertIn(expected, npc_scene)

        for expected in [
            "name=\"RescuedLabel\"",
            "text = \"15/13\"",
        ]:
            self.assertIn(expected, hud_scene)

        for expected in [
            "@onready var rescued_label: Label = %RescuedLabel",
            "GameState.rescued_changed.connect(_on_rescued_changed)",
            "func _on_rescued_changed(count: int, target: int) -> void:",
            "rescued_label.text = \"%d/%d\"",
        ]:
            self.assertIn(expected, hud_script)

        self.assertIn("res://scenes/characters/NPC.tscn", level_scene)
        self.assertIn('name="NPC_RescueTest"', level_scene)

    def test_out_of_bounds_respawn_has_death_zones_and_regression_scene(self):
        boat_script = self.read("scripts/player/boat.gd")
        death_zone_script = self.read("scripts/mechanics/death_zone.gd")
        death_zone_scene = self.read("scenes/mechanics/DeathZone.tscn")
        debug_scene = self.read("debug/OutOfBoundsRespawnTest.tscn")
        debug_script = self.read("debug/out_of_bounds_respawn_test.gd")
        tutorial_scene = self.read("scenes/levels/TutorialLevel.tscn")
        prototype_scene = self.read("scenes/levels/LevelPrototypeSlope.tscn")

        for expected in [
            "enum RespawnState",
            "func is_respawning() -> bool:",
            "func respawn_at(target_position: Vector2) -> void:",
            "_recall_anchor_for_respawn()",
            "_execute_respawn_launch(state)",
            "lose_crew(1)",
            "if _respawn_state != RespawnState.NONE:",
        ]:
            self.assertIn(expected, boat_script)

        for expected in [
            "class_name DeathZone",
            "@export var respawn_marker: Marker2D",
            "body.respawn_at(respawn_marker.global_position)",
        ]:
            self.assertIn(expected, death_zone_script)

        for expected in [
            "res://scripts/mechanics/death_zone.gd",
            'name="DeathZone"',
            'name="RespawnMarker"',
            "size = Vector2(800, 100)",
            "position = Vector2(0, -200)",
            "respawn_marker = NodePath(\"RespawnMarker\")",
        ]:
            self.assertIn(expected, death_zone_scene)

        for expected in [
            "res://debug/out_of_bounds_respawn_test.gd",
            "res://scenes/player/Boat.tscn",
            "res://scenes/mechanics/DeathZone.tscn",
            "res://scenes/level_parts/WaterSurface.tscn",
        ]:
            self.assertIn(expected, debug_scene)

        for expected in [
            "PASS: Out-of-bounds respawn works.",
            "FAIL: Out-of-bounds respawn test failed:",
            "_boat.is_respawning()",
            "_boat.crew_count != 2",
            "get_tree().quit(_exit_code)",
        ]:
            self.assertIn(expected, debug_script)

        for scene in [tutorial_scene, prototype_scene]:
            self.assertIn("res://scenes/mechanics/DeathZone.tscn", scene)
            self.assertIn('name="DeathZone"', scene)
            self.assertIn("respawn_marker = NodePath(\"../StartMarker\")", scene)


if __name__ == "__main__":
    unittest.main()
