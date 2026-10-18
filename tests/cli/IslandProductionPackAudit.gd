extends SceneTree

func _initialize() -> void:
	var pending: Array[String] = ["res://"]
	var files: Array[String] = []
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		for child: String in DirAccess.get_directories_at(directory):
			if not child.begins_with("."):
				pending.append(directory.path_join(child))
		for filename: String in DirAccess.get_files_at(directory):
			files.append(directory.path_join(filename))
	var required := [
		"IslandProductionSequence", "island-color", "island.glb", "ocean-shore",
		"ocean-ripple", "ocean_animated", "live_soft_blur", "island_video.js",
	]
	var missing: Array[String] = []
	for name: String in required:
		if not files.any(func(path: String) -> bool: return name in path):
			missing.append(name)
	var forbidden := files.filter(func(path: String) -> bool:
		return path.ends_with(".ogv") or path.ends_with(".mp4") or path.begins_with("res://dev/") or path.begins_with("res://art/source/")
	)
	if missing.is_empty() and forbidden.is_empty():
		print("ISLAND_PRODUCTION_PACK_PASS resources=", files.size(), " runtime scene, flat ocean, video bridge; native/source media excluded")
		quit(0)
	else:
		printerr("ISLAND_PRODUCTION_PACK_FAIL missing=", missing, " forbidden=", forbidden)
		quit(1)
