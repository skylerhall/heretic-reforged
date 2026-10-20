class_name GeometryBuilder
extends RefCounted
## Turns MapData into render meshes and collision triangles.
## Map (x, y, z) becomes Godot (x, z, -y) scaled to meters.

const S := Layers.S
const CHUNK := 512.0   # static geometry is split into cells so each cell
                       # only pays for the lights near it

var map: MapData
var tex: TextureLibrary
var sector_tris: Array = []   # per sector: flat PackedVector2Array of triangle corners
var sector_bounds: Array = [] # per sector: Rect2 in map units


class Accum:
	var chunked := false
	var surfaces := {}
	var faces := PackedVector3Array()        # solid for everyone
	var block_faces := PackedVector3Array()  # solid for monsters only

	func add_tri(mat_key: String, chunk: Vector2i, p: Array, uv: Array, n: Vector3, t: Vector3,
			image_up: Vector3, light: float) -> void:
		var key := "%s@%d,%d" % [mat_key, chunk.x, chunk.y] if chunked else mat_key
		if not surfaces.has(key):
			surfaces[key] = {"mat": mat_key, "chunk": chunk, "v": PackedVector3Array(),
				"n": PackedVector3Array(), "t": PackedFloat32Array(), "uv": PackedVector2Array(),
				"c": PackedColorArray()}
		var s: Dictionary = surfaces[key]
		var a: Vector3 = p[0]
		var b: Vector3 = p[1]
		var c: Vector3 = p[2]
		var ua: Vector2 = uv[0]
		var ub: Vector2 = uv[1]
		var uc: Vector2 = uv[2]
		# Godot treats clockwise triangles as front-facing.
		if (b - a).cross(c - a).dot(n) > 0.0:
			var tmp := b
			b = c
			c = tmp
			var tuv := ub
			ub = uc
			uc = tuv
		var w := 1.0 if n.cross(t).dot(image_up) > 0.0 else -1.0
		var col := Color(light, light, light)
		for v in [[a, ua], [b, ub], [c, uc]]:
			s.v.append(v[0])
			s.uv.append(v[1])
			s.n.append(n)
			s.t.append_array([t.x, t.y, t.z, w])
			s.c.append(col)


func _init(m: MapData, t: TextureLibrary) -> void:
	map = m
	tex = t
	_triangulate_sectors()


static func to_world(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x * S, z * S, -p.y * S)


func _triangulate_sectors() -> void:
	var edges := []
	for i in map.sectors.size():
		edges.append([])
	for line in map.lines:
		var a := map.vertices[line.v1]
		var b := map.vertices[line.v2]
		if a == b:
			continue
		var fs := map.front_sector(line)
		var bs := map.back_sector(line)
		if fs == bs:
			continue
		if fs >= 0:
			edges[fs].append([a, b])
		if bs >= 0:
			edges[bs].append([b, a])
	for i in map.sectors.size():
		var tris := PolyTools.triangulate_sector(PolyTools.build_loops(edges[i]))
		sector_tris.append(tris)
		var r := Rect2()
		if not tris.is_empty():
			r = Rect2(tris[0], Vector2.ZERO)
			for p in tris:
				r = r.expand(p)
		sector_bounds.append(r)


