class_name BoulevardCurbsideTransition
extends ScenarioTransitionController

enum Stage {
	CURBSIDE_ENTRY,
	TRASH_CAN_JUMP,
	FALL_TO_TARGET,
}

@onready var proxy: MeshInstance3D = %Proxy
@onready var trash_can: MeshInstance3D = %TrashCan

var current_stage: Stage = Stage.CURBSIDE_ENTRY
var stage_history: Array[Stage] = []


func start(transition_context: Dictionary) -> void:
	super.start(transition_context)
	current_stage = Stage.CURBSIDE_ENTRY
	stage_history = [current_stage]
	proxy.position = Vector3(-1.8, 0.9, 2.0)
	trash_can.rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if is_running:
		_update_authored_route()
	super._process(delta)


func _update_authored_route() -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	if progress < 0.3:
		_set_stage(Stage.CURBSIDE_ENTRY)
		proxy.position = Vector3(lerpf(-1.8, 0.1, progress / 0.3), 0.9, lerpf(2.0, -1.0, progress / 0.3))
	elif progress < 0.65:
		_set_stage(Stage.TRASH_CAN_JUMP)
		var jump_progress := (progress - 0.3) / 0.35
		proxy.position = Vector3(lerpf(0.1, 1.3, jump_progress), 0.9 + 2.2 * sin(jump_progress * PI), lerpf(-1.0, -4.0, jump_progress))
		trash_can.rotation.z = -0.25 * jump_progress
	else:
		_set_stage(Stage.FALL_TO_TARGET)
		var fall_progress := (progress - 0.65) / 0.35
		proxy.position = Vector3(lerpf(1.3, 2.0, fall_progress), lerpf(0.9, -3.0, fall_progress), lerpf(-4.0, -10.0, fall_progress))


func _set_stage(next_stage: Stage) -> void:
	if current_stage == next_stage:
		return
	current_stage = next_stage
	stage_history.append(current_stage)
