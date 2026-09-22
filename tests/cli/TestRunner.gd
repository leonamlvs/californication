extends SceneTree

const MAIN_SCENE_PATH := "res://main/Main.tscn"


func _initialize() -> void:
	var main_scene := ResourceLoader.load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		_fail("Could not load %s." % MAIN_SCENE_PATH)
		return

	var main_instance := main_scene.instantiate()
	root.add_child(main_instance)

	for required_node in [&"PresentationRoot", &"PresentationRoot/World", &"PresentationRoot/FrontendLayer", &"PresentationRoot/OverlayLayer"]:
		if main_instance.get_node_or_null(required_node) == null:
			_fail("Main scene is missing required composition node: %s" % required_node)
			return

	main_instance.queue_free()
	print("Task 00 foundation smoke test passed.")
	quit(0)


func _fail(message: String) -> void:
	printerr("Task 00 foundation smoke test failed: %s" % message)
	quit(1)
