class_name Weapons
extends Node3D
## First-person weapons: switching, firing, view bob, recoil and muzzle light.

# Models are drawn at half size, half as far away: same look on screen, but
# long weapons stay inside the player's collision radius instead of
# poking through walls.
const REST := Vector3(0.1, -0.1, -0.16)
const VIEW_SCALE := 0.5

var player: Player
var current := "wand"
var pending := ""
var cooldown := 0.0
var lower := 1.0     # 0 = raised and ready, 1 = fully lowered
var kick := 0.0
var _models := {}
var _model: Node3D
var _flash: OmniLight3D
var _sway := Vector2.ZERO


func setup(p: Player, start: String) -> void:
	player = p
	current = start if p.weapons.get(start, false) else "wand"
	_flash = OmniLight3D.new()
	_flash.omni_range = 7.0
	_flash.light_energy = 0.0
	_flash.position = Vector3(0, 0, -0.8)
	add_child(_flash)
	_show(current)


func _show(name: String) -> void:
	if _model != null:
		_model.visible = false
	if not _models.has(name):
		var m := Models.weapon(name)
		m.scale = Vector3.ONE * VIEW_SCALE
		add_child(m)
		_models[name] = m
	_model = _models[name]
	_model.visible = true


func on_new_weapon(name: String) -> void:
	# Like the original, grabbing a new weapon switches to it.
	if GameData.WEAPON_ORDER.find(name) > GameData.WEAPON_ORDER.find(current):
		select(name)


func select(name: String) -> void:
	if player.weapons.get(name, false) and name != current:
		pending = name


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.dead:
		return
	if event.is_action_pressed("weapon_next"):
		_cycle(1)
	elif event.is_action_pressed("weapon_prev"):
		_cycle(-1)
	else:
		for slot in range(1, 8):
			if event.is_action_pressed("weapon_%d" % slot):
				var options := []
				for w in GameData.WEAPON_ORDER:
					if GameData.WEAPON_SLOT[w] == slot and player.weapons.get(w, false):
						options.append(w)
				if options.is_empty():
					return
				var i := options.find(current)
				select(options[(i + 1) % options.size()])
				return


func _cycle(d: int) -> void:
	var order: Array = GameData.WEAPON_ORDER
	var i := order.find(pending if pending != "" else current)
	for k in order.size():
		i = posmod(i + d, order.size())
		var w: String = order[i]
		if player.weapons.get(w, false) and _has_ammo(w):
			select(w)
			return


func _has_ammo(w: String) -> bool:
	var d := GameData.weapon(w, player.powered > 0.0)
	return d.ammo == "" or player.ammo[d.ammo] >= float(d.get("use", 1))


func _best_weapon() -> String:
	var order: Array = GameData.WEAPON_ORDER
	for i in range(order.size() - 1, -1, -1):
		var w: String = order[i]
		if w != "phoenix" and player.weapons.get(w, false) and _has_ammo(w):
			return w
	return "staff"


func _process(dt: float) -> void:
	if player == null:
		return
	cooldown -= dt
	kick = move_toward(kick, 0.0, dt * 5.0)
	_flash.light_energy = move_toward(_flash.light_energy, 0.0, dt * 30.0)

	if pending != "":
		lower = move_toward(lower, 1.0, dt * 6.0)
		if lower >= 1.0:
			current = pending
			pending = ""
			_show(current)
	else:
		lower = move_toward(lower, 0.0, dt * 6.0)

	var firing := Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if firing and pending == "" and lower < 0.05 and cooldown <= 0.0 and not player.dead:
		if _has_ammo(current):
			_fire()
		else:
			select(_best_weapon())

	# sway with movement and mouse look
	var v := player.velocity
	var speed := Vector2(v.x, v.z).length()
	var t := Time.get_ticks_msec() / 1000.0
	var bob := Vector3(cos(t * 6.0) * 0.006, absf(sin(t * 6.0)) * 0.007, 0.0) * clampf(speed / Player.RUN, 0.0, 1.0)
	if not player.is_on_floor():
		bob = Vector3.ZERO
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * dt))
	var powered_shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.001 if player.powered > 0.0 else Vector3.ZERO
	_model.position = REST + bob + powered_shake + Vector3(_sway.x, _sway.y - lower * 0.22, kick * 0.035)
	_model.rotation = Vector3(kick * 0.12, 0.0, 0.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_sway -= Vector2(event.relative.x, -event.relative.y) * 0.00008


func _fire() -> void:
	var d := GameData.weapon(current, player.powered > 0.0)
	if d.ammo != "":
		player.ammo[d.ammo] = maxf(player.ammo[d.ammo] - float(d.get("use", 1)), 0.0)
	cooldown = d.rate
	kick = 1.0
	Sfx.play(d.sound, null, -3.0)
	var color: Color = d.get("color", Color(1, 0.8, 0.5))
	if float(d.get("flash", 0.0)) > 0.0:
		_flash.light_color = color
		_flash.light_energy = d.flash
	Game.world.noise_alert(player.global_position)

	var cam := player.camera
	var origin := cam.global_position
	var fwd := -cam.global_basis.z
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	match d.kind:
		"melee":
			_melee(d, origin, fwd)
		"hitscan":
			for i in int(d.get("count", 1)):
				var s: float = d.spread
				var dir := (fwd + right * randf_range(-s, s) + up * randf_range(-s, s) * 0.6).normalized()
				_hitscan(d, origin, dir, 64.0)
		"projectile":
			var muzzle: Node3D = _model.get_node("muzzle")
			var start := muzzle.global_position.lerp(origin + fwd * 0.4, 0.5)
			var s: float = d.get("spread", 0.0)
			for shot in d.shots:
				var dir := fwd.rotated(up, deg_to_rad(shot[1]))
				dir = (dir + right * randf_range(-s, s) + up * randf_range(-s, s)).normalized()
				Projectile.spawn(shot[0], start, dir, player)


func _ray(origin: Vector3, dir: Vector3, dist: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * dist, Layers.WORLD | Layers.MONSTER)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)


func _hitscan(d: Dictionary, origin: Vector3, dir: Vector3, dist: float) -> void:
	var hit := _ray(origin, dir, dist)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col.has_method("take_damage"):
		col.take_damage(randi_range(d.dmin, d.dmax), player, hit.position, dir * 1.5)
	else:
		Effects.puff(hit.position, hit.normal, d.get("color", Color(1, 0.85, 0.5)))


func _melee(d: Dictionary, origin: Vector3, dir: Vector3) -> void:
	var hit := _ray(origin, dir, d.range)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col.has_method("take_damage"):
		var dmg := randi_range(d.dmin, d.dmax)
		col.take_damage(dmg, player, hit.position, dir * float(d.get("knockback", 2.0)))
		Sfx.play("staff_hit", hit.position)
		if d.get("drain", false):
			player.health = minf(player.health + dmg * 0.5, 100.0)
		if d.has("color"):
			Effects.burst(hit.position, d.color, 16, 4.0, 0.3, 0.15)
	else:
		Effects.puff(hit.position, hit.normal, Color(0.8, 0.7, 0.6))
		Sfx.play("hit", hit.position, -4.0)
