extends SceneTree

const PRESENTATION := preload("res://frontend/loading/LoadingPresentation.tscn")
const OUTPUT := "res://build/rehabilitation/loading-images/"
const FIXTURE_COLOR := Color(1.0, 0.0, 1.0, 1.0)
const CROP_COLOR := Color(0.0, 0.5, 1.0, 1.0)

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(960, 720)
	var presentation := PRESENTATION.instantiate() as LoadingPresentation
	root.add_child(presentation)
	presentation.set_progress(0.95)
	for index: int in 8:
		presentation.set("image_%d" % (index + 1), null)
	var empty := await _capture(presentation, "fixture-empty")
	var solid := Image.create(75, 75, false, Image.FORMAT_RGBA8)
	solid.fill(FIXTURE_COLOR)
	var texture := ImageTexture.create_from_image(solid)
	for index: int in 8:
		presentation.set("image_%d" % (index + 1), texture)
	var filled := await _capture(presentation, "fixture-filled")
	for index: int in 8:
		var origin := Vector2i(presentation.IMAGE_LEFTS[index], presentation.IMAGE_TOPS[index])
		for offset: Vector2i in [Vector2i(4, 25), Vector2i(77, 25), Vector2i(25, 4), Vector2i(25, 77), Vector2i(41, 41)]:
			_check(_near(filled.get_pixelv(origin + offset), FIXTURE_COLOR), "Image %d does not fill its inner edge at %s." % [index + 1, offset])
		for offset: Vector2i in [Vector2i(3, 3), Vector2i(78, 3), Vector2i(78, 78), Vector2i(3, 78), Vector2i(1, 41), Vector2i(-1, -1)]:
			_check(_near(filled.get_pixelv(origin + offset), empty.get_pixelv(origin + offset)), "Image %d covers a rounded corner, border, or outside pixel at %s." % [index + 1, offset])
	presentation.image_1 = _crop_texture(Vector2i(150, 75), true)
	presentation.image_2 = _crop_texture(Vector2i(75, 150), false)
	presentation.image_3 = null
	var cropped := await _capture(presentation, "fixture-cropped-missing")
	for offset: int in [12, 25, 41, 57, 70]:
		_check(_near(cropped.get_pixel(55 + offset, 409 + 41), CROP_COLOR), "Wide replacement was stretched or did not center-crop.")
		_check(_near(cropped.get_pixel(165 + 41, 373 + offset), CROP_COLOR), "Tall replacement was stretched or did not center-crop.")
	_check(_near(cropped.get_pixel(274 + 41, 409 + 41), empty.get_pixel(274 + 41, 409 + 41)), "Missing texture did not preserve the empty frame.")
	presentation.set_progress(0.0)
	var unrevealed := await _capture(presentation, "fixture-unrevealed")
	for index: int in 8:
		var center := Vector2i(presentation.IMAGE_LEFTS[index] + 41, presentation.IMAGE_TOPS[index] + 41)
		_check(_near(unrevealed.get_pixelv(center), empty.get_pixelv(center)), "Image %d appeared before its reveal." % (index + 1))
	if failures.is_empty():
		print("LOADING_IMAGES_PASS checks=%d edge_fill, rounded_clipping, cover_crop, missing, unrevealed" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _crop_texture(dimensions: Vector2i, horizontal: bool) -> ImageTexture:
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	image.fill_rect(Rect2i(37, 0, 76, 75) if horizontal else Rect2i(0, 37, 75, 76), CROP_COLOR)
	return ImageTexture.create_from_image(image)


func _capture(presentation: LoadingPresentation, name: String) -> Image:
	presentation.foreground.queue_redraw()
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	captured.save_png(OUTPUT + name + ".png")
	return captured


func _near(actual: Color, expected: Color) -> bool:
	return maxf(absf(actual.r - expected.r), maxf(absf(actual.g - expected.g), absf(actual.b - expected.b))) <= 0.02


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
