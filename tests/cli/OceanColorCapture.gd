extends Node

const Study = preload("res://frontend/island/live/IslandRuntimeLiveScene.gd")
const PROFILE = preload("res://frontend/island/live/transition.tres")
var directory := "res://build/ocean-color/captures"
var study: Node3D
var view: SubViewport


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			directory = argument.trim_prefix("--output=")
	GameFlow.development_jump_to_state(GameFlow.BOOT)
	DirAccess.make_dir_recursive_absolute(directory)
	view = SubViewport.new()
	view.size = Vector2i(960, 720)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	study = Study.new()
	study.profile = PROFILE
	view.add_child(study)
	study.sample(PROFILE.reveal_time, false)
	await _capture("reveal")
	study.sample_water(86400.0)
	await _capture("static-later")
	for angle: int in range(0, 361, 45):
		study.sample(PROFILE.settle_end, true, deg_to_rad(angle))
		await _capture("rotation_%03d" % angle)
	study.sample(PROFILE.reveal_time, false)
	study.camera.size = 12.0
	await _capture("close-beach")
	print("OCEAN_COLOR_CAPTURE_PASS")
	get_tree().quit()


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error := view.get_texture().get_image().save_png(directory.path_join(name + ".png"))
	assert(error == OK)
