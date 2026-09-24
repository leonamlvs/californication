class_name PickupFeedback
extends Node3D

var runner: RunnerController
var _sparks: Array[MeshInstance3D] = []
var _elapsed := 1.0

func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.86, 0.35)
	for index: int in range(8):
		var spark := MeshInstance3D.new()
		spark.mesh = mesh
		spark.material_override = material
		add_child(spark)
		_sparks.append(spark)
	visible = false

func burst() -> void:
	if runner == null:
		return
	position = runner.position + Vector3(0, 0.8, 0)
	_elapsed = 0.0
	visible = true

func _process(delta: float) -> void:
	if not visible or GameFlow.current_state == GameFlow.PAUSED:
		return
	_elapsed += delta
	var progress := _elapsed / 0.3
	visible = progress < 1.0 and GameFlow.gameplay_input_enabled
	for index: int in range(_sparks.size()):
		var angle := TAU * index / _sparks.size()
		_sparks[index].position = Vector3(cos(angle), sin(angle), 0.2) * progress * 0.8
		_sparks[index].scale = Vector3.ONE * maxf(0.01, 1.0 - progress)
