extends Control

const Study = preload("res://dev/island_scene/IslandLiveStudy.gd")
const Playback = preload("res://frontend/island/video/IslandVideoPlayback.gd")
var scene: Node3D
var picture: TextureRect
var viewport: SubViewport
var reference: TextureRect
var controls: HFlowContainer
var status: Label
var timeline: HSlider
var elapsed := 3.737066666666667
var running := true
var focus_active := true
var _skip_next_delta := false
var relief_view := false
var water_only := true
var _web_callback: JavaScriptObject
var _web_interface: JavaScriptObject


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	scene = Study.new()
	scene.profile = load("res://dev/island_scene/transition.tres")
	viewport.add_child(scene)
	picture = TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	reference = TextureRect.new()
	reference.texture = load("res://dev/island_scene/reference.png")
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference.hide()
	add_child(reference)
	controls = HFlowContainer.new()
	controls.add_theme_constant_override("separation", 6)
	add_child(controls)
	for label in ["Pullback", "Pause", "Rotate", "Water", "Ref", "Relief"]:
		var button := Button.new()
		button.text = label
		button.pressed.connect(command.bind(label.to_lower()))
		controls.add_child(button)
	timeline = HSlider.new()
	timeline.min_value = scene.profile.blend_start
	timeline.max_value = scene.profile.settle_end
	timeline.step = 0.0001
	timeline.value = elapsed
	timeline.value_changed.connect(func(value: float): elapsed = value; running = false; scene.sample(elapsed))
	add_child(timeline)
	status = Label.new()
	status.position = Vector2(10, 10)
	add_child(status)
	resized.connect(_layout)
	_layout()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.islandStudy={command:null,state:null};", true)
		_web_interface = JavaScriptBridge.get_interface("islandStudy")
		_web_callback = JavaScriptBridge.create_callback(_web_command)
		_web_interface.command = _web_callback
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_suite.call_deferred(argument.trim_prefix("--capture="))
		elif argument.begins_with("--capture-ocean="):
			_capture_ocean.call_deferred(argument.trim_prefix("--capture-ocean="))
		elif argument == "--static-water":
			scene.animated_water = false
			scene.configure_ocean()


func _layout() -> void:
	if picture == null:
		return
	var rect := Playback.fit_picture(Rect2(Vector2.ZERO, size))
	picture.position = rect.position
	picture.size = rect.size
	reference.position = rect.position
	reference.size = rect.size
	controls.size.x = maxf(size.x - 20, 1)
	controls.position = Vector2(10, size.y - (100 if size.x < 430 else 68))
	timeline.position = Vector2(10, size.y - 30)
	timeline.size = Vector2(maxf(size.x - 20, 1), 20)


func _process(delta: float) -> void:
	if _skip_next_delta:
		delta = 0.0
		_skip_next_delta = false
	if running and focus_active:
		elapsed += delta
		if water_only:
			scene.sample_water(elapsed)
		else:
			scene.sample(elapsed)
		timeline.set_value_no_signal(minf(elapsed, timeline.max_value))
	status.text = "V3 water study | %.3f s | %s" % [elapsed, "SOURCE FRAME 199" if reference.visible else "LIVE 3D"]
	if _web_interface != null:
		_web_interface.state = JSON.stringify({"time":elapsed,"running":running,"reference":reference.visible,"size":scene.camera.size,"water_time":scene.water_time,"focus_active":focus_active,"wave_phase":scene.ocean_material.get_shader_parameter("wave_phase"),"rotation":scene.pivot.rotation.y})


