extends Node3D

@export var profile: IslandRuntimeTransitionProfile
@export var island_asset: PackedScene = preload("res://frontend/island/live/assets/island.glb")
@export var island_texture: Texture2D = preload("res://frontend/island/live/assets/island-color.png")
@export var ocean_profile: IslandRuntimeOceanProfile = preload("res://frontend/island/live/ocean.tres")
var water_time := 0.0
var pivot: Node3D
var camera: Camera3D
var ocean: MeshInstance3D
var ocean_material: ShaderMaterial
var _color_material: StandardMaterial3D
var _relief_material: ShaderMaterial


func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	var asset := island_asset.instantiate()
	pivot.add_child(asset)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = island_texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_color_material = material
	_relief_material = ShaderMaterial.new()
	_relief_material.shader = Shader.new()
	_relief_material.shader.code = "shader_type spatial; render_mode unshaded; void fragment(){ALBEDO=vec3(0.66,0.72,0.78)*(0.22+0.78*max(dot(normalize(NORMAL),normalize(vec3(-0.4,0.7,0.8))),0.0));}"
	for node in asset.find_children("*", "MeshInstance3D"):
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, 240.0)
	ocean.mesh = plane
	ocean_material = ShaderMaterial.new()
	configure_ocean()
	ocean.material_override = ocean_material
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	camera.far = 250.0
	camera.current = true
	add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("07134a")
	add_child(environment)
	sample(profile.reveal_time, false)


func sample(time: float, rotate := true, rotation_override := INF) -> void:
	var pose := profile.sample(time)
	camera.size = pose.size
	var target: Vector3 = pose.target
	var offset := Vector3(0.0, sin(pose.elevation), cos(pose.elevation)) * profile.camera_distance
	camera.position = target + offset
	camera.look_at(target, Vector3.UP)
	camera.rotate_object_local(Vector3.BACK, pose.roll)
	pivot.rotation.y = profile.rotation_at(time) if rotate else 0.0
	if is_finite(rotation_override):
		pivot.rotation.y = rotation_override
	ocean_material.set_shader_parameter("island_from_world", pivot.global_transform.affine_inverse())
	sample_water(time)


func configure_ocean() -> void:
	ocean_material.shader = preload("res://frontend/island/live/ocean_animated.gdshader")
	ocean_profile.apply(ocean_material)
	ocean_profile.sample(ocean_material, water_time)
	if pivot != null:
		ocean_material.set_shader_parameter("island_from_world", pivot.global_transform.affine_inverse())

func sample_water(time: float) -> void:
	water_time = time + profile.water_phase
	ocean_profile.sample(ocean_material, water_time)


func set_relief_view(enabled: bool) -> void:
	for node in pivot.find_children("*", "MeshInstance3D", true, false):
		node.material_override = _relief_material if enabled else _color_material
