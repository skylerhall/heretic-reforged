class_name Projectile
extends Node3D
## A moving shot (bolt, fireball, mace sphere...). Collision is a ray cast
## along each step, so fast shots never tunnel through thin walls.

var data: Dictionary
var vel := Vector3.ZERO
var shooter: Node3D
var mask := Layers.WORLD
var life := 5.0
var bounces := 0
var _light: OmniLight3D
var _mesh: MeshInstance3D
var _trail: CPUParticles3D
var _age := 0.0


static func spawn(kind: String, at: Vector3, dir: Vector3, from: Node3D) -> Projectile:
	var p := Projectile.new()
	p.data = GameData.PROJECTILES[kind]
	p.shooter = from
	p.mask = Layers.WORLD | (Layers.MONSTER if from is Player else Layers.PLAYER)
	Game.world.add_child(p)
	p.global_position = at
	p._setup(dir)
	return p


func _setup(dir: Vector3) -> void:
	vel = dir.normalized() * float(data.speed)
	life = data.get("life", 5.0)
	bounces = data.get("bounces", 0)
	var color: Color = data.color
	var size: float = data.size
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	_mesh.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if data.get("spin", false):
		_mesh.scale = Vector3(1.6, 0.4, 1.0)
	add_child(_mesh)
	if data.get("light", false) and (Game.quality >= Game.Quality.HIGH or size >= 0.25):
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.light_energy = 2.0
		_light.omni_range = 3.0 + size * 10.0
		add_child(_light)
	if data.get("trail", false):
		_trail = CPUParticles3D.new()
		_trail.mesh = Effects._mesh()
		_trail.material_override = Effects._mat(true)
		_trail.amount = 16
		_trail.lifetime = 0.35
		_trail.local_coords = false
		_trail.spread = 180.0
		_trail.initial_velocity_max = 0.3
		_trail.gravity = Vector3.ZERO
		_trail.scale_amount_min = size * 1.2
		_trail.scale_amount_max = size * 2.0
		var g := Gradient.new()
		g.set_color(0, color)
		g.set_color(1, Color(color.r, color.g, color.b, 0.0))
		_trail.color_ramp = g
		add_child(_trail)


func _physics_process(dt: float) -> void:
	_age += dt
	life -= dt
	if data.has("grow"):
		_mesh.scale = Vector3.ONE * (1.0 + _age * float(data.grow))
	if data.get("spin", false):
		_mesh.rotate_object_local(Vector3.FORWARD, dt * 18.0)
	if life <= 0.0:
		_detonate(global_position, Vector3.UP, null)
		return
	var homing: float = data.get("homing", 0.0)
	if homing > 0.0:
		var target := _homing_target()
		if target != null:
			var want := (target.global_position + Vector3(0, 0.9, 0) - global_position).normalized() * vel.length()
			vel = vel.lerp(want, clampf(homing * dt, 0.0, 1.0))
	vel.y -= float(data.get("gravity", 0.0)) * dt
	var from := global_position
	var to := from + vel * dt
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	if shooter != null and is_instance_valid(shooter) and shooter is CollisionObject3D:
		q.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	var col: Object = hit.collider
	if bounces > 0 and not col.has_method("take_damage"):
		bounces -= 1
		vel = vel.bounce(hit.normal) * 0.75
		global_position = hit.position + hit.normal * 0.05
		Sfx.play("bounce", global_position, -8.0)
		return
	if data.get("fuse", false):
		vel = Vector3.ZERO
		global_position = hit.position + hit.normal * float(data.size)
		return
	_detonate(hit.position, hit.normal, col)


func _homing_target() -> Node3D:
	if shooter is Player:
		var best: Node3D = null
		var best_d := 30.0
		for m in get_tree().get_nodes_in_group("monsters"):
			if m.dead:
				continue
			var d := global_position.distance_to(m.global_position)
			if d < best_d and vel.normalized().dot((m.global_position - global_position).normalized()) > 0.3:
				best_d = d
				best = m
		return best
	var p: Player = Game.world.player
	return p if p != null and not p.dead else null


func _detonate(at: Vector3, normal: Vector3, col: Object) -> void:
	var color: Color = data.color
	if col != null and col.has_method("take_damage"):
		col.take_damage(randi_range(data.dmin, data.dmax), shooter, at)
	var splash: float = data.get("splash", 0.0)
	if splash > 0.0:
		Damage.splash(at, splash, data.get("splash_dmg", 0), shooter, col)
		Effects.explosion(at, color, splash * 0.35)
		Sfx.play("explode", at)
	else:
		Effects.puff(at, normal, color)
		Effects.flash(at, color, 2.0, 3.0, 0.15)
		Sfx.play("hit", at, -6.0)
	queue_free()
