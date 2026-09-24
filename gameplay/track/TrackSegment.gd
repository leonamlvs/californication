class_name TrackSegment
extends Node3D

var definition: SegmentDefinition
var pattern: PatternDefinition
var start_distance := 0.0
var end_distance := 0.0
var legal_exit_state_mask := 0
var active_obstacles: Array[ObstacleBase] = []
var active_collectibles: Array[CollectibleBase] = []

@onready var floor_mesh: MeshInstance3D = %FloorMesh
var _dressing: Node3D
var _dressing_key := ""

func _ready() -> void:
	# Segment length changes must never mutate meshes shared by pooled siblings.
	floor_mesh.mesh = floor_mesh.mesh.duplicate()


func configure(segment_definition: SegmentDefinition, pattern_definition: PatternDefinition, distance: float, exit_mask: int) -> void:
	definition = segment_definition
	pattern = pattern_definition
	start_distance = distance
	end_distance = distance + segment_definition.length
	legal_exit_state_mask = exit_mask
	visible = true
	var box := floor_mesh.mesh as BoxMesh
	if box != null:
		box.size.z = segment_definition.length
		floor_mesh.position.z = -segment_definition.length * 0.5
	var key := "%s:%.2f" % [definition.id, definition.length]
	if key == _dressing_key:
		return
	_dressing_key = key
	if _dressing != null:
		remove_child(_dressing)
		_dressing.queue_free()
	_dressing = Node3D.new()
	add_child(_dressing)
	var aerial := definition.compatible_modes.has(&"FLY")
	var underwater := definition.compatible_modes.has(&"SWIM")
	floor_mesh.visible = not aerial and not underwater
	for z: int in range(0, ceili(definition.length), 5):
		for lane_edge: float in [-1.5, -0.5, 0.5, 1.5]:
			var x := lane_edge * definition.lane_spacing
			var marker := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.07, 0.025, 1.4)
			marker.mesh = mesh
			marker.position = Vector3(x, 0.035 if not aerial and not underwater else -1.3, -float(z))
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.6, 0.88, 0.83) if aerial or underwater else Color(0.82, 0.76, 0.56)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			marker.material_override = mat
			_dressing.add_child(marker)
		for side: int in [-1, 1]:
			var post := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.18, 0.9, 0.18)
			post.mesh = mesh
			post.position = Vector3(side * 3.4, 0.45, -float(z))
			_dressing.add_child(post)
			if definition.environment_tags.has(&"grass"):
				for tuft_index: int in range(3):
					var grass := MeshInstance3D.new()
					var blade := PrismMesh.new()
					blade.size = Vector3(0.25, 1.1 + tuft_index * 0.2, 0.12)
					grass.mesh = blade
					grass.position = Vector3(side * (4.2 + tuft_index * 0.55), 0.5, -float(z) - tuft_index)
					grass.set_meta("sway", float(z) + tuft_index)
					var material := StandardMaterial3D.new()
					material.albedo_color = Color(0.28, 0.46, 0.18)
					grass.material_override = material
					_dressing.add_child(grass)
			elif aerial:
				var cloud := MeshInstance3D.new()
				var cloud_mesh := SphereMesh.new()
				cloud_mesh.radius = 1.4
				cloud_mesh.height = 1.5
				cloud.mesh = cloud_mesh
				cloud.scale = Vector3(2.5, 0.6, 1.0)
				cloud.position = Vector3(side * 10.0, -3.0 + sin(float(z)), -float(z))
				_dressing.add_child(cloud)
				var building := MeshInstance3D.new()
				var tower := BoxMesh.new()
				tower.size = Vector3(2.0, 7.0 + float(z % 7), 2.0)
				building.mesh = tower
				building.position = Vector3(side * 6.5, -8.0, -float(z))
				_dressing.add_child(building)


func _process(_delta: float) -> void:
	if not visible or _dressing == null or not GameFlow.gameplay_input_enabled:
		return
	for child: Node3D in _dressing.get_children():
		if child.has_meta("sway"):
			child.rotation.z = sin(position.z * 0.3 + float(child.get_meta("sway"))) * 0.12


func update_visual(logical_distance: float) -> void:
	position = Vector3(0.0, 0.0, -(start_distance - logical_distance))


func reset_for_pool() -> void:
	definition = null
	pattern = null
	start_distance = 0.0
	end_distance = 0.0
	legal_exit_state_mask = 0
	active_obstacles.clear()
	active_collectibles.clear()
	position = Vector3.ZERO
	visible = false
