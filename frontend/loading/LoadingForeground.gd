class_name LoadingForeground
extends Control

## Sharp loading UI drawn above the independently cached map background.
const LOGICAL_SIZE := Vector2(960.0, 720.0)
const BAR_OUTER := Rect2(58.0, 249.0, 838.0, 43.0)
const BAR_INNER := Rect2(61.0, 252.0, 833.0, 37.0)
const TEXT_BOUNDS := Rect2(80.0, 195.0, 374.0, 40.0)
const IMAGE_SIZE := Vector2(82.0, 82.0)
const IMAGE_BORDER_WIDTH := 2.5
const IMAGE_CORNER_RADIUS := 7.0
const IMAGE_BORDER_OVERLAP := 0.5
const CORNER_SEGMENTS := 8
const IMAGE_LEFTS: Array[float] = [55.0, 165.0, 274.0, 382.0, 491.0, 600.0, 709.0, 817.0]
const IMAGE_TOPS: Array[float] = [409.0, 373.0, 409.0, 373.0, 409.0, 373.0, 409.0, 373.0]

@onready var presentation: LoadingPresentation = get_parent() as LoadingPresentation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
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
	_draw_glow_round_rect(BAR_OUTER, Color(0.09, 0.12, 0.38, 0.74), Color(0.93, 0.95, 1.0, 0.96), 2.5, 9.0)
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
	var text := "NOW LOADING"
	var font_size := 42
	var natural_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_scale := Vector2(TEXT_BOUNDS.size.x / maxf(natural_size.x, 1.0), TEXT_BOUNDS.size.y / maxf(natural_size.y, 1.0))
	# The fallback font's line box includes roughly ten pixels above its visible caps.
	var global_origin := composition_offset + (TEXT_BOUNDS.position + Vector2(0, -10)) * composition_scale
	draw_set_transform(global_origin, 0.0, Vector2(composition_scale * text_scale.x, composition_scale * text_scale.y))
	var baseline := Vector2(0.0, font.get_ascent(font_size))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 7, Color(0.58, 0.65, 0.94, 0.20))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color(0.92, 0.95, 1.0, 0.98))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.82, 0.85, 0.96, 0.92))


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


func _draw_glow_round_rect(rect: Rect2, fill: Color, border: Color, width: float, radius: float, strong := false) -> void:
	_draw_round_rect_glow(rect, border, radius, strong)
	draw_style_box(_style_box(fill, border, width, radius, radius), rect)


func _draw_round_rect_glow(rect: Rect2, border: Color, radius: float, strong: bool) -> void:
	var glow_alpha := 0.18 if strong else 0.11
	draw_style_box(_style_box(Color.TRANSPARENT, Color(border, glow_alpha), 8.0, radius + 4.0, radius + 4.0), rect.grow(3.0))
	draw_style_box(_style_box(Color.TRANSPARENT, Color(border, glow_alpha + 0.05), 5.0, radius + 2.0, radius + 2.0), rect.grow(1.0))


func _draw_glow_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, Color(color, color.a * 0.10), width + 8.0, true)
	draw_line(from, to, Color(color, color.a * 0.18), width + 4.0, true)
	draw_line(from, to, color, width, true)


func _style_box(fill: Color, border: Color, border_width: float, left_radius: float, right_radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	var integer_width := roundi(border_width)
	style.border_width_left = integer_width
	style.border_width_top = integer_width
	style.border_width_right = integer_width
	style.border_width_bottom = integer_width
	style.corner_radius_top_left = roundi(left_radius)
	style.corner_radius_bottom_left = roundi(left_radius)
	style.corner_radius_top_right = roundi(right_radius)
	style.corner_radius_bottom_right = roundi(right_radius)
	style.anti_aliasing = true
	return style


