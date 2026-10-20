class_name World
extends Node3D
## A running level: geometry, moving sectors, line specials, things and the
## player. Built entirely from MapData at runtime.

signal level_exited(secret: bool)

const S := Layers.S

var map: MapData
var tex: TextureLibrary
var geo: GeometryBuilder
var map_id := ""              # "" for the built-in level
var player: Player
var start_pos := Vector3.ZERO
var start_yaw := 0.0

var dynamic := {}             # sector -> true for sectors that can move
var floor_bodies := {}        # sector -> AnimatableBody3D
var ceil_bodies := {}
var wall_groups := {}         # group id -> {lines, node}
var sector_groups := {}       # sector -> {group id: true}
var dirty_groups := {}
var movers := {}              # "sector:plane" -> SectorMover
var tag_sectors := {}         # tag -> Array of sectors
var neighbors: Array = []     # sector -> Array of neighbouring sectors
var cross_lines: Array[int] = []
var teleport_dests: Array = []
var flicker_lights: Array = []
var used_once := {}
var switch_reverts: Array = []

var kills := 0
var total_kills := 0
var items := 0
var total_items := 0
var secrets := 0
var total_secrets := 0
var time := 0.0
var finished := false


func setup(m: MapData, t: TextureLibrary, id: String) -> void:
	map = m
	tex = t
	map_id = id
	name = "World"
	Game.world = self
	geo = GeometryBuilder.new(map, tex)
	_index_map()
	_find_dynamic()
	_build_geometry()
	EnvironmentBuilder.build(self, map, tex)
	ThingSpawner.spawn_all(self)


func _index_map() -> void:
	neighbors.resize(map.sectors.size())
	for s in map.sectors.size():
		neighbors[s] = []
		var sec: Dictionary = map.sectors[s]
		if sec.tag != 0:
			if not tag_sectors.has(sec.tag):
				tag_sectors[sec.tag] = []
			tag_sectors[sec.tag].append(s)
		if sec.special == 9:
			total_secrets += 1
	for li in map.lines.size():
		var line: Dictionary = map.lines[li]
		var fs := map.front_sector(line)
		var bs := map.back_sector(line)
		if fs >= 0 and bs >= 0 and fs != bs:
			if not neighbors[fs].has(bs):
				neighbors[fs].append(bs)
			if not neighbors[bs].has(fs):
				neighbors[bs].append(fs)
		var info := LineSpecials.info(line.special)
		if not info.is_empty() and info.trig == "cross":
			cross_lines.append(li)


func _find_dynamic() -> void:
	for line in map.lines:
		var info := LineSpecials.info(line.special)
		if info.is_empty():
			continue
		match info.act:
			"door", "lift", "floor":
				for s in tag_sectors.get(line.tag, []):
					dynamic[s] = true
			"stairs":
				for s in tag_sectors.get(line.tag, []):
					for c in LineSpecials.stair_chain(map, s):
						dynamic[c] = true
			"door_manual":
				var fs := map.front_sector(line)
				var bs := map.back_sector(line)
				if fs < 0 or bs < 0:
					continue
				var fc: float = map.sectors[fs].ceil
				var bc: float = map.sectors[bs].ceil
				if bc <= fc:
					dynamic[bs] = true
				if fc <= bc:
					dynamic[fs] = true


func _build_geometry() -> void:
	var static_acc := GeometryBuilder.Accum.new()
	static_acc.chunked = true
	var static_node := Node3D.new()
	static_node.name = "StaticGeometry"
	add_child(static_node)
	for s in map.sectors.size():
		if dynamic.has(s):
			_make_plane_body(s, true)
			_make_plane_body(s, false)
		else:
			geo.emit_plane(static_acc, s, true)
			geo.emit_plane(static_acc, s, false)
	for li in map.lines.size():
		var gid := _group_for_line(li)
		if gid == "":
			geo.emit_line(static_acc, li)
			continue
		if not wall_groups.has(gid):
			wall_groups[gid] = {"lines": [], "node": null}
		wall_groups[gid].lines.append(li)
		var line: Dictionary = map.lines[li]
		for s in [map.front_sector(line), map.back_sector(line)]:
			if s >= 0:
				if not sector_groups.has(s):
					sector_groups[s] = {}
				sector_groups[s][gid] = true
	geo.make_nodes(static_acc, static_node)
	for gid in wall_groups:
		_rebuild_group(gid)


