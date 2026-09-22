class_name GameOverController
extends Control

@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton


func _ready() -> void:
	yes_button.pressed.connect(_choose.bind(true))
	no_button.pressed.connect(_choose.bind(false))
	GameFlow.state_changed.connect(_on_state_changed)
	visible = GameFlow.current_state == GameFlow.LAVA_GAME_OVER


func _choose(yes: bool) -> void:
	GameFlow.choose_game_over(yes)


func _on_state_changed(_previous: StringName, next_state: StringName) -> void:
	visible = next_state == GameFlow.LAVA_GAME_OVER
