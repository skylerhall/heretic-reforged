class_name GameData
## Weapons, projectiles, items and ammo, as plain data tables.

const AMMO_MAX := {"wand": 100, "crossbow": 50, "claw": 200, "hellstaff": 200, "phoenix": 20, "mace": 150}
const AMMO_COLOR := {
	"wand": Color(0.45, 0.65, 1.0), "crossbow": Color(0.4, 1.0, 0.55), "claw": Color(0.4, 0.6, 1.0),
	"hellstaff": Color(1.0, 0.25, 0.25), "phoenix": Color(1.0, 0.55, 0.15), "mace": Color(0.75, 0.75, 0.85),
}

const WEAPON_ORDER := ["staff", "gauntlets", "wand", "crossbow", "claw", "hellstaff", "phoenix", "mace"]
const WEAPON_SLOT := {"staff": 1, "gauntlets": 1, "wand": 2, "crossbow": 3, "claw": 4, "hellstaff": 5, "phoenix": 6, "mace": 7}

# kind: melee | hitscan | projectile.  "powered" overrides fields while the
# Tome of Power is active.
const WEAPONS := {
	"staff": {"name": "STAFF", "ammo": "", "rate": 0.45, "kind": "melee", "range": 2.4, "dmin": 5, "dmax": 20,
		"sound": "staff", "flash": 0.0,
		"powered": {"dmin": 18, "dmax": 45, "knockback": 9.0, "flash": 1.5, "color": Color(0.6, 0.8, 1.0)}},
	"gauntlets": {"name": "GAUNTLETS OF THE NECROMANCER", "ammo": "", "rate": 0.12, "kind": "melee", "range": 2.4,
		"dmin": 2, "dmax": 16, "sound": "gauntlets", "flash": 1.2, "color": Color(0.4, 1.0, 0.5),
		"powered": {"dmin": 8, "dmax": 32, "range": 3.2, "drain": true, "color": Color(1.0, 0.3, 0.3)}},
	"wand": {"name": "ELVEN WAND", "ammo": "wand", "use": 1, "rate": 0.3, "kind": "hitscan", "count": 1,
		"spread": 0.01, "dmin": 7, "dmax": 14, "sound": "wand", "flash": 2.0, "color": Color(0.45, 0.65, 1.0),
		"powered": {"count": 5, "spread": 0.06, "dmin": 7, "dmax": 21, "rate": 0.35}},
	"crossbow": {"name": "ETHEREAL CROSSBOW", "ammo": "crossbow", "use": 1, "rate": 0.7, "kind": "projectile",
		"shots": [["bolt_big", 0.0], ["bolt", -5.0], ["bolt", 5.0]], "sound": "crossbow", "flash": 1.5,
		"color": Color(0.4, 1.0, 0.55),
		"powered": {"shots": [["bolt_big", -2.0], ["bolt_big", 2.0], ["bolt", -7.0], ["bolt", 7.0], ["bolt", -12.0], ["bolt", 12.0]]}},
	"claw": {"name": "DRAGON CLAW", "ammo": "claw", "use": 1, "rate": 0.16, "kind": "hitscan", "count": 1,
		"spread": 0.02, "dmin": 8, "dmax": 16, "sound": "claw", "flash": 2.0, "color": Color(0.4, 0.6, 1.0),
		"powered": {"kind": "projectile", "use": 5, "rate": 0.35, "shots": [["claw_ripper", 0.0]]}},
	"hellstaff": {"name": "HELLSTAFF", "ammo": "hellstaff", "use": 1, "rate": 0.12, "kind": "projectile",
		"shots": [["hell_skull", 0.0]], "spread": 0.015, "sound": "hellstaff", "flash": 1.5, "color": Color(1.0, 0.25, 0.25),
		"powered": {"use": 5, "rate": 0.6, "shots": [["hell_big", 0.0]]}},
	"phoenix": {"name": "PHOENIX ROD", "ammo": "phoenix", "use": 1, "rate": 0.9, "kind": "projectile",
		"shots": [["phoenix", 0.0]], "sound": "phoenix", "flash": 3.0, "color": Color(1.0, 0.55, 0.15),
		"powered": {"use": 0.2, "rate": 0.07, "shots": [["flame", 0.0]], "spread": 0.05, "sound": "flame", "flash": 2.0}},
	"mace": {"name": "FIREMACE", "ammo": "mace", "use": 1, "rate": 0.2, "kind": "projectile",
		"shots": [["mace_ball", 0.0]], "spread": 0.05, "sound": "mace", "flash": 1.0, "color": Color(0.8, 0.8, 1.0),
		"powered": {"use": 5, "rate": 0.8, "shots": [["mace_big", 0.0]]}},
}

