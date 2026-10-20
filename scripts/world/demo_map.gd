class_name DemoMap
## "The Sunken Keep": an original level that ships with the game, so it runs
## (and can be shared on the web) without the original game's data.
## Coordinates are Doom map units; thing numbers match Heretic's.


static func build() -> MapData:
	var s := MapSketch.new()

	# Courtyard under the open sky, with a fountain.
	var court := s.rect(0, 0, 768, 768, 0, 320, 190, "GRASS", "F_SKY1", "BRICKMOSS")
	var basin := s.room(_octagon(Vector2(384, 448), 112), -16, 320, 190, "FLTWAWA1", "F_SKY1", "MARBLE", 0, 0, court)
	s.rect(352, 416, 416, 480, 40, 320, 190, "FLOOR_TILE", "F_SKY1", "MARBLE", 0, 0, basin)   # plinth

	# Gatehouse: arch, door, arch.
	s.rect(768, 320, 832, 448, 0, 128, 150, "FLOOR_STONE", "CEIL_WOOD", "METAL")
	var gate := s.rect(832, 320, 864, 448, 0, 0, 150, "FLOOR_STONE", "CEIL_WOOD", "METAL")
	s.rect(864, 320, 896, 448, 0, 128, 150, "FLOOR_STONE", "CEIL_WOOD", "METAL")
	s.door(gate, "WOOD")

	# Great hall with pillars and a lava pit.
	var hall := s.rect(896, -128, 1664, 896, 0, 384, 140, "FLOOR_TILE", "CEIL_WOOD", "MARBLE")
	for c in [Vector2(1056, 96), Vector2(1504, 96), Vector2(1056, 672), Vector2(1504, 672)]:
		s.pillar(hall, _square(c, 32), "MARBLE")
	s.rect(1152, 288, 1408, 480, -16, 384, 210, "FLTLAVA1", "CEIL_WOOD", "BRICK", 5, 0, hall)

	# Steps up to the east platform, then a lift to the balcony.
	for i in 3:
		s.rect(1664 + i * 32, 192, 1696 + i * 32, 576, 16 * (i + 1), 384, 150, "FLOOR_STONE", "CEIL_WOOD", "METAL")
	var plat := s.rect(1760, 192, 1920, 576, 64, 384, 160, "FLOOR_TILE", "CEIL_WOOD", "MARBLE")
	s.rect(1920, 320, 1984, 448, 192, 384, 160, "METALFLOOR", "CEIL_WOOD", "METAL", 0, 5)
	s.room([Vector2(1920, 192), Vector2(2176, 192), Vector2(2176, 576), Vector2(1920, 576),
		Vector2(1920, 448), Vector2(1984, 448), Vector2(1984, 320), Vector2(1920, 320)],
		192, 384, 170, "FLOOR_TILE", "CEIL_WOOD", "MARBLE")
	s.set_line(Vector2(1920, 320), Vector2(1920, 448), 62, 5)
	s.set_line(Vector2(1984, 320), Vector2(1984, 448), 62, 5)
	s.set_side(Vector2(1920, 320), Vector2(1920, 448), plat, {"lower": "METAL"})

	# North: the green door and the exit chamber.
	s.rect(1232, 896, 1328, 928, 0, 128, 140, "FLOOR_STONE", "CEIL_WOOD", "METAL")
	var green_door := s.rect(1232, 928, 1328, 960, 0, 0, 140, "FLOOR_STONE", "CEIL_WOOD", "METAL")
	s.rect(1232, 960, 1328, 992, 0, 128, 160, "FLOOR_STONE", "CEIL_WOOD", "METAL")
	s.door(green_door, "DOORGREEN", 28)
	s.rect(1088, 992, 1472, 1248, 0, 256, 170, "FLOOR_TILE", "CEIL_WOOD", "MARBLE")
	var alcove := s.rect(1248, 1248, 1312, 1280, 0, 96, 200, "METALFLOOR", "CEIL_WOOD", "METAL")
	s.set_side(Vector2(1248, 1280), Vector2(1312, 1280), alcove, {"middle": "SW1OFF"})
	s.set_line(Vector2(1248, 1280), Vector2(1312, 1280), 11)

	# South: stairs down into the crypt.
	for i in 4:
		s.rect(1232, -224 - i * 96, 1328, -128 - i * 96, -16 * (i + 1), 128, 110 - i * 6, "FLOOR_STONE", "CEIL_WOOD", "BRICK")
	var crypt := s.rect(960, -896, 1600, -512, -64, 192, 90, "FLOOR_STONE", "CEIL_WOOD", "BRICK")
	s.rect(1040, -832, 1104, -672, -40, 192, 90, "METALFLOOR", "CEIL_WOOD", "BRICK", 0, 0, crypt)
	s.rect(1456, -832, 1520, -672, -40, 192, 90, "METALFLOOR", "CEIL_WOOD", "BRICK", 0, 0, crypt)
	s.rect(1248, -752, 1312, -688, -48, 192, 150, "FLOOR_TILE", "CEIL_WOOD", "MARBLE", 0, 0, crypt)
	s.pillar(crypt, _square(Vector2(1184, -608), 16), "BRICK")
	s.pillar(crypt, _square(Vector2(1376, -608), 16), "BRICK")

	# --- Things -------------------------------------------------------
	s.thing(384, 96, 1, 90)                     # player start

	# courtyard
	s.thing(200, 600, 66, 0)                    # gargoyles
	s.thing(580, 640, 66, 180)
	s.thing(384, 640, 2001, 270)                # ethereal crossbow
	s.thing(256, 200, 10)                       # wand crystals
	s.thing(512, 200, 10)
	s.thing(128, 420, 81)                       # crystal vial
	s.thing(384, 448, 27)                       # serpent torch on the plinth
	for c in [Vector2(64, 64), Vector2(704, 64), Vector2(64, 704), Vector2(704, 704)]:
		s.thing(c.x, c.y, 76)                   # braziers

	# great hall
	s.thing(1280, 160, 68, 270)                 # golems
	s.thing(1280, 640, 68, 90)
	s.thing(1280, 384, 5, 180)                  # fire gargoyle over the lava
	s.thing(1000, 300, 18)                      # ethereal arrows
	s.thing(1000, 470, 18)
	s.thing(960, 820, 85)                       # silver shield
	s.thing(1580, -60, 81)
	for c in [Vector2(1120, 96), Vector2(1440, 96), Vector2(1120, 672), Vector2(1440, 672)]:
		s.thing(c.x, c.y, 27)                   # serpent torches
	s.thing(1280, 384, 28)                      # chandelier

	# platform and balcony
	s.thing(1840, 384, 53)                      # dragon claw
	s.thing(1840, 240, 15, 180)                 # disciple of D'Sparil
	s.thing(1840, 530, 54)                      # claw orb
	s.thing(2100, 384, 64, 180)                 # undead warrior
	s.thing(2140, 240, 86)                      # tome of power
	s.thing(2140, 530, 83)                      # wings of wrath
	s.thing(2040, 530, 82)                      # quartz flask

	# crypt
	s.thing(1100, -560, 68, 90)
	s.thing(1460, -560, 68, 90)
	s.thing(1280, -850, 68, 90)
	s.thing(1400, -780, 45, 90)                 # nitrogolem
	s.thing(1000, -860, 66, 45)
	s.thing(1560, -860, 66, 135)
	s.thing(1280, -720, 73)                     # green key on the altar
	s.thing(1560, -560, 2003)                   # phoenix rod
	s.thing(1000, -560, 22)                     # flame orbs
	s.thing(1540, -620, 22)
	s.thing(1180, -850, 54)
	s.thing(1380, -850, 82)
	for c in [Vector2(976, -704), Vector2(1584, -704), Vector2(1100, -880), Vector2(1460, -880)]:
		s.thing(c.x, c.y, 50)                   # wall torches

	# exit chamber
	s.thing(1280, 1120, 64, 270)
	s.thing(1190, 1080, 64, 270)
	s.thing(1120, 1216, 76)
	s.thing(1440, 1216, 76)
	s.thing(1420, 1040, 81)
	return s.build()


static func _square(c: Vector2, half: float) -> Array:
	return [c + Vector2(-half, -half), c + Vector2(half, -half), c + Vector2(half, half), c + Vector2(-half, half)]


static func _octagon(c: Vector2, r: float) -> Array:
	var pts := []
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		pts.append((c + Vector2(cos(a), sin(a)) * r).round())
	return pts
