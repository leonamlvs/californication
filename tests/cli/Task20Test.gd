extends Node

const HUD_SCENE := preload("res://ui/hud/HUD.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(GameFlow.gameplay_input_enabled and GameFlow.run_timer_enabled, "Running state did not enable gameplay services.")
	_assert(GameFlow.pause_run(), "Pause transition was rejected from RUNNING.")
	_assert(GameFlow.current_state == GameFlow.PAUSED, "Pause did not enter PAUSED.")
	_assert(not GameFlow.gameplay_input_enabled and not GameFlow.run_timer_enabled, "Pause did not freeze gameplay input and timer.")

	var hud := HUD_SCENE.instantiate() as RunnerHUD
	get_tree().root.add_child(hud)
	await get_tree().process_frame
	var pause := hud.pause_overlay
	_assert(pause.visible, "HUD did not reveal the pause overlay while PAUSED.")
	_assert(pause.portraits.size() == 4, "Pause overlay did not provide four portraits.")
	_assert(pause.handle_intent(InputRouter.INTENT_DOWN), "Portrait down navigation was not handled.")
	_assert(pause.portrait_index == 1, "Down did not move to the next portrait.")
	_assert(pause.handle_intent(InputRouter.INTENT_CONFIRM), "Portrait confirmation was rejected.")
	_assert(GameFlow.selected_character_index == 1, "Portrait confirmation did not immediately apply its cosmetic selection.")
	_assert(pause.focus_target == PauseController.FocusTarget.BACK, "Portrait confirmation did not focus BACK.")

	GameFlow.development_jump_to_state(GameFlow.PAUSED)
	pause.focus_target = PauseController.FocusTarget.PORTRAITS
	_assert(pause.handle_intent(InputRouter.INTENT_LEFT), "Left from portraits was not handled.")
	_assert(pause.focus_target == PauseController.FocusTarget.SFX, "Left from portraits did not reach SFX LEVEL.")
	AudioManager.sfx_step = 5
	_assert(pause.handle_intent(InputRouter.INTENT_CONFIRM), "SFX adjustment mode did not enter.")
	pause.handle_intent(InputRouter.INTENT_RIGHT)
	_assert(AudioManager.sfx_step == 6, "SFX did not use discrete adjustment steps.")
	pause.handle_intent(InputRouter.INTENT_CONFIRM)
	_assert(not pause.adjusting_audio, "SFX adjustment mode did not exit.")
	pause.focus_target = PauseController.FocusTarget.MUSIC
	pause.handle_intent(InputRouter.INTENT_CONFIRM)
	AudioManager.music_step = 0
	pause.handle_intent(InputRouter.INTENT_LEFT)
	_assert(AudioManager.music_step == 0, "Music adjustment escaped its lower bound.")

	pause.focus_target = PauseController.FocusTarget.BACK
	_assert(pause.confirm(), "BACK did not resume the run.")
	_assert(GameFlow.current_state == GameFlow.RUNNING and GameFlow.gameplay_input_enabled and GameFlow.run_timer_enabled, "BACK did not resume the exact gameplay services.")
	hud.queue_free()
	if failures.is_empty():
		print("TASK20_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
