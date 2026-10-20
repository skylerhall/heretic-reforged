class_name Player
extends CharacterBody3D
## Corvus: first-person movement, flight (Wings of Wrath), inventory,
## artifacts, damage and pickups.

signal died
signal message(text: String)

const S := Layers.S
const RADIUS := 16.0 * S
const HEIGHT := 56.0 * S
const EYE := 41.0 * S
const STEP := 24.0 * S
const RUN := 10.5
const WALK := 5.5
const JUMP := 6.0
const GRAVITY := 22.0

var height := HEIGHT
var health := 100.0
var armor := 0.0
var armor_class := 0
var ammo := {}
var max_ammo := {}
var weapons := {"staff": true, "wand": true}
var keys := {"green": false, "blue": false, "yellow": false}
var inventory := {}
var inv_sel := 0
var has_bag := false
var powered := 0.0
var flight := 0.0
var invuln := 0.0
var invis := 0.0
var torch := 0.0
var dead := false

var yaw := 0.0
var pitch := 0.0
var head: Node3D
var camera: Camera3D
var weapon_node: Weapons
var torch_light: OmniLight3D

var damage_flash := 0.0
var pickup_flash := 0.0
var _step_offset := 0.0
var _bob := 0.0
var _sector := -1
var _sector_timer := 0.0
var _fly_sound := 0.0


func setup(carry: Dictionary) -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.MONSTER
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	add_to_group("damageable")
	add_to_group("actors")
	var cs := CollisionShape3D.new()
	# A flat-bottomed cylinder (the original used boxes) steps cleanly onto
	# stairs; a capsule's round bottom would perch on step edges.
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)

	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 85.0
	camera.near = 0.03
	camera.far = 400.0
	head.add_child(camera)
	camera.make_current()

	torch_light = OmniLight3D.new()
	torch_light.light_color = Color(1.0, 0.85, 0.6)
	torch_light.omni_range = 14.0
	torch_light.light_energy = 0.0
	torch_light.position = Vector3(0, 0.2, 0)
	camera.add_child(torch_light)

	for k in GameData.AMMO_MAX:
		max_ammo[k] = GameData.AMMO_MAX[k]
		ammo[k] = 0.0
	ammo.wand = 50.0
	if not carry.is_empty():
		_restore(carry)

	weapon_node = Weapons.new()
	camera.add_child(weapon_node)
	weapon_node.setup(self, carry.get("weapon", "wand"))


func snapshot() -> Dictionary:
	return {
		"health": health, "armor": armor, "armor_class": armor_class, "ammo": ammo.duplicate(),
		"max_ammo": max_ammo.duplicate(), "weapons": weapons.duplicate(), "inventory": inventory.duplicate(),
		"has_bag": has_bag, "weapon": weapon_node.current,
	}


func _restore(c: Dictionary) -> void:
	health = c.get("health", 100.0)
	armor = c.get("armor", 0.0)
	armor_class = c.get("armor_class", 0)
	ammo = c.get("ammo", ammo).duplicate()
	max_ammo = c.get("max_ammo", max_ammo).duplicate()
	weapons = c.get("weapons", weapons).duplicate()
	inventory = c.get("inventory", {}).duplicate()
	has_bag = c.get("has_bag", false)


func set_yaw(y: float) -> void:
	yaw = y
	rotation.y = yaw


func show_message(text: String) -> void:
	message.emit(text)


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Game.mouse_sensitivity
		yaw -= deg_to_rad(event.relative.x * sens)
		var dy: float = event.relative.y * sens * (-1.0 if Game.invert_mouse else 1.0)
		pitch = clampf(pitch - deg_to_rad(dy), deg_to_rad(-88.0), deg_to_rad(88.0))
	elif event.is_action_pressed("use"):
		Game.world.player_use(self)
	elif event.is_action_pressed("inv_next"):
		_cycle_inventory(1)
	elif event.is_action_pressed("inv_prev"):
		_cycle_inventory(-1)
	elif event.is_action_pressed("inv_use"):
		var items := inventory_list()
		if not items.is_empty():
			use_artifact(items[clampi(inv_sel, 0, items.size() - 1)])


func _physics_process(dt: float) -> void:
	_tick_powers(dt)
	damage_flash = move_toward(damage_flash, 0.0, dt * 1.6)
	pickup_flash = move_toward(pickup_flash, 0.0, dt * 2.5)
	if dead:
		head.position.y = move_toward(head.position.y, 0.25, dt * 1.5)
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
		velocity.y -= GRAVITY * dt
		move_and_slide()
		return

	yaw -= Input.get_axis("turn_left", "turn_right") * 2.6 * dt
	rotation.y = yaw
	head.rotation.x = pitch

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var speed := WALK if Input.is_action_pressed("walk") else RUN
	var flying := flight > 0.0
	var accel := 11.0 if (is_on_floor() or flying) else 2.0
	var hv := Vector3(velocity.x, 0.0, velocity.z).lerp(wish * speed, 1.0 - exp(-accel * dt))
	velocity.x = hv.x
	velocity.z = hv.z
	if flying:
		var lift := Input.get_axis("fly_down", "jump")
		velocity.y = lerpf(velocity.y, lift * 6.0, 1.0 - exp(-6.0 * dt))
		_fly_sound -= dt
		if _fly_sound <= 0.0 and lift != 0.0:
			_fly_sound = 0.35
			Sfx.play("wings", null, -12.0)
	else:
		velocity.y -= GRAVITY * dt
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP

	var before := global_position
	var climbed := Motion.move(self, STEP)
	_step_offset -= climbed
	_step_offset = move_toward(_step_offset, 0.0, dt * 3.0)

	var moving := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and moving > 0.5:
		_bob += dt * moving * 1.1
	var bob := sin(_bob * 2.0) * 0.035 * clampf(moving / RUN, 0.0, 1.0) if is_on_floor() else 0.0
	head.position.y = EYE + _step_offset + bob

	Game.world.check_crossings(self, before, global_position)
	_sector_effects(dt)


