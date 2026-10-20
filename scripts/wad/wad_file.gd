class_name WadFile
extends RefCounted
## Reads the lump directory of a Doom-engine WAD. Lump data stays in one
## byte array; readers decode straight from it using the stored offsets.

var data := PackedByteArray()
var names := PackedStringArray()
var offsets := PackedInt32Array()
var sizes := PackedInt32Array()
var is_iwad := false


static func from_bytes(bytes: PackedByteArray) -> WadFile:
	if bytes.size() < 12:
		return null
	var ident := read_name(bytes, 0).substr(0, 4)
	if ident != "IWAD" and ident != "PWAD":
		return null
	var count := bytes.decode_s32(4)
	var dir := bytes.decode_s32(8)
	if count < 0 or dir < 0 or dir + count * 16 > bytes.size():
		return null
	var w := WadFile.new()
	w.data = bytes
	w.is_iwad = ident == "IWAD"
	for i in count:
		var p := dir + i * 16
		var pos := bytes.decode_s32(p)
		var size := bytes.decode_s32(p + 4)
		if pos < 0 or size < 0 or pos + size > bytes.size():
			pos = 0
			size = 0
		w.offsets.append(pos)
		w.sizes.append(size)
		w.names.append(read_name(bytes, p + 8))
	return w


## Reads a NUL-padded 8-character name.
static func read_name(bytes: PackedByteArray, off: int) -> String:
	var s := ""
	for i in 8:
		var c := bytes[off + i]
		if c == 0:
			break
		s += char(c)
	return s.to_upper()


## Index of the last lump with this name (later lumps override earlier ones).
func find_lump(name: String) -> int:
	for i in range(names.size() - 1, -1, -1):
		if names[i] == name:
			return i
	return -1


func has_lump(name: String) -> bool:
	return find_lump(name) >= 0


func lump_data(index: int) -> PackedByteArray:
	return data.slice(offsets[index], offsets[index] + sizes[index])


## Lump indices between two marker lumps, e.g. F_START / F_END.
func lumps_between(start: String, end: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var inside := false
	for i in names.size():
		var n := names[i]
		if n == start or n == start.substr(0, 1) + start:
			inside = true
		elif n == end or n == end.substr(0, 1) + end:
			inside = false
		elif inside and sizes[i] > 0:
			out.append(i)
	return out


## Map marker names (ExMy or MAPxx) in directory order.
func map_names() -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("^(E\\dM\\d|MAP\\d\\d)$")
	for i in names.size() - 1:
		if re.search(names[i]) and names[i + 1] == "THINGS" and not out.has(names[i]):
			out.append(names[i])
	return out
