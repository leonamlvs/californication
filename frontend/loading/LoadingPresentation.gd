class_name LoadingPresentation
extends Control

## Reference-matched, deterministic boot loading presentation.
## The controller owns elapsed time; this class only renders a normalized seek position.

const LOGICAL_SIZE := Vector2(960.0, 720.0)
const TOTAL_DURATION := 2.0
const REFERENCE_PHASE_END := 0.95
const FILL_COMPLETION_END := 0.975
const BAR_OUTER := Rect2(58.0, 249.0, 838.0, 43.0)
const BAR_INNER := Rect2(61.0, 252.0, 833.0, 37.0)
const TEXT_BOUNDS := Rect2(80.0, 195.0, 374.0, 40.0)
const IMAGE_SIZE := Vector2(82.0, 82.0)
const IMAGE_LEFTS: Array[float] = [55.0, 165.0, 274.0, 382.0, 491.0, 600.0, 709.0, 817.0]
const IMAGE_TOPS: Array[float] = [409.0, 373.0, 409.0, 373.0, 409.0, 373.0, 409.0, 373.0]

# Source-frame measurements use exclusive fill-right coordinates from the 1280-wide capture.
# Frames 11-70 occupy the first 1.9 seconds and preserve the source's three visible pauses.
const FILL_FRAMES: Array[float] = [
	11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0,
	21.0, 22.0, 23.0, 24.0, 25.0, 26.0, 27.0, 28.0, 29.0, 39.0,
	40.0, 41.0, 42.0, 43.0, 52.0, 53.0, 54.0, 55.0, 56.0, 57.0,
	58.0, 59.0, 60.0, 61.0, 62.0, 68.0, 69.0, 70.0,
]
const FILL_RIGHTS: Array[float] = [
	221.0, 221.0, 239.0, 257.0, 294.0, 312.0, 330.0, 349.0, 385.0, 404.0,
	422.0, 440.0, 477.0, 495.0, 513.0, 532.0, 568.0, 586.0, 605.0, 605.0,
	630.0, 655.0, 681.0, 706.0, 706.0, 721.0, 736.0, 766.0, 794.0, 822.0,
	850.0, 906.0, 934.0, 962.0, 990.0, 990.0, 1015.0, 1040.0,
]
const IMAGE_REVEAL_FRAMES: Array[float] = [15.0, 19.0, 24.0, 29.0, 43.0, 55.0, 59.0, 62.0]
const DEFAULT_BACKGROUND_TEXTURE: Texture2D = preload("res://art/loading/california-map.svg")

@export_group("Background Map")
@export var background_texture: Texture2D = DEFAULT_BACKGROUND_TEXTURE
@export_range(0.01, 4.0, 0.01) var background_map_scale := 1.0
@export var background_map_offset := Vector2.ZERO
@export var background_color := Color("313189")
@export var background_map_tint := Color(1.12, 1.06, 1.02, 1.0)
@export_range(0.0, 1.0, 0.01) var background_map_opacity := 1.0
@export_subgroup("Outer Halo")
@export var background_halo_color := Color(0.68, 0.67, 0.88, 1.0)
@export_range(0.0, 1.0, 0.01) var background_halo_strength := 0.45
@export_range(0.0, 32.0, 0.5) var background_halo_radius := 32.0
@export var background_halo_direction_bias := Vector2(0.30, -0.45)
@export_subgroup("Drop Shadow")
@export var background_shadow_color := Color(0.08, 0.07, 0.22, 1.0)
@export_range(0.0, 1.0, 0.01) var background_shadow_opacity := 0.10
@export var background_shadow_offset := Vector2(2.0, 3.0)
@export_range(0.0, 10.0, 0.1) var background_shadow_softness := 2.0

@export_group("Loading Text")
@export var loading_fill_color := Color(1.0, 1.0, 1.0, 0.5)

@export_group("Foreground Glow")
@export_range(0.0, 24.0, 0.5) var text_glow_radius := 8.0
@export_range(0.0, 24.0, 0.5) var bar_glow_radius := 12.0
@export_range(0.0, 24.0, 0.5) var frame_glow_radius := 8.0
@export_range(0.0, 24.0, 0.5) var connector_glow_radius := 6.0
@export_range(0.0, 2.0, 0.05) var foreground_glow_strength := 1.0

@export_group("Replaceable Assets")
@export var loading_font: Font
@export var loading_fill_font: Font
@export var image_1: Texture2D
@export var image_2: Texture2D
@export var image_3: Texture2D
@export var image_4: Texture2D
@export var image_5: Texture2D
@export var image_6: Texture2D
@export var image_7: Texture2D
@export var image_8: Texture2D

