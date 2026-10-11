class_name LoadingCaliforniaPlaceholder
extends Node3D

## Replaceable graybox only. The final loading model is supplied through LoadingPresentation.

const PIXELS_PER_UNIT := 100.0
const LOGICAL_CENTER := Vector2(480.0, 360.0)
const BACK_OFFSET_PIXELS := Vector2(9.0, 12.0)
const DEPTH := 0.12
static var CONTOUR := PackedVector2Array([
	Vector2(150, 82), Vector2(317, 82), Vector2(317, 124), Vector2(337, 132),
	Vector2(337, 195), Vector2(472, 231), Vector2(603, 267), Vector2(697, 293),
	Vector2(758, 335), Vector2(803, 389), Vector2(852, 499), Vector2(786, 519),
	Vector2(758, 548), Vector2(714, 568), Vector2(588, 616), Vector2(552, 610),
	Vector2(513, 570), Vector2(476, 529), Vector2(444, 478), Vector2(410, 421),
	Vector2(376, 369), Vector2(340, 321), Vector2(298, 281), Vector2(254, 244),
	Vector2(216, 220), Vector2(164, 220), Vector2(158, 194), Vector2(164, 178),
	Vector2(145, 153), Vector2(143, 129), Vector2(151, 113),
])

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	mesh_instance.mesh = _build_mesh()


func _build_mesh() -> ArrayMesh:
	var triangulation := Geometry2D.triangulate_polygon(CONTOUR)
	assert(not triangulation.is_empty(), "Loading California placeholder contour could not be triangulated.")
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	for point: Vector2 in CONTOUR:
		front.append(_logical_to_world(point, 0.0))
		back.append(_logical_to_world(point + BACK_OFFSET_PIXELS, -DEPTH))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle_index: int in range(0, triangulation.size(), 3):
		var a := triangulation[triangle_index]
		var b := triangulation[triangle_index + 1]
		var c := triangulation[triangle_index + 2]
		_add_oriented_triangle(surface, front[a], front[b], front[c], Vector3.BACK)
		_add_oriented_triangle(surface, back[a], back[b], back[c], Vector3.FORWARD)

	for index: int in CONTOUR.size():
		var next := (index + 1) % CONTOUR.size()
		_add_triangle(surface, front[index], front[next], back[next])
		_add_triangle(surface, front[index], back[next], back[index])

	return surface.commit()


func _logical_to_world(point: Vector2, depth: float) -> Vector3:
	return Vector3(
		(point.x - LOGICAL_CENTER.x) / PIXELS_PER_UNIT,
		-(point.y - LOGICAL_CENTER.y) / PIXELS_PER_UNIT,
		depth
	)


func _add_oriented_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, desired_normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(desired_normal) < 0.0:
		var swap := b
		b = c
		c = swap
	_add_triangle(surface, a, b, c)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)