## Floor or ceiling of a sector. With `local`, it is built at height 0 so a
## moving sector can be translated instead of rebuilt.
func emit_plane(acc: Accum, s: int, is_floor: bool, local := false) -> void:
	var sec: Dictionary = map.sectors[s]
	var tex_name: String = sec.floor_tex if is_floor else sec.ceil_tex
	var h: float = 0.0 if local else (sec.floor if is_floor else sec.ceil)
	var tris: PackedVector2Array = sector_tris[s]
	var visible := not (not is_floor and tex.is_sky_flat(tex_name))
	var t := tex.flat(tex_name)
	var n := Vector3.UP if is_floor else Vector3.DOWN
	var light := _light(sec)
	for i in range(0, tris.size() - 2, 3):
		var pts := [tris[i], tris[i + 1], tris[i + 2]]
		var p := [to_world(pts[0], h), to_world(pts[1], h), to_world(pts[2], h)]
		acc.faces.append_array(PackedVector3Array(p))
		if not visible:
			continue
		var uv := []
		for q in pts:
			uv.append(Vector2(q.x / t.width, -q.y / t.height))
		var centre: Vector2 = (pts[0] + pts[1] + pts[2]) / 3.0
		acc.add_tri("f:" + tex_name, _chunk_of(centre), p, uv, n, Vector3.RIGHT, Vector3.FORWARD, light)


func emit_line(acc: Accum, li: int) -> void:
	var line: Dictionary = map.lines[li]
	var v1 := map.vertices[line.v1]
	var v2 := map.vertices[line.v2]
	if v1.distance_to(v2) < 0.01:
		return
	if line.front >= 0:
		_emit_side(acc, line, v1, v2, line.front, line.back)
	if line.back >= 0:
		_emit_side(acc, line, v2, v1, line.back, line.front)
	if line.front >= 0 and line.back >= 0 and (line.flags & 3) != 0:
		var a: Dictionary = map.sectors[map.front_sector(line)]
		var b: Dictionary = map.sectors[map.back_sector(line)]
		var lo := minf(a.floor, b.floor) - 64.0
		var hi := maxf(a.ceil, b.ceil) + 64.0
		var quad := _quad_points(v1, v2, lo, hi)
		var tris := PackedVector3Array([quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]])
		if line.flags & 1:
			acc.faces.append_array(tris)
		else:
			acc.block_faces.append_array(tris)


func _emit_side(acc: Accum, line: Dictionary, a: Vector2, b: Vector2, side_idx: int, other_idx: int) -> void:
	var side: Dictionary = map.sides[side_idx]
	var sec: Dictionary = map.sectors[side.sector]
	var f: float = sec.floor
	var c: float = sec.ceil
	var light := _light(sec)
	var flags: int = line.flags
	if other_idx < 0:
		var t := tex.wall(side.middle)
		if t == null:
			t = tex._get_fallback()
		var top := f + t.height if (flags & 16) else c
		_wall(acc, "w:", t, a, b, f, c, top, side, light, true)
		return
	var osec: Dictionary = map.sectors[map.sides[other_idx].sector]
	var of: float = osec.floor
	var oc: float = osec.ceil
	if of > f:
		var t := tex.wall(side.lower)
		var top := c if (flags & 16) else of
		_wall(acc, "w:", t, a, b, f, of, top, side, light, true)
	if oc < c:
		var sky_both := tex.is_sky_flat(sec.ceil_tex) and tex.is_sky_flat(osec.ceil_tex)
		var t := tex.wall(side.upper)
		if sky_both or t == null:
			var q := _quad_points(a, b, oc, c)
			acc.faces.append_array(PackedVector3Array([q[0], q[1], q[2], q[0], q[2], q[3]]))
		else:
			var top := c if (flags & 8) else oc + t.height
			_wall(acc, "w:", t, a, b, oc, c, top, side, light, true)
	if side.middle != "-" and side.middle != "":
		var t := tex.wall(side.middle)
		if t != null:
			var lo := maxf(f, of)
			var hi := minf(c, oc)
			var top: float = (lo + t.height if (flags & 16) else hi) + side.yoff
			var z0 := maxf(top - t.height, lo)
			var z1 := minf(top, hi)
			if z1 > z0:
				var plain := side.duplicate()
				plain.yoff = 0.0
				_wall(acc, "m:" if t.masked else "w:", t, a, b, z0, z1, top, plain, light, false)


