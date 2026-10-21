extends SceneTree
## Cuts the design map (art/design-map.png) into one reference image per
## character view, for image-to-image (the front view) and for checking 3D
## models (side and back). Also writes art/design-map-crops.png, a labeled
## sheet of every crop, so you can see at a glance that the boxes are right.
##
## godot --headless --path . -s res://tools/crop_design_map.gd
##
## Boxes are in pixels of the 1536x1024 map; if you replace the map with a
## different size, they scale with it. Edit CROPS if a crop misses.

const MAP := "res://art/design-map.png"
const OUT := "res://art/references"
const SHEET := "res://art/design-map-crops.png"
const BASE := Vector2(1536, 1024)
const UPSCALE := 3   # crops are small; give AI tools a bigger init image

# id: {view: [x, y, w, h]}
const CROPS := {
	"corvus": {"front": [324, 4, 190, 218], "side": [512, 42, 70, 180], "side2": [580, 42, 72, 180],
		"back": [650, 30, 102, 192], "closeup": [754, 2, 118, 222]},
	"weapon_staff": {"first_person": [875, 28, 274, 204]},
	"gryphon": {"front": [4, 278, 248, 150], "back": [244, 262, 90, 166]},
	"disciple": {"front": [342, 276, 124, 152], "side": [466, 266, 82, 162], "back": [548, 266, 80, 162]},
	"hell_knight": {"front": [636, 288, 126, 140], "side": [762, 252, 74, 176], "back": [834, 252, 82, 176]},
	"ophidian": {"front": [924, 277, 136, 151], "side": [1060, 268, 80, 160], "back": [1140, 268, 80, 160]},
	"wraithverge": {"front": [1228, 280, 144, 148], "side": [1372, 248, 78, 180], "back": [1450, 248, 82, 180]},
	"golem": {"front": [4, 594, 150, 148], "side": [150, 580, 76, 162], "back": [224, 580, 106, 162]},
	"sabreclaw": {"front": [340, 596, 130, 146], "side": [466, 578, 70, 164], "back": [532, 578, 78, 164]},
	"maulotaur": {"front": [616, 596, 146, 146], "side": [758, 580, 64, 162], "back": [818, 580, 88, 162]},
	"iron_liche": {"front": [920, 598, 106, 152], "side": [1024, 588, 86, 162], "back": [1110, 584, 82, 166]},
	"dsparil": {"front": [1196, 598, 226, 152], "back": [1420, 572, 112, 178]},
	"materials": {"cloth": [714, 896, 54, 82], "armor": [772, 896, 54, 82], "leather": [831, 896, 54, 82],
		"skin": [890, 896, 54, 82], "stone": [949, 896, 54, 82], "magic_lava": [1008, 896, 54, 82],
		"magic_lightning": [1067, 896, 56, 82]},
	"scale_lineup": {"all": [0, 880, 710, 132]},
}


func _init() -> void:
	var map := Image.load_from_file(ProjectSettings.globalize_path(MAP))
	if map == null:
		printerr("missing %s" % MAP)
		quit(1)
		return
	map.convert(Image.FORMAT_RGBA8)
	var k := Vector2(map.get_width(), map.get_height()) / BASE
	var crops: Array = []
	for id in CROPS:
		var dir := ProjectSettings.globalize_path(OUT).path_join(id)
		DirAccess.make_dir_recursive_absolute(dir)
		for view in CROPS[id]:
			var b: Array = CROPS[id][view]
			var r := Rect2i(int(b[0] * k.x), int(b[1] * k.y), int(b[2] * k.x), int(b[3] * k.y))
			var img := map.get_region(r)
			crops.append(["%s/%s" % [id, view], img.duplicate()])
			img.resize(img.get_width() * UPSCALE, img.get_height() * UPSCALE, Image.INTERPOLATE_LANCZOS)
			img.save_png(dir.path_join(view + ".png"))
	_sheet(crops).save_png(ProjectSettings.globalize_path(SHEET))
	print("wrote %d crops to %s and a contact sheet to %s" % [crops.size(), OUT, SHEET])
	quit(0)


## Every crop in a grid with its name, at map scale.
func _sheet(crops: Array) -> Image:
	var cell := Vector2i(260, 250)
	var cols := 8
	var rows := ceili(crops.size() / float(cols))
	var sheet := Image.create(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.11))
	for i in crops.size():
		var img: Image = crops[i][1]
		var s := minf(1.0, minf((cell.x - 10) / float(img.get_width()), (cell.y - 30) / float(img.get_height())))
		if s < 1.0:
			img.resize(int(img.get_width() * s), int(img.get_height() * s), Image.INTERPOLATE_BILINEAR)
		var at := Vector2i((i % cols) * cell.x + 5, (i / cols) * cell.y + 25)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
		_label(sheet, crops[i][0], Vector2i((i % cols) * cell.x + 5, (i / cols) * cell.y + 6))
	return sheet


## Tiny blocky label so the sheet needs no font.
func _label(img: Image, text: String, at: Vector2i) -> void:
	# a 3x5 pixel font for a-z, 0-9, / and _
	const GLYPHS := {
		"a": "010101111101101", "b": "110101110101110", "c": "011100100100011", "d": "110101101101110",
		"e": "111100110100111", "f": "111100110100100", "g": "011100101101011", "h": "101101111101101",
		"i": "111010010010111", "j": "001001001101010", "k": "101101110101101", "l": "100100100100111",
		"m": "101111111101101", "n": "110101101101101", "o": "010101101101010", "p": "110101110100100",
		"q": "010101101110011", "r": "110101110101101", "s": "011100010001110", "t": "111010010010010",
		"u": "101101101101111", "v": "101101101101010", "w": "101101111111101", "x": "101101010101101",
		"y": "101101010010010", "z": "111001010100111", "/": "001001010100100", "_": "000000000000111",
		"0": "111101101101111", "1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
	}
	var x := at.x
	for ch in text.to_lower():
		var g: String = GLYPHS.get(ch, "000000000000000")
		for py in 5:
			for px in 3:
				if g[py * 3 + px] == "1":
					for sy in 2:
						for sx in 2:
							img.set_pixel(x + px * 2 + sx, at.y + py * 2 + sy, Color(0.95, 0.8, 0.45))
		x += 8
