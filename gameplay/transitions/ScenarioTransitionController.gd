class_name ScenarioTransitionController
extends Node3D

signal completed
signal handoff_covered

@export_range(0.05, 30.0, 0.05, "suffix:s") var duration := 1.5
@export var camera_start_offset := Vector3(4.0, 2.7, 8.0)
@export var camera_end_offset := Vector3(-2.5, 2.2, 7.0)

var is_running := false
var context: Dictionary = {}
var _elapsed := 0.0
var transition_camera: Camera3D
var subject: Node3D
var _source_camera: Camera3D
var _entry_transform := Transform3D.IDENTITY
var _covered := false
var _character_subject: Node3D
var _entry_subject_position := Vector3.ZERO


func start(transition_context: Dictionary) -> void:
	context = transition_context.duplicate()
	_elapsed = 0.0
	is_running = true
	_covered = false
	subject = find_child("Proxy", true, false) as Node3D
	if subject == null:
		subject = find_child("PresentationProxy", true, false) as Node3D
	var character := context.get("character_definition") as CharacterDefinition
	if character != null and subject != null:
		if subject is MeshInstance3D:
			(subject as MeshInstance3D).mesh = null
		_character_subject = character.gameplay_cosmetic_scene.instantiate() as Node3D
		subject.add_child(_character_subject)
	var runner := context.get("runner") as RunnerController
	if runner != null:
		_entry_subject_position = runner.cosmetic_mount.global_position
		runner.visible = false
	_source_camera = context.get("gameplay_camera") as Camera3D
	if _source_camera != null:
		transition_camera = Camera3D.new()
		add_child(transition_camera)
		_entry_transform = _source_camera.global_transform
		transition_camera.global_transform = _entry_transform
		transition_camera.fov = _source_camera.fov
		transition_camera.environment = _source_camera.environment
		transition_camera.make_current()
	set_process(true)


func cancel() -> void:
	_restore_subject()
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
	_update_camera(delta)
	if _elapsed >= duration:
		force_complete()


func _update_camera(delta: float) -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	if _character_subject != null:
		_character_subject.global_position = _entry_subject_position.lerp(subject.global_position, smoothstep(0.0, 0.2, _elapsed))
	if transition_camera != null and subject != null:
		var offset := camera_start_offset.lerp(camera_end_offset, smoothstep(0.0, 1.0, progress))
		var target := subject.global_position
		var desired := Transform3D(Basis.IDENTITY, target + offset).looking_at(target, Vector3.UP)
		if _elapsed < 0.2:
			transition_camera.global_transform = _entry_transform.interpolate_with(desired, smoothstep(0.0, 0.2, _elapsed))
		else:
			transition_camera.global_transform = transition_camera.global_transform.interpolate_with(desired, 1.0 - exp(-10.0 * delta))
	var fx := context.get("fx") as CinematicTransitionFX
	if fx != null and progress > 0.88:
		fx.set_handoff_cover(smoothstep(0.88, 0.98, progress))
	if progress >= 0.98 and not _covered:
		_covered = true
		handoff_covered.emit()


func _restore_subject() -> void:
	var gameplay_owned := GameFlow.current_state in [GameFlow.RUNNING, GameFlow.TRANSITION_READY, GameFlow.TOKEN_COLLECTED, GameFlow.SCENARIO_TRANSITION, GameFlow.NEXT_SCENARIO, GameFlow.FAILURE_TRANSITION, GameFlow.LAVA_GAME_OVER]
	if is_instance_valid(context.get("runner")):
		context.runner.visible = gameplay_owned
	if is_instance_valid(_source_camera) and gameplay_owned:
		_source_camera.make_current()


func _exit_tree() -> void:
	_restore_subject()
