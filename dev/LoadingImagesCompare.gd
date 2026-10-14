extends SceneTree

## Loading-only capture and lossless-source checks; never exported.
const ROOT := "res://build/rehabilitation/loading-images/"


func _initialize() -> void:
	call_deferred("_compare")


func _compare() -> void:
	var report := {"captures": [], "assets": [], "pass": true}
	var compared_pixels := 0
	var outside_changes := 0
	for dimensions: Vector2i in [Vector2i(960, 720), Vector2i(1280, 720), Vector2i(844, 390), Vector2i(360, 640)]:
		for frame: int in [11, 20, 40, 60, 70, 71]:
			var name := "loading-frame-%02d-%dx%d.png" % [frame, dimensions.x, dimensions.y]
			var result := _compare_capture(name, Rect2(Vector2.ZERO, Vector2(dimensions)))
			report.captures.append(result)
	report.captures.append(_compare_capture("loading-frame-40-844x390-safe-inset.png", Rect2(36, 12, 788, 370)))
	report.captures.append(_compare_capture("loading-first-visible-960x720.png", Rect2(0, 0, 960, 720)))
	for capture: Dictionary in report.captures:
		compared_pixels += capture.compared_pixels
		outside_changes += capture.changed_outside_images
		report.pass = report.pass and capture.pass
	var source_before := 0
	var source_after := 0
	for index: int in range(1, 9):
		var filename := "loading_%02d.png" % index
		var before_path := ROOT + "before-assets/" + filename
		var after_path := "res://art/loading/frames/" + filename
		var before := Image.load_from_file(ProjectSettings.globalize_path(before_path))
		var after := Image.load_from_file(ProjectSettings.globalize_path(after_path))
		before.convert(Image.FORMAT_RGBA8)
		after.convert(Image.FORMAT_RGBA8)
		var same_pixels := before.get_size() == after.get_size() and before.get_data() == after.get_data()
		var old_bytes := FileAccess.get_file_as_bytes(before_path).size()
		var new_bytes := FileAccess.get_file_as_bytes(after_path).size()
		source_before += old_bytes
		source_after += new_bytes
		var asset_pass := same_pixels and new_bytes <= old_bytes
		report.assets.append({"name": filename, "before_bytes": old_bytes, "after_bytes": new_bytes, "pixels_identical": same_pixels, "pass": asset_pass})
		report.pass = report.pass and asset_pass
	report["compared_pixels"] = compared_pixels
	report["changed_outside_images"] = outside_changes
	report["source_before_bytes"] = source_before
	report["source_after_bytes"] = source_after
	var source := Image.load_from_file(ProjectSettings.globalize_path("res://.ref/frames/frame_0070.jpg"))
	source.get_region(Rect2i(160, 0, 960, 720)).save_png(ROOT + "reference-70-normalized.png")
	var html := '<!doctype html><meta charset="utf-8"><title>Loading image fill</title><style>body{font:16px sans-serif;background:#171720;color:white;margin:24px}section{display:flex;flex-wrap:wrap;gap:16px}figure{margin:0}img{width:480px;max-width:100%;height:auto}a{color:#8df}</style><h1>Loading image fill</h1><p>Only the eight image interiors change. Lossless source pixels are identical. <a href="measurements.json">Measurements</a></p><section>'
	for entry: Array in [["Reference", "reference-70-normalized.png"], ["Before", "before/loading-frame-70-960x720.png"], ["After", "after/loading-frame-70-960x720.png"], ["Edge and corner fixture", "fixture-filled.png"], ["Wide/tall crop and missing texture", "fixture-cropped-missing.png"]]:
		html += '<figure><figcaption>%s</figcaption><img src="%s"></figure>' % entry
	_write("comparison.html", html + "</section>")
	_write("measurements.json", JSON.stringify(report, "\t"))
	print("LOADING_IMAGES_COMPARE_%s captures=%d unchanged_outside_pixels=%d outside_changes=%d source_bytes=%d->%d" % ["PASS" if report.pass else "FAIL", report.captures.size(), compared_pixels, outside_changes, source_before, source_after])
	if not report.pass:
		for capture: Dictionary in report.captures:
			if not capture.pass:
				printerr(capture)
	quit(0 if report.pass else 1)


func _compare_capture(filename: String, presentation_rect: Rect2) -> Dictionary:
	var before := Image.load_from_file(ROOT + "before/" + filename)
	var after := Image.load_from_file(ROOT + "after/" + filename)
	before.convert(Image.FORMAT_RGBA8)
	after.convert(Image.FORMAT_RGBA8)
	var before_bytes := before.get_data()
	var after_bytes := after.get_data()
	var scale_factor := minf(presentation_rect.size.x / 960.0, presentation_rect.size.y / 720.0)
	var composition_size := Vector2(960, 720) * scale_factor
	var origin := presentation_rect.position + (presentation_rect.size - composition_size) * 0.5
	var allowed := PackedByteArray()
	allowed.resize(before.get_width() * before.get_height())
	for index: int in 8:
		var logical := Rect2(Vector2(LoadingPresentation.IMAGE_LEFTS[index], LoadingPresentation.IMAGE_TOPS[index]), LoadingPresentation.IMAGE_SIZE).grow(-2.5)
		var actual := Rect2(origin + logical.position * scale_factor, logical.size * scale_factor)
		var start := Vector2i(actual.position.floor())
		var end := Vector2i(actual.end.ceil())
		for y: int in range(maxi(start.y, 0), mini(end.y, before.get_height())):
			for x: int in range(maxi(start.x, 0), mini(end.x, before.get_width())):
				allowed[y * before.get_width() + x] = 1
	var changed_outside := 0
	var changed_inside := 0
	var compared := 0
	for pixel: int in allowed.size():
		var offset := pixel * 4
		var changed := before_bytes[offset] != after_bytes[offset] or before_bytes[offset + 1] != after_bytes[offset + 1] or before_bytes[offset + 2] != after_bytes[offset + 2] or before_bytes[offset + 3] != after_bytes[offset + 3]
		if allowed[pixel] == 0:
			compared += 1
			if changed:
				changed_outside += 1
		elif changed:
			changed_inside += 1
	var first_frame := "frame-11-" in filename or "first-visible" in filename
	return {"name": filename, "compared_pixels": compared, "changed_outside_images": changed_outside, "changed_inside_images": changed_inside, "pass": changed_outside == 0 and (not first_frame or changed_inside == 0)}


func _write(filename: String, content: String) -> void:
	var file := FileAccess.open(ROOT + filename, FileAccess.WRITE)
	file.store_string(content)
