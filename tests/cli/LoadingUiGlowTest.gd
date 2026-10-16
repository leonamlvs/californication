extends SceneTree

## Render the paired font and glow profiles against a known, flat backdrop.
const PRESENTATION := preload("res://frontend/loading/LoadingPresentation.tscn")
const OUTPUT := "res://build/rehabilitation/loading-ui-glow/fixtures/"
const BACKDROP := Color(0.2, 0.3, 0.5, 1.0)

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(960, 720)
	var presentation := PRESENTATION.instantiate() as LoadingPresentation
	root.add_child(presentation)
	presentation.background_map.hide()
	presentation.indigo_backdrop.hide()
	presentation.get_node("BlackBackdrop").color = BACKDROP
	presentation.set_progress(0.0)
	_check(presentation.loading_fill_color == Color(1, 1, 1, 0.5), "Default text fill is not exactly 50% white.")
	_check(presentation.loading_fill_font != null, "Solid fill font is missing.")
	_check_font_alignment(presentation.loading_font, presentation.loading_fill_font)
	presentation.foreground_glow_strength = 0.0
	var solid_font := presentation.loading_fill_font
	presentation.loading_fill_font = null
	var outline_only := await _capture(presentation, "outline-only")
	presentation.loading_fill_font = solid_font
	presentation.loading_fill_color.a = 0.0
	var transparent_fill := await _capture(presentation, "transparent-fill")
	_check(transparent_fill.get_data() == outline_only.get_data(), "Missing fill font did not preserve the outlined presentation.")
	presentation.loading_fill_color.a = 1.0
	var opaque_fill := await _capture(presentation, "opaque-fill")
	presentation.loading_fill_color.a = 0.5
	var half_fill := await _capture(presentation, "half-fill")
	var samples := 0
	var worst_fill_error := 0.0
	for y: int in range(180, 240):
		for x: int in range(75, 460):
			var bare := outline_only.get_pixel(x, y)
			var solid := opaque_fill.get_pixel(x, y)
			if _difference(bare, BACKDROP) < 0.005 and _difference(solid, Color.WHITE) < 0.005:
				var expected := bare.lerp(solid, 0.5)
				worst_fill_error = maxf(worst_fill_error, _difference(half_fill.get_pixel(x, y), expected))
				samples += 1
	_check(samples >= 100, "Not enough fully covered glyph-interior pixels to verify fill opacity: %d." % samples)
	_check(worst_fill_error <= 2.0 / 255.0, "Solid font did not composite as 50%% white: error=%f." % worst_fill_error)
	presentation.foreground_glow_strength = 1.0
	var glowing := await _capture(presentation, "glow-empty")
	_check_falloff(glowing, half_fill, Vector2i(90, 195), Vector2i.UP, 12, "text")
	_check(glowing.get_pixel(90, 191).r - half_fill.get_pixel(90, 191).r > 0.01, "Text glow collapsed to a narrow outline instead of the configured logical extent.")
	_check_falloff(glowing, half_fill, Vector2i(750, 249), Vector2i.UP, 14, "bar")
	_check_falloff(glowing, half_fill, Vector2i(55, 450), Vector2i.LEFT, 10, "frame")
	# The 2px sharp line has an antialiased fringe; sample beyond that fringe.
	_check_falloff(glowing, half_fill, Vector2i(750, 338), Vector2i.UP, 8, "connector")
	presentation.bar_glow_radius = 6.0
	var narrow := await _capture(presentation, "glow-narrow-bar")
	_check(_difference(narrow.get_pixel(750, 248), glowing.get_pixel(750, 248)) < 0.035, "Changing glow radius also changed near-edge brightness substantially.")
	_check(glowing.get_pixel(750, 241).r > narrow.get_pixel(750, 241).r, "Wider bar glow did not extend farther outside the bar.")
	presentation.bar_glow_radius = 12.0
	for progress: float in [0.5, 1.0]:
		presentation.set_progress(progress)
		var advanced := await _capture(presentation, "glow-progress-%s" % progress)
		for y: int in range(235, 249):
			_check(_difference(advanced.get_pixel(750, y), glowing.get_pixel(750, y)) <= 1.0 / 255.0, "Bar's outer glow changed with its moving fill.")
	presentation.set_progress(0.95)
	var highlighted := await _capture(presentation, "glow-highlight")
	var accent := highlighted.get_pixel(812, 414) - BACKDROP
	_check(accent.g > accent.b + 0.005 and accent.r > accent.b + 0.005, "Highlighted frame lost its green/yellow glow tint.")
	print("LOADING_UI_GLOW_MEASUREMENTS fill_samples=%d max_fill_error=%.6f" % [samples, worst_fill_error])
	if failures.is_empty():
		print("LOADING_UI_GLOW_PASS checks=%d fill_opacity, shared_alignment, missing_font, smooth_profiles, normalized_strength, stable_bar, highlight" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _check_font_alignment(outline: Font, solid: Font) -> void:
	var lines: Array[TextLine] = [TextLine.new(), TextLine.new()]
	lines[0].add_string("NOW LOADING", outline, 96)
	lines[1].add_string("NOW LOADING", solid, 96)
	var server := TextServerManager.get_primary_interface()
	var outer := server.shaped_text_get_glyphs(lines[0].get_rid())
	var inner := server.shaped_text_get_glyphs(lines[1].get_rid())
	_check(outer.size() == inner.size(), "Font layers shaped into different glyph counts.")
	for index: int in mini(outer.size(), inner.size()):
		_check(is_equal_approx(outer[index].advance, inner[index].advance) and outer[index].offset == inner[index].offset, "Font layers have different shaped glyph positions at %d." % index)


func _check_falloff(glowing: Image, bare: Image, origin: Vector2i, direction: Vector2i, extent: int, label: String) -> void:
	var previous := 1.0
	var profile: Array[float] = []
	for distance: int in range(1, extent + 1):
		var point := origin + direction * distance
		var gain := glowing.get_pixelv(point).r - bare.get_pixelv(point).r
		profile.append(gain)
		_check(gain <= previous + 1.5 / 255.0, "%s glow brightened again away from its border at %d." % [label, distance])
		previous = gain
	_check(profile[0] > 0.025, "%s glow is not visible near its border." % label)
	_check(absf(profile[-1]) <= 1.0 / 255.0, "%s glow escaped its configured extent." % label)
	print("LOADING_UI_GLOW_PROFILE %s %s" % [label, profile])


func _capture(presentation: LoadingPresentation, name: String) -> Image:
	presentation.foreground.queue_redraw()
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	captured.save_png(OUTPUT + name + ".png")
	return captured


func _difference(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
