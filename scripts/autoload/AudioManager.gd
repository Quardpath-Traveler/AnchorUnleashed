extends Node
## AudioManager (autoload)
## 统一管理所有音效和背景音乐的播放。
## SFX 使用 4 个 AudioStreamPlayer 池支持同时播放多个音效。
## Music 使用单独的 AudioStreamPlayer 支持淡入/淡出。

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

const STREAM_ANCHOR_LAUNCH := preload("res://assets/audio/anchor_launch.mp3")
const STREAM_ANCHOR_HOOK := preload("res://assets/audio/anchor_hook.mp3")
const STREAM_COIN_PICKUP := preload("res://assets/audio/coin_pickup.mp3")
const STREAM_BULLET_TIME := preload("res://assets/audio/bullet_time.mp3")
const STREAM_PAUSE_MENU := preload("res://assets/audio/pause_menu.mp3")
const STREAM_BUTTON_CLICK := preload("res://assets/audio/button_click.mp3")
const STREAM_START_GAME := preload("res://assets/audio/start_game.mp3")
const STREAM_TRANSITION := preload("res://assets/audio/transition.mp3")
const STREAM_BACKGROUND_MUSIC := preload("res://assets/audio/background_music.mp3")

const SFX_POOL_SIZE := 4
const MUSIC_FADE_IN_SECONDS := 1.0
const MUSIC_FADE_OUT_SECONDS := 0.5
const MUSIC_FADE_START_DB := -80.0
const MUSIC_TARGET_DB := 0.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_create_sfx_pool()
	_create_music_player()
	play_music()


## 确保 SFX 和 Music 总线存在
func _ensure_buses() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _create_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_pool.append(player)


func _create_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.stream = STREAM_BACKGROUND_MUSIC
	_music_player.volume_db = MUSIC_FADE_START_DB
	add_child(_music_player)


func _play_sfx(stream: AudioStream) -> void:
	var player := _get_available_sfx_player()
	player.stream = stream
	player.play()


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	return _sfx_pool[0]


# ---- 公开 API ----

func play_anchor_launch() -> void:
	_play_sfx(STREAM_ANCHOR_LAUNCH)


func play_anchor_hook() -> void:
	_play_sfx(STREAM_ANCHOR_HOOK)


func play_coin_pickup() -> void:
	_play_sfx(STREAM_COIN_PICKUP)


func play_bullet_time() -> void:
	_play_sfx(STREAM_BULLET_TIME)


func play_pause_menu() -> void:
	_play_sfx(STREAM_PAUSE_MENU)


func play_button_click() -> void:
	_play_sfx(STREAM_BUTTON_CLICK)


func play_start_game() -> void:
	_play_sfx(STREAM_START_GAME)


func play_transition() -> void:
	_play_sfx(STREAM_TRANSITION)


func play_music() -> void:
	if _music_player.playing:
		return
	_music_player.volume_db = MUSIC_FADE_START_DB
	_music_player.play()
	_fade_music(MUSIC_TARGET_DB, MUSIC_FADE_IN_SECONDS)


func stop_music() -> void:
	if not _music_player.playing:
		return
	_fade_music(MUSIC_FADE_START_DB, MUSIC_FADE_OUT_SECONDS)
	await get_tree().create_timer(MUSIC_FADE_OUT_SECONDS).timeout
	_music_player.stop()


func _fade_music(target_db: float, duration: float) -> void:
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music_player, "volume_db", target_db, duration)
