class_name MonsterDefs
## The roster, following the HD Character & Monster Design Template (the design
## map), not the 1994 sprites. Speeds in m/s, sizes in meters.
## model: placeholder builder in Models. asset: the replacement model's name in
## assets/monsters/ (variants try their own id first, then this).
## melee: [min, max] damage. proj: GameData.PROJECTILES key. rate: chance per
## second to open fire while the player is in sight.

const DEFS := {
	# Gryphon: basic enemy. Eagle-headed, winged, swoops in to claw.
	"gryphon": {"hp": 60, "speed": 7.0, "radius": 0.6, "height": 1.6, "fly": true, "model": "winged", "asset": "gryphon",
		"color": Color(0.5, 0.33, 0.16), "eye": Color(1.0, 0.85, 0.3), "melee": [4, 14], "painchance": 0.7,
		"sound": "gargoyle", "drop": ""},
	"fire_gryphon": {"hp": 90, "speed": 7.5, "radius": 0.6, "height": 1.6, "fly": true, "model": "winged", "asset": "gryphon",
		"color": Color(0.8, 0.42, 0.12), "eye": Color(1, 1, 0.6), "melee": [5, 14], "proj": "gargoyle_fire", "rate": 0.6,
		"painchance": 0.6, "sound": "gargoyle", "drop": ""},
	# Disciple: melee enemy. Red-hooded cultist with a spiked flail.
	"disciple": {"hp": 70, "speed": 4.2, "radius": 0.5, "height": 1.85, "model": "cultist", "asset": "disciple",
		"color": Color(0.55, 0.07, 0.05), "eye": Color(1.0, 0.5, 0.2), "melee": [6, 16], "painchance": 0.55,
		"sound": "disciple", "drop": "wand_ammo"},
	"disciple_ghost": {"hp": 70, "speed": 4.2, "radius": 0.5, "height": 1.85, "model": "cultist", "asset": "disciple",
		"color": Color(0.7, 0.75, 0.8), "ghost": true, "melee": [6, 16], "painchance": 0.55, "sound": "disciple", "drop": "wand_ammo"},
	# Golem: heavy enemy. Stone body split by molten cracks; hurls lava rock.
	"golem": {"hp": 260, "speed": 2.8, "radius": 0.8, "height": 2.4, "model": "stone_brute", "asset": "golem",
		"color": Color(0.27, 0.25, 0.24), "eye": Color(1.0, 0.45, 0.08), "melee": [12, 28], "proj": "lava_rock", "rate": 0.4,
		"painchance": 0.2, "sound": "golem", "drop": "wand_ammo_big"},
	"golem_ghost": {"hp": 260, "speed": 2.8, "radius": 0.8, "height": 2.4, "model": "stone_brute", "asset": "golem",
		"color": Color(0.6, 0.7, 0.75), "ghost": true, "eye": Color(0.4, 0.9, 1.0), "melee": [12, 28], "proj": "lava_rock",
		"rate": 0.4, "painchance": 0.2, "sound": "golem", "drop": "wand_ammo_big"},
	# Hell Knight: mid-tier enemy. Horned dark plate, axe and shield; throws axes.
	"hell_knight": {"hp": 200, "speed": 4.2, "radius": 0.6, "height": 2.3, "model": "knight", "asset": "hell_knight",
		"color": Color(0.33, 0.31, 0.31), "eye": Color(1.0, 0.25, 0.1), "melee": [10, 22], "proj": "warrior_axe", "rate": 0.6,
		"painchance": 0.35, "sound": "warrior", "drop": "arrows"},
	"hell_knight_ghost": {"hp": 200, "speed": 4.2, "radius": 0.6, "height": 2.3, "model": "knight", "asset": "hell_knight",
		"color": Color(0.7, 0.75, 0.8), "ghost": true, "melee": [10, 22], "proj": "warrior_axe", "rate": 0.6,
		"painchance": 0.35, "sound": "warrior", "drop": "arrows"},
	# Wraithverge: flying enemy. Tattered spectral wraith casting green magic.
	"wraithverge": {"hp": 160, "speed": 4.8, "radius": 0.6, "height": 2.6, "fly": true, "model": "wraith", "asset": "wraithverge",
		"color": Color(0.16, 0.42, 0.42), "eye": Color(0.4, 1.0, 0.6), "proj": "wraith_bolt", "rate": 0.7, "spread": 3,
		"painchance": 0.4, "sound": "disciple", "drop": "arrows", "blink": true},
	# Sabreclaw: fast enemy. Hairless muscular beast with long claws.
	"sabreclaw": {"hp": 150, "speed": 8.5, "radius": 0.6, "height": 1.8, "model": "beast", "asset": "sabreclaw",
		"color": Color(0.62, 0.47, 0.38), "eye": Color(1.0, 0.85, 0.3), "melee": [8, 22], "painchance": 0.3,
		"sound": "beast", "drop": "claw_orb"},
	# Not on the design map; kept so WAD maps that use it still work.
	"weredragon": {"hp": 220, "speed": 5.0, "radius": 0.7, "height": 2.2, "model": "dragon", "asset": "weredragon",
		"color": Color(0.6, 0.18, 0.12), "melee": [8, 20], "proj": "dragon_fire", "rate": 0.9, "burst": 3,
		"painchance": 0.3, "sound": "beast", "drop": "runes"},
	# Ophidian: ranged enemy. Purple-robed, gold-armored serpent-man with a green-fire staff.
	"ophidian": {"hp": 280, "speed": 3.6, "radius": 0.6, "height": 2.2, "model": "serpent", "asset": "ophidian",
		"color": Color(0.36, 0.16, 0.46), "eye": Color(0.5, 1.0, 0.4), "proj": "ophidian_ball", "rate": 0.8, "burst": 3,
		"painchance": 0.25, "sound": "beast", "drop": "runes"},
	# Iron Liche: ranged enemy. Armored skeletal sorcerer in purple and gold, orb scythe.
	"iron_liche": {"hp": 650, "speed": 3.2, "radius": 0.7, "height": 2.5, "model": "sorcerer", "asset": "iron_liche",
		"color": Color(0.3, 0.12, 0.42), "eye": Color(0.8, 0.4, 1.0), "proj": "liche_bolt", "rate": 0.6, "spread": 3,
		"painchance": 0.15, "sound": "golem", "drop": "flame_orb"},
	# Maulotaur: heavy enemy. Bull-headed brute with a great axe.
	"maulotaur": {"hp": 3000, "speed": 6.0, "radius": 1.0, "height": 3.0, "model": "minotaur", "asset": "maulotaur",
		"color": Color(0.42, 0.25, 0.15), "eye": Color(1.0, 0.3, 0.05), "melee": [20, 50], "proj": "maulotaur_fire",
		"rate": 0.6, "spread": 5, "painchance": 0.05, "sound": "beast", "drop": "", "boss": true},
	# D'Sparil: final boss. Towering horned sorcerer-king in purple and gold.
	"dsparil": {"hp": 2500, "speed": 4.0, "radius": 1.0, "height": 3.4, "model": "sorcerer", "asset": "dsparil",
		"color": Color(0.26, 0.1, 0.36), "eye": Color(0.7, 0.45, 1.0), "proj": "dsparil_bolt", "rate": 0.9, "spread": 3,
		"painchance": 0.05, "sound": "disciple", "drop": "", "boss": true, "blink": true, "crown": true},
}


static func get_def(kind: String) -> Dictionary:
	return DEFS.get(kind, DEFS["disciple"])
