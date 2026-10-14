extends SceneTree

## Development-only reference measurements; neither this tool nor .ref ships.
const ROOT := "res://build/rehabilitation/loading-svg/"
const PATCHES := [Vector2i(260, 110), Vector2i(650, 520), Vector2i(700, 550)]
const PROFILES := [
	{"name": "top", "center": Vector2(260, 82), "normal": Vector2(0, 1)},
	{"name": "northeast", "center": Vector2(330, 158), "normal": Vector2(-0.47, 0.882)},
	{"name": "west", "center": Vector2(152, 150), "normal": Vector2(1, 0)},
	{"name": "south", "center": Vector2(721, 585), "normal": Vector2(-0.30, -0.954)},
]


func _initialize() -> void:
	call_deferred("_compare")


func _compare() -> void:
	var before := Image.load_from_file(ROOT + "mesh-baseline/loading-frame-11-960x720.png")
	var after := Image.load_from_file(ROOT + "after/loading-frame-11-960x720.png")
	var report := {"patches": [], "profiles": [], "cross_checks": []}
	var references: Dictionary = {}
	for frame: int in [10, 11, 40, 70]:
		var source := Image.load_from_file(ProjectSettings.globalize_path("res://.ref/frames/frame_%04d.jpg" % frame))
		var reference := source.get_region(Rect2i(160, 80, 960, 566) if frame == 10 else Rect2i(160, 0, 960, 720))
		if frame == 10:
			reference.resize(960, 720, Image.INTERPOLATE_BILINEAR)
		reference.save_png(ROOT + "reference-%02d-normalized.png" % frame)
		references[frame] = reference
	var reference: Image = references[11]
	for point: Vector2i in PATCHES:
		var target := _patch(reference, point)
		var actual := _patch(after, point)
		var error := _rgb_error(actual, target)
		report.patches.append({"center": [point.x, point.y], "reference_rgb": _rgb(target), "after_rgb": _rgb(actual), "absolute_error": error, "before_error": _rgb_error(_patch(before, point), target), "pass": maxf(error[0], maxf(error[1], error[2])) <= 8.01})
	var csv := "profile,distance,valid,reference_r,reference_g,reference_b,before_r,before_g,before_b,after_r,after_g,after_b\n"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="960" height="840" viewBox="0 0 960 840"><rect width="960" height="840" fill="#151526"/><style>text{fill:white;font:14px sans-serif}</style><text x="20" y="24">Reference (white), before (red), after (cyan); average RGB brightness. Masked foreground samples omitted.</text>'
	for index: int in PROFILES.size():
		var profile: Dictionary = PROFILES[index]
		var paths := ["", "", ""]
		var total := 0.0
		var before_total := 0.0
		var count := 0
		var segment := false
		for distance: int in range(-40, 41):
			var point: Vector2 = profile.center + profile.normal.normalized() * distance
			var valid := not _foreground_mask(point)
			var colors := [_sample(reference, point), _sample(before, point), _sample(after, point)]
			csv += "%s,%d,%s,%s,%s,%s\n" % [profile.name, distance, valid, _csv_rgb(colors[0]), _csv_rgb(colors[1]), _csv_rgb(colors[2])]
			if not valid:
				segment = false
				continue
			var error := _rgb_error(colors[0], colors[2])
			var before_error := _rgb_error(colors[0], colors[1])
			total += (error[0] + error[1] + error[2]) / 3.0
			before_total += (before_error[0] + before_error[1] + before_error[2]) / 3.0
			count += 1
			for curve: int in 3:
				var brightness: float = (colors[curve].r + colors[curve].g + colors[curve].b) * 255.0 / 3.0
				paths[curve] += "%s%.2f,%.2f " % ["L" if segment else "M", 60.0 + (distance + 40) * 10.0, 190.0 + index * 195.0 - brightness]
			segment = true
		var mae := total / maxf(count, 1)
		report.profiles.append({"name": profile.name, "samples": count, "mae_rgb": mae, "before_mae_rgb": before_total / maxf(count, 1), "pass": count >= 15 and mae <= 8.01})
		svg += '<text x="20" y="%d">%s: %.2f RGB MAE, %d usable samples</text>' % [50 + index * 195, profile.name, mae, count]
		for curve: int in 3:
			svg += '<path d="%s" fill="none" stroke="%s" stroke-width="2"/>' % [paths[curve], ["#ffffff", "#ff6677", "#44eedd"][curve]]
	for frame: int in [10, 40, 70]:
		var patch_errors := []
		for point: Vector2i in PATCHES:
			patch_errors.append(_rgb_error(_patch(after, point), _patch(references[frame], point)))
		var patches_pass := true
		for error: Array in patch_errors:
			patches_pass = patches_pass and maxf(error[0], maxf(error[1], error[2])) <= 8.01
		report.cross_checks.append({"frame": frame, "patch_errors": patch_errors, "pass": patches_pass})
	_write(ROOT + "edge-profiles.csv", csv)
	_write(ROOT + "edge-profiles.svg", svg + "</svg>")
	var html := '<!doctype html><meta charset="utf-8"><title>Loading map effects comparison</title><style>body{background:#141420;color:#eee;font:16px sans-serif;margin:24px}section{display:flex;gap:12px}figure{margin:0}img{width:480px;height:auto}h2{font-size:18px}a{color:#6ed}</style><h1>Loading map effects comparison</h1><p>Reference pillarboxes removed. SVG replaces the loading mesh. Foreground and radial background are preserved; compare map artwork, halo, and shadow.</p><section><figure><h2>Reference frame 0011</h2><img src="reference-11-normalized.png"></figure><figure><h2>Before</h2><img src="mesh-baseline/loading-frame-11-960x720.png"></figure><figure><h2>After</h2><img src="after/loading-frame-11-960x720.png"></figure></section><p><a href="measurements.json">Measurements</a> · <a href="edge-profiles.csv">Profile CSV</a> · <a href="edge-profiles.svg">Profile plots</a></p><section>'
	for name: String in ["background", "artwork", "halo", "shadow"]:
		html += '<figure><h2>%s</h2><img src="after/diagnostic-%s-960x720.png"></figure>' % [name, name]
	_write(ROOT + "comparison.html", html + "</section>")
	var numerical_pass := true
	for measurement: Dictionary in report.patches + report.profiles:
		numerical_pass = numerical_pass and measurement.pass
	for measurement: Dictionary in report.cross_checks:
		if measurement.frame in [40, 70]:
			numerical_pass = numerical_pass and measurement.pass
	report["preservation"] = _check_preservation()
	numerical_pass = numerical_pass and report.preservation.pass
	report["numerical_pass"] = numerical_pass
	_write(ROOT + "measurements.json", JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if numerical_pass else 1)


