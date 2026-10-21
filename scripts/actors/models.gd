class_name Models
## Procedural 3D models for monsters, weapons, items and decorations, built
## from primitive meshes with PBR materials. Monsters face -Z. Animated parts
## are named (arm_l, arm_r, leg_l, leg_r, wing_l, wing_r, body, head) so the
## monster script can pose them.

static var _mats := {}


static func mat(color: Color, rough := 0.8, metal := 0.0, emit := Color(0, 0, 0), emit_energy := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s|%s" % [color, rough, metal, emit, emit_energy, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	return mat(color, 0.4, 0.0, color, energy)


static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg := Vector3.ZERO,
		scl := Vector3.ONE, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func sphere(r: float, segs := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(segs / 2, 4)
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 14
	c.rings = 6
	return c


static func cyl(top: float, bottom: float, h: float, segs := 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func gem(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.6
	s.radial_segments = 4
	s.rings = 2
	return s


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 16
	t.ring_segments = 8
	return t


# --- Monsters --------------------------------------------------------------

static func monster(model: String, d: Dictionary) -> Node3D:
	var ghost: bool = d.get("ghost", false)
	var a := 0.45 if ghost else 1.0
	var eye: Color = d.get("eye", Color(1, 0.3, 0.1))
	match model:
		"winged":
			return gargoyle(d.color, eye, a)
		"cultist":
			return humanoid({"h": d.height, "bulk": 1.0, "color": d.color, "skin": Color(0.55, 0.42, 0.34),
				"eye": eye, "head": "hood", "weapon": "flail", "robe": true, "alpha": a})
		"stone_brute":
			return humanoid({"h": d.height, "bulk": 1.7, "color": d.color, "skin": d.color.darkened(0.15),
				"eye": eye, "head": "box", "long_arms": true, "cracks": eye, "alpha": a})
		"knight":
			return humanoid({"h": d.height, "bulk": 1.25, "color": d.color, "skin": Color(0.22, 0.21, 0.22),
				"eye": eye, "head": "horned_helm", "metal": 0.8, "weapon": "axe", "shield": true, "alpha": a})
		"wraith":
			return robed(d.color, eye, d.height, 0.7)
		"beast":
			return humanoid({"h": d.height, "bulk": 1.2, "color": d.color, "skin": d.color.darkened(0.2),
				"eye": eye, "head": "snout", "weapon": "blades", "hunch": 30.0})
		"dragon":
			return humanoid({"h": d.height, "bulk": 1.3, "color": d.color, "skin": d.color.darkened(0.3),
				"eye": Color(1.0, 0.8, 0.1), "head": "snout"})
		"serpent":
			return ophidian(d.color)
		"sorcerer":
			return robed(d.color, eye, d.height, 1.0, d.get("crown", false))
		"minotaur":
			return humanoid({"h": d.height, "bulk": 1.6, "color": d.color, "skin": d.color.darkened(0.2),
				"eye": eye, "head": "bull", "weapon": "great_axe", "long_arms": true})
	return humanoid({"h": d.height, "color": d.color, "eye": eye})


static func humanoid(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var h: float = p.h
	var u := h / 2.0
	var bulk: float = p.get("bulk", 1.0)
	var a: float = p.get("alpha", 1.0)
	var body_m := mat(p.color, 0.6 if p.get("metal", 0.0) > 0.0 else 0.85, p.get("metal", 0.0), Color(0, 0, 0), 0.0, a)
	var skin_m := mat(p.get("skin", p.color), 0.85, 0.0, Color(0, 0, 0), 0.0, a)
	var eye_m := glow(p.eye, 5.0)
	var body := pivot(root, "body", Vector3(0, 0.9 * u, 0))
	body.rotation_degrees.x = -p.get("hunch", 0.0)
	part(body, capsule(0.3 * u * bulk, 0.85 * u), body_m, Vector3(0, 0.38 * u, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
	part(body, box(0.62 * u * bulk, 0.12 * u, 0.36 * u * bulk), body_m, Vector3(0, 0.05 * u, 0))
	var head := pivot(body, "head", Vector3(0, 0.88 * u, 0))
	match p.get("head", "box"):
		"helmet":
			part(head, cyl(0.15 * u, 0.19 * u, 0.32 * u), body_m, Vector3(0, 0.05 * u, 0))
			part(head, box(0.04 * u, 0.2 * u, 0.36 * u), body_m, Vector3(0, 0.25 * u, 0))
			part(head, box(0.26 * u, 0.04 * u, 0.02), eye_m, Vector3(0, 0.06 * u, -0.19 * u))
			for s in [-1, 1]:
				part(body, sphere(0.16 * u * bulk), body_m, Vector3(s * 0.36 * u * bulk, 0.66 * u, 0))
		"hood":
			part(head, sphere(0.21 * u), body_m, Vector3(0, 0.07 * u, 0.03 * u), Vector3.ZERO, Vector3(1, 1.15, 1.1))
			part(head, cyl(0.0, 0.12 * u, 0.22 * u), body_m, Vector3(0, 0.3 * u, 0.08 * u), Vector3(-25, 0, 0))
			part(head, sphere(0.15 * u), mat(Color(0.03, 0.02, 0.02), 1.0), Vector3(0, 0.03 * u, -0.08 * u))
			for s in [-1, 1]:
				part(head, sphere(0.025 * u), eye_m, Vector3(s * 0.05 * u, 0.06 * u, -0.19 * u))
		"horned_helm":
			part(head, cyl(0.15 * u, 0.19 * u, 0.32 * u), body_m, Vector3(0, 0.05 * u, 0))
			part(head, box(0.26 * u, 0.04 * u, 0.02), eye_m, Vector3(0, 0.06 * u, -0.19 * u))
			for s in [-1, 1]:
				part(head, cyl(0.0, 0.045 * u, 0.3 * u), mat(Color(0.8, 0.75, 0.6), 0.5), Vector3(s * 0.2 * u, 0.22 * u, 0), Vector3(0, 0, -s * 55))
				part(body, sphere(0.17 * u * bulk), body_m, Vector3(s * 0.36 * u * bulk, 0.66 * u, 0))
		"bandage":
			part(head, box(0.3 * u, 0.36 * u, 0.3 * u), skin_m, Vector3(0, 0.05 * u, 0), Vector3(0, 0, 4))
			for s in [-1, 1]:
				part(head, sphere(0.035 * u), eye_m, Vector3(s * 0.07 * u, 0.08 * u, -0.155 * u))
		"horns", "bull":
			var big: bool = p.head == "bull"
			part(head, sphere(0.19 * u), skin_m, Vector3(0, 0.05 * u, 0))
			part(head, box(0.18 * u, 0.14 * u, 0.2 * u), skin_m, Vector3(0, 0.0, -0.17 * u))
			for s in [-1, 1]:
				part(head, cyl(0.0, 0.05 * u, (0.4 if big else 0.25) * u), mat(Color(0.85, 0.8, 0.65), 0.5),
					Vector3(s * 0.2 * u, 0.2 * u, 0), Vector3(0, 0, -s * (70 if big else 25)))
				part(head, sphere(0.035 * u), eye_m, Vector3(s * 0.08 * u, 0.1 * u, -0.17 * u))
		"snout":
			part(head, sphere(0.18 * u), skin_m, Vector3(0, 0.05 * u, 0))
			part(head, box(0.16 * u, 0.12 * u, 0.3 * u), skin_m, Vector3(0, 0.0, -0.22 * u))
			for s in [-1, 1]:
				part(head, sphere(0.035 * u), eye_m, Vector3(s * 0.09 * u, 0.12 * u, -0.13 * u))
				part(head, cyl(0.0, 0.03 * u, 0.2 * u), mat(Color(0.9, 0.85, 0.7), 0.5), Vector3(s * 0.1 * u, 0.25 * u, 0.05 * u), Vector3(-30, 0, 0))
		_:
			part(head, sphere(0.18 * u), skin_m, Vector3(0, 0.05 * u, 0))
			for s in [-1, 1]:
				part(head, sphere(0.035 * u), eye_m, Vector3(s * 0.07 * u, 0.09 * u, -0.16 * u))
	if p.has("cracks"):
		var lava := glow(p.cracks, 4.0)
		for k in 7:
			part(body, box(0.03 * u, 0.25 * u, 0.02 * u), lava,
				Vector3((k - 3) * 0.08 * u * bulk, 0.3 * u + (k % 3) * 0.15 * u, -0.27 * u * bulk * 0.7), Vector3(0, 0, (k - 3) * 17))
	if p.get("robe", false):
		part(root, cyl(0.24 * u * bulk, 0.42 * u * bulk, 1.0 * u), body_m, Vector3(0, 0.5 * u, 0))
	var arm_len := (1.0 if p.get("long_arms", false) else 0.78) * u
	for s in [-1, 1]:
		var arm := pivot(body, "arm_l" if s < 0 else "arm_r", Vector3(s * 0.38 * u * bulk, 0.68 * u, 0))
		part(arm, capsule(0.085 * u * bulk, arm_len), skin_m, Vector3(0, -arm_len * 0.45, 0))
		if s > 0:
			match p.get("weapon", ""):
				"axe":
					part(arm, cyl(0.025 * u, 0.025 * u, 0.9 * u), mat(Color(0.3, 0.2, 0.1)), Vector3(0, -arm_len * 0.9, -0.2 * u), Vector3(90, 0, 0))
					part(arm, box(0.03 * u, 0.3 * u, 0.22 * u), glow(Color(0.35, 1.0, 0.3), 2.5), Vector3(0, -arm_len * 0.8, -0.6 * u))
				"flail":
					part(arm, cyl(0.02 * u, 0.02 * u, 0.45 * u), mat(Color(0.3, 0.2, 0.1)), Vector3(0, -arm_len * 0.95, -0.1 * u), Vector3(70, 0, 0))
					part(arm, cyl(0.01 * u, 0.01 * u, 0.3 * u), mat(Color(0.4, 0.4, 0.42), 0.4, 0.9), Vector3(0, -arm_len * 1.05, -0.38 * u))
					var ball := part(arm, sphere(0.09 * u), mat(Color(0.3, 0.3, 0.32), 0.4, 0.9), Vector3(0, -arm_len * 1.25, -0.45 * u))
					for k in 6:
						var dirv := Vector3.UP.rotated(Vector3.RIGHT, k * 1.05).rotated(Vector3.UP, k * 0.9)
						part(ball, cyl(0.0, 0.025 * u, 0.09 * u), mat(Color(0.5, 0.5, 0.52), 0.4, 0.9), dirv * 0.09 * u, Vector3(rad_to_deg(dirv.z), 0, -rad_to_deg(dirv.x)))
				"great_axe":
					part(arm, cyl(0.035 * u, 0.035 * u, 1.3 * u), mat(Color(0.3, 0.2, 0.1)), Vector3(0, -arm_len * 0.9, -0.35 * u), Vector3(90, 0, 0))
					part(arm, box(0.05 * u, 0.55 * u, 0.4 * u), mat(Color(0.45, 0.43, 0.42), 0.35, 0.9), Vector3(0, -arm_len * 0.75, -0.95 * u))
				"hammer":
					part(arm, cyl(0.04 * u, 0.04 * u, 1.0 * u), mat(Color(0.3, 0.2, 0.1)), Vector3(0, -arm_len * 0.9, -0.3 * u), Vector3(90, 0, 0))
					part(arm, box(0.3 * u, 0.3 * u, 0.45 * u), mat(Color(0.35, 0.33, 0.33), 0.4, 0.9), Vector3(0, -arm_len * 0.9, -0.85 * u))
		if s < 0 and p.get("shield", false):
			part(arm, cyl(0.28 * u, 0.28 * u, 0.05 * u, 16), mat(Color(0.3, 0.28, 0.27), 0.4, 0.85), Vector3(-0.08 * u, -arm_len * 0.6, -0.12 * u), Vector3(0, 0, 90))
			part(arm, sphere(0.06 * u), mat(Color(0.75, 0.6, 0.25), 0.3, 1.0), Vector3(-0.12 * u, -arm_len * 0.6, -0.12 * u))
		if p.get("weapon", "") == "blades":
			part(arm, box(0.03 * u, 0.05 * u, 0.7 * u), mat(Color(0.8, 0.8, 0.85), 0.25, 1.0), Vector3(0, -arm_len * 0.9, -0.3 * u))
	for s in [-1, 1]:
		var leg := pivot(root, "leg_l" if s < 0 else "leg_r", Vector3(s * 0.17 * u * bulk, 0.92 * u, 0))
		part(leg, capsule(0.11 * u * bulk, 0.92 * u), skin_m if p.get("metal", 0.0) == 0.0 else body_m, Vector3(0, -0.46 * u, 0))
		part(leg, box(0.2 * u * bulk, 0.08 * u, 0.3 * u), skin_m, Vector3(0, -0.9 * u, -0.06 * u))
	return root


static func gargoyle(color: Color, eye: Color, alpha: float) -> Node3D:
	var root := Node3D.new()
	var skin := mat(color, 0.75, 0.0, Color(0, 0, 0), 0.0, alpha)
	var wing_m := mat(color.darkened(0.35), 0.9, 0.0, Color(0, 0, 0), 0.0, alpha)
	var body := pivot(root, "body", Vector3(0, 0.75, 0))
	part(body, capsule(0.22, 0.6), skin, Vector3(0, 0, 0), Vector3(-25, 0, 0))
	var head := pivot(body, "head", Vector3(0, 0.38, -0.12))
	part(head, sphere(0.17), skin, Vector3.ZERO)
	part(head, box(0.14, 0.1, 0.16), skin, Vector3(0, -0.04, -0.14))
	for s in [-1, 1]:
		part(head, sphere(0.035), glow(eye, 5.0), Vector3(s * 0.07, 0.04, -0.15))
		part(head, cyl(0.0, 0.035, 0.22), mat(Color(0.85, 0.8, 0.7), 0.5), Vector3(s * 0.1, 0.18, 0.04), Vector3(-35, 0, -s * 25))
		var wing := pivot(body, "wing_l" if s < 0 else "wing_r", Vector3(s * 0.15, 0.2, 0.12))
		part(wing, box(0.9, 0.03, 0.45), wing_m, Vector3(s * 0.45, 0, 0.05))
		part(wing, box(0.9, 0.05, 0.05), skin, Vector3(s * 0.45, 0.02, -0.18))
		var arm := pivot(body, "arm_l" if s < 0 else "arm_r", Vector3(s * 0.2, 0.15, -0.05))
		part(arm, capsule(0.05, 0.4), skin, Vector3(0, -0.18, -0.05))
		var leg := pivot(root, "leg_l" if s < 0 else "leg_r", Vector3(s * 0.1, 0.5, 0.1))
		part(leg, capsule(0.06, 0.4), skin, Vector3(0, -0.2, 0))
	part(body, cyl(0.01, 0.06, 0.6), skin, Vector3(0, -0.35, 0.3), Vector3(-60, 0, 0))
	return root


static func robed(color: Color, eye: Color, h: float, alpha := 1.0, crown := false) -> Node3D:
	var root := Node3D.new()
	var u := h / 2.0
	var robe := mat(color, 0.9, 0.0, Color(0, 0, 0), 0.0, alpha)
	var trim := mat(Color(0.75, 0.6, 0.2), 0.35, 0.8)
	var body := pivot(root, "body", Vector3(0, 0.0, 0))
	part(body, cyl(0.22 * u, 0.45 * u, 1.3 * u), robe, Vector3(0, 0.75 * u, 0))
	part(body, cyl(0.23 * u, 0.23 * u, 0.06 * u), trim, Vector3(0, 1.35 * u, 0))
	var head := pivot(body, "head", Vector3(0, 1.58 * u, 0))
	part(head, sphere(0.22 * u), robe, Vector3(0, 0, 0.02 * u), Vector3.ZERO, Vector3(1, 1.15, 1))
	part(head, sphere(0.16 * u), mat(Color(0.02, 0.01, 0.02), 1.0), Vector3(0, -0.02 * u, -0.08 * u))
	if crown:
		for i in 5:
			var ang := deg_to_rad(-60.0 + i * 30.0)
			part(head, cyl(0.0, 0.04 * u, 0.4 * u), trim, Vector3(sin(ang) * 0.18 * u, 0.32 * u, -cos(ang) * 0.1 * u), Vector3(0, 0, -rad_to_deg(ang) * 0.6))
	for s in [-1, 1]:
		part(head, sphere(0.03 * u), glow(eye, 6.0), Vector3(s * 0.06 * u, 0.0, -0.2 * u))
		var arm := pivot(body, "arm_l" if s < 0 else "arm_r", Vector3(s * 0.3 * u, 1.3 * u, 0))
		part(arm, cyl(0.12 * u, 0.06 * u, 0.6 * u), robe, Vector3(0, -0.28 * u, -0.05 * u), Vector3(-15, 0, 0))
		part(arm, sphere(0.06 * u), glow(eye, 3.0), Vector3(0, -0.6 * u, -0.12 * u))
	return root


static func ophidian(color: Color) -> Node3D:
	var root := Node3D.new()
	var skin := mat(color, 0.55, 0.1)
	var belly := mat(Color(0.8, 0.75, 0.4), 0.7)
	var body := pivot(root, "body", Vector3.ZERO)
	for i in 6:
		var r := 0.32 - i * 0.03
		part(body, sphere(r), skin, Vector3(sin(i * 0.9) * 0.15, 0.3 + i * 0.28, 0.15 - i * 0.02))
	var head := pivot(body, "head", Vector3(0, 1.95, -0.05))
	part(head, sphere(0.24), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.8, 1.3))
	part(head, box(0.3, 0.06, 0.3), belly, Vector3(0, -0.12, -0.15))
	for s in [-1, 1]:
		part(head, sphere(0.04), glow(Color(1, 0.9, 0.2), 6.0), Vector3(s * 0.12, 0.08, -0.22))
		part(head, cyl(0.0, 0.025, 0.14), mat(Color(0.95, 0.95, 0.9), 0.4), Vector3(s * 0.08, -0.18, -0.3), Vector3(180, 0, 0))
		pivot(body, "arm_l" if s < 0 else "arm_r", Vector3.ZERO)
	return root


static func lich() -> Node3D:
	var root := Node3D.new()
	var bone := mat(Color(0.55, 0.55, 0.6), 0.35, 0.8)
	var body := pivot(root, "body", Vector3(0, 1.1, 0))
	var head := pivot(body, "head", Vector3.ZERO)
	part(head, sphere(0.85, 24), bone, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1))
	part(head, box(0.9, 0.3, 0.5), bone, Vector3(0, -0.65, -0.35))
	part(head, torus(0.8, 0.95), mat(Color(0.5, 0.35, 0.15), 0.3, 1.0), Vector3(0, 0.15, 0), Vector3(90, 0, 0), Vector3(1, 1, 0.3))
	for s in [-1, 1]:
		part(head, sphere(0.18), glow(Color(0.4, 0.9, 1.0), 8.0), Vector3(s * 0.3, 0.1, -0.72))
	for i in 8:
		var a := TAU * i / 8.0
		part(head, cyl(0.0, 0.08, 0.5), bone, Vector3(cos(a) * 0.8, 0.45, sin(a) * 0.8), Vector3(sin(a) * 40, 0, -cos(a) * 40))
	return root


# --- Weapons (first person, pointing down -Z) --------------------------------

## Typical sizes (meters) used to fit replacement models.
const WEAPON_LENGTH := {"staff": 0.9, "gauntlets": 0.4, "wand": 0.6, "crossbow": 0.6, "claw": 0.45,
	"hellstaff": 0.75, "phoenix": 0.62, "mace": 0.56}
const DECOR_HEIGHT := {"wall_torch": 0.7, "serpent_torch": 1.9, "brazier": 1.3, "chandelier": 1.2,
	"volcano": 1.5, "pillar_small": 2.6, "pillar_brown": 2.6, "stalagmite": 1.2, "stalagmite_big": 2.4,
	"key_statue_blue": 1.6, "key_statue_green": 1.6, "key_statue_yellow": 1.6}
const FIRE_DECOR := ["wall_torch", "serpent_torch", "brazier", "volcano"]


static func weapon(name: String) -> Node3D:
	var root := Node3D.new()
	var custom := AssetOverrides.model("weapons", [name], WEAPON_LENGTH.get(name, 0.55), "length")
	if custom != null:
		root.add_child(custom)
		var marker := Marker3D.new()
		marker.name = "muzzle"
		marker.position = Vector3(0, 0, -(custom.get_meta("size") as Vector3).z)
		root.add_child(marker)
		root.set_meta("custom", custom)
		return root
	var wood := mat(Color(0.35, 0.22, 0.12), 0.8)
	var gold := mat(Color(0.85, 0.65, 0.25), 0.3, 1.0)
	var iron := mat(Color(0.35, 0.34, 0.36), 0.4, 0.9)
	var muzzle := Vector3(0, 0, -0.55)
	match name:
		"staff":
			part(root, cyl(0.022, 0.026, 0.9), wood, Vector3(0, -0.05, -0.25), Vector3(-80, 0, 0))
			part(root, cyl(0.03, 0.03, 0.06), iron, Vector3(0, 0.03, -0.68), Vector3(-80, 0, 0))
			muzzle = Vector3(0, 0.05, -0.7)
		"gauntlets":
			part(root, box(0.11, 0.09, 0.22), iron, Vector3(0, 0, -0.2))
			for i in 4:
				part(root, box(0.02, 0.02, 0.1), iron, Vector3(-0.04 + i * 0.027, 0.02, -0.36))
			part(root, gem(0.03), glow(Color(0.4, 1.0, 0.5), 4.0), Vector3(0, 0.06, -0.2))
			muzzle = Vector3(0, 0, -0.42)
		"wand":
			part(root, cyl(0.016, 0.022, 0.38), gold, Vector3(0, 0, -0.2), Vector3(-90, 0, 0))
			part(root, cyl(0.03, 0.02, 0.04), gold, Vector3(0, 0, -0.39), Vector3(-90, 0, 0))
			part(root, gem(0.035), glow(Color(1.0, 0.85, 0.35), 5.0), Vector3(0, 0, -0.44), Vector3(-90, 0, 0))
			muzzle = Vector3(0, 0, -0.48)
		"crossbow":
			part(root, box(0.07, 0.07, 0.5), wood, Vector3(0, -0.02, -0.25))
			for s in [-1, 1]:
				part(root, box(0.3, 0.025, 0.04), mat(Color(0.2, 0.5, 0.3), 0.4, 0.5), Vector3(s * 0.15, 0.02, -0.45), Vector3(0, s * 18, 0))
			part(root, cyl(0.008, 0.008, 0.45), glow(Color(0.4, 1.0, 0.55), 4.0), Vector3(0, 0.03, -0.32), Vector3(-90, 0, 0))
			part(root, gem(0.03), glow(Color(0.4, 1.0, 0.55), 5.0), Vector3(0, 0.05, -0.55), Vector3(-90, 0, 0))
			muzzle = Vector3(0, 0.04, -0.58)
		"claw":
			part(root, cyl(0.05, 0.06, 0.25), mat(Color(0.25, 0.3, 0.5), 0.35, 0.8), Vector3(0, 0, -0.18), Vector3(-90, 0, 0))
			part(root, sphere(0.05), glow(Color(0.4, 0.6, 1.0), 5.0), Vector3(0, 0, -0.33))
			for i in 3:
				var a := TAU * i / 3.0
				part(root, box(0.02, 0.02, 0.18), mat(Color(0.75, 0.8, 0.95), 0.25, 1.0),
					Vector3(cos(a) * 0.05, sin(a) * 0.05, -0.38), Vector3(sin(a) * 15, -cos(a) * 15, 0))
			muzzle = Vector3(0, 0, -0.45)
		"hellstaff":
			part(root, cyl(0.02, 0.025, 0.8), mat(Color(0.12, 0.1, 0.1), 0.6), Vector3(0, -0.03, -0.25), Vector3(-82, 0, 0))
			part(root, sphere(0.07), mat(Color(0.85, 0.82, 0.75), 0.6), Vector3(0, 0.03, -0.62))
			for s in [-1, 1]:
				part(root, sphere(0.015), glow(Color(1.0, 0.2, 0.2), 6.0), Vector3(s * 0.025, 0.04, -0.685))
			muzzle = Vector3(0, 0.03, -0.7)
		"phoenix":
			part(root, cyl(0.02, 0.028, 0.55), gold, Vector3(0, 0, -0.25), Vector3(-90, 0, 0))
			part(root, gem(0.06), glow(Color(1.0, 0.5, 0.12), 5.0), Vector3(0, 0, -0.56), Vector3(-90, 0, 0))
			for s in [-1, 1]:
				part(root, box(0.16, 0.015, 0.06), gold, Vector3(s * 0.08, 0.02, -0.5), Vector3(0, 0, s * 20))
			muzzle = Vector3(0, 0, -0.62)
		"mace":
			part(root, cyl(0.03, 0.035, 0.45), iron, Vector3(0, 0, -0.22), Vector3(-90, 0, 0))
			part(root, sphere(0.08), iron, Vector3(0, 0, -0.47))
			for i in 6:
				var a := TAU * i / 6.0
				part(root, sphere(0.022), glow(Color(0.85, 0.85, 1.0), 2.0), Vector3(cos(a) * 0.08, sin(a) * 0.08, -0.47))
			muzzle = Vector3(0, 0, -0.56)
	var m := Marker3D.new()
	m.name = "muzzle"
	m.position = muzzle
	root.add_child(m)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


# --- Pickups -----------------------------------------------------------------

static func pickup(kind: String) -> Node3D:
	var root := Node3D.new()
	var item_size := 0.6 if kind.begins_with("weapon") else 0.45
	var custom := AssetOverrides.model("items", [kind], item_size)
	if custom != null:
		root.add_child(custom)
		return root
	var item: Dictionary = GameData.ITEMS.get(kind, {})
	if item.has("weapon"):
		var w := weapon(item.weapon)
		w.rotation_degrees = Vector3(0, 90, 20)
		w.scale = Vector3.ONE * 1.6
		w.position = Vector3(0, 0.2, 0)
		root.add_child(w)
		return root
	if item.has("ammo"):
		var c: Color = GameData.AMMO_COLOR[item.ammo]
		var n := 1 if int(item.amount) < 20 else 3
		for i in n:
			part(root, gem(0.08 + 0.02 * n), glow(c, 1.2), Vector3((i - (n - 1) * 0.5) * 0.18, 0.12, 0))
		return root
	match kind:
		"vial":
			part(root, sphere(0.1), mat(Color(0.3, 0.5, 1.0), 0.1, 0.0, Color(0.2, 0.4, 1.0), 1.5, 0.75), Vector3(0, 0.1, 0))
			part(root, cyl(0.03, 0.04, 0.1), mat(Color(0.8, 0.8, 0.9), 0.1, 0.0, Color(0, 0, 0), 0.0, 0.6), Vector3(0, 0.24, 0))
		"flask":
			part(root, sphere(0.14), mat(Color(0.9, 0.2, 0.3), 0.1, 0.0, Color(0.8, 0.1, 0.25), 2.0, 0.8), Vector3(0, 0.15, 0))
			part(root, cyl(0.04, 0.05, 0.14), mat(Color(0.8, 0.8, 0.9), 0.1, 0.0, Color(0, 0, 0), 0.0, 0.6), Vector3(0, 0.34, 0))
		"urn":
			part(root, cyl(0.1, 0.16, 0.35), mat(Color(0.85, 0.65, 0.25), 0.25, 1.0), Vector3(0, 0.18, 0))
			part(root, sphere(0.08), glow(Color(1.0, 0.3, 0.3), 3.0), Vector3(0, 0.4, 0))
		"shield_silver", "shield_enchanted":
			var c := Color(0.8, 0.82, 0.85) if kind == "shield_silver" else Color(0.4, 0.9, 0.6)
			part(root, cyl(0.3, 0.3, 0.05, 20), mat(c, 0.25, 1.0), Vector3(0, 0.3, 0), Vector3(90, 0, 0))
			part(root, gem(0.07), glow(Color(1.0, 0.3, 0.2) if kind == "shield_silver" else Color(0.4, 1.0, 0.6), 3.0), Vector3(0, 0.3, -0.04), Vector3(90, 0, 0))
		"bag":
			part(root, sphere(0.22), mat(Color(0.5, 0.35, 0.2), 0.9), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
			part(root, cyl(0.05, 0.1, 0.12), mat(Color(0.5, 0.35, 0.2), 0.9), Vector3(0, 0.42, 0))
		"key_green", "key_blue", "key_yellow":
			var c: Color = {"key_green": Color(0.2, 1.0, 0.35), "key_blue": Color(0.3, 0.5, 1.0), "key_yellow": Color(1.0, 0.85, 0.2)}[kind]
			part(root, torus(0.06, 0.11), glow(c, 3.0), Vector3(0, 0.45, 0), Vector3(90, 0, 0))
			part(root, cyl(0.025, 0.025, 0.35), glow(c, 3.0), Vector3(0, 0.2, 0))
			part(root, box(0.1, 0.06, 0.03), glow(c, 3.0), Vector3(0.05, 0.06, 0))
			var l := OmniLight3D.new()
			l.light_color = c
			l.omni_range = 3.0
			l.light_energy = 1.5
			l.position.y = 0.4
			root.add_child(l)
		"tome":
			part(root, box(0.35, 0.1, 0.45), mat(Color(0.55, 0.08, 0.08), 0.7), Vector3(0, 0.15, 0))
			part(root, box(0.33, 0.08, 0.43), mat(Color(0.9, 0.85, 0.7), 0.9), Vector3(0.015, 0.15, 0))
			part(root, gem(0.05), glow(Color(1.0, 0.8, 0.3), 4.0), Vector3(0, 0.21, 0))
		"wings":
			for s in [-1, 1]:
				part(root, box(0.4, 0.03, 0.2), mat(Color(0.9, 0.75, 0.3), 0.3, 0.8, Color(1, 0.8, 0.3), 1.0), Vector3(s * 0.2, 0.3, 0), Vector3(0, 0, s * 25))
		"ring":
			part(root, torus(0.12, 0.17), mat(Color(0.95, 0.8, 0.3), 0.2, 1.0), Vector3(0, 0.3, 0), Vector3(90, 0, 0))
			part(root, gem(0.06), glow(Color(0.4, 0.8, 1.0), 4.0), Vector3(0, 0.45, 0))
		"shadow":
			part(root, sphere(0.2), mat(Color(0.2, 0.15, 0.3), 0.1, 0.0, Color(0.4, 0.2, 0.8), 1.5, 0.55), Vector3(0, 0.3, 0))
		"torch":
			part(root, cyl(0.03, 0.04, 0.4), mat(Color(0.35, 0.22, 0.12)), Vector3(0, 0.2, 0))
			Effects.fire(root, Vector3(0, 0.45, 0), 0.5)
		"bomb":
			part(root, sphere(0.16), mat(Color(0.15, 0.13, 0.12), 0.5, 0.6), Vector3(0, 0.18, 0))
			part(root, cyl(0.01, 0.01, 0.12), glow(Color(1.0, 0.6, 0.2), 4.0), Vector3(0, 0.38, 0))
		"chaos":
			part(root, box(0.25, 0.25, 0.25), mat(Color(0.35, 0.15, 0.45), 0.4, 0.5, Color(0.5, 0.2, 0.8), 1.5), Vector3(0, 0.25, 0), Vector3(45, 45, 0))
		_:
			part(root, gem(0.12), glow(Color(1, 1, 1), 2.0), Vector3(0, 0.2, 0))
	return root


# --- Decorations ---------------------------------------------------------

static func decoration(kind: String) -> Node3D:
	var root := Node3D.new()
	var h: float = DECOR_HEIGHT.get(kind, 1.5)
	var custom := AssetOverrides.model("decor", [kind], h)
	if custom != null:
		root.add_child(custom)
		if kind == "chandelier":
			custom.position.y = -h   # hangs from the ceiling
		elif kind in FIRE_DECOR:
			Effects.fire(root, Vector3(0, h, 0), 1.0)
		return root
	var iron := mat(Color(0.25, 0.24, 0.24), 0.5, 0.8)
	var stone := mat(Color(0.42, 0.4, 0.36), 0.9)
	match kind:
		"wall_torch":
			part(root, cyl(0.03, 0.02, 0.4), mat(Color(0.35, 0.22, 0.12)), Vector3(0, 1.6, 0))
			part(root, cyl(0.07, 0.04, 0.1), iron, Vector3(0, 1.82, 0))
			Effects.fire(root, Vector3(0, 1.9, 0), 0.8)
		"serpent_torch":
			part(root, cyl(0.05, 0.08, 1.6), mat(Color(0.3, 0.45, 0.3), 0.4, 0.6), Vector3(0, 0.8, 0))
			part(root, cyl(0.22, 0.08, 0.18), iron, Vector3(0, 1.66, 0))
			Effects.fire(root, Vector3(0, 1.8, 0), 1.0)
		"brazier":
			part(root, cyl(0.06, 0.12, 0.9), iron, Vector3(0, 0.45, 0))
			part(root, cyl(0.4, 0.2, 0.3), iron, Vector3(0, 1.0, 0))
			part(root, cyl(0.36, 0.36, 0.05), glow(Color(1.0, 0.4, 0.1), 3.0), Vector3(0, 1.13, 0))
			Effects.fire(root, Vector3(0, 1.2, 0), 1.6)
		"chandelier":
			part(root, cyl(0.01, 0.01, 1.0), iron, Vector3(0, -0.5, 0))
			part(root, torus(0.55, 0.65), iron, Vector3(0, -1.0, 0))
			for i in 6:
				var a := TAU * i / 6.0
				var at := Vector3(cos(a) * 0.6, -0.92, sin(a) * 0.6)
				part(root, cyl(0.03, 0.03, 0.14), mat(Color(0.9, 0.88, 0.8)), at)
				Effects.fire(root, at + Vector3(0, 0.1, 0), 0.35)
		"volcano":
			part(root, cyl(0.3, 1.0, 1.4), mat(Color(0.2, 0.15, 0.12), 0.95), Vector3(0, 0.7, 0))
			part(root, cyl(0.28, 0.28, 0.05), glow(Color(1.0, 0.3, 0.05), 4.0), Vector3(0, 1.41, 0))
			Effects.fire(root, Vector3(0, 1.5, 0), 1.5, Color(1.0, 0.3, 0.05))
		"pillar_small", "pillar_brown":
			part(root, cyl(0.4, 0.45, 2.6), stone, Vector3(0, 1.3, 0))
		"stalagmite", "stalagmite_big":
			var big := kind == "stalagmite_big"
			part(root, cyl(0.02, 0.5 if big else 0.3, 2.4 if big else 1.2), stone, Vector3(0, 1.2 if big else 0.6, 0))
		"key_statue_blue", "key_statue_green", "key_statue_yellow":
			var c: Color = {"key_statue_blue": Color(0.3, 0.5, 1.0), "key_statue_green": Color(0.3, 1.0, 0.4), "key_statue_yellow": Color(1.0, 0.85, 0.3)}[kind]
			part(root, cyl(0.35, 0.45, 1.0), stone, Vector3(0, 0.5, 0))
			part(root, gem(0.18), glow(c, 4.0), Vector3(0, 1.35, 0))
	return root
