extends Node

## Reserved authoritative game-state boundary. Task 03 implements its state machine.
signal state_changed(previous_state: StringName, next_state: StringName)

var current_state: StringName = &"BOOT"


func request_transition(_next_state: StringName) -> bool:
	return false


func start_new_run() -> void:
	pass


func pause_run() -> void:
	pass


func resume_run() -> void:
	pass


func fail_run() -> void:
	pass


func exit_run() -> void:
	pass
