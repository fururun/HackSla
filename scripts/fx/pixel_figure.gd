class_name PixelFigure
extends RefCounted
## 整数矩形の絵を一つのメッシュにまとめる。画像ファイルは作らない。

var _vertices := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


func add_rect(rect: Rect2, ink: Color) -> void:
	var start: int = _vertices.size()
	for point: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		_vertices.append(Vector3(point.x, point.y, 0))
		_colors.append(ink)
	for index: int in [0, 1, 2, 0, 2, 3]:
		_indices.append(start + index)


func make_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
