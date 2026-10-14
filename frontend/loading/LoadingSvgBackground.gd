class_name LoadingSvgBackground
extends Control

const DEFAULT_TEXTURE: Texture2D = preload("res://art/loading/california-map.svg")
const LOGICAL_SIZE := Vector2(960.0, 720.0)
const TARGET_RECT := Rect2(143.0, 82.0, 718.0, 546.0)

@onready var viewport: SubViewport = %SourceViewport
@onready var horizontal_viewport: SubViewport = %BlurHorizontal
@onready var vertical_viewport: SubViewport = %BlurVertical
@onready var horizontal_pass: TextureRect = %HorizontalPass
@onready var vertical_pass: TextureRect = %VerticalPass
@onready var map_rect: TextureRect = %MapArtwork
@onready var texture_rect: TextureRect = $MapTexture

var _logical_bounds := TARGET_RECT
var _using_fallback := false
var _render_generation := 0


func _ready() -> void:
	# Nested, isolated canvases render source -> horizontal -> vertical together.
	for target: SubViewport in [viewport, horizontal_viewport, vertical_viewport]:
		target.world_2d = World2D.new()
	horizontal_pass.texture = viewport.get_texture()
	vertical_pass.texture = horizontal_viewport.get_texture()
	horizontal_pass.material = horizontal_pass.material.duplicate()
	vertical_pass.material = vertical_pass.material.duplicate()
	texture_rect.texture = viewport.get_texture()
	texture_rect.material = texture_rect.material.duplicate()
	texture_rect.material.set_shader_parameter("blurred_mask", vertical_viewport.get_texture())


func configure(
	map_texture: Texture2D,
	map_scale: float,
	map_offset: Vector2,
	map_tint: Color,
	map_opacity: float,
	halo_color: Color,
	halo_strength: float,
	halo_radius: float,
	halo_direction_bias: Vector2,
	shadow_color: Color,
	shadow_opacity: float,
	shadow_offset: Vector2,
	shadow_softness: float
) -> void:
	_using_fallback = map_texture == null or map_texture.get_width() <= 0 or map_texture.get_height() <= 0
	map_rect.texture = DEFAULT_TEXTURE if _using_fallback else map_texture
	var source_size := map_rect.texture.get_size()
	var fit := minf(TARGET_RECT.size.x / source_size.x, TARGET_RECT.size.y / source_size.y) * maxf(map_scale, 0.001)
	var fitted_size := source_size * fit
	_logical_bounds = Rect2(TARGET_RECT.get_center() + map_offset - fitted_size * 0.5, fitted_size)
	map_rect.position = _logical_bounds.position
	map_rect.size = _logical_bounds.size
	var composite := texture_rect.material as ShaderMaterial
	composite.set_shader_parameter("map_tint", map_tint)
	composite.set_shader_parameter("map_opacity", map_opacity)
	composite.set_shader_parameter("halo_color", halo_color)
	composite.set_shader_parameter("halo_strength", halo_strength)
	composite.set_shader_parameter("halo_direction_bias", halo_direction_bias)
	composite.set_shader_parameter("shadow_color", shadow_color)
	composite.set_shader_parameter("shadow_opacity", shadow_opacity)
	composite.set_shader_parameter("shadow_offset_px", shadow_offset)
	var narrow := _gaussian_kernel(shadow_softness, ceili(shadow_softness * 3.0))
	var broad := _gaussian_kernel(halo_radius / 3.0, ceili(halo_radius))
	for pass_rect: TextureRect in [horizontal_pass, vertical_pass]:
		var material := pass_rect.material as ShaderMaterial
		material.set_shader_parameter("center_weights", Vector2(narrow.center, broad.center))
		material.set_shader_parameter("narrow_pairs", narrow.pairs)
		material.set_shader_parameter("broad_pairs", broad.pairs)
		material.set_shader_parameter("narrow_count", narrow.count)
		material.set_shader_parameter("broad_count", broad.count)
	render_once()


func set_composition_rect(composition_rect: Rect2) -> void:
	texture_rect.position = composition_rect.position
	texture_rect.size = composition_rect.size


func set_loading_active(active: bool) -> void:
	if active:
		render_once()
	else:
		for target: SubViewport in [viewport, horizontal_viewport, vertical_viewport]:
			target.render_target_update_mode = SubViewport.UPDATE_DISABLED


func render_once() -> void:
	if not is_visible_in_tree():
		set_loading_active(false)
		return
	if viewport.render_target_update_mode != SubViewport.UPDATE_ONCE:
		_render_generation += 1
	for target: SubViewport in [viewport, horizontal_viewport, vertical_viewport]:
		target.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not RenderingServer.frame_post_draw.is_connected(_finish_cached_render):
		RenderingServer.frame_post_draw.connect(_finish_cached_render, CONNECT_ONE_SHOT)


func _finish_cached_render() -> void:
	for target: SubViewport in [viewport, horizontal_viewport, vertical_viewport]:
		target.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_finish_cached_render):
		RenderingServer.frame_post_draw.disconnect(_finish_cached_render)


func _gaussian_kernel(sigma: float, radius: int) -> Dictionary:
	radius = clampi(radius, 0, 32)
	var weights := PackedFloat32Array([1.0])
	var total := 1.0
	for distance: int in range(1, radius + 1):
		var weight := exp(-float(distance * distance) / (2.0 * maxf(sigma * sigma, 0.0001)))
		weights.append(weight)
		total += 2.0 * weight
	var pairs := PackedVector2Array()
	pairs.resize(16)
	var count := 0
	for distance: int in range(1, radius + 1, 2):
		var first := weights[distance]
		var second := weights[distance + 1] if distance + 1 <= radius else 0.0
		var combined := first + second
		pairs[count] = Vector2(float(distance) + second / maxf(combined, 0.000001), combined / total)
		count += 1
	return {"center": 1.0 / total, "pairs": pairs, "count": count}


func snapshot() -> Dictionary:
	return {
		"viewport_size": viewport.size,
		"viewport_update_mode": viewport.render_target_update_mode,
		"texture_path": map_rect.texture.resource_path,
		"texture_size": map_rect.texture.get_size(),
		"projected_bounds_logical": _logical_bounds,
		"using_fallback": _using_fallback,
		"effect_target_sizes": [horizontal_viewport.size, vertical_viewport.size],
		"effect_update_modes": [horizontal_viewport.render_target_update_mode, vertical_viewport.render_target_update_mode],
		"render_generation": _render_generation,
		"effect_worlds_isolated": viewport.world_2d != horizontal_viewport.world_2d and viewport.world_2d != vertical_viewport.world_2d and horizontal_viewport.world_2d != vertical_viewport.world_2d and viewport.world_2d != get_viewport().world_2d and horizontal_viewport.world_2d != get_viewport().world_2d and vertical_viewport.world_2d != get_viewport().world_2d,
		"all_targets_2d": viewport.disable_3d and horizontal_viewport.disable_3d and vertical_viewport.disable_3d,
	}