@onready var indigo_backdrop: ColorRect = %IndigoBackdrop
@onready var background_map: LoadingSvgBackground = %BackgroundMap
@onready var foreground: LoadingForeground = %Foreground

var normalized_time := 0.0
var fill_fraction := 0.0
var revealed_image_count := 0
var highlighted_image_index := -1
var _composition_rect := Rect2(Vector2.ZERO, LOGICAL_SIZE)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_composition_rect()
	refresh_background()
	reset()


func reset() -> void:
	set_progress(0.0)
	if is_instance_valid(background_map):
		background_map.render_once()


func refresh_background() -> void:
	if not is_node_ready():
		return
	indigo_backdrop.color = background_color
	background_map.configure(
		background_texture,
		background_map_scale,
		background_map_offset,
		background_map_tint,
		background_map_opacity,
		background_halo_color,
		background_halo_strength,
		background_halo_radius,
		background_halo_direction_bias,
		background_shadow_color,
		background_shadow_opacity,
		background_shadow_offset,
		background_shadow_softness
	)


func set_progress(value: float) -> void:
	normalized_time = clampf(value, 0.0, 1.0)
	var source_frame := _source_frame_for(normalized_time)
	fill_fraction = _fill_for(normalized_time, source_frame)
	revealed_image_count = 0
	if normalized_time <= REFERENCE_PHASE_END:
		for reveal_frame: float in IMAGE_REVEAL_FRAMES:
			if source_frame >= reveal_frame:
				revealed_image_count += 1
	else:
		revealed_image_count = IMAGE_REVEAL_FRAMES.size()
	highlighted_image_index = revealed_image_count - 1
	foreground.queue_redraw()


func get_visual_snapshot() -> Dictionary:
	_update_composition_rect()
	var result := {
		"normalized_time": normalized_time,
		"fill_fraction": fill_fraction,
		"revealed_image_count": revealed_image_count,
		"highlighted_image_index": highlighted_image_index,
		"composition_rect": _composition_rect,
		"bar_outer_rect": _logical_to_actual(BAR_OUTER),
		"text_bounds": _logical_to_actual(TEXT_BOUNDS),
		"image_frame_rects": _actual_image_rects(),
	}
	if is_instance_valid(background_map):
		var background_snapshot := background_map.snapshot()
		for key: String in background_snapshot:
			result["background_%s" % key] = background_snapshot[key]
		result["background_projected_bounds"] = _logical_to_actual(background_snapshot.projected_bounds_logical)
	return result


func _source_frame_for(value: float) -> float:
	return 70.0 if value > REFERENCE_PHASE_END else 11.0 + 59.0 * value / REFERENCE_PHASE_END


func _fill_for(value: float, source_frame: float) -> float:
	var measured_final := (1040.0 - 221.0) / 833.0
	if value > REFERENCE_PHASE_END:
		return lerpf(measured_final, 1.0, inverse_lerp(REFERENCE_PHASE_END, FILL_COMPLETION_END, minf(value, FILL_COMPLETION_END)))
	for index: int in range(FILL_FRAMES.size() - 1):
		if source_frame <= FILL_FRAMES[index + 1]:
			var right := lerpf(FILL_RIGHTS[index], FILL_RIGHTS[index + 1], inverse_lerp(FILL_FRAMES[index], FILL_FRAMES[index + 1], source_frame))
			return clampf((right - 221.0) / 833.0, 0.0, 1.0)
	return measured_final


func _logical_to_actual(rect: Rect2) -> Rect2:
	var scale_factor := _composition_rect.size.x / LOGICAL_SIZE.x
	return Rect2(_composition_rect.position + rect.position * scale_factor, rect.size * scale_factor)


func _actual_image_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for index: int in IMAGE_LEFTS.size():
		result.append(_logical_to_actual(Rect2(Vector2(IMAGE_LEFTS[index], IMAGE_TOPS[index]), IMAGE_SIZE)))
	return result


func _update_composition_rect() -> void:
	var scale_factor := minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	scale_factor = maxf(scale_factor, 0.001)
	var composition_size := LOGICAL_SIZE * scale_factor
	_composition_rect = Rect2((size - composition_size) * 0.5, composition_size)
	if is_instance_valid(indigo_backdrop):
		indigo_backdrop.position = _composition_rect.position
		indigo_backdrop.size = _composition_rect.size
	if is_instance_valid(background_map):
		background_map.set_composition_rect(_composition_rect)
	if is_instance_valid(foreground):
		foreground.position = _composition_rect.position
		foreground.size = _composition_rect.size


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_composition_rect()
		if is_instance_valid(foreground):
			foreground.queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_instance_valid(background_map):
		background_map.set_loading_active(is_visible_in_tree())
