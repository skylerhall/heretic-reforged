class_name TextureLibrary
extends RefCounted
## Wall textures and floor flats, either composed from a WAD's patches or
## generated procedurally, plus the materials that render them.

const WORLD_SHADER := preload("res://shaders/world.gdshader")
const MASKED_SHADER := preload("res://shaders/world_masked.gdshader")


class TexInfo:
	var name := ""
	var width := 64.0    # size in map units
	var height := 64.0
	var texture: Texture2D
	var glow := 0.0      # self-illumination for lava and magic surfaces
	var scroll := Vector2.ZERO
	var wobble := 0.0
	var masked := false


var wad: WadFile
var palette := PackedByteArray()
var _patch_lumps: Array = []    # PNAMES index -> lump index (or -1)
var _tex_defs := {}             # name -> {w, h, patches: [[x, y, pnames index]]}
var _flat_lumps := {}           # name -> lump index
var _walls := {}
var _flats := {}
var _materials := {}
var _procedural := false
var _fallback: TexInfo


static func from_wad(w: WadFile) -> TextureLibrary:
	var lib := TextureLibrary.new()
	lib.wad = w
	lib._read_wad_tables()
	return lib


static func procedural() -> TextureLibrary:
	var lib := TextureLibrary.new()
	lib._procedural = true
	return lib


func is_sky_flat(name: String) -> bool:
	return name == "F_SKY1" or name == "F_SKY"


func wall(name: String) -> TexInfo:
	if name == "" or name == "-":
		return null
	if not _walls.has(name):
		_walls[name] = _make_procedural(name, false) if _procedural else _compose_wall(name)
	var t: TexInfo = _walls[name]
	return t if t != null else _get_fallback()


func has_wall(name: String) -> bool:
	return name in ProceduralTextures.WALLS if _procedural else _tex_defs.has(name)


func flat(name: String) -> TexInfo:
	if not _flats.has(name):
		_flats[name] = _make_procedural(name, true) if _procedural else _read_flat(name)
	var t: TexInfo = _flats[name]
	return t if t != null else _get_fallback()


## Material for a texture, cached. `masked` enables see-through pixels.
func material(t: TexInfo, masked := false) -> Material:
	var key := "%s|%s|%d" % [t.name, masked, t.get_instance_id()]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = MASKED_SHADER if masked else WORLD_SHADER
	m.set_shader_parameter("albedo_tex", t.texture)
	m.set_shader_parameter("glow", t.glow)
	m.set_shader_parameter("scroll", t.scroll)
	m.set_shader_parameter("wobble", t.wobble)
	_materials[key] = m
	return m


func sky_texture(name: String) -> Texture2D:
	if _procedural:
		return null
	var t := _compose_wall(name)
	if t == null:
		return null
	# Doom skies repeat four times around the horizon and fill the upper
	# half of the view; stretch that into an equirectangular panorama.
	var src: Image = t.texture.get_image()
	if src.is_compressed():
		src.decompress()
	src.clear_mipmaps()
	var pw := 768
	var ph := 384
	var pano := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	var sw := src.get_width()
	var sh := src.get_height()
	var top_row := src.get_pixel(0, 0)
	var bottom := src.get_pixel(0, sh - 1)
	for y in ph:
		var v := (float(y) / ph - 0.12) / (0.52 - 0.12)
		for x in pw:
			var sx := int(float(x) / pw * sw * 4.0) % sw
			var c: Color
			if v < 0.0:
				c = top_row.lerp(src.get_pixel(sx, 0), clampf(1.0 + v * 4.0, 0.0, 1.0))
			elif v > 1.0:
				c = src.get_pixel(sx, sh - 1).lerp(bottom.darkened(0.6), clampf((v - 1.0) * 2.0, 0.0, 1.0))
			else:
				c = src.get_pixel(sx, mini(int(v * sh), sh - 1))
			pano.set_pixel(x, y, c)
	pano.generate_mipmaps()
	return ImageTexture.create_from_image(pano)


# --- WAD textures ----------------------------------------------------------

func _read_wad_tables() -> void:
	var d := wad.data
	var pal := wad.find_lump("PLAYPAL")
	palette = d.slice(wad.offsets[pal], wad.offsets[pal] + 768)

	var pn := wad.find_lump("PNAMES")
	if pn >= 0:
		var o := wad.offsets[pn]
		var count := d.decode_s32(o)
		for i in count:
			_patch_lumps.append(wad.find_lump(WadFile.read_name(d, o + 4 + i * 8)))

	for lump_name in ["TEXTURE1", "TEXTURE2"]:
		var li := wad.find_lump(lump_name)
		if li < 0:
			continue
		var o := wad.offsets[li]
		var count := d.decode_s32(o)
		for i in count:
			var p := o + d.decode_s32(o + 4 + i * 4)
			var tname := WadFile.read_name(d, p)
			var def := {"w": d.decode_s16(p + 12), "h": d.decode_s16(p + 14), "patches": []}
			var pc := d.decode_s16(p + 20)
			for k in pc:
				var q := p + 22 + k * 10
				def.patches.append([d.decode_s16(q), d.decode_s16(q + 2), d.decode_s16(q + 4)])
			if not _tex_defs.has(tname):
				_tex_defs[tname] = def

	for i in wad.lumps_between("F_START", "F_END"):
		if wad.sizes[i] >= 4096:
			_flat_lumps[wad.names[i]] = i


