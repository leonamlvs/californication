class_name IslandVideoPlayback
extends Control

## Presentation-only adapter. The caller owns GameFlow and the live-scene clock.
signal prepared()
signal state_changed(state: StringName)
signal frame_presented(media_time: float)
signal completed()
signal playback_failed(message: String)

const DURATION := 104.0 * 1001.0 / 30000.0
const FRAME_RATE := 30000.0 / 1001.0
const WEB_SCRIPT := "res://frontend/island/video/island_video.js"

var state: StringName = &"idle"
var media_time := 0.0
var duration := DURATION
var is_prepared := false
var last_error := ""
var picture_rect := Rect2()
var _web: JavaScriptObject
var _native: VideoStreamPlayer
var _host: Control
var _held: TextureRect
var _action: Button
var _poster: Texture2D
var _final_frame: Texture2D
var _web_url := ""
var _native_path := ""
var _poster_path := ""
var _final_path := ""
var _wants_play := false
var _focus_active := true
var _preparing_native := false
var _prepare_elapsed := 0.0
var _completion_sent := false
var _completion_count := 0
var _frame_count := 0
var _last_reported_time := -1.0
var _ready_sent := false
var _opacity := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func fit_picture(available: Rect2) -> Rect2:
	var scale_factor := minf(available.size.x / 960.0, available.size.y / 720.0)
	var fitted := Vector2(960.0, 720.0) * maxf(scale_factor, 0.0)
	return Rect2(available.get_center() - fitted * 0.5, fitted)


func prepare(web_url: String, native_path: String, poster_path: String, final_frame_path := "") -> void:
	if state == &"released":
		return
	_web_url = web_url
	_native_path = native_path
	_poster_path = poster_path
	_final_path = final_frame_path
	_wants_play = false
	_completion_sent = false
	_ready_sent = false
	is_prepared = false
	last_error = ""
	media_time = 0.0
	_frame_count = 0
	_last_reported_time = -1.0
	_set_state(&"preparing")
	if OS.has_feature("web"):
		if _web == null:
			if not FileAccess.file_exists(WEB_SCRIPT):
				_fail("Island video bridge was not included in this build.")
				return
			JavaScriptBridge.eval(FileAccess.get_file_as_string(WEB_SCRIPT), true)
			var bridge := JavaScriptBridge.get_interface("IslandVideoBridge")
			if bridge == null:
				_fail("Island video bridge could not initialize.")
				return
			_web = bridge.create()
		_web.prepare(web_url, poster_path)
		set_picture_rect(picture_rect)
		set_opacity(_opacity)
	else:
		_prepare_native()


func play() -> void:
	if state in [&"ended", &"error", &"released", &"idle"]:
		return
	_wants_play = true
	if _web != null:
		_web.play()
	elif is_prepared and _focus_active:
		_native.paused = false
		_held.visible = false
		_native.visible = true
		_set_state(&"playing")


func pause() -> void:
	_wants_play = false
	if _web != null:
		_web.pause()
	elif _native != null and is_prepared and state not in [&"ended", &"error", &"released"]:
		_native.paused = true
		_set_state(&"paused")


func restart() -> void:
	if state == &"released":
		return
	prepare(_web_url, _native_path, _poster_path, _final_path)
	play()


func set_focus_active(active: bool) -> void:
	_focus_active = active
	if _web != null:
		_web.setFocusActive(active)
	elif _native != null and is_prepared and state not in [&"ended", &"error", &"released"]:
		_native.paused = not active or not _wants_play
		if _wants_play:
			_set_state(&"playing" if active else &"paused")


func set_picture_rect(value: Rect2) -> void:
	picture_rect = value
	if _web != null:
		var viewport_size := get_viewport().get_visible_rect().size.max(Vector2.ONE)
		_web.setPictureRect(value.position.x / viewport_size.x, value.position.y / viewport_size.y, value.size.x / viewport_size.x, value.size.y / viewport_size.y)
	if _host != null:
		_host.position = value.position
		_host.size = value.size
		var scale_factor := value.size.x / 960.0
		_native.position = Vector2(-160.0 * scale_factor, 0.0)
		_native.size = Vector2(1280.0, 720.0) * scale_factor
		_held.position = Vector2.ZERO
		_held.size = value.size
		_action.position = Vector2(maxf(0.0, value.size.x * 0.5 - 90.0), value.size.y * 0.78)
		_action.size = Vector2(minf(180.0, value.size.x), 44.0)


func set_opacity(value: float) -> void:
	_opacity = clampf(value, 0.0, 1.0)
	if _web != null:
		_web.setOpacity(_opacity)
	if _host != null:
		_host.modulate.a = _opacity
		_host.visible = _opacity > 0.0


