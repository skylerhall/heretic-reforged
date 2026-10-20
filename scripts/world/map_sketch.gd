class_name MapSketch
extends RefCounted
## Builds Doom-format MapData from room outlines, so the built-in level goes
## through exactly the same geometry pipeline as a map loaded from a WAD.
##
## Rooms must not overlap. Rooms that touch share walls automatically (edges
## are split wherever another room's corner lies on them). A room with a
## `parent` sits inside that room (a pit, a platform); a pillar is a solid
## hole in its parent.


class Room:
	var poly: PackedVector2Array
	var sector := -1
	var wall := ""
	var parent := -1
	var solid := false


var rooms: Array[Room] = []
var sectors: Array[Dictionary] = []
var things: Array[Dictionary] = []
var _side_props: Array = []   # [a, b, room, {upper/lower/middle/xoff/yoff}]
var _line_props: Array = []   # [a, b, {special, tag, flags}]
var _doors := {}              # sector -> door face texture


func room(points: Array, floor_h: float, ceil_h: float, light: int, floor_tex: String, ceil_tex: String,
		wall_tex: String, special := 0, tag := 0, parent := -1) -> int:
	var poly := PackedVector2Array(points)
	if PolyTools.signed_area(poly) > 0.0:
		poly.reverse()
	sectors.append({"floor": floor_h, "ceil": ceil_h, "floor_tex": floor_tex, "ceil_tex": ceil_tex,
		"light": light, "special": special, "tag": tag})
	var r := Room.new()
	r.poly = poly
	r.sector = sectors.size() - 1
	r.wall = wall_tex
	r.parent = parent
	rooms.append(r)
	return rooms.size() - 1


func rect(x1: float, y1: float, x2: float, y2: float, floor_h: float, ceil_h: float, light: int,
		floor_tex: String, ceil_tex: String, wall_tex: String, special := 0, tag := 0, parent := -1) -> int:
	return room([Vector2(x1, y1), Vector2(x2, y1), Vector2(x2, y2), Vector2(x1, y2)],
		floor_h, ceil_h, light, floor_tex, ceil_tex, wall_tex, special, tag, parent)


func pillar(parent: int, points: Array, wall_tex: String) -> void:
	var poly := PackedVector2Array(points)
	if PolyTools.signed_area(poly) < 0.0:
		poly.reverse()
	var r := Room.new()
	r.poly = poly
	r.wall = wall_tex
	r.parent = parent
	r.solid = true
	rooms.append(r)


## Marks a room as a door: its neighbours show `face_tex` above the opening
## and the shared lines open it on use.
func door(room_id: int, face_tex: String, special := 1) -> void:
	_doors[rooms[room_id].sector] = {"tex": face_tex, "special": special}


func set_line(a: Vector2, b: Vector2, special: int, tag := 0, flags := 0) -> void:
	_line_props.append([a, b, {"special": special, "tag": tag, "flags": flags}])


func set_side(a: Vector2, b: Vector2, room_id: int, props: Dictionary) -> void:
	_side_props.append([a, b, rooms[room_id].sector, props])


func thing(x: float, y: float, type: int, angle := 0.0, flags := 7) -> void:
	things.append({"x": x, "y": y, "angle": angle, "type": type, "flags": flags})


func sector_of(room_id: int) -> int:
	return rooms[room_id].sector


