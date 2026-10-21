extends Node
## Game flow: title screen, starting levels, pausing, death, intermissions
## and moving on to the next map.

const SECRET_RETURN := {"1": 7, "2": 5, "3": 5, "4": 5, "5": 4}

var world: World
var hud: Hud
var menus: Menus
var map_id := ""                 # "" = the built-in level
var _level_carry := {}
var _builtin_tex: TextureLibrary
var _died_at := 0.0
var _was_captured := false
var _next_map := ""


func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 2
	add_child(menu_layer)
	menus = Menus.new()
	menu_layer.add_child(menus)
	menus.play_builtin.connect(func(): start_level("", {}))
	menus.play_map.connect(func(n: String): start_level(n, {}))
	menus.resume.connect(_resume)
	menus.restart.connect(func(): start_level(map_id, _level_carry))
	menus.quit_to_title.connect(_to_title)
	menus.continue_next.connect(_continue)
	Game.find_existing_wad()
	menus.show_title()
	var args := _launch_args()
	Game.peaceful = args.has("peaceful")
	if args.has("autostart"):
		await start_level("", {})
		if args.has("warp"):
			_warp(args.warp)


## Launch options from the command line (`-- --autostart --warp=x,y,angle --peaceful`)
## or, on the web, the page URL (`?autostart&warp=x,y,angle&peaceful`).
## peaceful: monsters never notice you, for looking at art in the game.
func _launch_args() -> Dictionary:
	var out := {}
	var parts: PackedStringArray = OS.get_cmdline_user_args()
	if Game.is_web():
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and q.length() > 1:
			parts = q.substr(1).split("&")
	for a in parts:
		var kv := a.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else ""
	return out


## Puts the player at map coordinates, for testing and screenshots.
func _warp(spec: String) -> void:
	var v := spec.split_floats(",")
	if v.size() < 2 or world == null:
		return
	var p := Vector2(v[0], v[1])
	world.player.global_position = GeometryBuilder.to_world(p, world.floor_at(p)) + Vector3(0, 0.05, 0)
	if v.size() > 2:
		world.player.set_yaw(deg_to_rad(v[2] - 90.0))
	if v.size() > 3:
		world.player.pitch = deg_to_rad(v[3])


func start_level(id: String, carry: Dictionary) -> void:
	_clear_world()
	get_tree().paused = false
	map_id = id
	menus.show_loading("Building the level ..." if id == "" else "Reading %s from your WAD ..." % id)
	await get_tree().process_frame
	await get_tree().process_frame
	var m: MapData
	var tex: TextureLibrary
	if id == "":
		m = DemoMap.build()
		if _builtin_tex == null:
			_builtin_tex = TextureLibrary.procedural()
		tex = _builtin_tex
	else:
		m = MapData.from_wad(Game.wad, id)
		tex = Game.textures_for_wad()
	if m == null:
		menus.show_message("CAN'T LOAD MAP", "%s couldn't be read from this WAD." % id)
		return
	Game.carry = carry
	_level_carry = carry.duplicate(true)
	world = World.new()
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.setup(m, tex, id)
	world.level_exited.connect(_on_level_exited)
	world.player.died.connect(func(): _died_at = Time.get_ticks_msec() / 1000.0)
	hud.bind(world.player, world)
	hud.center_message(m.title)
	menus.hide_all()
	_capture()


func _clear_world() -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	world = null
	Game.world = null
	hud.player = null
	_was_captured = false


func _capture() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_dt: float) -> void:
	if world == null or not is_instance_valid(world) or menus.visible:
		hud.set_hint("")
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if captured:
		_was_captured = true
		hud.set_hint("")
	elif _was_captured and not world.player.dead:
		# The browser releases the pointer on Esc; treat that as a pause.
		_pause()
	else:
		hud.set_hint("Click to play")


func _unhandled_input(event: InputEvent) -> void:
	if world == null or not is_instance_valid(world):
		return
	if event.is_action_pressed("pause"):
		if menus.current() == "pause":
			_resume()
		elif not menus.visible:
			_pause()
		get_viewport().set_input_as_handled()
		return
	if menus.visible:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture()
	if world.player.dead and Time.get_ticks_msec() / 1000.0 - _died_at > 1.0:
		if event.is_action_pressed("fire") or event.is_action_pressed("use"):
			start_level(map_id, _level_carry)


func _pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.show_pause()


func _resume() -> void:
	menus.hide_all()
	get_tree().paused = false
	_was_captured = false
	_capture()


func _to_title() -> void:
	_clear_world()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.show_title()


func _on_level_exited(secret: bool) -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.carry = world.player.snapshot()
	_next_map = _next_map_name(secret)
	var title := "%s COMPLETE" % ("LEVEL" if map_id == "" else map_id)
	var label := "CONTINUE TO %s" % _next_map if _next_map != "" else ("RETURN TO TITLE" if map_id != "" else "VICTORY!  RETURN TO TITLE")
	menus.show_intermission(title, world, label)


func _continue() -> void:
	if _next_map == "":
		_to_title()
	else:
		start_level(_next_map, Game.carry)


func _next_map_name(secret: bool) -> String:
	if map_id == "" or map_id.length() != 4 or not map_id.begins_with("E"):
		return ""
	var ep := map_id.substr(1, 1)
	var n := int(map_id.substr(3, 1))
	var next := ""
	if secret:
		next = "E%sM9" % ep
	elif n == 9:
		next = "E%sM%d" % [ep, SECRET_RETURN.get(ep, 5)]
	elif n < 8:
		next = "E%sM%d" % [ep, n + 1]
	return next if Game.wad != null and Game.wad.has_lump(next) else ""
