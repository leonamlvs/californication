extends Control

## Development-only loading-screen seeker. Left/Right changes checkpoints; S captures.

const CHECKPOINT_FRAMES: Array[int] = [11, 20, 40, 60, 70, 71]

@onready var presentation: LoadingPresentation = $LoadingPresentation

var checkpoint_index := 0
var capture_index := 0
var output_directory := ""
var diagnostic_mode := 0
var capture_effects := false


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	output_directory = ProjectSettings.globalize_path("res://.godot/loading-comparison")
	capture_effects = arguments.has("--capture-loading-effects")
	for argument: String in arguments:
		if argument.begins_with("--loading-output="):
			output_directory = argument.trim_prefix("--loading-output=")
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
	elif event.keycode == KEY_B:
		presentation.foreground.visible = not presentation.foreground.visible
	elif event.keycode == KEY_D:
		diagnostic_mode = posmod(diagnostic_mode + 1, 4)
		presentation.foreground.visible = false
		presentation.background_map.texture_rect.material.set_shader_parameter("diagnostic_mode", diagnostic_mode)


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
	DirAccess.make_dir_recursive_absolute(output_directory)
	get_window().size = Vector2i(960, 720)
	await RenderingServer.frame_post_draw
	var first_frame_path := output_directory.path_join("loading-first-visible-960x720.png")
	var first_presentation_image := get_viewport().get_texture().get_image()
	first_presentation_image.save_png(first_frame_path)
	print("LOADING_PREVIEW_CAPTURE " + first_frame_path)
	var first_mask := presentation.background_map.vertical_viewport.get_texture().get_image()
	var first_source := presentation.background_map.viewport.get_texture().get_image()
	if first_source.get_pixel(260, 110).a < 0.9 or first_mask.get_pixel(260, 81).g < 0.1:
		push_error("Loading's first visible frame did not contain the complete SVG/blur pipeline.")
		get_tree().quit(1)
		return
	if capture_effects:
		await _capture_effect_diagnostics()
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
			var captured := get_viewport().get_texture().get_image()
			captured.save_png(path)
			if dimensions == Vector2i(960, 720) and source_frame == 11 and first_presentation_image.get_data() != captured.get_data():
				push_error("First loading frame differs from the settled empty composition.")
				get_tree().quit(1)
				return
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
	var replacement_image := Image.create(240, 120, false, Image.FORMAT_RGBA8)
	replacement_image.fill(Color(0.8, 0.6, 0.9, 1.0))
	presentation.background_texture = ImageTexture.create_from_image(replacement_image)
	presentation.refresh_background()
	for settle_frame: int in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var replacement_path := output_directory.path_join("loading-replacement-texture-960x720.png")
	get_viewport().get_texture().get_image().save_png(replacement_path)
	print("LOADING_PREVIEW_CAPTURE " + replacement_path)
	get_tree().quit(0)


func _capture_effect_diagnostics() -> void:
	var background := presentation.background_map
	var first_generation: int = background.snapshot().render_generation
	var first_texture := background.vertical_viewport.get_texture().get_image()
	presentation.foreground.hide()
	var material := background.texture_rect.material as ShaderMaterial
	for mode: int in range(4):
		material.set_shader_parameter("diagnostic_mode", mode)
		await RenderingServer.frame_post_draw
		var name: String = ["background", "artwork", "halo", "shadow"][mode]
		get_viewport().get_texture().get_image().save_png(output_directory.path_join("diagnostic-%s-960x720.png" % name))
	background.viewport.get_texture().get_image().save_png(output_directory.path_join("diagnostic-source.png"))
	first_texture.save_png(output_directory.path_join("diagnostic-blurred-mask.png"))
	background.hide()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_directory.path_join("diagnostic-backdrop-960x720.png"))
	presentation.foreground.show()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_directory.path_join("diagnostic-foreground-960x720.png"))
	background.show()
	await RenderingServer.frame_post_draw
	var settled := background.snapshot()
	if settled.render_generation != first_generation or settled.effect_update_modes != [SubViewport.UPDATE_DISABLED, SubViewport.UPDATE_DISABLED]:
		push_error("Loading blur cache rerendered while seeking or failed to settle to UPDATE_DISABLED: %s" % settled)
		get_tree().quit(1)
	material.set_shader_parameter("diagnostic_mode", 0)
	presentation.foreground.show()
	print("LOADING_EFFECTS_CACHE_PASS generation=%d" % first_generation)
