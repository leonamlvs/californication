class_name TrackPool
extends Node

const DEFAULT_SEGMENT_SCENE := preload("res://gameplay/track/TrackSegment.tscn")
const COLLECTIBLE_SCENE := preload("res://gameplay/collectibles/CollectibleBase.tscn")

var obstacle_library: ObstacleSceneLibrary
var segment_root: Node3D
var obstacle_root: Node3D
var collectible_root: Node3D
var inactive_root: Node3D
var created_segment_count := 0
var created_obstacle_count := 0
var created_collectible_count := 0

var _available_segments: Array[TrackSegment] = []
var _available_obstacles: Dictionary = {}
var _available_collectibles: Array[CollectibleBase] = []


func configure(library: ObstacleSceneLibrary, active_segment_root: Node3D, active_obstacle_root: Node3D, active_collectible_root: Node3D, pooled_root: Node3D) -> void:
	obstacle_library = library
	segment_root = active_segment_root
	obstacle_root = active_obstacle_root
	collectible_root = active_collectible_root
	inactive_root = pooled_root


func acquire_segment(scene: PackedScene = null) -> TrackSegment:
	var segment: TrackSegment
	if not _available_segments.is_empty():
		segment = _available_segments.pop_back()
		segment.reparent(segment_root)
	else:
		var source := scene if scene != null else DEFAULT_SEGMENT_SCENE
		segment = source.instantiate() as TrackSegment
		segment_root.add_child(segment)
		created_segment_count += 1
	segment.visible = true
	return segment


func release_segment(segment: TrackSegment) -> void:
	if segment == null:
		return
	for obstacle: ObstacleBase in segment.active_obstacles.duplicate():
		release_obstacle(obstacle)
	for collectible: CollectibleBase in segment.active_collectibles.duplicate():
		release_collectible(collectible)
	segment.reset_for_pool()
	segment.reparent(inactive_root)
	_available_segments.append(segment)


func acquire_obstacle(definition: ObstacleDefinition) -> ObstacleBase:
	if definition == null or obstacle_library == null:
		return null
	var bucket: Array = _available_obstacles.get(definition.id, [])
	var obstacle: ObstacleBase
	if not bucket.is_empty():
		obstacle = bucket.pop_back() as ObstacleBase
		_available_obstacles[definition.id] = bucket
		obstacle.reparent(obstacle_root)
	else:
		var scene := obstacle_library.scene_for(definition.id)
		if scene == null:
			return null
		obstacle = scene.instantiate() as ObstacleBase
		obstacle_root.add_child(obstacle)
		created_obstacle_count += 1
	obstacle.definition = definition
	obstacle.visible = true
	return obstacle


func release_obstacle(obstacle: ObstacleBase) -> void:
	if obstacle == null or obstacle.definition == null:
		return
	var obstacle_id := obstacle.definition.id
	obstacle.prepare_for_pool()
	obstacle.reparent(inactive_root)
	var bucket: Array = _available_obstacles.get(obstacle_id, [])
	bucket.append(obstacle)
	_available_obstacles[obstacle_id] = bucket


func acquire_collectible() -> CollectibleBase:
	var collectible: CollectibleBase
	if not _available_collectibles.is_empty():
		collectible = _available_collectibles.pop_back()
		collectible.reparent(collectible_root)
	else:
		collectible = COLLECTIBLE_SCENE.instantiate() as CollectibleBase
		collectible_root.add_child(collectible)
		created_collectible_count += 1
	collectible.visible = true
	return collectible


func release_collectible(collectible: CollectibleBase) -> void:
	if collectible == null:
		return
	collectible.prepare_for_pool()
	collectible.reparent(inactive_root)
	_available_collectibles.append(collectible)


func available_segment_count() -> int:
	return _available_segments.size()


func available_obstacle_count() -> int:
	var total := 0
	for bucket: Array in _available_obstacles.values():
		total += bucket.size()
	return total


func available_collectible_count() -> int:
	return _available_collectibles.size()
