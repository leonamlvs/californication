class_name IslandRuntimeOceanProfile
extends Resource

## Untouched full video frame aligned beneath the island. Animation is disabled.
@export var color_plate: Texture2D = preload("res://frontend/island/live/assets/ocean-frame.png")
@export var deep_texture: Texture2D = preload("res://frontend/island/live/assets/ocean-deep-color.png")
@export var deep_tile_size := 16.0
## Retained data for the later wave-animation revision; unused by this material.
@export var shore_data: Texture2D = preload("res://frontend/island/live/assets/ocean-shore.png")
@export var ripple_texture: Texture2D = preload("res://frontend/island/live/assets/ocean-ripple.png")
@export var foam_color := Color("b2eaf2")
@export var map_size := Vector2(32.0, 24.536174)
@export var map_center := Vector2.ZERO
@export var distance_range := 4.0
@export var wave_spacing := 0.6
@export var wave_speed := 0.09
@export var wave_strength := 0.0
@export var wave_reach := 2.2
@export var wave_breakup := 0.3
@export var ripple_tile_size := 9.0
@export var ripple_strength := 0.0
@export var ripple_velocity_a := Vector2(0.012, 0.007)
@export var ripple_velocity_b := Vector2(-0.008, 0.011)
@export var phase_origin := 3.737066666666667


func apply(material: ShaderMaterial) -> void:
	for property: String in ["color_plate", "deep_texture", "deep_tile_size", "map_size", "map_center"]:
		material.set_shader_parameter(property, get(property))


func phases_at(seconds: float) -> Dictionary:
	# Double precision controller clock, bounded shader phases. Every wrap is
	# periodic: long attract waits do not lose precision or reset animation.
	var t := seconds - phase_origin
	return {
		"wave_phase": fposmod(t * wave_speed / maxf(wave_spacing, 0.001), 1.0),
		"ripple_offset_a": _periodic_offset(t, ripple_velocity_a),
		"ripple_offset_b": _periodic_offset(t, ripple_velocity_b)
	}


func _periodic_offset(seconds: float, velocity: Vector2) -> Vector2:
	var offset := Vector2(fposmod(seconds*velocity.x, 1.0), fposmod(seconds*velocity.y, 1.0))
	# Vector2 stores float32: values infinitesimally below one can round to one.
	# Canonicalize to the equivalent periodic origin after that conversion.
	if offset.x >= 1.0: offset.x = 0.0
	if offset.y >= 1.0: offset.y = 0.0
	return offset


func sample(_material: ShaderMaterial, _seconds: float) -> void:
	# Controller interface preserved; static review does not change any uniforms.
	pass
