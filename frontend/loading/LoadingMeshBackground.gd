class_name LoadingMeshBackground
extends Control

const DEFAULT_MODEL: PackedScene = preload("res://frontend/loading/LoadingCaliforniaPlaceholder.tscn")
const MESH_SHADER: Shader = preload("res://frontend/loading/loading_mesh.gdshader")
const LOGICAL_SIZE := Vector2(960.0, 720.0)
const PIXELS_PER_UNIT := 100.0
const TARGET_RECT := Rect2(143.0, 82.0, 718.0, 546.0)

@onready var viewport: SubViewport = $SubViewport
@onready var model_pivot: Node3D = $SubViewport/ModelPivot
@onready var model_transform: Node3D = $SubViewport/ModelPivot/ModelTransform
@onready var texture_rect: TextureRect = $MeshTexture

var _mesh_material: ShaderMaterial
var _model_root: Node3D
var _logical_projected_bounds := TARGET_RECT
var _fitted_depth := 0.0
var _mesh_count := 0
var _using_fallback := false
var _warned_meshless := false


func _ready() -> void:
	texture_rect.texture = viewport.get_texture()
	texture_rect.material = texture_rect.material.duplicate()
	_mesh_material = ShaderMaterial.new()
	_mesh_material.shader = MESH_SHADER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(
	model_scene: PackedScene,
	rotation_degrees: Vector3,
	model_scale: float,
	offset_pixels: Vector2,
	mesh_tint: Color,
	surface_opacity: float,
	edge_strength: float,
	halo_strength: float,
	halo_radius_pixels: float
) -> void:
	_mesh_material.set_shader_parameter("mesh_tint", mesh_tint)
	var composite := texture_rect.material as ShaderMaterial
	composite.set_shader_parameter("surface_opacity", surface_opacity)
	composite.set_shader_parameter("edge_strength", edge_strength)
	composite.set_shader_parameter("halo_strength", halo_strength)
	composite.set_shader_parameter("edge_width_px", 1.0)
	composite.set_shader_parameter("halo_radius_px", halo_radius_pixels * 0.5)
	_replace_model(model_scene, rotation_degrees, model_scale, offset_pixels)
	render_once()


func set_composition_rect(composition_rect: Rect2) -> void:
	texture_rect.position = composition_rect.position
	texture_rect.size = composition_rect.size


func set_loading_active(active: bool) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if active else SubViewport.UPDATE_DISABLED


func render_once() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED


func snapshot() -> Dictionary:
	return {
		"viewport_size": viewport.size,
		"viewport_update_mode": viewport.render_target_update_mode,
		"world_isolated": viewport.own_world_3d and viewport.find_world_3d() != get_viewport().find_world_3d(),
		"mesh_instance_count": _mesh_count,
		"model_root_count": model_transform.get_child_count(),
		"material_override_count": _count_material_overrides(),
		"mesh_depth": _fitted_depth,
		"projected_bounds_logical": _logical_projected_bounds,
		"using_fallback": _using_fallback,
	}


func _count_material_overrides() -> int:
	var count := 0
	if _model_root != null:
		for mesh_instance: MeshInstance3D in _collect_meshes(_model_root):
			if mesh_instance.material_override == _mesh_material:
				count += 1
	return count


func _replace_model(model_scene: PackedScene, rotation_degrees: Vector3, model_scale: float, offset_pixels: Vector2) -> void:
	_clear_model()
	_using_fallback = model_scene == null
	var requested := model_scene if model_scene != null else DEFAULT_MODEL
	_model_root = requested.instantiate() as Node3D
	if _model_root == null:
		_using_fallback = true
		_model_root = DEFAULT_MODEL.instantiate() as Node3D
	_sanitize_model(_model_root)
	model_transform.add_child(_model_root)
	model_transform.rotation_degrees = rotation_degrees
	var meshes := _collect_meshes(_model_root)
	if meshes.is_empty() and requested != DEFAULT_MODEL:
		model_transform.remove_child(_model_root)
		_model_root.queue_free()
		_model_root = DEFAULT_MODEL.instantiate() as Node3D
		_sanitize_model(_model_root)
		model_transform.add_child(_model_root)
		meshes = _collect_meshes(_model_root)
		_using_fallback = true
		if OS.is_debug_build() and not _warned_meshless:
			push_warning("Loading background model contained no MeshInstance3D; using the California placeholder.")
			_warned_meshless = true
	_mesh_count = meshes.size()
	for mesh_instance: MeshInstance3D in meshes:
		mesh_instance.material_override = _mesh_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fit_model(meshes, maxf(model_scale, 0.001), offset_pixels)


func _clear_model() -> void:
	if _model_root == null:
		return
	model_transform.remove_child(_model_root)
	_model_root.queue_free()
	_model_root = null


func _sanitize_model(root: Node) -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in root.find_children("*", "", true, false):
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is Camera3D:
			(child as Camera3D).current = false
		elif child is Light3D:
			(child as Light3D).visible = false
		elif child is AnimationPlayer:
			(child as AnimationPlayer).stop()


func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		result.append(root as MeshInstance3D)
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh != null:
			result.append(mesh_instance)
	return result


func _fit_model(meshes: Array[MeshInstance3D], user_scale: float, offset_pixels: Vector2) -> void:
	model_pivot.position = Vector3.ZERO
	model_pivot.scale = Vector3.ONE
	model_transform.force_update_transform()
	var bounds := _combined_bounds(meshes)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var target_world_size := TARGET_RECT.size / PIXELS_PER_UNIT
	var fitted_scale := minf(target_world_size.x / bounds.size.x, target_world_size.y / bounds.size.y) * user_scale
	model_pivot.scale = Vector3.ONE * fitted_scale
	var target_center_pixels := TARGET_RECT.get_center() - LOGICAL_SIZE * 0.5 + offset_pixels
	var target_center_world := Vector3(target_center_pixels.x, -target_center_pixels.y, 0.0) / PIXELS_PER_UNIT
	var bounds_center := bounds.get_center()
	model_pivot.position = target_center_world - bounds_center * fitted_scale
	var projected_size := Vector2(bounds.size.x, bounds.size.y) * fitted_scale * PIXELS_PER_UNIT
	var projected_center := LOGICAL_SIZE * 0.5 + Vector2(
		bounds_center.x * fitted_scale + model_pivot.position.x,
		-(bounds_center.y * fitted_scale + model_pivot.position.y)
	) * PIXELS_PER_UNIT
	_logical_projected_bounds = Rect2(projected_center - projected_size * 0.5, projected_size)
	_fitted_depth = bounds.size.z * fitted_scale


func _combined_bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for mesh_instance: MeshInstance3D in meshes:
		mesh_instance.force_update_transform()
		var relative := model_pivot.global_transform.affine_inverse() * mesh_instance.global_transform
		var local_aabb := mesh_instance.get_aabb()
		for endpoint: int in 8:
			var point := relative * local_aabb.get_endpoint(endpoint)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)
