extends Control

const Playback = preload("res://frontend/island/video/IslandVideoPlayback.gd")
const MEDIA := "res://dev/island_video/media/"
var player: IslandVideoPlayback
var failures: Array[String] = []
var ended_count := 0
var captures := ""


func _ready() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	for available: Rect2 in [Rect2(0, 0, 960, 720), Rect2(0, 0, 360, 640), Rect2(0, 0, 844, 390), Rect2(20, 15, 320, 600)]:
		var fitted := Playback.fit_picture(available)
		_assert(is_equal_approx(fitted.size.x / fitted.size.y, 4.0 / 3.0), "Aspect ratio changed")
		_assert(available.encloses(fitted), "Picture exceeds available area")
		_assert(fitted.get_center().is_equal_approx(available.get_center()), "Picture is not centered")
	player = Playback.new()
	add_child(player)
	player.completed.connect(func(): ended_count += 1)
	player.set_picture_rect(Playback.fit_picture(Rect2(Vector2.ZERO, get_viewport_rect().size)))
	player.prepare("", "res://missing-intro.ogv", "")
	_assert(player.state == &"error" and not player.is_prepared, "Missing native media did not fail safely")
	player.play()
	_assert(player.state == &"error" and ended_count == 0, "Play bypassed failed preparation")
	if DisplayServer.get_name() == "headless":
		player.release()
		player.release()
		player.play()
		_assert(player.state == &"released", "Release is not terminal/idempotent")
		_finish("ISLAND_VIDEO_CONTRACT_PASS")
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(captures)
	player.prepare("", MEDIA + "intro.ogv", MEDIA + "poster.png", MEDIA + "last.png")
	await _wait_prepared()
	_assert(player.is_prepared, "Native decoder did not prepare")
	if not player.is_prepared:
		_finish("ISLAND_VIDEO_NATIVE_PASS")
		return
	await _capture("native-poster")
	player.set_focus_active(true)
	player.play()
	await get_tree().create_timer(0.55).timeout
	_assert(player.state == &"playing" and player.media_time > 0.3, "Native playback did not advance")
	player.pause()
	var paused_time := player.media_time
	await get_tree().create_timer(0.25).timeout
	_assert(is_equal_approx(player.media_time, paused_time), "Explicit pause advanced the clock")
	await _capture("native-paused-desktop")
	get_window().size = Vector2i(360, 640)
	await get_tree().process_frame
	await get_tree().process_frame
	player.set_picture_rect(Playback.fit_picture(Rect2(Vector2.ZERO, get_viewport_rect().size)))
	await _capture("native-paused-portrait")
	_assert(is_equal_approx(player.media_time, paused_time), "Resize restarted playback")
	player.set_opacity(0.5)
	_assert(is_equal_approx(player._host.modulate.a, 0.5), "Native opacity was not applied")
	player.set_opacity(1.0)
	player.play()
	await get_tree().create_timer(0.2).timeout
	player.set_focus_active(false)
	var focus_time := player.media_time
	await get_tree().create_timer(0.25).timeout
	_assert(player.state == &"paused" and is_equal_approx(player.media_time, focus_time), "Focus loss did not freeze playback")
	player.set_focus_active(true)
	await _wait_ended()
	_assert(player.state == &"ended" and ended_count == 1, "Native completion did not fire once")
	_assert(absf(player.media_time - Playback.DURATION) < 0.0001, "Native final clock differs from source duration")
	await _capture("native-complete-portrait")
	player.play()
	await get_tree().create_timer(0.2).timeout
	_assert(player.state == &"ended" and ended_count == 1, "Completed clip replayed implicitly")
	player.restart()
	await _wait_prepared()
	player.set_focus_active(true)
	await get_tree().create_timer(0.15).timeout
	_assert(player.state == &"playing" and player.media_time < 0.8, "Explicit restart did not reset time")
	player.release()
	player.release()
	await get_tree().process_frame
	_assert(player.state == &"released" and player._native == null and ended_count == 1, "Release retained active native resources")
	_finish("ISLAND_VIDEO_NATIVE_PASS")


func _wait_prepared() -> void:
	for _index in range(500):
		if player.is_prepared or player.state == &"error":
			return
		await get_tree().create_timer(0.01).timeout


func _wait_ended() -> void:
	for _index in range(600):
		if player.state in [&"ended", &"error"]:
			return
		await get_tree().create_timer(0.01).timeout


func _capture(label: String) -> void:
	if captures.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(captures.path_join(label + ".png"))


func _finish(marker: String) -> void:
	if failures.is_empty():
		print(marker)
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("ISLAND_VIDEO_FAIL: ", failure)
		get_tree().quit(1)
