extends Node

const Study = preload("res://dev/island_scene/IslandLiveStudy.gd")
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value: failures.append(message)


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,720)
	viewport.own_world_3d = true
	add_child(viewport)
	var scene := Study.new()
	scene.profile = load("res://dev/island_scene/transition.tres")
	viewport.add_child(scene)
	var meshes := scene.pivot.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "Island must have one mesh")
	if meshes.is_empty():
		printerr("ISLAND_SCENE_FAIL: missing mesh")
		get_tree().quit(1)
		return
	var mesh: Mesh = meshes[0].mesh
	check(mesh.get_surface_count() == 1, "Island must have one material surface")
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	check(indices.size() / 3 <= 15000 and indices.size() / 3 > 1000, "Triangle budget violated")
	check(uvs.size() == vertices.size(), "Missing UV coordinates")
	check(mesh.get_aabb().position.y < 0.0 and mesh.get_aabb().end.y > 2.0, "Missing submerged edge or actual terrain relief")
	check(scene.island_texture.get_size() == Vector2(2048,2048), "Color atlas dimensions changed")
	check(scene.ocean.mesh is PlaneMesh and scene.ocean.mesh.get_faces().size() == 6, "Water must be one two-triangle plane")
	var profile: IslandTransitionProfile = scene.profile
	check(profile.times.size() == 14 and profile.targets.size() == 14, "Missing camera measurements")
	for i: int in range(1,profile.times.size()):
		check(profile.times[i] > profile.times[i-1], "Nonmonotonic camera time")
		check(profile.ortho_sizes[i] > profile.ortho_sizes[i-1], "Pullback scale reverses")
	for i: int in range(14):
		var pose := profile.sample(profile.times[i])
		check(absf(pose.size-profile.ortho_sizes[i]) < 0.0001, "Camera misses a measured frame pose")
	var before: Dictionary = profile.sample(profile.settle_end)
	var after: Dictionary = profile.sample(profile.settle_end+300.0)
	check(is_equal_approx(before.size,after.size) and before.target.is_equal_approx(after.target), "Attract resets the settled camera")
	check(absf(rad_to_deg(profile.rotation_at(20.0)-profile.rotation_at(19.0))-5.0)<0.001, "Attract rotation speed differs")
	for degrees: int in range(0,361,5):
		scene.sample(profile.settle_end, false, deg_to_rad(float(degrees)))
		for vertex: Vector3 in vertices:
			var projected: Vector2 = scene.camera.unproject_position(meshes[0].global_transform*vertex)
			check(projected.x>=0 and projected.x<=960 and projected.y>=0 and projected.y<=720, "Island clipped during rotation at %d degrees"%degrees)
		var mapping: Transform3D = scene.ocean_material.get_shader_parameter("island_from_world")
		check((mapping*scene.pivot.global_transform).is_equal_approx(Transform3D.IDENTITY), "Static shoreline map lost island alignment")
	# Ocean covers all picture corners during every authored camera sample.
	for t: float in profile.times:
		scene.sample(t,false)
		for corner: Vector2 in [Vector2.ZERO,Vector2(960,0),Vector2(0,720),Vector2(960,720)]:
			var origin := scene.camera.project_ray_origin(corner)
			var direction := scene.camera.project_ray_normal(corner)
			var intersection := origin-direction*(origin.y/direction.y)
			check(absf(intersection.x)<120 and absf(intersection.z)<120,"Ocean plane does not cover camera")
	if failures.is_empty():
		print("ISLAND_SCENE_PASS triangles=%d rotation_poses=73 camera_knots=14" % (indices.size()/3))
		get_tree().quit(0)
	else:
		for failure in failures.slice(0,20):printerr("ISLAND_SCENE_FAIL: ",failure)
		get_tree().quit(1)
