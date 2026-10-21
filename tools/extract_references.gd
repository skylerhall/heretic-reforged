extends SceneTree
## Dumps the original art from your own WAD as PNGs, to use as references for
## AI image-to-image (keeps the original silhouettes and colors) and when
## modeling. The output is for your own use; don't redistribute it.
##
## godot --headless --path . -s res://tools/extract_references.gd -- \
##     --wad=/path/to/HERETIC.WAD --out=/path/to/references

const SCALE := 4   # sprites are tiny; upscale (nearest) so AI tools get usable input

# Sprite name prefixes in Heretic, for the index. Anything not listed is
# still extracted; check the contact sheets.
const KNOWN := {
	"IMPX": "Gargoyle / Fire Gargoyle", "MUMM": "Golem / Nitrogolem", "KNIG": "Undead Warrior",
	"WZRD": "Disciple of D'Sparil", "CLNK": "Sabreclaw", "BEAS": "Weredragon", "SNKE": "Ophidian",
	"HEAD": "Iron Lich", "MNTR": "Maulotaur", "SRCR": "D'Sparil on his serpent", "SOR2": "D'Sparil",
	"PLAY": "Corvus (player)", "CHKN": "Chicken (Morph Ovum)",
	"STFF": "Staff (first person)", "GAUN": "Gauntlets (first person)", "GWND": "Elven Wand (first person)",
	"CRBW": "Ethereal Crossbow (first person)", "BLSR": "Dragon Claw (first person)",
	"HROD": "Hellstaff (first person)", "PHNX": "Phoenix Rod (first person)", "MACE": "Firemace (first person)",
	"WBOW": "Crossbow pickup", "WBLS": "Dragon Claw pickup", "WSKL": "Hellstaff pickup",
	"WPHX": "Phoenix Rod pickup", "WMCE": "Firemace pickup", "WGNT": "Gauntlets pickup",
	"PTN1": "Crystal Vial", "PTN2": "Quartz Flask", "SPHL": "Mystic Urn", "PWBK": "Tome of Power",
	"SOAR": "Wings of Wrath", "INVU": "Ring of Invincibility", "INVS": "Shadowsphere", "TRCH": "Torch",
	"FBMB": "Time Bomb", "ATLP": "Chaos Device", "SHLD": "Silver Shield", "SHD2": "Enchanted Shield",
	"BAGH": "Bag of Holding", "AKYY": "Key", "BKYY": "Key", "CKYY": "Key",
	"WTRH": "Wall torch", "SRTC": "Serpent torch", "KFR1": "Fire brazier", "CHDL": "Chandelier",
	"VLCO": "Volcano",
}


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if not args.has("wad") or not args.has("out"):
		printerr("usage: -- --wad=HERETIC.WAD --out=DIR")
		quit(2)
		return
	var bytes := FileAccess.get_file_as_bytes(args.wad)
	var wad := WadFile.from_bytes(bytes)
	if wad == null or not wad.has_lump("PLAYPAL"):
		printerr("not a usable IWAD: %s" % args.wad)
		quit(1)
		return
	var lib := TextureLibrary.from_wad(wad)
	var out: String = args.out
	var counts := {"sprites": 0, "textures": 0, "flats": 0}

	# sprites, grouped by their 4-letter prefix
	var groups := {}
	for i in wad.lumps_between("S_START", "S_END"):
		var img := lib.picture(i)
		if img == null:
			continue
		var name := wad.names[i]
		var prefix := name.substr(0, 4)
		if not groups.has(prefix):
			groups[prefix] = []
		groups[prefix].append([name, img])
	for prefix in groups:
		var dir := out.path_join("sprites").path_join(prefix)
		DirAccess.make_dir_recursive_absolute(dir)
		for entry in groups[prefix]:
			var big: Image = entry[1].duplicate()
			big.resize(big.get_width() * SCALE, big.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
			big.save_png(dir.path_join(entry[0] + ".png"))
			counts.sprites += 1
		_contact_sheet(groups[prefix]).save_png(out.path_join("sprites").path_join(prefix + "_sheet.png"))

	# wall textures and flats at original size
	DirAccess.make_dir_recursive_absolute(out.path_join("textures"))
	for n in lib.wall_names():
		var t := lib.wall(n)
		if t != null and t.texture != null:
			_plain(t.texture).save_png(out.path_join("textures").path_join(n + ".png"))
			counts.textures += 1
	DirAccess.make_dir_recursive_absolute(out.path_join("flats"))
	for n in lib.flat_names():
		var t := lib.flat(n)
		if t != null and t.texture != null:
			_plain(t.texture).save_png(out.path_join("flats").path_join(n + ".png"))
			counts.flats += 1

	var md := "# Reference art extracted from %s\n\nFor personal reference only; this art is copyrighted.\n\n| Prefix | Probably | Frames |\n|---|---|---|\n" % args.wad.get_file()
	var prefixes := groups.keys()
	prefixes.sort()
	for p in prefixes:
		md += "| %s | %s | %d |\n" % [p, KNOWN.get(p, ""), groups[p].size()]
	var f := FileAccess.open(out.path_join("INDEX.md"), FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print("extracted %d sprites (%d groups), %d textures, %d flats into %s" % [counts.sprites, groups.size(), counts.textures, counts.flats, out])
	quit(0)


func _plain(tex: Texture2D) -> Image:
	var img := tex.get_image()
	img.clear_mipmaps()
	return img


## All frames of one sprite group side by side on a dark checkerboard.
func _contact_sheet(frames: Array) -> Image:
	var cell := 0
	for e in frames:
		cell = maxi(cell, maxi(e[1].get_width(), e[1].get_height()))
	cell = cell * 2 + 8
	var cols := mini(frames.size(), 8)
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	for y in sheet.get_height():
		for x in sheet.get_width():
			var dark := ((x / 8) + (y / 8)) % 2 == 0
			sheet.set_pixel(x, y, Color(0.12, 0.12, 0.13) if dark else Color(0.18, 0.18, 0.2))
	for i in frames.size():
		var img: Image = frames[i][1].duplicate()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var at := Vector2i((i % cols) * cell + (cell - img.get_width()) / 2, (i / cols) * cell + cell - img.get_height() - 4)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	return sheet
