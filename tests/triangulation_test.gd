extends SceneTree
## Checks that every built-in sector's triangles cover exactly its outline.
## Run: godot --headless -s res://tests/triangulation_test.gd
func _init() -> void:
	var bad := 0
	var m := DemoMap.build()
	var edges := []
	for i in m.sectors.size():
		edges.append([])
	for line in m.lines:
		var a := m.vertices[line.v1]
		var b := m.vertices[line.v2]
		var fs := m.front_sector(line)
		var bs := m.back_sector(line)
		if fs == bs:
			continue
		if fs >= 0: edges[fs].append([a, b])
		if bs >= 0: edges[bs].append([b, a])
	for s in m.sectors.size():
		var loops := PolyTools.build_loops(edges[s])
		var want := 0.0
		for l in loops:
			want += -PolyTools.signed_area(l)
		var tris := PolyTools.triangulate_sector(loops)
		var got := 0.0
		for i in range(0, tris.size(), 3):
			got += absf(PolyTools.signed_area(PackedVector2Array([tris[i], tris[i+1], tris[i+2]])))
		if absf(got - want) > 1.0:
			bad += 1
			print("sector %d: loops=%d outline area=%.0f triangles=%.0f" % [s, loops.size(), want, got])
	print("RESULT: %s" % ("PASS" if bad == 0 else "FAIL"))
	quit(0 if bad == 0 else 1)
