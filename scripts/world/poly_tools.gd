class_name PolyTools
## 2D polygon helpers that turn Doom sector outlines (which may have holes
## for pillars and nested sectors) into triangles.
## Convention: boundary edges keep the sector interior on their right, so
## outer loops run clockwise and hole loops counter-clockwise (y up).


static func signed_area(p: PackedVector2Array) -> float:
	var a := 0.0
	var n := p.size()
	for i in n:
		var q := p[(i + 1) % n]
		a += p[i].x * q.y - q.x * p[i].y
	return a * 0.5


static func point_in_polygon(pt: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var a := poly[i]
		var b := poly[j]
		if (a.y > pt.y) != (b.y > pt.y):
			if pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x:
				inside = not inside
		j = i
	return inside


static func point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _orient(a, b, p)
	var d2 := _orient(b, c, p)
	var d3 := _orient(c, a, p)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)


## Chains directed edges [from, to] into closed loops, taking the sharpest
## right turn wherever several edges leave the same vertex.
static func build_loops(edges: Array) -> Array:
	var outgoing := {}
	for i in edges.size():
		var a: Vector2 = edges[i][0]
		if not outgoing.has(a):
			outgoing[a] = []
		outgoing[a].append(i)
	var used := PackedByteArray()
	used.resize(edges.size())
	var loops := []
	for first in edges.size():
		if used[first]:
			continue
		var loop := PackedVector2Array()
		var start: Vector2 = edges[first][0]
		var cur := first
		var closed := false
		for _guard in edges.size() + 1:
			used[cur] = 1
			var a: Vector2 = edges[cur][0]
			var b: Vector2 = edges[cur][1]
			loop.append(a)
			if b == start:
				closed = true
				break
			var back := (a - b).angle()
			var best := -1
			var best_turn := INF
			for c in outgoing.get(b, []):
				if used[c]:
					continue
				var to: Vector2 = edges[c][1]
				var turn := fposmod((to - b).angle() - back, TAU)
				if turn < 0.0001:
					turn = TAU
				if turn < best_turn:
					best_turn = turn
					best = c
			if best < 0:
				break
			cur = best
		if closed and loop.size() >= 3:
			loops.append(loop)
	return loops


## Triangulates a sector from its boundary loops. Returns a flat list of
## triangle corners.
static func triangulate_sector(loops: Array) -> PackedVector2Array:
	var outers := []
	var holes := []
	for l in loops:
		var area := signed_area(l)
		if absf(area) < 0.5:
			continue
		if area < 0.0:
			outers.append(l)
		else:
			holes.append(l)
	var assigned := []
	for o in outers:
		assigned.append([])
	for h in holes:
		var probe := _hole_probe(h)
		var best := -1
		var best_area := INF
		for i in outers.size():
			if point_in_polygon(probe, outers[i]):
				var ar := absf(signed_area(outers[i]))
				if ar < best_area:
					best_area = ar
					best = i
		if best >= 0:
			assigned[best].append(h)
	var tris := PackedVector2Array()
	for i in outers.size():
		var poly: PackedVector2Array = outers[i]
		if not assigned[i].is_empty():
			poly = _merge_holes(poly, assigned[i])
		tris.append_array(triangulate(poly))
	return tris


## Triangulates one simple polygon (bridged holes allowed).
static func triangulate(poly: PackedVector2Array) -> PackedVector2Array:
	var ccw := poly.duplicate()
	if signed_area(ccw) < 0.0:
		ccw.reverse()
	var out := PackedVector2Array()
	var idx := Geometry2D.triangulate_polygon(ccw)
	if not idx.is_empty():
		for i in idx:
			out.append(ccw[i])
		return out
	return _ear_clip(ccw)


static func _hole_probe(h: PackedVector2Array) -> Vector2:
	var a := h[0]
	var b := h[1]
	var d := (b - a).normalized()
	return (a + b) * 0.5 + Vector2(d.y, -d.x) * 0.25


static func _max_x(p: PackedVector2Array) -> float:
	var m := -INF
	for v in p:
		m = maxf(m, v.x)
	return m


static func _merge_holes(outer: PackedVector2Array, holes_in: Array) -> PackedVector2Array:
	var holes := holes_in.duplicate()
	holes.sort_custom(func(a, b): return _max_x(a) > _max_x(b))
	var poly := outer
	for hi in holes.size():
		var h: PackedVector2Array = holes[hi]
		var hv := 0
		for k in h.size():
			if h[k].x > h[hv].x:
				hv = k
		var p := h[hv]
		var order := range(poly.size())
		order.sort_custom(func(a, b): return poly[a].distance_squared_to(p) < poly[b].distance_squared_to(p))
		var best: int = order[0]
		for k in order:
			if _bridge_clear(p, poly[k], poly, holes, hi):
				best = k
				break
		var merged := PackedVector2Array()
		for k in best + 1:
			merged.append(poly[k])
		for k in h.size() + 1:
			merged.append(h[(hv + k) % h.size()])
		for k in range(best, poly.size()):
			merged.append(poly[k])
		poly = merged
	return poly


static func _bridge_clear(a: Vector2, b: Vector2, poly: PackedVector2Array, holes: Array, from_hole: int) -> bool:
	if _crosses_loop(a, b, poly):
		return false
	for j in range(from_hole, holes.size()):
		if _crosses_loop(a, b, holes[j]):
			return false
	return true


static func _crosses_loop(a: Vector2, b: Vector2, loop: PackedVector2Array) -> bool:
	var n := loop.size()
	for i in n:
		var c := loop[i]
		var d := loop[(i + 1) % n]
		if c == a or c == b or d == a or d == b:
			continue
		var d1 := _orient(c, d, a)
		var d2 := _orient(c, d, b)
		var d3 := _orient(a, b, c)
		var d4 := _orient(a, b, d)
		if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
			return true
	return false


static func _orient(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


## Ear clipping for counter-clockwise polygons; tolerates the duplicate
## vertices created by hole bridges and never loops forever.
static func _ear_clip(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in p.size():
		idx.append(i)
	while idx.size() > 3:
		var m := idx.size()
		var clipped := false
		for k in m:
			var a := p[idx[(k + m - 1) % m]]
			var b := p[idx[k]]
			var c := p[idx[(k + 1) % m]]
			if _orient(a, b, c) <= 1e-9:
				continue
			var ear := true
			for j in m:
				if j == k or j == (k + m - 1) % m or j == (k + 1) % m:
					continue
				var q := p[idx[j]]
				if q == a or q == b or q == c:
					continue
				if point_in_triangle(q, a, b, c):
					ear = false
					break
			if ear:
				out.append(a)
				out.append(b)
				out.append(c)
				idx.remove_at(k)
				clipped = true
				break
		if not clipped:
			# Degenerate outline: drop the flattest corner and carry on.
			var worst := 0
			var worst_v := INF
			for k in m:
				var v := absf(_orient(p[idx[(k + m - 1) % m]], p[idx[k]], p[idx[(k + 1) % m]]))
				if v < worst_v:
					worst_v = v
					worst = k
			idx.remove_at(worst)
	if idx.size() == 3:
		out.append(p[idx[0]])
		out.append(p[idx[1]])
		out.append(p[idx[2]])
	return out