func release() -> void:
	if state == &"released":
		return
	if _web != null:
		_web.release()
		_web = null
	if _native != null:
		_native.stop()
		_native.stream = null
	if _host != null:
		_host.queue_free()
		_host = null
		_native = null
		_held = null
		_action = null
	_poster = null
	_final_frame = null
	_wants_play = false
	_preparing_native = false
	is_prepared = false
	_set_state(&"released")


func snapshot() -> Dictionary:
	return {
		"state": state, "prepared": is_prepared, "media_time": media_time,
		"duration": duration, "error": last_error, "frame_count": _frame_count,
		"completion_count": _completion_count, "backend": "web" if OS.has_feature("web") else "native",
		"picture_rect": [picture_rect.position.x, picture_rect.position.y, picture_rect.size.x, picture_rect.size.y],
	}


func _process(delta: float) -> void:
	if _web != null:
		var data: Dictionary = JSON.parse_string(_web.snapshot())
		is_prepared = bool(data.get("prepared", false))
		media_time = float(data.get("media_time", 0.0))
		duration = float(data.get("duration", DURATION))
		_frame_count = int(data.get("frame_count", 0))
		last_error = str(data.get("error", ""))
		var next_state := StringName(data.get("state", "idle"))
		if next_state == &"error" and state != &"error":
			playback_failed.emit(last_error)
		_set_state(next_state)
	elif _preparing_native:
		_prepare_elapsed += delta
		if _native.get_video_texture() != null and _native.stream_position > 0.0:
			_preparing_native = false
			is_prepared = true
			_native.paused = true
			_set_state(&"ready")
			if _wants_play and _focus_active:
				play()
		elif _prepare_elapsed > 5.0:
			_fail("Native preview could not decode its first frame.")
	elif state == &"playing" and _native != null:
		media_time = maxf(media_time, minf(_native.stream_position, duration))
		_frame_count = mini(104, int(media_time * FRAME_RATE) + 1)
	if is_prepared and not _ready_sent:
		_ready_sent = true
		prepared.emit()
	if is_prepared and not is_equal_approx(media_time, _last_reported_time):
		_last_reported_time = media_time
		frame_presented.emit(media_time)
	if state == &"ended":
		_emit_completion_once()


func _prepare_native() -> void:
	if _host == null:
		_host = Control.new()
		_host.clip_contents = true
		_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_host)
		_native = VideoStreamPlayer.new()
		_native.expand = true
		_native.volume = 0.0
		_native.loop = false
		_native.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_native.finished.connect(_native_finished)
		_host.add_child(_native)
		_held = TextureRect.new()
		_held.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_held.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_host.add_child(_held)
		_action = Button.new()
		_action.text = "Retry"
		_action.mouse_filter = Control.MOUSE_FILTER_STOP
		_action.pressed.connect(restart)
		_host.add_child(_action)
	_native.stop()
	_native.stream = null
	_native.visible = false
	_native.paused = false
	_action.hide()
	_poster = _load_picture(_poster_path)
	_final_frame = _load_picture(_final_path)
	_held.texture = _poster
	_held.show()
	set_picture_rect(picture_rect)
	set_opacity(_opacity)
	if not FileAccess.file_exists(_native_path):
		_fail("Native preview media is missing. Generate the isolated preview first.")
		return
	var stream := VideoStreamTheora.new()
	stream.file = _native_path
	_native.stream = stream
	_prepare_elapsed = 0.0
	_preparing_native = true
	_native.play()


func _load_picture(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null


func _native_finished() -> void:
	if state in [&"released", &"error"] or _completion_sent:
		return
	media_time = duration
	_frame_count = 104
	_wants_play = false
	_held.texture = _final_frame if _final_frame != null else _native.get_video_texture()
	_held.show()
	_native.hide()
	_set_state(&"ended")
	_emit_completion_once()


func _emit_completion_once() -> void:
	if not _completion_sent:
		_completion_sent = true
		_completion_count += 1
		completed.emit()


func _fail(message: String) -> void:
	last_error = message
	_preparing_native = false
	is_prepared = false
	_wants_play = false
	if _native != null:
		_native.paused = true
		_action.show()
	_set_state(&"error")
	playback_failed.emit(message)


func _set_state(value: StringName) -> void:
	if state != value:
		state = value
		state_changed.emit(state)


func _notification(what: int) -> void:
	# Browser focus/visibility is handled inside the DOM bridge, including its buttons.
	if OS.has_feature("web"):
		return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		set_focus_active(false)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		set_focus_active(true)


func _exit_tree() -> void:
	release()