func _group_for_line(li: int) -> String:
	var line: Dictionary = map.lines[li]
	var fs := map.front_sector(line)
	var bs := map.back_sector(line)
	var best := -1
	for s in [fs, bs]:
		if s >= 0 and dynamic.has(s) and (best < 0 or s < best):
			best = s
	if best >= 0:
		return "s%d" % best
	var info := LineSpecials.info(line.special)
	if not info.is_empty() and info.trig == "use":
		return "l%d" % li
	return ""


func _make_plane_body(s: int, is_floor: bool) -> void:
	var body := AnimatableBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	var acc := GeometryBuilder.Accum.new()
	geo.emit_plane(acc, s, is_floor, true)
	geo.make_nodes(acc, body, false)
	if not acc.faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(acc.faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	var sec: Dictionary = map.sectors[s]
	body.position.y = (sec.floor if is_floor else sec.ceil) * S
	if is_floor:
		floor_bodies[s] = body
	else:
		ceil_bodies[s] = body


func _rebuild_group(gid: String) -> void:
	var g: Dictionary = wall_groups[gid]
	if g.node != null:
		g.node.queue_free()
	var node := Node3D.new()
	add_child(node)
	g.node = node
	var acc := GeometryBuilder.Accum.new()
	for li in g.lines:
		geo.emit_line(acc, li)
	geo.make_nodes(acc, node)


## Called by movers after they change a sector's floor or ceiling height.
func sector_changed(s: int) -> void:
	var sec: Dictionary = map.sectors[s]
	if floor_bodies.has(s):
		floor_bodies[s].position.y = sec.floor * S
	if ceil_bodies.has(s):
		ceil_bodies[s].position.y = sec.ceil * S
	for gid in sector_groups.get(s, {}):
		dirty_groups[gid] = true


func _physics_process(dt: float) -> void:
	time += dt
	for key in movers.keys():
		var m: SectorMover = movers[key]
		if m.update(self, dt):
			movers.erase(key)
	for gid in dirty_groups:
		_rebuild_group(gid)
	dirty_groups.clear()
	for i in range(switch_reverts.size() - 1, -1, -1):
		var r: Array = switch_reverts[i]
		r[0] -= dt
		if r[0] <= 0.0:
			LineSpecials.flip_switch(self, r[1], false)
			switch_reverts.remove_at(i)


func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in flicker_lights:
		var l: OmniLight3D = f[0]
		var base: float = f[1]
		var ph: float = f[2]
		l.light_energy = base * (0.85 + 0.1 * sin(t * 13.0 + ph) + 0.06 * sin(t * 29.0 + ph * 2.3))


# --- Queries -------------------------------------------------------------

static func to_map(p: Vector3) -> Vector2:
	return Vector2(p.x / S, -p.z / S)


func sector_at(p: Vector3) -> int:
	return geo.sector_at(to_map(p))


func floor_at(p: Vector2) -> float:
	var s := geo.sector_at(p)
	return map.sectors[s].floor if s >= 0 else 0.0


func lowest_neighbor_floor(s: int) -> float:
	var v: float = map.sectors[s].floor
	for n in neighbors[s]:
		v = minf(v, map.sectors[n].floor)
	return v


func highest_neighbor_floor(s: int) -> float:
	var v := -32768.0
	for n in neighbors[s]:
		v = maxf(v, map.sectors[n].floor)
	return v if not neighbors[s].is_empty() else map.sectors[s].floor


func next_higher_floor(s: int) -> float:
	var cur: float = map.sectors[s].floor
	var v := INF
	for n in neighbors[s]:
		var f: float = map.sectors[n].floor
		if f > cur:
			v = minf(v, f)
	return v if v != INF else cur


func lowest_neighbor_ceiling(s: int) -> float:
	var v := INF
	for n in neighbors[s]:
		v = minf(v, map.sectors[n].ceil)
	return v if v != INF else map.sectors[s].ceil


## True if any living actor would be crushed by lowering this ceiling.
func ceiling_blocked(s: int, new_ceil: float) -> bool:
	for a in get_tree().get_nodes_in_group("actors"):
		if not is_instance_valid(a) or a.get("dead"):
			continue
		if sector_at(a.global_position) != s:
			continue
		if a.global_position.y + a.get("height") > new_ceil * S:
			return true
	return false


func noise_alert(at: Vector3) -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		m.hear(at)


# --- Player interaction ----------------------------------------------------

func player_use(p: Player) -> void:
	var o := to_map(p.global_position)
	var f := -p.global_basis.z
	var dir := Vector2(f.x, -f.z).normalized()
	var reach := 80.0
	var e := o + dir * reach
	var hits := []
	for li in map.lines.size():
		var line: Dictionary = map.lines[li]
		var hit = Geometry2D.segment_intersects_segment(o, e, map.vertices[line.v1], map.vertices[line.v2])
		if hit != null:
			hits.append([o.distance_to(hit), li])
	hits.sort_custom(func(a, b): return a[0] < b[0])
	for h in hits:
		var line: Dictionary = map.lines[h[1]]
		var info := LineSpecials.info(line.special)
		if not info.is_empty() and info.trig == "use" and line.special != 0:
			LineSpecials.activate(self, h[1], "use", p)
			return
		if line.back < 0 or line.front < 0:
			Sfx.play("noway", null, -6.0)
			return
		var a: Dictionary = map.sectors[map.front_sector(line)]
		var b: Dictionary = map.sectors[map.back_sector(line)]
		if minf(a.ceil, b.ceil) - maxf(a.floor, b.floor) <= 0.0:
			Sfx.play("noway", null, -6.0)
			return


## Checks walk-over specials crossed while moving from `from` to `to`.
func check_crossings(who: Node3D, from: Vector3, to: Vector3) -> void:
	var a := to_map(from)
	var b := to_map(to)
	if a.distance_squared_to(b) < 0.0001:
		return
	for li in cross_lines:
		var line: Dictionary = map.lines[li]
		var v1 := map.vertices[line.v1]
		var v2 := map.vertices[line.v2]
		if Geometry2D.segment_intersects_segment(a, b, v1, v2) == null:
			continue
		var from_front := (v2 - v1).cross(a - v1) <= 0.0
		LineSpecials.activate(self, li, "cross", who, from_front)


func enter_sector(p: Player, s: int) -> void:
	var sec: Dictionary = map.sectors[s]
	if sec.special == 9:
		sec.special = 0
		secrets += 1
		p.show_message("A SECRET AREA!")
		Sfx.play("secret")


func teleport(who: Node3D, tag: int) -> bool:
	for d in teleport_dests:
		if tag_sectors.get(tag, []).has(d.sector):
			Effects.teleport_flash(who.global_position)
			var floor_y: float = map.sectors[d.sector].floor * S
			who.global_position = Vector3(d.pos.x, floor_y + 0.05, d.pos.z)
			who.velocity = Vector3.ZERO
			if who.has_method("set_yaw"):
				who.set_yaw(d.yaw)
			Effects.teleport_flash(who.global_position)
			Sfx.play("teleport")
			return true
	return false


func exit_level(secret: bool) -> void:
	if finished:
		return
	finished = true
	level_exited.emit(secret)


func add_flicker(light: OmniLight3D) -> void:
	flicker_lights.append([light, light.light_energy, randf() * TAU])
