class_name CollectibleLayoutLibrary
extends Resource

@export var layouts: Array[CollectibleLayout] = []


func is_valid_library(lane_count: int = 3) -> bool:
	if layouts.size() != CollectibleLayout.LayoutType.size():
		return false
	var ids: Dictionary = {}
	var types: Dictionary = {}
	for layout: CollectibleLayout in layouts:
		if layout == null or not layout.is_valid_definition(lane_count) or ids.has(layout.id) or types.has(layout.layout_type):
			return false
		ids[layout.id] = true
		types[layout.layout_type] = true
	return true


func compatible_layouts(mode: StringName) -> Array[CollectibleLayout]:
	var result: Array[CollectibleLayout] = []
	for layout: CollectibleLayout in layouts:
		if layout.is_mode_supported(mode):
			result.append(layout)
	return result
