extends Control

const Study = preload("res://dev/island_scene/IslandLiveStudy.gd")
const Playback = preload("res://frontend/island/video/IslandVideoPlayback.gd")
const FX = preload("res://presentation/cinematic_fx/CinematicTransitionFX.tscn")
const MEDIA := "res://dev/island_video/media/"
@export var profile: IslandHandoffProfile = preload("res://dev/island_transition/handoff.tres")
var clock := IslandPresentationClock.new()
var study: Node3D
var fx: CinematicTransitionFX
var viewport: SubViewport
var picture: TextureRect
var poster: TextureRect
var prompt: Label
var player: IslandVideoPlayback
var scene_ready := false
var paused := false
var focused := true
var opacity := 1.0
var _started := false
var _interface: JavaScriptObject
var _callback: JavaScriptObject
var _native_capture := ""
var _previous_video_state: StringName = &"idle"


func _ready() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960,720)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	study = Study.new()
	study.profile = profile.camera_profile
	viewport.add_child(study)
	fx = FX.instantiate()
	viewport.add_child(fx)
	fx.begin_external(profile.blur_profile,CinematicTransitionFX.Quality.AUTO,true)
	fx.sample_external(0.5,1.0) # Compile the live blur behind the first-frame poster.
	picture = TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	poster = TextureRect.new()
	poster.texture = load(MEDIA+"poster.png")
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(poster)
	prompt = Label.new()
	prompt.text = "PRESS ENTER / TAP TO CONTINUE"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.hide()
	add_child(prompt)
	_new_player()
	resized.connect(_layout)
	_layout()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.islandTransition={command:null,state:null};",true)
		_interface = JavaScriptBridge.get_interface("islandTransition")
		_callback = JavaScriptBridge.create_callback(_web_command)
		_interface.command = _callback
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://dev/island_transition/preview_controls.js"),true)
	else:
		var bar := HBoxContainer.new()
		bar.position = Vector2(8,8)
		add_child(bar)
		for command: String in ["pause","play","restart","attract"]:
			var button := Button.new()
			button.text = command.capitalize()
			button.pressed.connect(_command.bind(command))
			bar.add_child(button)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	scene_ready = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-native="):
			_native_capture = argument.trim_prefix("--capture-native=")


func _new_player() -> void:
	if is_instance_valid(player):
		player.release()
		player.queue_free()
	player = Playback.new()
	player.process_priority = -20
	add_child(player)
	_previous_video_state = &"idle"
	player.state_changed.connect(_on_video_state_changed)
	if OS.has_feature("web"):
		player.prepare("index.island-intro.mp4","","index.poster.png")
	else:
		player.prepare("",MEDIA+"intro.ogv",MEDIA+"poster.png",MEDIA+"last.png")
	player.set_picture_rect(Playback.fit_picture(Rect2(Vector2.ZERO,size)))
	player.set_focus_active(focused)


func _on_video_state_changed(next: StringName) -> void:
	# The adapter's Retry/Start button executes inside the browser gesture. It
	# can restart between host frames and must also clear a paused host clock.
	if _previous_video_state in [&"error", &"gesture_required"] and next in [&"preparing", &"ready", &"playing"]:
		paused = false
		clock.reset()
	_previous_video_state = next


func _layout() -> void:
	if picture == null: return
	var rect := Playback.fit_picture(Rect2(Vector2.ZERO,size))
	for image: TextureRect in [picture,poster]:
		image.position = rect.position
		image.size = rect.size
	prompt.position = rect.position+Vector2(0.0,rect.size.y*0.88)
	prompt.size.x = rect.size.x
	player.set_picture_rect(rect)


func _process(delta: float) -> void:
	if not scene_ready: return
	if _interface != null:
		# DOM controls can blur the canvas while the browser window stays active.
		focused = bool(_interface.active)
	elif not _native_capture.is_empty():
		# Automated native capture runs in a hidden window; simulate active focus.
		focused = true
		player.set_focus_active(true)
	if not _started and player.is_prepared:
		_started = true
		poster.hide()
		if not paused: player.play()
	var snapshot := player.snapshot()
	var time := clock.advance(snapshot,delta,focused and not paused)
	_apply(time)
	if clock.live_tail and time >= profile.camera_profile.settle_end and player.state != &"released":
		player.release()
	if _interface != null:
		_interface.state = JSON.stringify({"time":time,"video":snapshot,"opacity":opacity,"tail":clock.live_tail,"paused":paused,"focused":focused,"camera_size":study.camera.size,"water_time":study.water_time,"blur":fx.shader_parameter(&"blur_strength"),"samples":fx.active_sample_count,"rotation":study.pivot.rotation.y,"ready":scene_ready})
	if not _native_capture.is_empty() and time > 6.0:
		viewport.get_texture().get_image().save_png(_native_capture)
		print("ISLAND_HANDOFF_NATIVE_PASS video released, live attract reached")
		get_tree().quit(0)


func _apply(time: float) -> void:
	study.sample(time)
	opacity = profile.video_opacity(time)
	player.set_opacity(opacity)
	var camera_profile := profile.camera_profile
	if time < camera_profile.settle_end:
		if not fx.is_active: fx.begin_external(profile.blur_profile,CinematicTransitionFX.Quality.AUTO,true)
		fx.sample_external(inverse_lerp(camera_profile.blend_start,camera_profile.settle_end,time),profile.blur_envelope(time))
	elif fx.is_active:
		fx.cancel(&"handoff_complete")
	prompt.visible = time >= camera_profile.settle_end


func _command(command: String) -> void:
	match command:
		"pause":
			paused = true
			player.pause()
		"play":
			paused = false
			player.play()
		"restart":
			paused = false
			_started = false
			clock.reset()
			poster.show()
			_new_player()
			_apply(0.0)
		"attract":
			paused = false
			_started = true
			poster.hide()
			player.release()
			clock.time = profile.camera_profile.settle_end
			clock.live_tail = true
			_apply(clock.time)


func _web_command(arguments: Array) -> void:
	if not arguments.is_empty(): _command(str(arguments[0]))


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		focused = false
		clock.advance({},0.0,false)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		focused = true


func _exit_tree() -> void:
	if is_instance_valid(player): player.release()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.islandTransition?.lifetime?.abort(); document.getElementById('transition-controls')?.remove(); delete window.islandTransition;",true)