func build() -> MapData:
	# 1. Directed edges, each owned by the sector on its right.
	var raw := []   # [a, b, sector, wall]
	for r in rooms:
		var n := r.poly.size()
		if r.solid:
			var owner := rooms[r.parent].sector
			for i in n:
				raw.append([r.poly[i], r.poly[(i + 1) % n], owner, r.wall])
			continue
		for i in n:
			raw.append([r.poly[i], r.poly[(i + 1) % n], r.sector, r.wall])
		if r.parent >= 0:
			var p := rooms[r.parent]
			for i in n:
				raw.append([r.poly[(i + 1) % n], r.poly[i], p.sector, p.wall])

	# 2. Split edges where another room's corner touches them.
	var corners := {}
	for r in rooms:
		for v in r.poly:
			corners[v] = true
	var edges := []
	for e in raw:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var cuts := []
		for v in corners:
			if v != a and v != b and _on_segment(v, a, b):
				cuts.append(v)
		cuts.sort_custom(func(p, q): return a.distance_squared_to(p) < a.distance_squared_to(q))
		var prev := a
		for v in cuts + [b]:
			edges.append([prev, v, e[2], e[3]])
			prev = v

	# 3. Pair opposite edges into two-sided lines.
	var m := MapData.new()
	m.name = "BUILTIN"
	m.title = "The Sunken Keep"
	m.sky = "SKYKEEP"   # procedural unless assets/textures/SKYKEEP.png exists
	for s in sectors:
		m.sectors.append(s.duplicate())
	var vindex := {}
	var by_dir := {}
	for i in edges.size():
		by_dir[_key(edges[i][0], edges[i][1])] = i
	var done := {}
	for i in edges.size():
		if done.has(i):
			continue
		var e: Array = edges[i]
		done[i] = true
		var line := {"v1": _vert(m, vindex, e[0]), "v2": _vert(m, vindex, e[1]), "flags": 0,
			"special": 0, "tag": 0, "front": -1, "back": -1}
		var j: int = by_dir.get(_key(e[1], e[0]), -1)
		if j >= 0 and not done.has(j):
			done[j] = true
			line.front = _side(m, e, true)
			line.back = _side(m, edges[j], true)
			line.flags = 4   # two-sided
		else:
			line.front = _side(m, e, false)
			line.flags = 1   # impassable
		_apply_doors(m, line, e, edges[j] if j >= 0 else [])
		for lp in _line_props:
			if _same_segment(e[0], e[1], lp[0], lp[1]):
				line.special = lp[2].special
				line.tag = lp[2].tag
				line.flags |= lp[2].flags
		m.lines.append(line)
	m.things = things.duplicate(true)
	return m


func _apply_doors(m: MapData, line: Dictionary, e: Array, other: Array) -> void:
	if other.is_empty():
		if _doors.has(e[2]):
			line.flags |= 16   # door jamb: keep the texture still as it opens
		return
	for pair in [[e, line.back], [other, line.front]]:
		var door_sector: int = pair[0][2]
		if _doors.has(door_sector):
			m.sides[pair[1]].upper = _doors[door_sector].tex
			if line.special == 0:
				line.special = _doors[door_sector].special


func _side(m: MapData, e: Array, two_sided: bool) -> int:
	var side := {"xoff": 0.0, "yoff": 0.0, "sector": e[2], "upper": e[3], "lower": e[3],
		"middle": "-" if two_sided else e[3]}
	for sp in _side_props:
		if sp[2] == e[2] and _on_or_equal(e[0], e[1], sp[0], sp[1]):
			for k in sp[3]:
				side[k] = sp[3][k]
	m.sides.append(side)
	return m.sides.size() - 1


static func _key(a: Vector2, b: Vector2) -> String:
	return "%s|%s" % [a, b]


func _vert(m: MapData, vindex: Dictionary, v: Vector2) -> int:
	if not vindex.has(v):
		vindex[v] = m.vertices.size()
		m.vertices.append(v)
	return vindex[v]


static func _on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var cross := ab.x * (p.y - a.y) - ab.y * (p.x - a.x)
	if absf(cross) > 0.01 * ab.length():
		return false
	var t := (p - a).dot(ab) / ab.length_squared()
	return t > 0.0001 and t < 0.9999


## True when segment a-b lies on segment c-d (either direction).
static func _on_or_equal(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return (a == c or a == d or _on_segment(a, c, d)) and (b == c or b == d or _on_segment(b, c, d))


static func _same_segment(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return _on_or_equal(a, b, c, d)
