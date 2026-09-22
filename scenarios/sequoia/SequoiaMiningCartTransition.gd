class_name SequoiaMiningCartTransition
extends ScenarioTransitionController

enum Stage { CAVE_ENTRY, CART_ROUTE, CART_EXIT }

@onready var proxy: MeshInstance3D = %Proxy
@onready var cart: MeshInstance3D = %MiningCart
@onready var cave: Node3D = %Cave

var current_stage: Stage = Stage.CAVE_ENTRY
var stage_history: Array[Stage] = []


func start(transition_context: Dictionary) -> void:
	super.start(transition_context)
	current_stage = Stage.CAVE_ENTRY
	stage_history = [current_stage]
	proxy.position = Vector3(0.0, 0.9, 2.0)
	cart.position = Vector3(0.0, 0.45, -1.0)
	cave.visible = true


func _process(delta: float) -> void:
	if is_running:
		_update_authored_route()
	super._process(delta)


func _update_authored_route() -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	if progress < 0.25:
		_set_stage(Stage.CAVE_ENTRY)
		proxy.position = Vector3(0.0, 0.9, lerpf(2.0, -1.0, progress / 0.25))
	elif progress < 0.78:
		_set_stage(Stage.CART_ROUTE)
		var route_progress := (progress - 0.25) / 0.53
		var route_position := _sample_cart_route(route_progress)
		cart.position = route_position
		proxy.position = route_position + Vector3(0.0, 0.9, 0.0)
	else:
		_set_stage(Stage.CART_EXIT)
		var exit_progress := (progress - 0.78) / 0.22
		proxy.position = Vector3(lerpf(0.4, 2.2, exit_progress), 0.9 + 2.1 * sin(exit_progress * PI), lerpf(-10.0, -14.0, exit_progress))


## Fixed authored route: the player has no rail-switch input or branch.
func _sample_cart_route(progress: float) -> Vector3:
	var points := [Vector3(0.0, 0.45, -1.0), Vector3(-1.2, 0.7, -4.0), Vector3(0.8, 0.25, -7.0), Vector3(0.4, 0.45, -10.0)]
	var scaled := clampf(progress, 0.0, 1.0) * float(points.size() - 1)
	var index := mini(floori(scaled), points.size() - 2)
	return points[index].lerp(points[index + 1], scaled - float(index))


func _set_stage(next_stage: Stage) -> void:
	if current_stage == next_stage:
		return
	current_stage = next_stage
	stage_history.append(current_stage)