func command(value: String) -> void:
	match value:
		"pullback":
			water_only = false
			elapsed = scene.profile.blend_start
			running = true
			reference.hide()
		"pause": running = false
		"rotate":
			water_only = false
			elapsed = scene.profile.settle_end
			running = true
			reference.hide()
		"water":
			elapsed = scene.profile.reveal_time
			scene.sample(elapsed, false)
			water_only = true
			running = true
			reference.hide()
		"reference", "ref":
			running = false
			elapsed = scene.profile.reveal_time
			scene.sample(elapsed, false)
			reference.visible = not reference.visible
		"relief":
			reference.hide()
			relief_view = not relief_view
			scene.set_relief_view(relief_view)
		_:
			if value.begins_with("seek:"):
				water_only = false
				running = false
				elapsed = value.trim_prefix("seek:").to_float()
				scene.sample(elapsed)


func _web_command(arguments: Array) -> void:
	if not arguments.is_empty(): command(str(arguments[0]))


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		focus_active = false
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		focus_active = true
		_skip_next_delta = true


func _capture_suite(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	running = false
	# Preserve the V2 capture recipe; V3 has its own capture/evidence directory.
	scene.animated_water = false
	scene.configure_ocean()
	controls.hide(); timeline.hide(); status.hide()
	for index: int in range(186, 200):
		elapsed = float(index - 87) * 1001.0 / 30000.0
		scene.sample(elapsed, false)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(directory.path_join("live_%04d.png" % index))
	for angle: int in [0, 45, 90, 135, 180, 225, 270, 315, 360]:
		scene.sample(scene.profile.settle_end, false, deg_to_rad(float(angle)))
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(directory.path_join("rotation_%03d.png" % angle))
	scene.set_relief_view(true)
	scene.sample(scene.profile.settle_end, false)
	scene.camera.position = Vector3(17.0, 28.0, 28.0)
	scene.camera.look_at(Vector3.ZERO)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(directory.path_join("relief-oblique.png"))
	scene.set_relief_view(false)
	# Record a deterministic camera/settle/rotation preview; source-speed playback at 30fps.
	for index: int in range(150):
		elapsed = scene.profile.blend_start + float(index) / 30.0
		scene.sample(elapsed)
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(directory.path_join("preview_%04d.png" % index))
	print("ISLAND_SCENE_CAPTURE_PASS")
	get_tree().quit(0)


func _ocean_capture(directory: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(directory.path_join(name + ".png"))


func _capture_ocean(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	running = false
	controls.hide(); timeline.hide(); status.hide()
	var origin: float = scene.ocean_profile.phase_origin
	scene.sample(scene.profile.reveal_time, false)
	for pair: Array in [["reveal", origin], ["later", origin+2.0], ["repeat", origin], ["long-wait", origin+86400.0]]:
		scene.sample_water(pair[1])
		await _ocean_capture(directory, pair[0])
	# Sample both sides of wave and UV wraps at a fixed camera/island pose.
	var period: float = scene.ocean_profile.wave_spacing / scene.ocean_profile.wave_speed
	for pair: Array in [["wave-wrap-before", origin+period-0.001], ["wave-wrap-after", origin+period+0.001], ["ripple-wrap-before", origin+1.0/scene.ocean_profile.ripple_velocity_a.x-0.001], ["ripple-wrap-after", origin+1.0/scene.ocean_profile.ripple_velocity_a.x+0.001]]:
		scene.sample_water(pair[1])
		await _ocean_capture(directory, pair[0])
	for angle: int in range(0, 361, 45):
		scene.sample(scene.profile.settle_end, false, deg_to_rad(float(angle)))
		scene.sample_water(origin)
		await _ocean_capture(directory, "rotation_%03d" % angle)
	# Fixed view isolates the subtle water motion at its real speed.
	scene.sample(scene.profile.reveal_time, false)
	for index: int in range(150):
		scene.sample_water(origin + float(index)/30.0)
		await _ocean_capture(directory, "water_%04d" % index)
	# Entire 72-second rotation sampled at 5 fps for coverage inspection.
	for index: int in range(361):
		var t: float = scene.profile.settle_end + float(index)/5.0
		scene.sample(t, false, deg_to_rad(float(index)))
		await _ocean_capture(directory, "turn_%04d" % index)
	print("ISLAND_OCEAN_CAPTURE_PASS")
	get_tree().quit(0)
