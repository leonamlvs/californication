class_name ObstacleHitEvent
extends RefCounted

var definition: ObstacleDefinition
var obstacle: ObstacleBase
var contact_distance := 0.0
var runner_lane := -1
var was_avoided := false
var was_suppressed := false


func _init(source_definition: ObstacleDefinition = null, source_obstacle: ObstacleBase = null) -> void:
	definition = source_definition
	obstacle = source_obstacle
