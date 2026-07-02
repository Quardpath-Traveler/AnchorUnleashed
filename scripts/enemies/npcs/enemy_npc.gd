extends CharacterBody2D

@export var speed: float = 120.0


func _ready() -> void:
	EventBus.player_spawned.connect(_on_player_spawned)


func _physics_process(_delta: float) -> void:
	move_and_slide()


func _on_player_spawned(_player: Node) -> void:
	pass
