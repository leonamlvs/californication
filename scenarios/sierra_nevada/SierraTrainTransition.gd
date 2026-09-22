class_name SierraTrainTransition
extends ScenarioTransitionController

enum Stage {
	FALL_ONTO_TRAIN,
	TUNNEL_CROSSING,
	JUMP_AWAY,
}

@onready var proxy: MeshInstance3D = %Proxy
@onready var train_roof: MeshInstance3D = %TrainRoof
@onready var tunnel: MeshInstance3D = %Tunnel

var current_stage: Stage = Stage.FALL_ONTO_TRAIN
var stage_history: Array[Stage] = []


func start(transition_context: Dictionary) -> void:
	super.start(transition_context)
	current_stage = Stage.FALL_ONTO_TRAIN
	stage_history = [current_stage]
	proxy.position = Vector3(0.0, 5.0, 2.0)
	tunnel.visible = false


func _process(delta: float) -> void:
	if is_running:
		_update_authored_route()
	super._process(delta)


func _update_authored_route() -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	if progress < 0.3:
		_set_stage(Stage.FALL_ONTO_TRAIN)
		proxy.position = Vector3(0.0, lerpf(5.0, 1.3, progress / 0.3), lerpf(2.0, -2.0, progress / 0.3))
	elif progress < 0.7:
		_set_stage(Stage.TUNNEL_CROSSING)
		tunnel.visible = true
		proxy.position = Vector3(0.0, 1.3, lerpf(-2.0, -8.0, (progress - 0.3) / 0.4))
		train_roof.position.z = proxy.position.z
	else:
		_set_stage(Stage.JUMP_AWAY)
		tunnel.visible = false
		var jump_progress := (progress - 0.7) / 0.3
		proxy.position = Vector3(lerpf(0.0, 2.5, jump_progress), 1.3 + 2.2 * sin(jump_progress * PI), lerpf(-8.0, -13.0, jump_progress))


func _set_stage(next_stage: Stage) -> void:
	if current_stage == next_stage:
		return
	current_stage = next_stage
	stage_history.append(current_stage)
