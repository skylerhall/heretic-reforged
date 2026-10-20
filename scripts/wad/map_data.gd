class_name MapData
extends RefCounted
## A Doom-format map held in memory: vertices, linedefs, sidedefs, sectors
## and things. Sector heights are live state; movers change them in play.

var name := ""
var title := ""
var sky := "SKY1"
var vertices := PackedVector2Array()
var lines: Array[Dictionary] = []
var sides: Array[Dictionary] = []
var sectors: Array[Dictionary] = []
var things: Array[Dictionary] = []


static func from_wad(wad: WadFile, map_name: String) -> MapData:
	var marker := wad.find_lump(map_name)
	if marker < 0:
		return null
	var idx := {}
	for k in range(marker + 1, mini(marker + 12, wad.names.size())):
		var n := wad.names[k]
		if not n in ["THINGS", "LINEDEFS", "SIDEDEFS", "VERTEXES", "SEGS", "SSECTORS", "NODES", "SECTORS", "REJECT", "BLOCKMAP"]:
			break
		idx[n] = k
	for need in ["THINGS", "LINEDEFS", "SIDEDEFS", "VERTEXES", "SECTORS"]:
		if not idx.has(need):
			return null

	var m := MapData.new()
	m.name = map_name
	m.title = map_name
	var ep := map_name.substr(1, 1)
	m.sky = {"1": "SKY1", "2": "SKY2", "3": "SKY3", "4": "SKY1", "5": "SKY3"}.get(ep, "SKY1")
	var d := wad.data

	var o := wad.offsets[idx.VERTEXES]
	for k in wad.sizes[idx.VERTEXES] / 4:
		m.vertices.append(Vector2(d.decode_s16(o + k * 4), d.decode_s16(o + k * 4 + 2)))

	o = wad.offsets[idx.SECTORS]
	for k in wad.sizes[idx.SECTORS] / 26:
		var p := o + k * 26
		m.sectors.append({
			"floor": float(d.decode_s16(p)), "ceil": float(d.decode_s16(p + 2)),
			"floor_tex": WadFile.read_name(d, p + 4), "ceil_tex": WadFile.read_name(d, p + 12),
			"light": d.decode_s16(p + 20), "special": d.decode_s16(p + 22), "tag": d.decode_s16(p + 24),
		})

	o = wad.offsets[idx.SIDEDEFS]
	for k in wad.sizes[idx.SIDEDEFS] / 30:
		var p := o + k * 30
		m.sides.append({
			"xoff": float(d.decode_s16(p)), "yoff": float(d.decode_s16(p + 2)),
			"upper": WadFile.read_name(d, p + 4), "lower": WadFile.read_name(d, p + 12),
			"middle": WadFile.read_name(d, p + 20),
			"sector": clampi(d.decode_u16(p + 28), 0, maxi(m.sectors.size() - 1, 0)),
		})

	o = wad.offsets[idx.LINEDEFS]
	for k in wad.sizes[idx.LINEDEFS] / 14:
		var p := o + k * 14
		var v1 := d.decode_u16(p)
		var v2 := d.decode_u16(p + 2)
		if v1 >= m.vertices.size() or v2 >= m.vertices.size():
			continue
		var front := d.decode_u16(p + 10)
		var back := d.decode_u16(p + 12)
		m.lines.append({
			"v1": v1, "v2": v2, "flags": d.decode_u16(p + 4),
			"special": d.decode_s16(p + 6), "tag": d.decode_s16(p + 8),
			"front": front if front < m.sides.size() else -1,
			"back": back if back < m.sides.size() else -1,
		})

	o = wad.offsets[idx.THINGS]
	for k in wad.sizes[idx.THINGS] / 10:
		var p := o + k * 10
		m.things.append({
			"x": float(d.decode_s16(p)), "y": float(d.decode_s16(p + 2)),
			"angle": float(d.decode_s16(p + 4)), "type": d.decode_s16(p + 6), "flags": d.decode_s16(p + 8),
		})
	return m


func front_sector(line: Dictionary) -> int:
	return sides[line.front].sector if line.front >= 0 else -1


func back_sector(line: Dictionary) -> int:
	return sides[line.back].sector if line.back >= 0 else -1
