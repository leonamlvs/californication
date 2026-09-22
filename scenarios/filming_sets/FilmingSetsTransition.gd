class_name FilmingSetsTransition
extends ScenarioTransitionController

enum Stage { SPACE_ACTION, GLAMOROUS_ROMANTIC, WORKSHOP, EXIT_DOOR }

@onready var presentation_proxy: MeshInstance3D = %PresentationProxy
@onready var space_set: Node3D = %SpaceActionSet
@onready var romantic_set: Node3D = %RomanticSet
@onready var workshop_set: Node3D = %WorkshopSet
@onready var exit_door: MeshInstance3D = %ExitDoor

var current_stage: Stage = Stage.SPACE_ACTION
var stage_history: Array[Stage] = []


func start(transition_context: Dictionary) -> void:
	super.start(transition_context)
	current_stage = Stage.SPACE_ACTION
	stage_history = [current_stage]
	presentation_proxy.position = Vector3(0.0, 0.9, 2.0)
	_set_visibility(true, false, false, false)


func _process(delta: float) -> void:
	if is_running:
		_update_authored_stages()
	super._process(delta)


func _update_authored_stages() -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	if progress < 0.25:
		_set_stage(Stage.SPACE_ACTION)
		_set_visibility(true, false, false, false)
		presentation_proxy.position = Vector3(0.0, 0.9, lerpf(2.0, -1.5, progress / 0.25))
	elif progress < 0.5:
		_set_stage(Stage.GLAMOROUS_ROMANTIC)
		_set_visibility(false, true, false, false)
		presentation_proxy.position = Vector3(lerpf(-0.8, 0.8, (progress - 0.25) / 0.25), 0.9, lerpf(-1.5, -5.0, (progress - 0.25) / 0.25))
	elif progress < 0.75:
		_set_stage(Stage.WORKSHOP)
		_set_visibility(false, false, true, false)
		presentation_proxy.position = Vector3(0.0, 0.9, lerpf(-5.0, -8.5, (progress - 0.5) / 0.25))
	else:
		_set_stage(Stage.EXIT_DOOR)
		_set_visibility(false, false, false, true)
		var exit_progress := (progress - 0.75) / 0.25
		presentation_proxy.position = Vector3(0.0, 0.9 + 1.8 * sin(exit_progress * PI), lerpf(-8.5, -13.0, exit_progress))


func _set_visibility(show_space: bool, show_romantic: bool, show_workshop: bool, show_exit: bool) -> void:
	space_set.visible = show_space
	romantic_set.visible = show_romantic
	workshop_set.visible = show_workshop
	exit_door.visible = show_exit


func _set_stage(next_stage: Stage) -> void:
	if current_stage == next_stage:
		return
	current_stage = next_stage
	stage_history.append(current_stage)
