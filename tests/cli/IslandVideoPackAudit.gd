extends SceneTree


func _initialize() -> void:
	var preview := "--preview" in OS.get_cmdline_user_args()
	var pending: Array[String] = ["res://"]
	var failures: Array[String] = []
	var count := 0
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		for child: String in DirAccess.get_directories_at(directory):
			if not child.begins_with("."):
				pending.append(directory.path_join(child))
		for filename: String in DirAccess.get_files_at(directory):
			var path := directory.path_join(filename)
			count += 1
			if path.begins_with("res://docs/evidence/island_intro/") or path.get_extension().to_lower() in ["mp4", "ogv", "blend"]:
				failures.append(path)
	if preview and not FileAccess.file_exists("res://frontend/island/video/island_video.js"):
		failures.append("Missing browser bridge")
	if failures.is_empty() and count > 0:
		print("ISLAND_VIDEO_PACK_PASS preview=%s resources=%d" % [preview, count])
		quit(0)
	else:
		printerr("ISLAND_VIDEO_PACK_FAIL ", failures)
		quit(1)
