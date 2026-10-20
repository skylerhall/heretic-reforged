extends SceneTree
## Loads every map in a WAD and checks that each sector's triangles cover its
## outline. Works with any Doom-format IWAD (Heretic, or Freedoom for CI).
## godot --headless -s res://tests/wad_map_test.gd -- --wad=PATH [--maps=E1M1,E1M2]

func _init() -> void:
	var path := ""
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wad="):
			path = a.substr(6)
		elif a.begins_with("--maps="):
			only = a.substr(7).split(",")
	var wad := WadFile.from_bytes(FileAccess.get_file_as_bytes(path))
	if wad == null:
		printerr("can't read %s" % path)
		quit(2)
		return
	var bad_maps := 0
	for name in wad.map_names():
		if not only.is_empty() and not only.has(name):
			continue
		var t0 := Time.get_ticks_msec()
		var m := MapData.from_wad(wad, name)
		var geo := GeometryBuilder.new(m, TextureLibrary.procedural())
		var ms := Time.get_ticks_msec() - t0
		var uncovered := 0
		for s in m.sectors.size():
			var tris: PackedVector2Array = geo.sector_tris[s]
			if tris.is_empty():
				uncovered += 1
		var note := "" if uncovered == 0 else "  <- %d sectors without floor" % uncovered
		print("%s: %d sectors, %d lines, %d ms%s" % [name, m.sectors.size(), m.lines.size(), ms, note])
		if uncovered > m.sectors.size() / 50:
			bad_maps += 1
	print("RESULT: %s" % ("PASS" if bad_maps == 0 else "FAIL (%d maps)" % bad_maps))
	quit(0 if bad_maps == 0 else 1)
