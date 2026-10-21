extends Node
## Headless smoke test: builds the built-in level, walks the player around,
## fires weapons, opens the gate and reports what happened.
## Run: godot --headless res://tests/smoke_test.tscn

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	# If a script fails to compile the game never starts; don't hang forever.
	get_tree().create_timer(180.0).timeout.connect(func():
		print("RESULT: FAIL (timed out)")
		get_tree().quit(1))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	await main.start_level("", {})
	var w: World = main.world
	print("level built in %d ms" % (Time.get_ticks_msec() - t0))
	_check(w != null, "world exists")
	_check(w.player != null, "player spawned")
	print("sectors: %d  lines: %d  dynamic sectors: %d  wall groups: %d" % [w.map.sectors.size(), w.map.lines.size(), w.dynamic.size(), w.wall_groups.size()])
	var empty := 0
	for s in w.map.sectors.size():
		if w.geo.sector_tris[s].is_empty():
			empty += 1
			print("  sector %d has no triangles" % s)
	_check(empty == 0, "every sector triangulated")
	print("monsters: %d  items: %d" % [w.total_kills, w.total_items])
	_check(w.total_kills > 10, "monsters spawned")

	# let physics settle, the player should be standing on the courtyard floor
	for i in 30:
		await get_tree().physics_frame
	var p: Player = w.player
	print("player at %s on_floor=%s sector=%d" % [p.global_position, p.is_on_floor(), w.sector_at(p.global_position)])
	_check(p.is_on_floor(), "player stands on the floor")
	_check(absf(p.global_position.y) < 0.2, "player at floor height")

	# walk toward the gate (east) and press use on it
	p.global_position = GeometryBuilder.to_world(Vector2(800, 384), 0.0) + Vector3(0, 0.05, 0)
	p.set_yaw(deg_to_rad(0.0 - 90.0))
	for i in 5:
		await get_tree().physics_frame
	w.player_use(p)
	_check(w.movers.size() > 0, "gate starts opening")
	for i in 120:
		await get_tree().physics_frame
	var gate_sector := w.sector_at(GeometryBuilder.to_world(Vector2(848, 384), 0.0))
	print("gate ceiling now %s" % w.map.sectors[gate_sector].ceil)
	_check(w.map.sectors[gate_sector].ceil > 100.0, "gate opened")

	# fire every weapon type once
	for k in ["crossbow", "claw", "hellstaff", "phoenix", "mace", "gauntlets"]:
		p.weapons[k] = true
	for a in p.ammo:
		p.ammo[a] = 50.0
	for wname in ["wand", "crossbow", "claw", "hellstaff", "phoenix", "mace", "staff"]:
		p.weapon_node.current = wname
		p.weapon_node._show(wname)
		p.weapon_node._fire()
		for i in 10:
			await get_tree().physics_frame
	p.powered = 10.0
	for wname in ["wand", "crossbow", "claw", "hellstaff", "phoenix", "mace"]:
		p.weapon_node.current = wname
		p.weapon_node._show(wname)
		p.weapon_node._fire()
		for i in 5:
			await get_tree().physics_frame

	# walk up the steps to the east platform (needs step climbing). Monsters
	# are awake by now; keep their hits from knocking the player around.
	p.invuln = 1000.0
	p.global_position = GeometryBuilder.to_world(Vector2(1600, 384), 0.0) + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	for i in 60:
		p.velocity.x = 6.0
		await get_tree().physics_frame
	var floor_now: float = p.global_position.y / Layers.S
	print("after stairs: map pos %s height %.1f" % [World.to_map(p.global_position), floor_now])
	_check(floor_now > 50.0, "climbed the stairs onto the platform")

	# lift
	p.global_position = GeometryBuilder.to_world(Vector2(1890, 384), 64.0) + Vector3(0, 0.05, 0)
	p.set_yaw(deg_to_rad(0.0 - 90.0))
	await get_tree().physics_frame
	w.player_use(p)
	for i in 90:
		await get_tree().physics_frame
	var lift_s := w.sector_at(GeometryBuilder.to_world(Vector2(1950, 384), 0.0))
	print("lift floor: %s" % w.map.sectors[lift_s].floor)
	_check(w.map.sectors[lift_s].floor < 100.0, "lift lowered")

	# monsters wake up and fight
	w.noise_alert(p.global_position)
	for i in 240:
		await get_tree().physics_frame
	var awake := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.state != Monster.State.IDLE:
			awake += 1
	print("awake monsters: %d, player health %.0f, kills %d" % [awake, p.health, w.kills])

	# exit switch
	p.health = 100.0
	p.invuln = 100.0
	p.global_position = GeometryBuilder.to_world(Vector2(1280, 1250), 0.0) + Vector3(0, 0.05, 0)
	p.set_yaw(deg_to_rad(90.0 - 90.0))
	await get_tree().physics_frame
	w.player_use(p)
	_check(w.finished, "exit switch ends the level")

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures.append(what)
