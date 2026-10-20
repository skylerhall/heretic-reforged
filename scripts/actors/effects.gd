class_name Effects
## One-shot particle bursts and light flashes. CPU particles are used so
## everything also runs on the web (Compatibility) renderer.

static var _materials := {}
static var _quad: QuadMesh


static func _mat(additive: bool) -> StandardMaterial3D:
	var key := "add" if additive else "mix"
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _soft_dot()
		_materials[key] = m
	return _materials[key]


static func _soft_dot() -> Texture2D:
	if _materials.has("dot"):
		return _materials["dot"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	var t := ImageTexture.create_from_image(img)
	_materials["dot"] = t
	return t


static func _mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(1, 1)
	return _quad


## Generic burst. Frees itself when done.
static func burst(at: Vector3, color: Color, amount: int, speed: float, life: float, size: float,
		gravity := 0.0, additive := true, dir := Vector3.UP, spread := 180.0) -> CPUParticles3D:
	var w = Game.world
	if w == null or not is_instance_valid(w):
		return null
	var p := CPUParticles3D.new()
	var mi := _mesh()
	p.mesh = mi
	p.material_override = _mat(additive)
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	w.add_child(p)
	p.global_position = at
	p.emitting = true
	w.get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)
	return p


static func flash(at: Vector3, color: Color, energy: float, light_range: float, time: float) -> void:
	var w = Game.world
	if w == null or not is_instance_valid(w):
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	w.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time)
	tw.tween_callback(l.queue_free)


static func puff(at: Vector3, normal: Vector3, color := Color(1.0, 0.85, 0.5)) -> void:
	burst(at + normal * 0.05, color, 10, 3.0, 0.35, 0.12, 4.0, true, normal, 60.0)


static func blood(at: Vector3, color := Color(0.6, 0.05, 0.03)) -> void:
	burst(at, color, 14, 3.5, 0.6, 0.14, 9.0, false, Vector3.UP, 90.0)


static func explosion(at: Vector3, color: Color, radius: float) -> void:
	burst(at, color.lightened(0.3), 28, radius * 3.0, 0.55, radius * 0.6, 1.0, true)
	burst(at, Color(0.15, 0.12, 0.1, 0.7), 12, radius * 1.2, 1.1, radius * 0.9, -1.0, false)
	flash(at, color, 6.0, radius * 4.0 + 3.0, 0.4)


static func teleport_flash(at: Vector3) -> void:
	burst(at + Vector3(0, 1.0, 0), Color(0.5, 1.0, 0.7), 40, 3.0, 0.9, 0.25, -2.0, true)
	flash(at + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.6), 4.0, 8.0, 0.7)


## Continuous flame for torches and braziers.
static func fire(parent: Node3D, offset: Vector3, scale_m := 1.0, color := Color(1.0, 0.55, 0.15)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mesh()
	p.material_override = _mat(true)
	p.amount = 18 if Game.quality >= Game.Quality.HIGH else 10
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.6 * scale_m
	p.initial_velocity_max = 1.4 * scale_m
	p.gravity = Vector3(0, 1.5 * scale_m, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12 * scale_m
	p.scale_amount_min = 0.25 * scale_m
	p.scale_amount_max = 0.45 * scale_m
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	g.add_point(0.4, color)
	g.set_color(g.get_point_count() - 1, Color(color.r * 0.5, 0.05, 0.02, 0.0))
	p.color_ramp = g
	p.position = offset
	parent.add_child(p)
	return p
