class_name HUDCoordinateProfile
extends Resource

## Decorative HUD telemetry only. These values deliberately never receive a
## player transform or gameplay distance.
@export var minimum: Vector3 = Vector3(-122.600, 37.700, 13.800)
@export var maximum: Vector3 = Vector3(-122.300, 37.950, 14.300)
@export_range(0.05, 2.0, 0.05, "suffix:s") var update_interval := 0.45


func is_valid_profile() -> bool:
	return minimum.x <= maximum.x and minimum.y <= maximum.y and minimum.z <= maximum.z and update_interval > 0.0


static func fallback_for_scenario(scenario_id: StringName) -> HUDCoordinateProfile:
	var profile := HUDCoordinateProfile.new()
	var ranges: Dictionary[StringName, Array] = {
		&"boulevard": [Vector3(-122.60, 37.70, 13.80), Vector3(-122.30, 37.95, 14.30)],
		&"sierra_nevada": [Vector3(-119.86, 38.75, 1850.0), Vector3(-119.45, 39.08, 2450.0)],
		&"san_francisco_bay": [Vector3(-122.55, 37.55, -38.0), Vector3(-122.25, 37.88, -4.0)],
		&"sequoia": [Vector3(-118.98, 36.35, 1200.0), Vector3(-118.55, 36.72, 2500.0)],
		&"filming_sets": [Vector3(-118.42, 34.08, 85.0), Vector3(-118.25, 34.20, 145.0)],
		&"golden_gate": [Vector3(-122.52, 37.79, 52.0), Vector3(-122.44, 37.84, 78.0)],
		&"hollywood": [Vector3(-118.38, 34.08, 220.0), Vector3(-118.24, 34.16, 720.0)],
		&"grass": [Vector3(-121.95, 36.35, 15.0), Vector3(-121.55, 36.72, 68.0)],
		&"earthquake": [Vector3(-118.42, 34.00, -12.0), Vector3(-118.12, 34.22, 42.0)],
	}
	var range: Array = ranges.get(scenario_id, [Vector3(-122.6, 37.7, 13.8), Vector3(-122.3, 37.95, 14.3)])
	profile.minimum = range[0]
	profile.maximum = range[1]
	return profile
