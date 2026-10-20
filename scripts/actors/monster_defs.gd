class_name MonsterDefs
## Monster stats. Speeds in m/s, sizes in meters, attack timings in seconds.
## melee: [min, max] damage. proj: GameData.PROJECTILES key. rate: chance per
## second to open fire while the player is in sight.

const DEFS := {
	"gargoyle": {"hp": 40, "speed": 6.5, "radius": 0.45, "height": 1.1, "fly": true, "model": "gargoyle",
		"color": Color(0.55, 0.2, 0.15), "melee": [3, 12], "painchance": 0.8, "sound": "gargoyle", "drop": ""},
	"fire_gargoyle": {"hp": 80, "speed": 7.0, "radius": 0.45, "height": 1.1, "fly": true, "model": "gargoyle",
		"color": Color(0.9, 0.5, 0.12), "eye": Color(1, 1, 0.6), "melee": [5, 14], "proj": "gargoyle_fire", "rate": 0.6,
		"painchance": 0.6, "sound": "gargoyle", "drop": ""},
	"golem": {"hp": 80, "speed": 3.4, "radius": 0.6, "height": 2.0, "model": "golem", "color": Color(0.62, 0.55, 0.42),
		"melee": [6, 16], "painchance": 0.5, "sound": "golem", "drop": "wand_ammo"},
	"nitrogolem": {"hp": 100, "speed": 3.4, "radius": 0.6, "height": 2.0, "model": "golem", "color": Color(0.45, 0.52, 0.48),
		"eye": Color(0.3, 0.8, 1.0), "melee": [6, 16], "proj": "golem_skull", "rate": 0.5, "painchance": 0.4,
		"sound": "golem", "drop": "wand_ammo"},
	"golem_ghost": {"hp": 80, "speed": 3.4, "radius": 0.6, "height": 2.0, "model": "golem", "color": Color(0.7, 0.75, 0.8),
		"ghost": true, "melee": [6, 16], "painchance": 0.5, "sound": "golem", "drop": "wand_ammo"},
	"nitrogolem_ghost": {"hp": 100, "speed": 3.4, "radius": 0.6, "height": 2.0, "model": "golem", "color": Color(0.6, 0.75, 0.8),
		"ghost": true, "eye": Color(0.3, 0.8, 1.0), "melee": [6, 16], "proj": "golem_skull", "rate": 0.5,
		"painchance": 0.4, "sound": "golem", "drop": "wand_ammo"},
	"warrior": {"hp": 200, "speed": 4.2, "radius": 0.6, "height": 2.2, "model": "warrior", "color": Color(0.5, 0.5, 0.56),
		"melee": [8, 20], "proj": "warrior_axe", "rate": 0.7, "painchance": 0.35, "sound": "warrior", "drop": "arrows"},
	"warrior_ghost": {"hp": 200, "speed": 4.2, "radius": 0.6, "height": 2.2, "model": "warrior", "color": Color(0.7, 0.75, 0.8),
		"ghost": true, "melee": [8, 20], "proj": "warrior_axe", "rate": 0.7, "painchance": 0.35, "sound": "warrior", "drop": "arrows"},
	"sabreclaw": {"hp": 150, "speed": 8.5, "radius": 0.55, "height": 1.8, "model": "sabreclaw", "color": Color(0.45, 0.3, 0.2),
		"melee": [8, 22], "painchance": 0.3, "sound": "beast", "drop": "claw_orb"},
	"weredragon": {"hp": 220, "speed": 5.0, "radius": 0.7, "height": 2.2, "model": "dragon", "color": Color(0.6, 0.18, 0.12),
		"melee": [8, 20], "proj": "dragon_fire", "rate": 0.9, "burst": 3, "painchance": 0.3, "sound": "beast", "drop": "runes"},
	"ophidian": {"hp": 280, "speed": 3.6, "radius": 0.6, "height": 2.2, "model": "ophidian", "color": Color(0.25, 0.5, 0.25),
		"proj": "ophidian_ball", "rate": 0.8, "burst": 3, "painchance": 0.25, "sound": "beast", "drop": "runes"},
	"disciple": {"hp": 180, "speed": 4.5, "radius": 0.5, "height": 2.0, "fly": true, "model": "disciple",
		"color": Color(0.28, 0.12, 0.38), "proj": "disciple_bolt", "rate": 0.7, "spread": 3, "painchance": 0.4,
		"sound": "disciple", "drop": "arrows", "blink": true},
	"iron_lich": {"hp": 700, "speed": 2.8, "radius": 1.0, "height": 2.2, "fly": true, "model": "lich",
		"color": Color(0.55, 0.55, 0.6), "proj": "lich_ice", "rate": 0.6, "spread": 3, "painchance": 0.1,
		"sound": "golem", "drop": "flame_orb"},
	"maulotaur": {"hp": 3000, "speed": 6.0, "radius": 1.0, "height": 3.2, "model": "maulotaur", "color": Color(0.42, 0.25, 0.15),
		"melee": [20, 50], "proj": "maulotaur_fire", "rate": 0.6, "spread": 5, "painchance": 0.05, "sound": "beast", "drop": "", "boss": true},
	"dsparil": {"hp": 2000, "speed": 4.0, "radius": 1.0, "height": 3.0, "fly": true, "model": "dsparil",
		"color": Color(0.15, 0.2, 0.45), "eye": Color(0.5, 0.8, 1.0), "proj": "dsparil_bolt", "rate": 0.9, "spread": 3,
		"painchance": 0.05, "sound": "disciple", "drop": "", "boss": true, "blink": true},
}


static func get_def(kind: String) -> Dictionary:
	return DEFS.get(kind, DEFS["golem"])
