extends SceneTree

func _initialize() -> void:
	var pending: Array[String] = ["res://"]
	var count := 0
	var forbidden: Array[String] = []
	while not pending.is_empty():
		var path: String = pending.pop_back()
		for directory: String in DirAccess.get_directories_at(path):
			if not directory.begins_with("."):
				pending.append(path.path_join(directory))
		for filename: String in DirAccess.get_files_at(path):
			var file := path.path_join(filename)
			count += 1
			if file.begins_with("res://ref/") or file.begins_with("res://dev/") or file.begins_with("res://tests/") or "GameFlowPlaceholder" in file or file.get_extension().to_lower() in ["mp3", "mp4", "avi"]:
				forbidden.append(file)
	if forbidden.is_empty() and count > 100:
		print("PACK_CONTENT_PASS resources=%d no references, recorded audio, tests, or debug frontend" % count)
		quit(0)
	else:
		printerr("PACK_CONTENT_FAIL ", forbidden, " resources=", count)
		quit(1)