func _wall(acc: Accum, kind: String, t: TextureLibrary.TexInfo, a: Vector2, b: Vector2, z0: float, z1: float,
		top_ref: float, side: Dictionary, light: float, collide: bool) -> void:
	if t == null or z1 - z0 < 0.01:
		return
	var length := a.distance_to(b)
	var d := (b - a) / length
	var q := _quad_points(a, b, z0, z1)
	var xo: float = side.xoff
	var yo: float = side.yoff
	var u0 := xo / t.width
	var u1 := (xo + length) / t.width
	var v_bot := (top_ref - z0 + yo) / t.height
	var v_top := (top_ref - z1 + yo) / t.height
	var uv := [Vector2(u0, v_bot), Vector2(u1, v_bot), Vector2(u1, v_top), Vector2(u0, v_top)]
	var n := Vector3(d.y, 0.0, d.x)
	var tangent := Vector3(d.x, 0.0, -d.y)
	var chunk := _chunk_of((a + b) * 0.5)
	var key := kind + t.name
	acc.add_tri(key, chunk, [q[0], q[1], q[2]], [uv[0], uv[1], uv[2]], n, tangent, Vector3.UP, light)
	acc.add_tri(key, chunk, [q[0], q[2], q[3]], [uv[0], uv[2], uv[3]], n, tangent, Vector3.UP, light)
	if collide:
		acc.faces.append_array(PackedVector3Array([q[0], q[1], q[2], q[0], q[2], q[3]]))


func _quad_points(a: Vector2, b: Vector2, z0: float, z1: float) -> Array:
	return [to_world(a, z0), to_world(b, z0), to_world(b, z1), to_world(a, z1)]


func _chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))


func _light(sec: Dictionary) -> float:
	return clampf(float(sec.light) / 255.0, 0.0, 1.0)


## Creates MeshInstance3D nodes (one per chunk) and, optionally, a static
## body holding the collision triangles.
func make_nodes(acc: Accum, parent: Node3D, collision := true) -> void:
	var meshes := {}
	for key in acc.surfaces:
		var s: Dictionary = acc.surfaces[key]
		if s.v.is_empty():
			continue
		var ck: Vector2i = s.chunk
		if not meshes.has(ck):
			meshes[ck] = ArrayMesh.new()
		var mesh: ArrayMesh = meshes[ck]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.v
		arrays[Mesh.ARRAY_NORMAL] = s.n
		arrays[Mesh.ARRAY_TANGENT] = s.t
		arrays[Mesh.ARRAY_TEX_UV] = s.uv
		arrays[Mesh.ARRAY_COLOR] = s.c
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(s.mat))
	for ck in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[ck]
		# Ceilings face down, so from the moon they'd be back faces; double
		# sided shadows keep moonlight out of interiors.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		parent.add_child(mi)
	if collision and not acc.faces.is_empty():
		parent.add_child(_body(acc.faces, Layers.WORLD))
	if collision and not acc.block_faces.is_empty():
		parent.add_child(_body(acc.block_faces, Layers.MONSTER_BLOCK))


func _body(faces: PackedVector3Array, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


func _material(key: String) -> Material:
	var kind := key.substr(0, 2)
	var name := key.substr(2)
	var t := tex.flat(name) if kind == "f:" else tex.wall(name)
	return tex.material(t, kind == "m:")


## Index of the sector containing a map-space point, or -1.
func sector_at(p: Vector2) -> int:
	var best := -1
	for s in sector_tris.size():
		var r: Rect2 = sector_bounds[s]
		if p.x < r.position.x or p.y < r.position.y or p.x > r.end.x or p.y > r.end.y:
			continue
		var tris: PackedVector2Array = sector_tris[s]
		for i in range(0, tris.size() - 2, 3):
			if PolyTools.point_in_triangle(p, tris[i], tris[i + 1], tris[i + 2]):
				# nested sectors sit inside their parent's bounds; prefer the smaller
				if best < 0 or r.get_area() < (sector_bounds[best] as Rect2).get_area():
					best = s
				break
	return best
