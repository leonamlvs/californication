class_name IslandProductionSequence
extends Control

const Study = preload("res://frontend/island/live/IslandRuntimeLiveScene.gd")
const Playback = preload("res://frontend/island/video/IslandVideoPlayback.gd")
const FX = preload("res://presentation/cinematic_fx/CinematicTransitionFX.tscn")
const MEDIA := "res://frontend/island/live/media/"

@export var profile: IslandRuntimeHandoffProfile = preload("res://frontend/island/live/handoff.tres")

var clock := IslandRuntimePresentationClock.new()
var study: Node3D
var fx: CinematicTransitionFX
var player: IslandVideoPlayback
var picture: TextureRect
var poster: TextureRect
var prompt: Label
var cover: ColorRect
var scene_ready := false
var intro_play_count := 0
var _started := false
var _focused := true
var _previous_video_state: StringName = &"idle"
var _cover_elapsed := -1.0
var _cover_duration := 0.30


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 720)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	study = Study.new()
	study.profile = profile.camera_profile
	viewport.add_child(study)
	fx = FX.instantiate()
	viewport.add_child(fx)
	fx.begin_external(profile.blur_profile, CinematicTransitionFX.Quality.AUTO, true)
	fx.sample_external(0.5, 1.0)
	picture = TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	poster = TextureRect.new()
	poster.texture = load(MEDIA + "poster.png")
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(poster)
	prompt = Label.new()
	prompt.text = "PRESS ENTER / TAP TO CONTINUE"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	cover = ColorRect.new()
	cover.color = Color("1f7ebd")
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	_new_player()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	GameFlow.state_changed.connect(_on_state_changed)
	_layout()
	visible = GameFlow.current_state in [GameFlow.ISLAND_INTRO, GameFlow.ISLAND_ATTRACT]
	if GameFlow.current_state == GameFlow.ISLAND_ATTRACT:
		_enter_direct_attract()
	elif GameFlow.current_state == GameFlow.ISLAND_INTRO:
		_begin_intro()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	scene_ready = true


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
		player.prepare("index.island-intro.mp4", "", "index.poster.png")
	else:
		player.prepare("", MEDIA + "intro.ogv", MEDIA + "poster.png", MEDIA + "last.png")
	player.set_picture_rect(Playback.fit_picture(Rect2(Vector2.ZERO, size)))
	player.set_opacity(0.0) # HTML media is outside Godot's visibility hierarchy.


func _on_video_state_changed(next: StringName) -> void:
	if _previous_video_state in [&"error", &"gesture_required"] and next in [&"preparing", &"ready", &"playing"]:
		clock.reset()
	if next == &"playing":
		poster.hide()
	_previous_video_state = next


func _layout() -> void:
	if picture == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if size.distance_to(viewport_size) > 0.1:
		size = viewport_size
	var rect := Playback.fit_picture(Rect2(Vector2.ZERO, viewport_size))
	for image: Control in [picture, poster, cover]:
		image.position = rect.position
		image.size = rect.size
	prompt.position = rect.position + Vector2(0.0, rect.size.y * 0.88)
	prompt.size.x = rect.size.x
	player.set_picture_rect(rect)


func _process(delta: float) -> void:
	if not scene_ready:
		return
	var state := GameFlow.current_state
	if state == GameFlow.LOGO_REVEAL and _cover_elapsed >= 0.0:
		if _presentation_active():
			_cover_elapsed += maxf(delta, 0.0)
		cover.modulate.a = smoothstep(0.0, _cover_duration, _cover_elapsed)
		if _cover_elapsed >= _cover_duration:
			_cover_elapsed = -1.0
			visible = false
		return
	if state not in [GameFlow.ISLAND_INTRO, GameFlow.ISLAND_ATTRACT]:
		return
	var active := _presentation_active()
	if not OS.has_feature("web"):
		player.set_focus_active(active)
	if state == GameFlow.ISLAND_INTRO and not _started and scene_ready and player.is_prepared:
		_started = true
		poster.hide()
		player.play()
	if not _started and state == GameFlow.ISLAND_INTRO:
		return # The poster remains after loading until video and live scene are ready.
	var time := clock.advance(player.snapshot(), delta, active)
	_apply(time)
	if state == GameFlow.ISLAND_INTRO and clock.live_tail and time >= profile.camera_profile.settle_end:
		player.release()
		GameFlow.complete_island_intro()


