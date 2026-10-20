class_name ProceduralTextures
## Original, procedurally generated textures for the built-in level, so the
## game is playable (and shareable) without any of the original game data.
## Every generator tiles seamlessly. Flats are 64 map units at 2 texels/unit.


const WALLS := ["BRICK", "BRICKMOSS", "MARBLE", "METAL", "WOOD", "DOORGREEN", "SW1OFF", "SW1ON"]


static func generate(name: String) -> Dictionary:
	match name:
		"BRICK":
			return _wall(_bricks(128, 128, 64, 32, Color(0.44, 0.39, 0.33), 0.0, 11), 128, 128)
		"BRICKMOSS":
			return _wall(_bricks(128, 128, 64, 32, Color(0.40, 0.38, 0.31), 0.55, 12), 128, 128)
		"MARBLE":
			return _wall(_marble(128, 128, 13), 128, 128)
		"METAL":
			return _wall(_metal(64, 128, Color(0.30, 0.29, 0.30), 14), 64, 128)
		"WOOD":
			return _wall(_wood_door(64, 128, Color(0, 0, 0, 0), 15), 64, 128)
		"DOORGREEN":
			return _wall(_wood_door(64, 128, Color(0.15, 0.95, 0.35), 16), 64, 128)
		"SW1OFF":
			return _wall(_switch(64, 128, false), 64, 128)
		"SW1ON":
			return _wall(_switch(64, 128, true), 64, 128)
		"FLOOR_STONE":
			return _flat(_flagstones(128, 21))
		"FLOOR_TILE":
			return _flat(_checker(128, 22))
		"CEIL_WOOD":
			return _flat(_planks(128, 23))
		"GRASS":
			return _flat(_grass(128, 24))
		"FLTLAVA1":
			var d := _flat(_lava(128, 25))
			d["glow"] = 1.4
			return d
		"FLTWAWA1":
			return _flat(_water(128, 26))
		"METALFLOOR":
			return _flat(_metal(128, 128, Color(0.33, 0.31, 0.29), 27))
	return {}


static func _wall(img: Image, w: float, h: float) -> Dictionary:
	return {"image": img, "width": w, "height": h}


static func _flat(img: Image) -> Dictionary:
	return {"image": img, "width": 64.0, "height": 64.0}


