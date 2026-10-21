class_name ThingSpawner
## Places map things (player start, monsters, items, decorations) using
## Heretic's thing numbers. Everything is centralised here so a wrong number
## is a one-line fix.

const S := Layers.S

# Heretic's monster slots filled with the design map's roster, by role:
# the common melee slot (golem) is the Disciple, the tougher ranged slot
# (nitrogolem) is the heavy Golem, the flying caster slot is the Wraithverge.
const MONSTERS := {
	66: "gryphon", 5: "fire_gryphon",
	68: "disciple", 69: "disciple_ghost", 45: "golem", 46: "golem_ghost",
	64: "hell_knight", 65: "hell_knight_ghost",
	90: "sabreclaw", 70: "weredragon", 92: "ophidian", 15: "wraithverge",
	6: "iron_liche", 9: "maulotaur", 7: "dsparil",
}

const PICKUPS := {
	10: "wand_ammo", 12: "wand_ammo_big", 18: "arrows", 19: "quiver",
	54: "claw_orb", 55: "energy_orb", 20: "runes", 21: "runes_big",
	22: "flame_orb", 23: "inferno_orb", 13: "mace_spheres", 16: "mace_pile",
	81: "vial", 85: "shield_silver", 31: "shield_enchanted", 8: "bag",
	2005: "weapon_gauntlets", 2001: "weapon_crossbow", 53: "weapon_claw",
	2004: "weapon_hellstaff", 2003: "weapon_phoenix",
	73: "key_green", 79: "key_blue", 80: "key_yellow",
	82: "flask", 32: "urn", 86: "tome", 83: "wings", 84: "ring", 75: "shadow",
	33: "torch", 34: "bomb", 36: "chaos",
}

# type: [model, light color, light range (m), hangs from ceiling, solid radius]
const DECOR := {
	50: ["wall_torch", Color(1.0, 0.55, 0.2), 9.0, false, 0.0],
	27: ["serpent_torch", Color(1.0, 0.5, 0.15), 11.0, false, 0.4],
	76: ["brazier", Color(1.0, 0.45, 0.12), 12.0, false, 0.5],
	28: ["chandelier", Color(1.0, 0.75, 0.4), 14.0, true, 0.0],
	87: ["volcano", Color(1.0, 0.25, 0.05), 10.0, false, 0.8],
	29: ["pillar_small", Color(0, 0, 0), 0.0, false, 0.5],
	47: ["pillar_brown", Color(0, 0, 0), 0.0, false, 0.5],
	37: ["stalagmite", Color(0, 0, 0), 0.0, false, 0.4],
	38: ["stalagmite_big", Color(0, 0, 0), 0.0, false, 0.6],
	94: ["key_statue_blue", Color(0.3, 0.5, 1.0), 6.0, false, 0.5],
	95: ["key_statue_green", Color(0.3, 1.0, 0.4), 6.0, false, 0.5],
	96: ["key_statue_yellow", Color(1.0, 0.85, 0.3), 6.0, false, 0.5],
}

const MACE_SPOT := 2002
const PLAYER_START := 1
const TELEPORT_DEST := 14


static func spawn_all(w: World) -> void:
	var skill_bit := 1 if Game.skill <= 1 else (2 if Game.skill == 2 else 4)
	var lights_left := 64 if Game.quality >= Game.Quality.HIGH else 24
	var shadow_lights_left := 12 if Game.quality >= Game.Quality.HIGH else 0
	var mace_spots: Array = []
	var started := false
	for t in w.map.things:
		var p := Vector2(t.x, t.y)
		var type: int = t.type
		var floor_h := w.floor_at(p)
		var pos := GeometryBuilder.to_world(p, floor_h)
		var yaw := deg_to_rad(t.angle - 90.0)
		if type == PLAYER_START:
			if not started:
				started = true
				_spawn_player(w, pos, yaw)
			continue
		if type == TELEPORT_DEST:
			w.teleport_dests.append({"pos": pos, "yaw": yaw, "sector": w.geo.sector_at(p)})
			continue
		if (int(t.flags) & 16) != 0 or (int(t.flags) & skill_bit) == 0:
			continue
		if type == MACE_SPOT:
			mace_spots.append(pos)
		elif MONSTERS.has(type):
			var m := Monster.new()
			w.add_child(m)
			m.setup(MONSTERS[type], (int(t.flags) & 8) != 0)
			m.global_position = pos + Vector3(0, 0.02, 0)
			m.rotation.y = yaw
			w.total_kills += 1
		elif PICKUPS.has(type):
			var k: String = PICKUPS[type]
			var item := Pickup.new()
			w.add_child(item)
			item.setup(k)
			item.global_position = pos
			if not k.begins_with("key"):
				w.total_items += 1
		elif DECOR.has(type):
			var d: Array = DECOR[type]
			var ceil_h: float = w.map.sectors[maxi(w.geo.sector_at(p), 0)].ceil
			var at := GeometryBuilder.to_world(p, ceil_h) if d[3] else pos
			var node := Models.decoration(d[0])
			w.add_child(node)
			node.global_position = at
			node.rotation.y = yaw
			if d[4] > 0.0:
				_add_solid(node, d[4])
			if d[2] > 0.0 and lights_left > 0:
				lights_left -= 1
				var l := OmniLight3D.new()
				l.light_color = d[1]
				l.omni_range = d[2]
				l.light_energy = 2.2
				l.omni_attenuation = 1.3
				l.position = Vector3(0, -0.5 if d[3] else (0.6 if d[0] == "wall_torch" else 1.3), 0)
				if shadow_lights_left > 0:
					shadow_lights_left -= 1
					l.shadow_enabled = true
					l.shadow_bias = 0.05
				node.add_child(l)
				w.add_flicker(l)
	if not mace_spots.is_empty():
		var item := Pickup.new()
		w.add_child(item)
		item.setup("weapon_mace")
		item.global_position = mace_spots[randi() % mace_spots.size()]
		w.total_items += 1
	if not started:
		_spawn_player(w, Vector3.ZERO, 0.0)


static func _spawn_player(w: World, pos: Vector3, yaw: float) -> void:
	var p := Player.new()
	w.add_child(p)
	p.setup(Game.carry)
	p.global_position = pos + Vector3(0, 0.05, 0)
	p.set_yaw(yaw)
	w.player = p
	w.start_pos = p.global_position
	w.start_yaw = yaw


static func _add_solid(node: Node3D, radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 2.0
	cs.shape = shape
	cs.position.y = 1.0
	body.add_child(cs)
	node.add_child(body)
