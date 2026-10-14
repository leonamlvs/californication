extends SceneTree

## Observe the production clock and first presentation frame; never seek it.
const OUTPUT := "res://build/rehabilitation/loading-svg/"
var frontend: Node
var frames := 0
var captured_middle := false
var captured_hold := false
var started_msec := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := load("res://main/Main.tscn").instantiate() as Node
	root.add_child(main)
	frontend = main.get_node("PresentationRoot/GameFrame/WorldContainer/GameViewport/World/IslandFrontend")
	started_msec = Time.get_ticks_msec()
	RenderingServer.frame_post_draw.connect(_record)


func _record() -> void:
	frames += 1
	var flow := root.get_node("GameFlow")
	if flow.current_state == &"LOADING":
		if frames <= 4:
			_save("native-first-%02d" % frames)
			var source: Image = frontend.loading_overlay.background_map.viewport.get_texture().get_image()
			var blur: Image = frontend.loading_overlay.background_map.vertical_viewport.get_texture().get_image()
			if source.get_pixel(260, 110).a < 0.9 or blur.get_pixel(260, 81).g < 0.1:
				push_error("Production boot showed an incomplete loading SVG/blur pipeline.")
				quit(1)
		if not captured_middle and frontend.loading_elapsed >= 0.8:
			captured_middle = true
			_save("native-intermediate")
		if not captured_hold and frontend.loading_elapsed >= 1.95:
			captured_hold = true
			_save("native-full-hold")
	elif flow.current_state == &"ISLAND_INTRO":
		_save("native-first-island-intro")
		print("LOADING_NATIVE_BOOT_PASS active_seconds=%.4f wall_seconds=%.4f frames=%d full_hold=%s" % [frontend.loading_elapsed, (Time.get_ticks_msec() - started_msec) / 1000.0, frames, captured_hold])
		RenderingServer.frame_post_draw.disconnect(_record)
		quit(0)
	if Time.get_ticks_msec() - started_msec > 15000:
		push_error("Native boot capture timed out; check application focus.")
		quit(1)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")
