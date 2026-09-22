class_name MovementMode
extends RefCounted

func enter(_runner: RunnerController, _profile: MovementProfile) -> void:
	pass


func exit(_runner: RunnerController) -> void:
	pass


func handle_intent(_runner: RunnerController, _intent: StringName) -> bool:
	return false


func physics_step(_runner: RunnerController, _delta: float) -> void:
	pass
