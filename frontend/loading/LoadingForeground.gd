class_name LoadingForeground
extends Control

## Sharp loading UI drawn above the independently cached map background.
const LOGICAL_SIZE := Vector2(960.0, 720.0)
const BAR_OUTER := Rect2(58.0, 249.0, 838.0, 43.0)
const BAR_INNER := Rect2(61.0, 252.0, 833.0, 37.0)
const TEXT_BOUNDS := Rect2(80.0, 195.0, 374.0, 40.0)
const LOADING_TEXT := "NOW LOADING"
const LOADING_FONT_SIZE := 96
const GLOW_PASSES := 16
const IMAGE_SIZE := Vector2(82.0, 82.0)
const IMAGE_BORDER_WIDTH := 2.5
const IMAGE_CORNER_RADIUS := 7.0
const IMAGE_BORDER_OVERLAP := 0.5
const CORNER_SEGMENTS := 8
const IMAGE_LEFTS: Array[float] = [55.0, 165.0, 274.0, 382.0, 491.0, 600.0, 709.0, 817.0]
const IMAGE_TOPS: Array[float] = [409.0, 373.0, 409.0, 373.0, 409.0, 373.0, 409.0, 373.0]

@onready var presentation: LoadingPresentation = get_parent() as LoadingPresentation

var _measured_font: Font
var _text_fit_bounds := Rect2()
var _text_outline_scale := 1.0
var _glow_settings: Array = []
var _glow_pass_cache: Dictionary = {}
var _style_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_refresh_glow_cache()
	var scale_factor := size.x / LOGICAL_SIZE.x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	_draw_connectors()
	_draw_progress_bar()
	_draw_image_frames()
	_draw_loading_text(Vector2.ZERO, scale_factor)


func _draw_connectors() -> void:
	var line_color := Color(0.965, 0.99, 1.0, 1.0)
	_draw_glow_line(Vector2(472, 292), Vector2(472, 340), line_color, 2.0)
	_draw_glow_line(Vector2(97, 340), Vector2(858, 340), line_color, 2.0)
	for index: int in IMAGE_LEFTS.size():
		var center_x := IMAGE_LEFTS[index] + IMAGE_SIZE.x * 0.5
		_draw_glow_line(Vector2(center_x, 340), Vector2(center_x, IMAGE_TOPS[index]), line_color, 2.0)


func _draw_progress_bar() -> void:
	_draw_glow_round_rect(BAR_OUTER, Color(0.09, 0.12, 0.38, 0.74), Color(0.93, 0.95, 1.0, 0.96), 2.5, 9.0, false, presentation.bar_glow_radius)
	if presentation.fill_fraction <= 0.0:
		return
	var fill_rect := BAR_INNER
	fill_rect.size.x *= presentation.fill_fraction
	var right_radius := 6.0 if presentation.fill_fraction >= 0.999 else 0.0
	var fill_style := _style_box(Color(0.87, 0.88, 0.97, 0.90), Color.TRANSPARENT, 0.0, 6.0, right_radius)
	draw_style_box(fill_style, fill_rect)
	# Soft top-to-bottom variation without changing the vertical leading edge.
	draw_rect(Rect2(fill_rect.position + Vector2(5, 3), Vector2(maxf(0.0, fill_rect.size.x - 5), 8)), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(fill_rect.position + Vector2(5, 24), Vector2(maxf(0.0, fill_rect.size.x - 5), 8)), Color(0.56, 0.61, 0.88, 0.10))


