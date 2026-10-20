class_name Monster
extends CharacterBody3D
## Monster AI, in the spirit of the original: wake on sight (or on hearing
## a shot), chase in zig-zags, melee up close, throw projectiles from range,
## flinch when hurt.

enum State { IDLE, CHASE, ATTACK, PAIN, DEAD }

const GRAVITY := 22.0
const STEP := 24.0 * Layers.S

var kind := ""
var def: Dictionary
var health := 100.0
var height := 2.0
var radius := 0.5
var dead := false
var state: State = State.IDLE
var ambush := false
var target: Player
var model: Node3D

var _parts := {}
var _state_t := 0.0
var _think := 0.0
var _dir := Vector3.FORWARD
var _dir_t := 0.0
var _cooldown := 1.0
var _attack_kind := ""
var _attacked := false
var _burst_left := 0
var _anim := 0.0
var _phase := 0.0
var _knock := Vector3.ZERO
var _stuck_t := 0.0
var _heard := false
var _flinch := 0.0


func setup(k: String, is_ambush: bool) -> void:
	kind = k
	def = MonsterDefs.get_def(k)
	ambush = is_ambush
	health = float(def.hp) * (0.75 if Game.skill == 0 else 1.0)
	height = def.height
	radius = def.radius
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD | Layers.MONSTER_BLOCK | Layers.PLAYER | Layers.MONSTER
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position.y = height * 0.5
	add_child(cs)
	model = Models.monster(def.model, def)
	add_child(model)
	for n in ["body", "head", "arm_l", "arm_r", "leg_l", "leg_r", "wing_l", "wing_r"]:
		var f := model.find_child(n, true, false)
		if f != null:
			_parts[n] = f
	add_to_group("monsters")
	add_to_group("damageable")
	add_to_group("actors")
	floor_snap_length = 0.3
	_phase = randf() * TAU
	_think = randf() * 0.3


func _physics_process(dt: float) -> void:
	if dead:
		_death_update(dt)
		return
	_state_t += dt
	_cooldown -= dt
	_anim += dt
	_flinch = move_toward(_flinch, 0.0, dt * 4.0)
	var p: Player = Game.world.player if Game.world != null else null
	if target != null and (not is_instance_valid(target) or target.dead):
		target = null
		state = State.IDLE
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * dt)
			_think -= dt
			if _think <= 0.0:
				_think = 0.25
				if p != null and _can_see(p, not (ambush or _heard)):
					_wake(p)
		State.CHASE:
			_chase(dt)
		State.ATTACK:
			_attack_update(dt)
		State.PAIN:
			velocity.x = 0.0
			velocity.z = 0.0
			if _state_t > 0.35:
				state = State.CHASE if target != null else State.IDLE

	if def.get("fly", false):
		var want := global_position.y
		if target != null:
			want = target.global_position.y + 1.0 + sin(_anim * 1.7 + _phase) * 0.6
		velocity.y = clampf((want - global_position.y) * 2.0, -def.speed, def.speed)
	elif not is_on_floor():
		velocity.y -= GRAVITY * dt
	velocity += _knock
	var start := global_position
	if def.get("fly", false):
		move_and_slide()
	else:
		Motion.move(self, STEP)
	velocity -= _knock
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * dt)
	_track_stuck(start, dt)
	_animate(dt)


func _can_see(p: Player, use_fov: bool) -> bool:
	if p.dead:
		return false
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	if dist > 70.0:
		return false
	if p.invis > 0.0 and dist > 6.0 and randf() < 0.85:
		return false
	if use_fov and dist > 3.0:
		var fwd := -global_basis.z
		if fwd.dot(Vector3(to_p.x, 0, to_p.z).normalized()) < -0.2:
			return false
	return _has_los(p)