static func _noise(seed_value: int, freq: float, octaves := 4, type := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Noise that tiles every `s` pixels, by blending four shifted samples.
static func _tn(n: FastNoiseLite, x: float, y: float, s: float) -> float:
	var u := x / s
	var v := y / s
	var a := n.get_noise_2d(x, y)
	var b := n.get_noise_2d(x - s, y)
	var c := n.get_noise_2d(x, y - s)
	var d := n.get_noise_2d(x - s, y - s)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


static func _hash(x: int, y: int, seed_value: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed_value * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10000) / 10000.0


static func _bricks(w: int, h: int, bw: int, bh: int, base: Color, moss: float, seed_value: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var grain := _noise(seed_value, 0.08)
	var big := _noise(seed_value + 7, 0.02, 3)
	var moss_n := _noise(seed_value + 3, 0.05, 4)
	for y in h:
		var row := y / bh
		var ly := y % bh
		for x in w:
			var off := (bw / 2) * (row % 2)
			var col := ((x + off) % w) / bw
			var lx := (x + off) % bw
			var g := _tn(grain, x, y, w)
			var c: Color
			if lx < 2 or ly < 2:
				c = Color(0.12, 0.10, 0.09) * (0.8 + g * 0.3)
			else:
				var tint := 0.82 + _hash(col, row, seed_value) * 0.3
				c = base * tint * (0.88 + g * 0.22 + _tn(big, x, y, w) * 0.12)
				# bevel the block edges so the generated normals read as depth
				if lx < 5 or ly < 5:
					c = c.lightened(0.12)
				elif lx > bw - 5 or ly > bh - 5:
					c = c.darkened(0.22)
				if moss > 0.0:
					var m := clampf(_tn(moss_n, x, y, w) * 1.6 + (float(y) / h) * moss - 0.2, 0.0, 1.0)
					c = c.lerp(Color(0.20, 0.32, 0.12) * (0.8 + g * 0.4), m * 0.8)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _marble(w: int, h: int, seed_value: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := _noise(seed_value, 0.03, 5)
	var fine := _noise(seed_value + 1, 0.15, 2)
	for y in h:
		for x in w:
			var t := _tn(n, x, y, w)
			var vein := absf(sin((x + y * 0.6 + t * 60.0) * 0.12))
			vein = pow(1.0 - vein, 6.0)
			var c := Color(0.20, 0.34, 0.30).lerp(Color(0.62, 0.72, 0.62), vein * 0.8)
			c *= 0.9 + _tn(fine, x, y, w) * 0.12
			var px := x % 64
			var py := y % 64
			if px < 3 or py < 3:
				c = Color(0.55, 0.43, 0.18) * (0.9 + _tn(fine, x, y, w) * 0.2)   # gold trim
			elif px < 5 or py < 5:
				c = c.darkened(0.35)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _metal(w: int, h: int, base: Color, seed_value: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := _noise(seed_value, 0.06, 4)
	var scratch := _noise(seed_value + 5, 0.25, 1)
	for y in h:
		for x in w:
			var px := x % 32
			var py := y % 32
			var c := base * (0.85 + _tn(n, x, y, maxi(w, h)) * 0.25)
			c = c.lerp(Color(0.38, 0.22, 0.12), clampf(_tn(n, x + 50, y, maxi(w, h)) * 1.4 - 0.3, 0.0, 0.5))
			if absf(_tn(scratch, x, y * 0.2, maxi(w, h))) < 0.03:
				c = c.lightened(0.15)
			if px == 0 or py == 0:
				c = c.darkened(0.6)
			elif px == 1 or py == 1:
				c = c.lightened(0.25)
			var rv := Vector2(px, py)
			for corner in [Vector2(5, 5), Vector2(27, 5), Vector2(5, 27), Vector2(27, 27)]:
				var dist := rv.distance_to(corner)
				if dist < 2.5:
					c = Color(0.55, 0.52, 0.5) * (1.2 - dist * 0.25)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _wood_door(w: int, h: int, gem: Color, seed_value: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var grain := _noise(seed_value, 0.04, 3)
	for y in h:
		for x in w:
			var plank := x / 16
			var lx := x % 16
			var g := _tn(grain, x * 4.0, y * 0.5, w * 4.0)
			var c := Color(0.36, 0.22, 0.12) * (0.75 + _hash(plank, 0, seed_value) * 0.3 + g * 0.35)
			if lx == 0:
				c = c.darkened(0.6)
			for band in [18, 106]:
				if y >= band and y < band + 8:
					c = Color(0.22, 0.21, 0.22) * (0.9 + g * 0.2)
					if y == band:
						c = c.lightened(0.3)
					if (x % 16 == 8) and (y == band + 4):
						c = Color(0.6, 0.58, 0.55)
			if gem.a > 0.0:
				var dv := Vector2(x - w * 0.5, y - h * 0.5)
				var r := dv.length()
				if r < 10.0:
					c = gem * (1.3 - r / 10.0)
				elif r < 13.0:
					c = Color(0.6, 0.5, 0.2)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _switch(w: int, h: int, on: bool) -> Image:
	var img := _metal(w, h, Color(0.28, 0.27, 0.30), 31)
	for y in range(40, 88):
		for x in range(14, 50):
			var c := Color(0.12, 0.11, 0.12)
			if x == 14 or y == 40:
				c = Color(0.5, 0.45, 0.3)
			img.set_pixel(x, y, c)
	var gem := Color(0.2, 1.0, 0.35) if on else Color(1.0, 0.15, 0.1)
	var lever_y := 52 if on else 74
	for y in range(lever_y - 3, lever_y + 3):
		for x in range(20, 44):
			img.set_pixel(x, y, Color(0.65, 0.55, 0.3))
	for y in range(26, 36):
		for x in range(27, 37):
			var r := Vector2(x - 31.5, y - 30.5).length()
			if r < 5.0:
				img.set_pixel(x, y, gem * (1.4 - r / 5.0))
	return img


static func _flagstones(s: int, seed_value: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cell := _noise(seed_value, 0.045, 1, FastNoiseLite.TYPE_CELLULAR)
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var cell_id := _noise(seed_value, 0.045, 1, FastNoiseLite.TYPE_CELLULAR)
	cell_id.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var grain := _noise(seed_value + 2, 0.12, 3)
	for y in s:
		for x in s:
			var edge := _tn(cell, x, y, s)
			var tint := _tn(cell_id, x, y, s)
			var c := Color(0.40, 0.37, 0.33) * (0.85 + tint * 0.2 + _tn(grain, x, y, s) * 0.2)
			if edge < -0.85:
				c = Color(0.10, 0.09, 0.08)
			elif edge < -0.75:
				c = c.darkened(0.3)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _checker(s: int, seed_value: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var n := _noise(seed_value, 0.05, 4)
	for y in s:
		for x in s:
			var light := ((x / 64) + (y / 64)) % 2 == 0
			var t := _tn(n, x, y, s)
			var vein := pow(1.0 - absf(sin((x - y + t * 50.0) * 0.1)), 8.0)
			var c := (Color(0.46, 0.40, 0.32) if light else Color(0.16, 0.12, 0.11)) * (0.9 + t * 0.15)
			c = c.lerp(Color(0.75, 0.7, 0.6) if light else Color(0.35, 0.25, 0.2), vein * 0.5)
			if x % 64 < 2 or y % 64 < 2:
				c = Color(0.08, 0.07, 0.06)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _planks(s: int, seed_value: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var grain := _noise(seed_value, 0.05, 3)
	for y in s:
		for x in s:
			var plank := y / 32
			var g := _tn(grain, x * 0.4, y * 3.0, s * 0.4)
			var c := Color(0.30, 0.19, 0.11) * (0.75 + _hash(plank, 1, seed_value) * 0.3 + g * 0.3)
			if y % 32 < 2:
				c = Color(0.06, 0.04, 0.03)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _grass(s: int, seed_value: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var n := _noise(seed_value, 0.04, 5)
	var fine := _noise(seed_value + 1, 0.4, 2)
	for y in s:
		for x in s:
			var t := _tn(n, x, y, s)
			var c := Color(0.22, 0.27, 0.12).lerp(Color(0.30, 0.24, 0.16), clampf(t + 0.5, 0.0, 1.0))
			c *= 0.8 + _tn(fine, x, y, s) * 0.35
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _lava(s: int, seed_value: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cell := _noise(seed_value, 0.05, 1, FastNoiseLite.TYPE_CELLULAR)
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var n := _noise(seed_value + 4, 0.06, 4)
	for y in s:
		for x in s:
			var e := _tn(cell, x, y, s)
			var heat := clampf(-e * 1.1 - 0.35 + _tn(n, x, y, s) * 0.5, 0.0, 1.0)
			var c := Color(0.25, 0.05, 0.02).lerp(Color(1.0, 0.45, 0.05), heat)
			c = c.lerp(Color(1.0, 0.9, 0.4), pow(heat, 4.0))
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _water(s: int, seed_value: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var n := _noise(seed_value, 0.05, 4)
	for y in s:
		for x in s:
			var t := _tn(n, x, y, s)
			var c := Color(0.05, 0.16, 0.26).lerp(Color(0.25, 0.45, 0.6), clampf(t + 0.4, 0.0, 1.0))
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img