func _draw_image_frames() -> void:
	var textures: Array[Texture2D] = [presentation.image_1, presentation.image_2, presentation.image_3, presentation.image_4, presentation.image_5, presentation.image_6, presentation.image_7, presentation.image_8]
	for index: int in IMAGE_LEFTS.size():
		var frame_rect := Rect2(Vector2(IMAGE_LEFTS[index], IMAGE_TOPS[index]), IMAGE_SIZE)
		var highlighted := index == presentation.highlighted_image_index
		var border := Color(0.88, 0.94, 0.72, 0.98) if highlighted else Color(0.92, 0.95, 1.0, 0.94)
		var fill := Color(0.10, 0.14, 0.40, 0.48)
		var texture: Texture2D = textures[index] if index < presentation.revealed_image_count else null
		if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
			_draw_glow_round_rect(frame_rect, fill, border, IMAGE_BORDER_WIDTH, IMAGE_CORNER_RADIUS, highlighted)
			continue
		_draw_round_rect_glow(frame_rect, border, IMAGE_CORNER_RADIUS, highlighted)
		var style := _style_box(fill, Color.TRANSPARENT, IMAGE_BORDER_WIDTH, IMAGE_CORNER_RADIUS, IMAGE_CORNER_RADIUS)
		draw_style_box(style, frame_rect)
		# Extend below the inner border so filtering cannot leave a hairline gap.
		var inset := roundf(IMAGE_BORDER_WIDTH) - IMAGE_BORDER_OVERLAP
		_draw_texture_cover(texture, frame_rect.grow(-inset), IMAGE_CORNER_RADIUS - inset)
		var outline := _style_box(Color.TRANSPARENT, border, IMAGE_BORDER_WIDTH, IMAGE_CORNER_RADIUS, IMAGE_CORNER_RADIUS)
		outline.draw_center = false
		draw_style_box(outline, frame_rect)


func _draw_loading_text(composition_offset: Vector2, composition_scale: float) -> void:
	var font := presentation.loading_font if presentation.loading_font != null else ThemeDB.fallback_font
	if font != _measured_font:
		_measure_loading_text(font)
	var text_scale := TEXT_BOUNDS.size / _text_fit_bounds.size.max(Vector2.ONE)
	var origin := TEXT_BOUNDS.position - _text_fit_bounds.position * text_scale
	draw_set_transform(composition_offset + origin * composition_scale, 0.0, text_scale * composition_scale)
	# Keep glow extents in logical canvas pixels despite the fitted glyph transform.
	for glow: Vector2 in _glow_passes(presentation.text_glow_radius, 0.18):
		var outline_size := ceili(glow.x * _text_outline_scale / minf(text_scale.x, text_scale.y))
		draw_string_outline(font, Vector2.ZERO, LOADING_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LOADING_FONT_SIZE, outline_size, Color(0.72, 0.77, 1.0, glow.y))
	# The paired fonts share advances and bearings: use one transform and baseline.
	if presentation.loading_fill_font != null and presentation.loading_font != null:
		draw_string(presentation.loading_fill_font, Vector2.ZERO, LOADING_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LOADING_FONT_SIZE, presentation.loading_fill_color)
	draw_string(font, Vector2.ZERO, LOADING_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LOADING_FONT_SIZE, Color(0.90, 0.92, 1.0, 0.94))


func _measure_loading_text(font: Font) -> void:
	# Fit the full ink width and leading N's cap height. The corrected I's dot
	# extends above that cap line without compressing the other letters.
	var line := TextLine.new()
	line.add_string(LOADING_TEXT, font, LOADING_FONT_SIZE)
	var server := TextServerManager.get_primary_interface()
	var advance := 0.0
	var cap_bounds := Rect2()
	_text_fit_bounds = Rect2()
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		var glyph_size := Vector2i(glyph.font_size, 0)
		var offset := server.font_get_glyph_offset(glyph.font_rid, glyph_size, glyph.index)
		var ink_size := server.font_get_glyph_size(glyph.font_rid, glyph_size, glyph.index)
		for repeat_index: int in glyph.repeat:
			if ink_size.x > 0.0 and ink_size.y > 0.0:
				var ink := Rect2(Vector2(advance, 0.0) + glyph.offset + offset, ink_size)
				if not cap_bounds.has_area():
					cap_bounds = ink
					# Dynamic-font rasterization can scale stroke units differently
					# from glyph pixels. Calibrate once using the same leading N.
					var expanded := server.font_get_glyph_offset(glyph.font_rid, Vector2i(glyph.font_size, 64), glyph.index)
					var stroke_growth := offset.y - expanded.y
					_text_outline_scale = 64.0 / stroke_growth if stroke_growth > 0.0 else 1.0
				_text_fit_bounds = ink if not _text_fit_bounds.has_area() else _text_fit_bounds.merge(ink)
			advance += glyph.advance
	_text_fit_bounds.position.y = cap_bounds.position.y
	_text_fit_bounds.size.y = cap_bounds.size.y
	_measured_font = font


