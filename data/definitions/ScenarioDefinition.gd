class_name ScenarioDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export var movement_mode: StringName = &"RUN"
@export_range(0.1, 100.0, 0.1, "suffix:m/s") var base_speed := 10.0
@export_range(0.1, 100.0, 0.1, "suffix:m/s") var max_speed := 16.0
@export_range(0.1, 10.0, 0.1, "suffix:m") var lane_spacing := 1.6
@export var segment_library: Array[SegmentDefinition] = []
@export var obstacle_library: ObstacleSceneLibrary
@export var collectible_patterns: CollectibleLayoutLibrary
@export var environment_scene: PackedScene
@export var camera_profile: Resource
@export var hud_coordinate_profile: Resource
@export var transition_definition: TransitionDefinition
@export_range(0.0, 600.0, 0.5, "suffix:s") var minimum_transition_time := 40.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var guaranteed_transition_time := 55.0
@export_range(0.0, 120.0, 0.5, "suffix:s") var development_minimum_transition_time := 15.0
@export_range(0.0, 120.0, 0.5, "suffix:s") var development_guaranteed_transition_time := 20.0
@export var movement_profile: MovementProfile
@export var movement_capability_profile: MovementCapabilityProfile
@export var failure_family: StringName = &"floor_fall"
@export var scenario_component_scene: PackedScene


func is_valid_definition(development_fixture := false) -> bool:
	if id.is_empty() or display_name.is_empty() or movement_mode.is_empty():
		return false
	if base_speed <= 0.0 or max_speed < base_speed or lane_spacing <= 0.0:
		return false
	if segment_library.is_empty() or obstacle_library == null or collectible_patterns == null:
		return false
	if environment_scene == null or camera_profile == null or hud_coordinate_profile == null or movement_profile == null or movement_capability_profile == null:
		return false
	if movement_profile.movement_mode != movement_mode or movement_capability_profile.movement_mode != movement_mode or not movement_capability_profile.is_valid_profile() or transition_definition == null or not transition_definition.is_valid_definition():
		return false
	if transition_definition.source_scenario != id:
		return false
	if guaranteed_transition_time < minimum_transition_time:
		return false
	if failure_family != &"floor_fall" and failure_family != &"launch":
		return false
	if development_fixture and development_guaranteed_transition_time < development_minimum_transition_time:
		return false
	return true
