extends Control

@onready var state_label: Label = %StateLabel
@onready var detail_label: Label = %DetailLabel
@onready var advance_button: Button = %AdvanceButton
@onready var ready_button: Button = %ReadyButton
@onready var pause_button: Button = %PauseButton
@onready var resume_button: Button = %ResumeButton
@onready var fail_button: Button = %FailButton
@onready var retry_yes_button: Button = %RetryYesButton
@onready var retry_no_button: Button = %RetryNoButton
@onready var select_left_button: Button = %SelectLeftButton
@onready var select_right_button: Button = %SelectRightButton
@onready var touch_confirm_surface: Control = %TouchConfirmSurface
@onready var panel: Control = %Panel


func _ready() -> void:
	GameFlow.state_changed.connect(_refresh)
	GameFlow.selected_character_changed.connect(_on_selection_changed)
	advance_button.pressed.connect(GameFlow.advance_placeholder)
	ready_button.pressed.connect(_mark_run_intro_ready)
	pause_button.pressed.connect(GameFlow.pause_run)
	resume_button.pressed.connect(GameFlow.resume_run)
	fail_button.pressed.connect(GameFlow.fail_run)
	retry_yes_button.pressed.connect(func() -> void: GameFlow.choose_try_again(true))
	retry_no_button.pressed.connect(func() -> void: GameFlow.choose_try_again(false))
	select_left_button.pressed.connect(func() -> void: GameFlow.select_character_offset(-1))
	select_right_button.pressed.connect(func() -> void: GameFlow.select_character_offset(1))
	if GameFlow.current_state == GameFlow.BOOT:
		GameFlow.begin_session()
	_refresh()


func _exit_tree() -> void:
	if GameFlow.state_changed.is_connected(_refresh):
		GameFlow.state_changed.disconnect(_refresh)
	if GameFlow.selected_character_changed.is_connected(_on_selection_changed):
		GameFlow.selected_character_changed.disconnect(_on_selection_changed)


func _refresh(_previous_state: StringName = &"", _next_state: StringName = &"") -> void:
	state_label.text = "GAMEFLOW PLACEHOLDER\n%s" % GameFlow.current_state
	detail_label.text = _detail_for_state()
	panel.visible = GameFlow.current_state not in [GameFlow.LOADING, GameFlow.ISLAND_INTRO, GameFlow.ISLAND_ATTRACT]
	advance_button.visible = GameFlow.current_state in [GameFlow.LOGO_REVEAL, GameFlow.CHARACTER_SELECT_ENTER, GameFlow.CHARACTER_SELECT_ACTIVE, GameFlow.CHARACTER_CONFIRMED, GameFlow.FAILURE_TRANSITION, GameFlow.LAVA_GAME_OVER]
	ready_button.visible = GameFlow.current_state == GameFlow.RUN_INTRO
	pause_button.visible = GameFlow.current_state == GameFlow.RUNNING
	resume_button.visible = GameFlow.current_state == GameFlow.PAUSED
	fail_button.visible = GameFlow.current_state == GameFlow.RUNNING
	retry_yes_button.visible = GameFlow.current_state == GameFlow.TRY_AGAIN
	retry_no_button.visible = GameFlow.current_state == GameFlow.TRY_AGAIN
	select_left_button.visible = GameFlow.current_state == GameFlow.CHARACTER_SELECT_ACTIVE
	select_right_button.visible = GameFlow.current_state == GameFlow.CHARACTER_SELECT_ACTIVE
	touch_confirm_surface.visible = GameFlow.current_state == GameFlow.ISLAND_ATTRACT


func _on_selection_changed(_character_id: StringName, _selection_index: int) -> void:
	_refresh()


func _mark_run_intro_ready() -> void:
	GameFlow.report_run_intro_ready(true, true)


func _detail_for_state() -> String:
	match GameFlow.current_state:
		GameFlow.ISLAND_ATTRACT:
			return "Waits indefinitely. Confirm or Advance enters LOGO_REVEAL."
		GameFlow.CHARACTER_SELECT_ACTIVE:
			return "Selection only: %s. Confirm/Advance locks the selection." % GameFlow.selected_character_id
		GameFlow.RUN_INTRO:
			return "Gameplay input and timer remain disabled until Camera Settled."
		GameFlow.RUNNING:
			return "Placeholder run active. Pause or force failure for flow testing."
		GameFlow.TRY_AGAIN:
			return "Retry retains the selected character and prepares Boulevard."
	return "Placeholder stage control only; final presentation belongs to later tasks."