func _presentation_active() -> bool:
	if not OS.has_feature("web"):
		return _focused
	return bool(JavaScriptBridge.eval("!document.hidden && document.hasFocus()", true))


func _apply(time: float) -> void:
	study.sample(time)
	player.set_opacity(profile.video_opacity(time))
	if time < profile.camera_profile.settle_end:
		if not fx.is_active:
			fx.begin_external(profile.blur_profile, CinematicTransitionFX.Quality.AUTO, true)
		fx.sample_external(inverse_lerp(profile.camera_profile.blend_start, profile.camera_profile.settle_end, time), profile.blur_envelope(time))
	elif fx.is_active:
		fx.cancel(&"handoff_complete")
	prompt.visible = GameFlow.current_state == GameFlow.ISLAND_ATTRACT


func _on_state_changed(previous: StringName, next: StringName) -> void:
	match next:
		GameFlow.LOADING:
			visible = false
			player.set_opacity(0.0)
			_cover_elapsed = -1.0
			if player.state == &"released":
				_new_player()
		GameFlow.ISLAND_INTRO:
			_begin_intro()
		GameFlow.ISLAND_ATTRACT:
			if previous == GameFlow.ISLAND_INTRO:
				_apply(clock.time)
			else:
				_enter_direct_attract()
		GameFlow.LOGO_REVEAL:
			player.release()
			fx.cancel(&"logo_handoff")
			prompt.hide()
			var logo := get_node_or_null("../GameFrame/WorldContainer/GameViewport/World/LogoPresentationRig") as LogoRevealController
			if logo != null:
				var blue_material := logo.blue_handoff_plane.mesh.surface_get_material(0) as StandardMaterial3D
				cover.color = blue_material.albedo_color if blue_material != null else logo.handoff_blue_color()
			_cover_elapsed = 0.0
			cover.modulate.a = 0.0
			cover.show()
		_:
			visible = false
			_cover_elapsed = -1.0
			if player.state != &"released":
				player.release()
			if fx.is_active:
				fx.cancel(&"state_exit")


func _begin_intro() -> void:
	if player.state == &"released":
		_new_player()
	clock.reset()
	_started = false
	intro_play_count += 1
	poster.show()
	cover.hide()
	prompt.hide()
	visible = true
	_apply(0.0)
	poster.show()


func _enter_direct_attract() -> void:
	clock.time = profile.camera_profile.settle_end
	clock.live_tail = true
	_started = true
	player.release()
	poster.hide()
	cover.hide()
	visible = true
	_apply(clock.time)


func development_replay_intro() -> void:
	if GameFlow.current_state == GameFlow.ISLAND_INTRO:
		_new_player()
		_begin_intro()
	else:
		GameFlow.development_jump_to_state(GameFlow.ISLAND_INTRO)


func development_enter_attract() -> void:
	GameFlow.development_jump_to_state(GameFlow.ISLAND_ATTRACT)


func development_skip_stage() -> void:
	if GameFlow.current_state != GameFlow.ISLAND_INTRO:
		return
	# Development shortcut samples the approved final pose; it never seeks the source clip.
	player.release()
	clock.time = profile.camera_profile.settle_end
	clock.live_tail = true
	GameFlow.complete_island_intro()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_focused = false
		clock.advance({}, 0.0, false)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_focused = true


func _exit_tree() -> void:
	if GameFlow.state_changed.is_connected(_on_state_changed):
		GameFlow.state_changed.disconnect(_on_state_changed)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.disconnect(_layout)
	if is_instance_valid(player):
		player.release()
