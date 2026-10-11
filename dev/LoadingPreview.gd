extends Control

## Development-only loading-screen seeker. Left/Right changes checkpoints; S captures.

const CHECKPOINT_FRAMES: Array[int] = [11, 20, 40, 60, 70, 71]

@onready var presentation: LoadingPresentation = $LoadingPresentation

var checkpoint_index := 0
var capture_index := 0


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument.begins_with("--loading-frame="):
			var requested := argument.trim_prefix("--loading-frame=").to_int()
			checkpoint_index = maxi(0, CHECKPOINT_FRAMES.find(requested))
	_seek_current()
	if arguments.has("--capture-loading-suite"):
		call_deferred("_capture_suite")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_LEFT:
		checkpoint_index = posmod(checkpoint_index - 1, CHECKPOINT_FRAMES.size())
		_seek_current()
	elif event.keycode == KEY_RIGHT:
		checkpoint_index = posmod(checkpoint_index + 1, CHECKPOINT_FRAMES.size())
		_seek_current()
	elif event.keycode == KEY_S:
		_capture()


func _seek_current() -> void:
	var frame := CHECKPOINT_FRAMES[checkpoint_index]
	var normalized := 0.975 if frame == 71 else clampf(float(frame - 11) / 59.0 * 0.95, 0.0, 0.95)
	presentation.set_progress(normalized)
	print("LOADING_PREVIEW frame=%d normalized=%.4f" % [frame, normalized])


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var frame := CHECKPOINT_FRAMES[checkpoint_index]
	var dimensions := get_window().size
	var path := "res://.godot/loading-preview-%02d-frame-%02d-%dx%d.png" % [capture_index, frame, dimensions.x, dimensions.y]
	get_viewport().get_texture().get_image().save_png(path)
	print("LOADING_PREVIEW_CAPTURE " + path)
	capture_index += 1


func _capture_suite() -> void:
	var output_directory := ProjectSettings.globalize_path("res://.godot/loading-comparison")
	DirAccess.make_dir_recursive_absolute(output_directory)
	get_window().size = Vector2i(960, 720)
	await RenderingServer.frame_post_draw
	var first_frame_path := output_directory.path_join("loading-first-visible-960x720.png")
	get_viewport().get_texture().get_image().save_png(first_frame_path)
	print("LOADING_PREVIEW_CAPTURE " + first_frame_path)
	for dimensions: Vector2i in [Vector2i(960, 720), Vector2i(1280, 720), Vector2i(844, 390), Vector2i(360, 640)]:
		get_window().size = dimensions
		for settle_frame: int in range(3):
			await get_tree().process_frame
		for index: int in CHECKPOINT_FRAMES.size():
			checkpoint_index = index
			_seek_current()
			await RenderingServer.frame_post_draw
			var source_frame := CHECKPOINT_FRAMES[index]
			var path := output_directory.path_join("loading-frame-%02d-%dx%d.png" % [source_frame, dimensions.x, dimensions.y])
			get_viewport().get_texture().get_image().save_png(path)
			print("LOADING_PREVIEW_CAPTURE " + path)
	get_window().size = Vector2i(844, 390)
	presentation.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	presentation.position = Vector2(36, 12)
	presentation.size = Vector2(788, 370)
	checkpoint_index = CHECKPOINT_FRAMES.find(40)
	_seek_current()
	for settle_frame: int in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var safe_path := output_directory.path_join("loading-frame-40-844x390-safe-inset.png")
	get_viewport().get_texture().get_image().save_png(safe_path)
	print("LOADING_PREVIEW_CAPTURE " + safe_path)
	get_window().size = Vector2i(960, 720)
	presentation.position = Vector2.ZERO
	presentation.size = Vector2(960, 720)
	var replacement_root := Node3D.new()
	var replacement_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 2.0, 0.5)
	replacement_mesh.mesh = box
	replacement_root.add_child(replacement_mesh)
	replacement_mesh.owner = replacement_root
	var replacement_scene := PackedScene.new()
	replacement_scene.pack(replacement_root)
	replacement_root.free()
	presentation.background_model_scene = replacement_scene
	presentation.background_model_rotation_degrees = Vector3(0, 20, 0)
	presentation.refresh_background_model()
	for settle_frame: int in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var replacement_path := output_directory.path_join("loading-replacement-box-960x720.png")
	get_viewport().get_texture().get_image().save_png(replacement_path)
	print("LOADING_PREVIEW_CAPTURE " + replacement_path)
	get_tree().quit(0)