# speed m/s, damage range, look, and behaviour flags
const PROJECTILES := {
	"bolt": {"speed": 32.0, "dmin": 10, "dmax": 20, "color": Color(0.35, 1.0, 0.5), "size": 0.1, "trail": true},
	"bolt_big": {"speed": 36.0, "dmin": 25, "dmax": 50, "color": Color(0.45, 1.0, 0.6), "size": 0.16, "light": true, "trail": true},
	"claw_ripper": {"speed": 28.0, "dmin": 30, "dmax": 60, "color": Color(0.45, 0.65, 1.0), "size": 0.22, "light": true, "splash": 2.0, "splash_dmg": 30, "trail": true},
	"hell_skull": {"speed": 34.0, "dmin": 8, "dmax": 20, "color": Color(1.0, 0.2, 0.2), "size": 0.12},
	"hell_big": {"speed": 22.0, "dmin": 60, "dmax": 100, "color": Color(1.0, 0.15, 0.15), "size": 0.45, "light": true, "splash": 5.0, "splash_dmg": 90, "trail": true},
	"phoenix": {"speed": 36.0, "dmin": 20, "dmax": 40, "color": Color(1.0, 0.5, 0.12), "size": 0.3, "light": true, "splash": 4.0, "splash_dmg": 110, "trail": true},
	"flame": {"speed": 16.0, "dmin": 4, "dmax": 9, "color": Color(1.0, 0.45, 0.1), "size": 0.3, "life": 0.4, "grow": 3.0},
	"mace_ball": {"speed": 24.0, "dmin": 12, "dmax": 24, "color": Color(0.85, 0.85, 1.0), "size": 0.14, "gravity": 14.0, "bounces": 2},
	"mace_big": {"speed": 20.0, "dmin": 70, "dmax": 140, "color": Color(0.7, 0.7, 1.0), "size": 0.35, "gravity": 8.0, "bounces": 4, "homing": 3.0, "light": true},
	"bomb": {"speed": 0.0, "dmin": 0, "dmax": 0, "color": Color(1.0, 0.6, 0.2), "size": 0.25, "gravity": 12.0, "life": 1.2, "splash": 6.0, "splash_dmg": 160, "fuse": true},
	# monster attacks
	"gargoyle_fire": {"speed": 16.0, "dmin": 5, "dmax": 10, "color": Color(1.0, 0.5, 0.1), "size": 0.18, "light": true},
	"golem_skull": {"speed": 13.0, "dmin": 6, "dmax": 16, "color": Color(0.4, 0.9, 1.0), "size": 0.22, "light": true, "homing": 1.5, "life": 6.0},
	"warrior_axe": {"speed": 15.0, "dmin": 8, "dmax": 16, "color": Color(0.4, 1.0, 0.3), "size": 0.2, "light": true, "spin": true},
	"disciple_bolt": {"speed": 15.0, "dmin": 4, "dmax": 10, "color": Color(0.8, 0.35, 1.0), "size": 0.15, "light": true},
	"dragon_fire": {"speed": 20.0, "dmin": 8, "dmax": 18, "color": Color(1.0, 0.4, 0.1), "size": 0.2, "light": true},
	"ophidian_ball": {"speed": 18.0, "dmin": 6, "dmax": 14, "color": Color(0.45, 1.0, 0.35), "size": 0.18, "light": true},
	"lava_rock": {"speed": 15.0, "dmin": 10, "dmax": 22, "color": Color(1.0, 0.45, 0.08), "size": 0.28, "light": true, "gravity": 3.0, "splash": 2.0, "splash_dmg": 15},
	"wraith_bolt": {"speed": 15.0, "dmin": 5, "dmax": 12, "color": Color(0.35, 1.0, 0.6), "size": 0.16, "light": true},
	"liche_bolt": {"speed": 18.0, "dmin": 15, "dmax": 30, "color": Color(0.75, 0.35, 1.0), "size": 0.28, "light": true, "splash": 3.0, "splash_dmg": 25},
	"lich_ice": {"speed": 18.0, "dmin": 20, "dmax": 40, "color": Color(0.5, 0.9, 1.0), "size": 0.3, "light": true, "splash": 3.0, "splash_dmg": 30},
	"maulotaur_fire": {"speed": 22.0, "dmin": 20, "dmax": 40, "color": Color(1.0, 0.35, 0.05), "size": 0.4, "light": true, "splash": 3.0, "splash_dmg": 40},
	"dsparil_bolt": {"speed": 20.0, "dmin": 15, "dmax": 30, "color": Color(0.7, 0.4, 1.0), "size": 0.25, "light": true},
}

