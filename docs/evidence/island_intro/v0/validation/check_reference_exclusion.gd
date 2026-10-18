extends SceneTree


func _initialize() -> void:
	var pending: Array[String] = ["res://"]
	var inspected := 0
	var forbidden: Array[String] = []
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		for child: String in DirAccess.get_directories_at(directory):
			if child.begins_with("."):
				continue
			var child_path := directory.path_join(child)
			if child_path.begins_with("res://docs/evidence/island_intro"):
				forbidden.append(child_path)
			pending.append(child_path)
		for filename: String in DirAccess.get_files_at(directory):
			inspected += 1
			var path := directory.path_join(filename)
			if path.begins_with("res://docs/evidence/island_intro/"):
				forbidden.append(path)
	if forbidden.is_empty() and inspected > 100:
		print("ISLAND_REFERENCE_EXCLUSION_PASS resources=%d" % inspected)
		quit(0)
	else:
		printerr("ISLAND_REFERENCE_EXCLUSION_FAIL resources=%d paths=%s" % [inspected, forbidden])
		quit(1)
