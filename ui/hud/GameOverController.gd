class_name GameOverController
extends Control

var selected_yes := true
var _accept_routed_intents := false

@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton


func _ready() -> void:
	yes_button.pressed.connect(_choose.bind(true))
	no_button.pressed.connect(_choose.bind(false))
	GameFlow.state_changed.connect(_on_state_changed)
	InputRouter.intent_requested.connect(_on_intent_requested)
	_set_active(GameFlow.current_state == GameFlow.LAVA_GAME_OVER)


func _exit_tree() -> void:
	if GameFlow.state_changed.is_connected(_on_state_changed):
		GameFlow.state_changed.disconnect(_on_state_changed)
	if InputRouter.intent_requested.is_connected(_on_intent_requested):
		InputRouter.intent_requested.disconnect(_on_intent_requested)


func handle_intent(intent: StringName) -> bool:
	if GameFlow.current_state != GameFlow.LAVA_GAME_OVER:
		return false
	if intent == InputRouter.INTENT_LEFT or intent == InputRouter.INTENT_UP:
		selected_yes = true
		_refresh_focus()
		return true
	if intent == InputRouter.INTENT_RIGHT or intent == InputRouter.INTENT_DOWN:
		selected_yes = false
		_refresh_focus()
		return true
	if intent == InputRouter.INTENT_CONFIRM:
		return GameFlow.choose_game_over(selected_yes)
	if intent == InputRouter.INTENT_BACK:
		return GameFlow.choose_game_over(false)
	return false


func _choose(yes: bool) -> void:
	selected_yes = yes
	GameFlow.choose_game_over(yes)


func _on_state_changed(_previous: StringName, next_state: StringName) -> void:
	_set_active(next_state == GameFlow.LAVA_GAME_OVER)


func _set_active(active: bool) -> void:
	visible = active
	_accept_routed_intents = false
	if not active:
		return
	selected_yes = true
	_refresh_focus()
	call_deferred("_enable_routed_intents")


func _on_intent_requested(intent: StringName) -> void:
	if _accept_routed_intents:
		handle_intent(intent)


func _enable_routed_intents() -> void:
	_accept_routed_intents = visible and GameFlow.current_state == GameFlow.LAVA_GAME_OVER


func _refresh_focus() -> void:
	if not is_node_ready():
		return
	yes_button.modulate = Color(1.0, 0.86, 0.2) if selected_yes else Color.WHITE
	no_button.modulate = Color(1.0, 0.86, 0.2) if not selected_yes else Color.WHITE