func _has_los(p: Player) -> bool:
	var from := global_position + Vector3(0, height * 0.8, 0)
	var to := p.global_position + Vector3(0, 1.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _wake(p: Player) -> void:
	target = p
	state = State.CHASE
	_cooldown = randf_range(0.4, 1.2)
	Sfx.play(def.sound, global_position)


## Gunfire is heard nearby; ambushers still wait until they see you.
func hear(at: Vector3) -> void:
	if dead or state != State.IDLE:
		return
	if global_position.distance_to(at) < 28.0:
		_heard = true
		if not ambush and Game.world.player != null:
			_wake(Game.world.player)


func _chase(dt: float) -> void:
	if target == null:
		state = State.IDLE
		return
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	_face(to_p, dt)
	if _cooldown <= 0.0:
		var reach := radius + 1.3
		if def.has("melee") and dist < reach:
			_begin_attack("melee")
			return
		if def.has("proj") and dist < 45.0 and dist > 2.0 and randf() < float(def.rate) * dt * 1.5 and _has_los(target):
			_begin_attack("proj")
			return
	_dir_t -= dt
	if _dir_t <= 0.0 or _stuck_t > 0.25:
		_stuck_t = 0.0
		_dir_t = randf_range(0.5, 1.3)
		var base := to_p.normalized() if dist > 0.01 else -global_basis.z
		if randf() < 0.7:
			_dir = base.rotated(Vector3.UP, randf_range(-0.4, 0.4))
		else:
			_dir = base.rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
	var spd: float = def.speed
	if dist < radius + 0.9:
		spd = 0.0
	velocity.x = _dir.x * spd
	velocity.z = _dir.z * spd


func _begin_attack(k: String) -> void:
	state = State.ATTACK
	_state_t = 0.0
	_attack_kind = k
	_attacked = false
	_burst_left = def.get("burst", 1) if k == "proj" else 1
	velocity.x = 0.0
	velocity.z = 0.0


func _attack_update(dt: float) -> void:
	if target == null:
		state = State.IDLE
		return
	var to_p := target.global_position - global_position
	_face(Vector3(to_p.x, 0, to_p.z), dt * 2.0)
	var windup := 0.35 if _attack_kind == "melee" else 0.5
	if not _attacked and _state_t >= windup:
		_attacked = true
		if _attack_kind == "melee":
			Sfx.play("monster_swing", global_position)
			if Vector2(to_p.x, to_p.z).length() < radius + 1.8 and absf(to_p.y) < height:
				var m: Array = def.melee
				target.take_damage(randi_range(m[0], m[1]), self)
		else:
			_fire()
			_burst_left -= 1
			if _burst_left > 0:
				_attacked = false
				_state_t = windup - 0.2
	if _state_t >= windup + 0.45:
		state = State.CHASE
		_cooldown = randf_range(0.5, 1.6)


func _fire() -> void:
	var fwd := -global_basis.z
	var origin := global_position + Vector3(0, height * 0.65, 0) + fwd * (radius + 0.2)
	var aim := target.global_position + Vector3(0, 1.0, 0)
	if target is Player and target.invis > 0.0:
		aim += Vector3(randf_range(-2, 2), randf_range(-0.5, 0.5), randf_range(-2, 2))
	var n: int = def.get("spread", 1)
	var dir := (aim - origin).normalized()
	for i in n:
		var yaw := deg_to_rad((i - (n - 1) * 0.5) * 7.0)
		Projectile.spawn(def.proj, origin, dir.rotated(Vector3.UP, yaw), self)
	Sfx.play("monster_shoot", origin, -2.0)


func _face(dir: Vector3, dt: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(8.0 * dt, 0.0, 1.0))


func _track_stuck(start: Vector3, dt: float) -> void:
	if state != State.CHASE:
		return
	var expected := Vector2(velocity.x, velocity.z).length() * dt
	if expected < 0.001:
		return
	var moved := Vector2(global_position.x - start.x, global_position.z - start.z).length()
	if moved < expected * 0.3:
		_stuck_t += dt
	else:
		_stuck_t = maxf(_stuck_t - dt, 0.0)


func take_damage(amount: float, source: Node3D = null, at = null, push := Vector3.ZERO) -> void:
	if dead:
		return
	health -= amount
	var where: Vector3 = at if at is Vector3 else global_position + Vector3(0, height * 0.6, 0)
	Effects.blood(where, Color(0.55, 0.6, 0.65) if def.get("ghost", false) else Color(0.55, 0.04, 0.03))
	_knock += push / maxf(float(def.hp) / 100.0, 1.0)
	_flinch = 1.0
	if source is Player and target == null:
		_wake(source)
	if health <= 0.0:
		_die()
		return
	if randf() < float(def.painchance) and state != State.PAIN:
		state = State.PAIN
		_state_t = 0.0
		Sfx.play("monster_pain", global_position)


func _die() -> void:
	dead = true
	state = State.DEAD
	_state_t = 0.0
	collision_layer = 0
	collision_mask = Layers.WORLD
	remove_from_group("monsters")
	remove_from_group("damageable")
	remove_from_group("actors")
	Game.world.kills += 1
	Sfx.play("monster_death", global_position)
	Effects.blood(global_position + Vector3(0, height * 0.5, 0))
	velocity = Vector3(velocity.x * 0.3, 0.0, velocity.z * 0.3)
	var drop: String = def.get("drop", "")
	if drop != "" and randf() < 0.6:
		var item := Pickup.new()
		Game.world.add_child(item)
		item.setup(drop)
		item.global_position = global_position + Vector3(0, 0.1, 0)
	if def.get("boss", false):
		Game.world.player.show_message("THE BEAST IS SLAIN!")


func _death_update(dt: float) -> void:
	_state_t += dt
	var t := clampf(_state_t * 2.5, 0.0, 1.0)
	model.rotation.x = lerpf(0.0, PI * 0.5, t * t)
	model.position.y = -0.1 * t
	if not is_on_floor():
		velocity.y -= GRAVITY * dt
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
	move_and_slide()
	if _state_t > 3.0 and is_on_floor():
		set_physics_process(false)


func _animate(_dt: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	var walk := sin(_anim * (5.0 + spd * 1.2) + _phase)
	var amt := clampf(spd / 3.0, 0.0, 1.0)
	if _parts.has("leg_l"):
		_parts.leg_l.rotation.x = walk * 0.6 * amt
		_parts.leg_r.rotation.x = -walk * 0.6 * amt
	var arm_r := -walk * 0.4 * amt
	if state == State.ATTACK:
		var windup := 0.35 if _attack_kind == "melee" else 0.5
		var k := _state_t / windup
		arm_r = lerpf(0.0, -2.4, clampf(k, 0.0, 1.0)) if k < 1.0 else lerpf(-2.4, 0.7, clampf((k - 1.0) * 4.0, 0.0, 1.0))
	if _parts.has("arm_l"):
		_parts.arm_l.rotation.x = walk * 0.4 * amt if state != State.ATTACK else arm_r * 0.5
		_parts.arm_r.rotation.x = arm_r
	if _parts.has("wing_l"):
		var flap := sin(_anim * 13.0 + _phase) * 0.75
		_parts.wing_l.rotation.z = flap
		_parts.wing_r.rotation.z = -flap
	if _parts.has("body"):
		_parts.body.rotation.z = sin(_anim * 1.3 + _phase) * 0.04
		_parts.body.position.x = sin(_anim * 40.0) * 0.03 * _flinch
	if def.get("fly", false):
		model.position.y = sin(_anim * 3.0 + _phase) * 0.1
	if def.get("blink", false):
		model.visible = not (state == State.PAIN and int(_anim * 14.0) % 2 == 0)
