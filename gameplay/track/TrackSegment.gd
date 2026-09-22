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
