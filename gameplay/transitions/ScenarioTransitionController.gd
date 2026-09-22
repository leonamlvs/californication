class_name ScenarioTransitionController
extends Node3D

signal completed

@export_range(0.05, 30.0, 0.05, "suffix:s") var duration := 1.5

var is_running := false
var context: Dictionary = {}
var _elapsed := 0.0


func start(transition_context: Dictionary) -> void:
	context = transition_context.duplicate()
	_elapsed = 0.0
	is_running = true
	set_process(true)


func cancel() -> void:
	is_running = false
	_elapsed = 0.0
	context.clear()
	set_process(false)


func force_complete() -> void:
	if not is_running:
		return
	is_running = false
	set_process(false)
	completed.emit()


func _process(delta: float) -> void:
	if not is_running:
		return
	_elapsed += delta
	if _elapsed >= duration:
		force_complete()