func _compose_wall(name: String) -> TexInfo:
	if not _tex_defs.has(name):
		return null
	var def: Dictionary = _tex_defs[name]
	var w: int = def.w
	var h: int = def.h
	if w <= 0 or h <= 0:
		return null
	var buf := PackedByteArray()
	buf.resize(w * h * 4)
	for p in def.patches:
		if p[2] >= 0 and p[2] < _patch_lumps.size() and _patch_lumps[p[2]] >= 0:
			_draw_patch(buf, w, h, _patch_lumps[p[2]], p[0], p[1])
	var masked := false
	for i in range(3, buf.size(), 4):
		if buf[i] == 0:
			masked = true
			break
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, buf)
	if masked:
		img.fix_alpha_edges()
	var t := _finish(name, img, w, h)
	t.masked = masked
	_apply_liquid_rules(t)
	return t


func _draw_patch(buf: PackedByteArray, bw: int, bh: int, lump: int, ox: int, oy: int) -> void:
	var d := wad.data
	var base := wad.offsets[lump]
	var end := base + wad.sizes[lump]
	var pw := d.decode_s16(base)
	for col in pw:
		var x := ox + col
		if x < 0 or x >= bw:
			continue
		var p := base + d.decode_s32(base + 8 + col * 4)
		var top := -1
		while p < end and d[p] != 255:
			var delta := d[p]
			top = top + delta if delta <= top else delta   # tall-patch support
			var length := d[p + 1]
			var src := p + 3
			for k in length:
				var y := oy + top + k
				if y >= 0 and y < bh and src + k < end:
					var ci := d[src + k] * 3
					var o := (y * bw + x) * 4
					buf[o] = palette[ci]
					buf[o + 1] = palette[ci + 1]
					buf[o + 2] = palette[ci + 2]
					buf[o + 3] = 255
			p += length + 4


func _read_flat(name: String) -> TexInfo:
	if not _flat_lumps.has(name):
		return null
	var d := wad.data
	var o := wad.offsets[_flat_lumps[name]]
	var buf := PackedByteArray()
	buf.resize(64 * 64 * 4)
	for i in 4096:
		var ci := d[o + i] * 3
		buf[i * 4] = palette[ci]
		buf[i * 4 + 1] = palette[ci + 1]
		buf[i * 4 + 2] = palette[ci + 2]
		buf[i * 4 + 3] = 255
	var t := _finish(name, Image.create_from_data(64, 64, false, Image.FORMAT_RGBA8, buf), 64, 64)
	_apply_liquid_rules(t)
	return t


func _apply_liquid_rules(t: TexInfo) -> void:
	var n := t.name
	if n.begins_with("FLTLAVA") or n.begins_with("FLATHUH") or n.begins_with("LAVA"):
		t.glow = 1.4
		t.scroll = Vector2(0.03, 0.02)
		t.wobble = 0.02
	elif n.begins_with("FLTWAWA") or n.begins_with("FLTFLWW") or n.begins_with("WATER"):
		t.scroll = Vector2(0.05, 0.0)
		t.wobble = 0.025
	elif n.begins_with("FLTSLUD"):
		t.glow = 0.3
		t.scroll = Vector2(0.02, 0.02)
		t.wobble = 0.02
	elif n.begins_with("FLTTELE"):
		t.glow = 1.0


func _finish(name: String, img: Image, w: float, h: float) -> TexInfo:
	img.generate_mipmaps()
	var t := TexInfo.new()
	t.name = name
	t.width = w
	t.height = h
	t.texture = ImageTexture.create_from_image(img)
	return t


func _get_fallback() -> TexInfo:
	if _fallback == null:
		var g := ProceduralTextures.generate("BRICK")
		_fallback = _finish("__fallback", g.image, g.width, g.height)
	return _fallback


func _make_procedural(name: String, is_flat: bool) -> TexInfo:
	var g := ProceduralTextures.generate(name)
	if g.is_empty():
		return null
	var t := _finish(name, g.image, g.width, g.height)
	t.glow = g.get("glow", 0.0)
	_apply_liquid_rules(t)
	return t
