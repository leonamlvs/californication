class_name BayWaveTransition
extends ScenarioTransitionController

enum Stage { SURFACE, SHARK_WAVE, LAUNCH }

@onready var proxy: MeshInstance3D = %Proxy
@onready var surface: MeshInstance3D = %Surface
@onready var shark_wave: Node3D = %SharkWave

var current_stage: Stage = Stage.SURFACE
var stage_history: Array[Stage] = []


func start(transition_context: Dictionary) -> void:
	super.start(transition_context)
	current_stage = Stage.SURFACE
	stage_history = [current_stage]
	proxy.position = Vector3(0.0, -1.2, 1.5)
	shark_wave.visible = false


func _process(delta: float) -> void:
	if is_running:
		_update_authored_route()
	super._process(delta)


func _update_authored_route() -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	if progress < 0.3:
		_set_stage(Stage.SURFACE)
		proxy.position = Vector3(0.0, lerpf(-1.2, 1.0, progress / 0.3), lerpf(1.5, -1.5, progress / 0.3))
	elif progress < 0.7:
		_set_stage(Stage.SHARK_WAVE)
		shark_wave.visible = true
		proxy.position = Vector3(0.0, 1.0 + 0.25 * sin(progress * TAU), lerpf(-1.5, -7.0, (progress - 0.3) / 0.4))
		shark_wave.position.z = proxy.position.z
	else:
		_set_stage(Stage.LAUNCH)
		shark_wave.visible = false
		var launch_progress := (progress - 0.7) / 0.3
		proxy.position = Vector3(lerpf(0.0, 2.4, launch_progress), 1.0 + 3.2 * sin(launch_progress * PI), lerpf(-7.0, -12.0, launch_progress))


func _set_stage(next_stage: Stage) -> void:
	if current_stage == next_stage:
		return
	current_stage = next_stage
	stage_history.append(current_stage)
