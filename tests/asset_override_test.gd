extends Node
## Checks that drop-in art replaces the placeholders. Give it a folder with
## monsters/golem.glb (e.g. made by art/tools/blender_prepare.py); the test
## adds an HD texture set and reuses the model for a weapon, item and prop.
## godot --headless res://tests/asset_override_test.tscn -- --mods=DIR

var failures: Array[String] = []


func _ready() -> void:
	get_tree().create_timer(180.0).timeout.connect(func():
		print("RESULT: FAIL (timed out)")
		get_tree().quit(1))
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mods="):
			dir = a.substr(7)
	var golem := dir.path_join("monsters/golem.glb")
	_check(FileAccess.file_exists(golem), "test model present at %s" % golem)
	for kind in ["weapons/wand.glb", "items/vial.glb", "decor/brazier.glb"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(kind.get_base_dir()))
		DirAccess.copy_absolute(golem, dir.path_join(kind))
	_make_texture_set(dir.path_join("textures"))

	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main.start_level("", {})
	var w: World = main.world

	var golems := get_tree().get_nodes_in_group("monsters").filter(func(m): return m.kind == "golem")
	_check(not golems.is_empty(), "golems spawned")
	var g: Monster = golems[0]
	_check(g._custom, "golem uses the replacement model")
	var anims: Dictionary = g.model.get_meta("anims", {})
	print("  golem clips: %s" % anims)
	_check(anims.has("idle") and anims.has("walk") and anims.has("attack"), "idle/walk/attack clips mapped")
	var fitted: Vector3 = g.model.get_meta("size")
	_check(absf(fitted.y - g.height) < 0.01, "golem fitted to %.2f m (wanted %.2f)" % [fitted.y, g.height])

	var brick := w.tex.wall("BRICK")
	_check(brick.hd and brick.normal != null and brick.roughness != null, "HD brick texture with normal + roughness maps")
	_check(is_equal_approx(brick.width, 128.0), "HD texture keeps the original's size in map units")

	var p: Player = w.player
	p.weapon_node._show("wand")
	_check(p.weapon_node._models["wand"].has_meta("custom"), "replacement weapon model")
	var found_item := false
	for n in w.get_children():
		if n is Pickup and n.kind == "vial" and n._model.get_child(0).name.begins_with("Custom_"):
			found_item = true
	_check(found_item, "replacement item model")

	# wake everything and make sure the golem animates
	w.noise_alert(g.global_position)
	for i in 120:
		await get_tree().physics_frame
	var ap: AnimationPlayer = g.model.get_meta("anim_player")
	print("  golem state %s playing '%s'" % [Monster.State.keys()[g.state], ap.current_animation])
	_check(ap.is_playing(), "golem animation is playing")

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func _make_texture_set(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(512, 512, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.45, 0.4))
	img.save_png(dir.path_join("BRICK.png"))
	img.fill(Color(0.5, 0.5, 1.0))
	img.save_png(dir.path_join("BRICK_normal.png"))
	img.fill(Color(0.8, 0.8, 0.8))
	img.save_png(dir.path_join("BRICK_roughness.png"))


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures.append(what)