func _check_preservation() -> Dictionary:
	var unchanged_pixels := 0
	var changed_pixels := 0
	# Conservatively exclude both maps and their complete effect support.
	var map_region := Rect2i(108, 46, 790, 620)
	for frame: int in [11, 20, 40, 60, 70, 71]:
		var before := Image.load_from_file(ROOT + "mesh-baseline/loading-frame-%02d-960x720.png" % frame)
		var after := Image.load_from_file(ROOT + "after/loading-frame-%02d-960x720.png" % frame)
		for y: int in 720:
			for x: int in 960:
				if not map_region.has_point(Vector2i(x, y)):
					unchanged_pixels += 1
					if before.get_pixel(x, y) != after.get_pixel(x, y):
						changed_pixels += 1
	var fit_space_errors := 0
	for dimensions: Vector2i in [Vector2i(960, 720), Vector2i(1280, 720), Vector2i(844, 390), Vector2i(360, 640)]:
		var image := Image.load_from_file(ROOT + "after/loading-frame-11-%dx%d.png" % [dimensions.x, dimensions.y])
		var scale_factor := minf(float(dimensions.x) / 960.0, float(dimensions.y) / 720.0)
		var composition_size := Vector2(960, 720) * scale_factor
		var fit := Rect2((Vector2(dimensions) - composition_size) * 0.5, composition_size)
		for y: int in dimensions.y:
			for x: int in dimensions.x:
				if not fit.has_point(Vector2(x + 0.5, y + 0.5)) and image.get_pixel(x, y) != Color.BLACK:
					fit_space_errors += 1
	return {"compared_pixels": unchanged_pixels, "changed_outside_map": changed_pixels, "nonblack_fit_pixels": fit_space_errors, "pass": changed_pixels == 0 and fit_space_errors == 0}


func _patch(image: Image, center: Vector2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y: int in range(center.y - 2, center.y + 3):
		for x: int in range(center.x - 2, center.x + 3):
			sum += image.get_pixel(x, y)
	return sum / 25.0


func _sample(image: Image, point: Vector2) -> Color:
	return image.get_pixel(clampi(roundi(point.x), 0, 959), clampi(roundi(point.y), 0, 719))


func _foreground_mask(point: Vector2) -> bool:
	# The reference's foreground bloom extends beyond the measured structural
	# rectangles. Exclude it rather than attributing that brightness to the map.
	if Rect2(60, 174, 416, 76).has_point(point) or Rect2(40, 225, 874, 88).has_point(point):
		return true
	if Rect2(462, 292, 20, 58).has_point(point) or Rect2(87, 330, 781, 20).has_point(point):
		return true
	for index: int in 8:
		var left: float = LoadingPresentation.IMAGE_LEFTS[index]
		var top: float = LoadingPresentation.IMAGE_TOPS[index]
		if Rect2(left - 10, top - 10, 102, 102).has_point(point) or Rect2(left + 31, 340, 20, top - 340).has_point(point):
			return true
	return false


func _rgb(color: Color) -> Array:
	return [color.r * 255.0, color.g * 255.0, color.b * 255.0]


func _rgb_error(first: Color, second: Color) -> Array:
	return [absf(first.r - second.r) * 255.0, absf(first.g - second.g) * 255.0, absf(first.b - second.b) * 255.0]


func _csv_rgb(color: Color) -> String:
	return "%.3f,%.3f,%.3f" % [color.r * 255.0, color.g * 255.0, color.b * 255.0]


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
