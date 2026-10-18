extends SceneTree


func _initialize() -> void:
	var pending: Array[String] = ["res://"]
	var forbidden: Array[String] = []
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		for child: String in DirAccess.get_directories_at(directory):
			if not child.begins_with("."): pending.append(directory.path_join(child))
		for filename: String in DirAccess.get_files_at(directory):
			var path := directory.path_join(filename)
			if path.begins_with("res://dev/island_scene/") or path.begins_with("res://dev/island_transition/") or path.begins_with("res://art/source/island_intro/") or path.begins_with("res://docs/evidence/island_intro/") or path.get_extension() in ["blend", "blend1"]:
				forbidden.append(path)
	if forbidden.is_empty():
		print("ISLAND_SCENE_PACK_PASS no study or editable/reference assets")
		quit(0)
	else:
		printerr("ISLAND_SCENE_PACK_FAIL ",forbidden)
		quit(1)