func _sector_effects(dt: float) -> void:
	var s: int = Game.world.sector_at(global_position)
	if s < 0:
		return
	if s != _sector:
		_sector = s
		Game.world.enter_sector(self, s)
	var sec: Dictionary = Game.world.map.sectors[s]
	var dmg := 0
	match int(sec.special):
		4, 5: dmg = 5
		7: dmg = 4
		16: dmg = 8
	if dmg > 0 and global_position.y <= sec.floor * S + 0.1:
		_sector_timer -= dt
		if _sector_timer <= 0.0:
			_sector_timer = 0.9
			take_damage(dmg, null)
	else:
		_sector_timer = 0.0


func _tick_powers(dt: float) -> void:
	var was_powered := powered > 0.0
	powered = maxf(powered - dt, 0.0)
	if was_powered and powered <= 0.0:
		show_message("YOUR WEAPONS RETURN TO NORMAL")
	var was_flying := flight > 0.0
	flight = maxf(flight - dt, 0.0)
	if was_flying and flight <= 0.0:
		show_message("YOUR WINGS FADE")
	invuln = maxf(invuln - dt, 0.0)
	invis = maxf(invis - dt, 0.0)
	torch = maxf(torch - dt, 0.0)
	torch_light.light_energy = move_toward(torch_light.light_energy, 1.6 if torch > 0.0 else 0.0, dt * 2.0)


func take_damage(amount: float, _source: Node3D = null, _at = null, push := Vector3.ZERO) -> void:
	if dead or invuln > 0.0:
		return
	if Game.skill == 0:
		amount *= 0.5
	if armor > 0.0:
		var save := minf(amount * (0.5 if armor_class == 1 else 0.75), armor)
		armor -= save
		amount -= save
		if armor <= 0.0:
			armor_class = 0
	health -= amount
	velocity += push
	damage_flash = clampf(damage_flash + amount / 40.0, 0.25, 0.9)
	if health <= 0.0:
		health = 0.0
		die()
	else:
		Sfx.play("pain", null, -2.0)


func die() -> void:
	dead = true
	weapon_node.visible = false
	Sfx.play("death")
	died.emit()


# --- Items -----------------------------------------------------------------

func give(kind: String) -> bool:
	var item: Dictionary = GameData.ITEMS.get(kind, {})
	if item.is_empty():
		return false
	var took := false
	if item.has("weapon"):
		var wname: String = item.weapon
		if not weapons.get(wname, false):
			weapons[wname] = true
			took = true
			weapon_node.on_new_weapon(wname)
	if item.has("ammo"):
		var a: String = item.ammo
		if ammo[a] < max_ammo[a]:
			var amount: float = item.amount
			if Game.skill == 0 or Game.skill == 4:
				amount *= 1.5
			ammo[a] = minf(ammo[a] + amount, max_ammo[a])
			took = true
	if item.has("health"):
		if health < 100.0:
			health = minf(health + float(item.health), 100.0)
			took = true
	if item.has("armor"):
		if armor < float(item.armor):
			armor = item.armor
			armor_class = item.armor_class
			took = true
	if item.has("key"):
		if not keys[item.key]:
			keys[item.key] = true
			took = true
	if item.has("artifact"):
		var art: String = item.artifact
		if inventory.get(art, 0) < 16:
			inventory[art] = inventory.get(art, 0) + 1
			took = true
	if item.has("bag"):
		if not has_bag:
			has_bag = true
			for k in max_ammo:
				max_ammo[k] = GameData.AMMO_MAX[k] * 2
		ammo.wand = minf(ammo.wand + 20.0, max_ammo.wand)
		took = true
	if took:
		show_message(item.msg)
		pickup_flash = 0.35
		if item.has("weapon"):
			Sfx.play("weapon_up")
		elif item.has("artifact") or item.has("key"):
			Sfx.play("artifact")
		else:
			Sfx.play("pickup")
	return took


func inventory_list() -> Array:
	var out := []
	for a in GameData.ARTIFACT_ORDER:
		if inventory.get(a, 0) > 0:
			out.append(a)
	return out


func _cycle_inventory(d: int) -> void:
	var n := inventory_list().size()
	if n > 0:
		inv_sel = posmod(inv_sel + d, n)


func use_artifact(art: String) -> void:
	var used := true
	match art:
		"flask":
			used = health < 100.0
			health = minf(health + 25.0, 100.0)
		"urn":
			used = health < 100.0
			health = 100.0
		"tome":
			powered = 30.0
			Sfx.play("powerup")
		"wings":
			flight = 60.0
		"ring":
			invuln = 30.0
		"shadow":
			invis = 60.0
		"torch":
			torch = 120.0
		"bomb":
			var fwd := -global_basis.z
			Projectile.spawn("bomb", global_position + fwd * 0.8 + Vector3(0, 0.4, 0), Vector3.DOWN, self)
		"chaos":
			Effects.teleport_flash(global_position)
			global_position = Game.world.start_pos
			velocity = Vector3.ZERO
			set_yaw(Game.world.start_yaw)
			Sfx.play("teleport")
	if not used:
		return
	inventory[art] -= 1
	if inventory[art] <= 0:
		inventory.erase(art)
		inv_sel = clampi(inv_sel, 0, maxi(inventory_list().size() - 1, 0))
	if art != "tome":
		Sfx.play("artifact")