# Item effects: ammo, health, armor, weapon, key, artifact, bag.
const ITEMS := {
	"wand_ammo": {"ammo": "wand", "amount": 10, "msg": "WAND CRYSTAL"},
	"wand_ammo_big": {"ammo": "wand", "amount": 50, "msg": "CRYSTAL GEODE"},
	"arrows": {"ammo": "crossbow", "amount": 5, "msg": "ETHEREAL ARROWS"},
	"quiver": {"ammo": "crossbow", "amount": 20, "msg": "QUIVER OF ETHEREAL ARROWS"},
	"claw_orb": {"ammo": "claw", "amount": 10, "msg": "CLAW ORB"},
	"energy_orb": {"ammo": "claw", "amount": 25, "msg": "ENERGY ORB"},
	"runes": {"ammo": "hellstaff", "amount": 20, "msg": "LESSER RUNES"},
	"runes_big": {"ammo": "hellstaff", "amount": 100, "msg": "GREATER RUNES"},
	"flame_orb": {"ammo": "phoenix", "amount": 1, "msg": "FLAME ORB"},
	"inferno_orb": {"ammo": "phoenix", "amount": 10, "msg": "INFERNO ORB"},
	"mace_spheres": {"ammo": "mace", "amount": 20, "msg": "MACE SPHERES"},
	"mace_pile": {"ammo": "mace", "amount": 100, "msg": "PILE OF MACE SPHERES"},
	"vial": {"health": 10, "msg": "CRYSTAL VIAL"},
	"shield_silver": {"armor": 100, "armor_class": 1, "msg": "SILVER SHIELD"},
	"shield_enchanted": {"armor": 200, "armor_class": 2, "msg": "ENCHANTED SHIELD"},
	"bag": {"bag": true, "msg": "BAG OF HOLDING"},
	"weapon_gauntlets": {"weapon": "gauntlets", "msg": "GAUNTLETS OF THE NECROMANCER"},
	"weapon_crossbow": {"weapon": "crossbow", "ammo": "crossbow", "amount": 10, "msg": "ETHEREAL CROSSBOW"},
	"weapon_claw": {"weapon": "claw", "ammo": "claw", "amount": 30, "msg": "DRAGON CLAW"},
	"weapon_hellstaff": {"weapon": "hellstaff", "ammo": "hellstaff", "amount": 50, "msg": "HELLSTAFF"},
	"weapon_phoenix": {"weapon": "phoenix", "ammo": "phoenix", "amount": 2, "msg": "PHOENIX ROD"},
	"weapon_mace": {"weapon": "mace", "ammo": "mace", "amount": 50, "msg": "FIREMACE"},
	"key_green": {"key": "green", "msg": "GREEN KEY"},
	"key_blue": {"key": "blue", "msg": "BLUE KEY"},
	"key_yellow": {"key": "yellow", "msg": "YELLOW KEY"},
	"flask": {"artifact": "flask", "msg": "QUARTZ FLASK"},
	"urn": {"artifact": "urn", "msg": "MYSTIC URN"},
	"tome": {"artifact": "tome", "msg": "TOME OF POWER"},
	"wings": {"artifact": "wings", "msg": "WINGS OF WRATH"},
	"ring": {"artifact": "ring", "msg": "RING OF INVINCIBILITY"},
	"shadow": {"artifact": "shadow", "msg": "SHADOWSPHERE"},
	"torch": {"artifact": "torch", "msg": "TORCH"},
	"bomb": {"artifact": "bomb", "msg": "TIME BOMB OF THE ANCIENTS"},
	"chaos": {"artifact": "chaos", "msg": "CHAOS DEVICE"},
}

const ARTIFACT_ORDER := ["flask", "urn", "tome", "wings", "ring", "shadow", "torch", "bomb", "chaos"]
const ARTIFACT_NAMES := {
	"flask": "QUARTZ FLASK", "urn": "MYSTIC URN", "tome": "TOME OF POWER", "wings": "WINGS OF WRATH",
	"ring": "RING OF INVINCIBILITY", "shadow": "SHADOWSPHERE", "torch": "TORCH",
	"bomb": "TIME BOMB", "chaos": "CHAOS DEVICE",
}


## Weapon definition with Tome of Power overrides applied when powered.
static func weapon(name: String, powered: bool) -> Dictionary:
	var d: Dictionary = WEAPONS[name].duplicate()
	if powered and d.has("powered"):
		d.merge(d.powered, true)
	return d