func _draw_texture_cover(texture: Texture2D, destination: Rect2, corner_radius: float) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var destination_aspect := destination.size.x / destination.size.y
	var source_aspect := texture_size.x / texture_size.y
	var source_rect := Rect2(Vector2.ZERO, texture_size)
	if source_aspect > destination_aspect:
		source_rect.size.x = texture_size.y * destination_aspect
		source_rect.position.x = (texture_size.x - source_rect.size.x) * 0.5
	else:
		source_rect.size.y = texture_size.x / destination_aspect
		source_rect.position.y = (texture_size.y - source_rect.size.y) * 0.5
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var centers := [
		destination.position + Vector2(corner_radius, corner_radius),
		Vector2(destination.end.x - corner_radius, destination.position.y + corner_radius),
		destination.end - Vector2.ONE * corner_radius,
		Vector2(destination.position.x + corner_radius, destination.end.y - corner_radius),
	]
	for corner: int in 4:
		for step: int in range(CORNER_SEGMENTS + 1):
			var angle := PI + float(corner) * PI * 0.5 + float(step) / CORNER_SEGMENTS * PI * 0.5
			var point: Vector2 = centers[corner] + Vector2.from_angle(angle) * corner_radius
			points.append(point)
			uvs.append((source_rect.position + (point - destination.position) / destination.size * source_rect.size) / texture_size)
	draw_colored_polygon(points, Color.WHITE, uvs, texture)


func _draw_glow_round_rect(rect: Rect2, fill: Color, border: Color, width: float, radius: float, strong := false, glow_extent := -1.0) -> void:
	_draw_round_rect_glow(rect, border, radius, strong, glow_extent)
	draw_style_box(_style_box(fill, border, width, radius, radius), rect)


func _draw_round_rect_glow(rect: Rect2, border: Color, radius: float, strong: bool, glow_extent := -1.0) -> void:
	var extent := presentation.frame_glow_radius if glow_extent < 0.0 else glow_extent
	var peak_alpha := 0.32 if strong else 0.24
	for glow: Vector2 in _glow_passes(extent, peak_alpha):
		# Put the inner edge underneath the original border, never over image content.
		var width := ceili(glow.x) + 1
		var style := _style_box(Color.TRANSPARENT, Color(border, glow.y * border.a), width, radius + glow.x, radius + glow.x)
		draw_style_box(style, rect.grow(glow.x))


func _draw_glow_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	for glow: Vector2 in _glow_passes(presentation.connector_glow_radius, 0.20):
		draw_line(from, to, Color(color, color.a * glow.y), width + glow.x * 2.0, true)
	draw_line(from, to, color, width, true)


func _refresh_glow_cache() -> void:
	var settings := [presentation.text_glow_radius, presentation.bar_glow_radius, presentation.frame_glow_radius, presentation.connector_glow_radius, presentation.foreground_glow_strength]
	if settings != _glow_settings:
		_glow_settings = settings
		_glow_pass_cache.clear()
		_style_cache.clear()


func _glow_passes(radius: float, peak_alpha: float) -> Array[Vector2]:
	var key := Vector2(radius, peak_alpha)
	if _glow_pass_cache.has(key):
		return _glow_pass_cache[key]
	var result: Array[Vector2] = []
	var peak := clampf(peak_alpha * presentation.foreground_glow_strength, 0.0, 0.95)
	if radius > 0.0 and peak > 0.0:
		var accumulated := 0.0
		for step: int in range(GLOW_PASSES, 0, -1):
			var distance := float(step - 1) / GLOW_PASSES
			# Sigma = radius/3. Incremental source-over alpha makes the near-edge
			# opacity equal to peak for every radius, independent of pass overlap.
			var target := peak * exp(-4.5 * distance * distance)
			var alpha := (target - accumulated) / (1.0 - accumulated)
			result.append(Vector2(radius * float(step) / GLOW_PASSES, alpha))
			accumulated = target
	_glow_pass_cache[key] = result
	return result


func _style_box(fill: Color, border: Color, border_width: float, left_radius: float, right_radius: float) -> StyleBoxFlat:
	var integer_width := roundi(border_width)
	var key := str([fill, border, integer_width, roundi(left_radius), roundi(right_radius)])
	if _style_cache.has(key):
		return _style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = integer_width
	style.border_width_top = integer_width
	style.border_width_right = integer_width
	style.border_width_bottom = integer_width
	style.corner_radius_top_left = roundi(left_radius)
	style.corner_radius_bottom_left = roundi(left_radius)
	style.corner_radius_top_right = roundi(right_radius)
	style.corner_radius_bottom_right = roundi(right_radius)
	style.anti_aliasing = true
	_style_cache[key] = style
	return style


