extends Node

const Study = preload("res://dev/island_scene/IslandLiveStudy.gd")
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Study.new()
	scene.profile = load("res://dev/island_scene/transition.tres")
	add_child(scene)
	var profile: IslandOceanProfile = scene.ocean_profile
	check(profile.shore_data.get_size() == Vector2(1024,1024), "Packed shore map budget")
	check(profile.ripple_texture.get_size() == Vector2(256,256), "Ripple map budget")
	check(scene.ocean.mesh.get_faces().size() == 6 and scene.ocean.mesh.get_surface_count() == 1, "Ocean must be two triangles and one surface")
	var shader: String = scene.ocean_material.shader.code
	check(not "TIME" in shader and not "ALPHA" in shader and not "DEPTH" in shader, "Ocean must use explicit phases and opaque color shading")
	check(shader.count("texture(") == 3, "Ocean sample budget changed")
	check("world_position.xz /" in shader, "Deep water lost world coordinates")
	check(absf(profile.map_size.x-960.0/scene.profile.pixels_per_unit)<0.001, "Shore X mapping diverged")
	check(absf(profile.map_size.y-720.0/scene.profile.pixels_per_unit/sin(deg_to_rad(scene.profile.elevation_degrees)))<0.001, "Shore Z mapping diverged")
	var data := profile.shore_data.get_image()
	for i: int in range(1024):
		for p: Vector2i in [Vector2i(i,0),Vector2i(i,1023),Vector2i(0,i),Vector2i(1023,i)]:
			var c := data.get_pixelv(p)
			check(c.r == 1.0 and c.g == 0.0 and c.a == 0.0, "Shore boundary must meet constant deep water")
	# Imported alpha carries shelf data, so automatic alpha-border repair must be off.
	check(data.get_pixel(0,0).r == 1.0, "Import corrupted packed data in transparent pixels")
	var t := 7.125
	scene.sample(t)
	var expected := profile.phases_at(t)
	scene.sample(1234.567)
	scene.sample(t)
	for key: String in expected:
		check(scene.ocean_material.get_shader_parameter(key) == expected[key], "Seeking must reproduce phases: "+key)
	scene.profile = scene.profile.duplicate()
	scene.profile.water_phase = 0.7
	scene.sample(t)
	check(is_equal_approx(scene.water_time,t+0.7), "Transition profile water phase ignored")
	scene.profile.water_phase = 0.0
	for degrees: int in range(0,361,5):
		scene.sample(t,false,deg_to_rad(float(degrees)))
		var mapping: Transform3D = scene.ocean_material.get_shader_parameter("island_from_world")
		check((mapping*scene.pivot.global_transform).is_equal_approx(Transform3D.IDENTITY), "Shore rotation alignment")
		check(scene.ocean.global_transform.is_equal_approx(Transform3D.IDENTITY), "World ocean must not rotate")
		check(scene.ocean_material.get_shader_parameter("ripple_offset_a") == expected.ripple_offset_a, "Rotation changed deep-water phase")
	for seconds: float in [0.0,3.3033,3.47013333,3.73706667,4.13706667,3600.0,86400.0,1000000000.0]:
		var phases := profile.phases_at(seconds)
		check(phases.wave_phase >= 0.0 and phases.wave_phase < 1.0, "Unbounded wave phase")
		for offset: Vector2 in [phases.ripple_offset_a,phases.ripple_offset_b]:
			check(offset.x>=0 and offset.x<1 and offset.y>=0 and offset.y<1, "Unbounded ripple offset")
	var period := profile.wave_spacing/profile.wave_speed
	var before := profile.phases_at(profile.phase_origin+period-0.0001)
	var after := profile.phases_at(profile.phase_origin+period+0.0001)
	check(absf(sin(before.wave_phase*TAU)-sin(after.wave_phase*TAU))<0.001, "Wave phase wraps discontinuously")
	# No free-running shader clock: holding input time must hold every shader phase.
	scene.sample(t)
	await get_tree().create_timer(0.12).timeout
	check(scene.water_time == t and scene.ocean_material.get_shader_parameter("wave_phase") == expected.wave_phase, "Paused scene advanced water")
	if failures.is_empty():
		print("ISLAND_OCEAN_PASS packed_edges=4096 rotation_poses=73 deterministic_clock=true samples=3")
		get_tree().quit(0)
	else:
		for failure in failures.slice(0,20): printerr("ISLAND_OCEAN_FAIL: ",failure)
		get_tree().quit(1)
