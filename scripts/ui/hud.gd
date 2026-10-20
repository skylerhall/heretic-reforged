class_name Hud
extends Control
## The status bar (with Heretic's life chain), crosshair, messages and
## screen flashes, all drawn directly so it scales cleanly at any size.

const GOLD := Color(0.86, 0.68, 0.3)
const DIM := Color(0.55, 0.47, 0.36)
const BAR_H := 96.0

var player: Player
var world: World
var _messages: Array = []   # [text, time_left]
var _center := ""
var _center_t := 0.0
var _hint := ""
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func bind(p: Player, w: World) -> void:
	player = p
	world = w
	_messages.clear()
	p.message.connect(add_message)


func add_message(text: String) -> void:
	_messages.append([text, 4.0])
	if _messages.size() > 4:
		_messages.pop_front()


func center_message(text: String, seconds := 3.0) -> void:
	_center = text
	_center_t = seconds


func set_hint(text: String) -> void:
	_hint = text


func _process(dt: float) -> void:
	for m in _messages:
		m[1] -= dt
	_messages = _messages.filter(func(m): return m[1] > 0.0)
	_center_t -= dt
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 4, Color(0, 0, 0, 0.85 * color.a))
	draw_string(_font, pos, s, align, width, size, color)


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var sz := size
	var full := Rect2(Vector2.ZERO, sz)

	# screen tints
	if player.damage_flash > 0.0:
		draw_rect(full, Color(0.75, 0.0, 0.0, player.damage_flash * 0.45))
	if player.pickup_flash > 0.0:
		draw_rect(full, Color(1.0, 0.85, 0.3, player.pickup_flash * 0.22))
	if player.invuln > 0.0:
		draw_rect(full, Color(1.0, 0.95, 0.75, 0.10))
	if player.dead:
		draw_rect(full, Color(0.25, 0.0, 0.0, 0.35))

	# crosshair
	if not player.dead:
		var c := sz * 0.5
		var cc := Color(1, 0.9, 0.7, 0.75)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * 4.0, c + d * 10.0, cc, 2.0)

	_draw_bar(sz)

	# messages
	var y := 30.0
	for m in _messages:
		_text(Vector2(20, y), m[0], 18, Color(GOLD, clampf(m[1], 0.0, 1.0)))
		y += 24.0
	if _center_t > 0.0 and _center != "":
		_text(Vector2(0, sz.y * 0.3), _center, 40, Color(GOLD, clampf(_center_t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	if player.dead:
		_text(Vector2(0, sz.y * 0.42), "YOU HAVE DIED", 44, Color(0.9, 0.2, 0.15), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
		_text(Vector2(0, sz.y * 0.42 + 44), "Click or press E to try again", 20, DIM, HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	elif _hint != "":
		_text(Vector2(0, sz.y * 0.6), _hint, 24, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, sz.x)


func _draw_bar(sz: Vector2) -> void:
	var y0 := sz.y - BAR_H
	draw_rect(Rect2(0, y0, sz.x, BAR_H), Color(0.08, 0.06, 0.05, 0.9))
	draw_rect(Rect2(0, y0, sz.x, 3), GOLD)
	draw_rect(Rect2(0, y0 + 3, sz.x, 1), Color(0.3, 0.22, 0.1))

	# the life chain: a gem slides along it as health changes
	var cy := y0 + 16.0
	var x0 := 24.0
	var x1 := sz.x - 24.0
	var x := x0
	var i := 0
	while x < x1:
		draw_arc(Vector2(x + 8.0, cy), 7.0 if i % 2 == 0 else 5.0, 0, TAU, 12, Color(0.6, 0.6, 0.62), 2.0)
		x += 14.0
		i += 1
	var gx := lerpf(x0, x1, clampf(player.health / 100.0, 0.0, 1.0))
	var gem := PackedVector2Array([Vector2(gx, cy - 9), Vector2(gx + 7, cy), Vector2(gx, cy + 9), Vector2(gx - 7, cy)])
	draw_colored_polygon(gem, Color(0.9, 0.1, 0.1))
	draw_polyline(gem + PackedVector2Array([gem[0]]), Color(1, 0.6, 0.5), 1.5)

	var base := y0 + 76.0
	var hc := Color(0.95, 0.25, 0.2) if player.health < 25.0 else GOLD
	_text(Vector2(30, y0 + 40), "HEALTH", 13, DIM)
	_text(Vector2(30, base), "%d" % ceili(player.health), 38, hc)
	_text(Vector2(160, y0 + 40), "ARMOR", 13, DIM)
	_text(Vector2(160, base), "%d" % ceili(player.armor), 38, GOLD if player.armor_class < 2 else Color(0.5, 1.0, 0.6))

	var wd := GameData.weapon(player.weapon_node.current, player.powered > 0.0)
	var mid := sz.x * 0.5
	_text(Vector2(mid - 200, y0 + 40), wd.name, 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, 400)
	if wd.ammo != "":
		var ac: Color = GameData.AMMO_COLOR[wd.ammo]
		_text(Vector2(mid - 200, base), "%d" % int(ceil(player.ammo[wd.ammo] - 0.001)), 38, ac, HORIZONTAL_ALIGNMENT_CENTER, 400)
	else:
		_text(Vector2(mid - 200, base), "-", 38, DIM, HORIZONTAL_ALIGNMENT_CENTER, 400)

	# keys
	var kx := sz.x * 0.5 + 170.0
	var kc := {"yellow": Color(1.0, 0.85, 0.2), "green": Color(0.2, 1.0, 0.35), "blue": Color(0.3, 0.5, 1.0)}
	var k := 0
	for key in ["yellow", "green", "blue"]:
		var p := Vector2(kx + k * 26.0, y0 + 60.0)
		var poly := PackedVector2Array([p + Vector2(0, -10), p + Vector2(8, 0), p + Vector2(0, 10), p + Vector2(-8, 0)])
		if player.keys[key]:
			draw_colored_polygon(poly, kc[key])
		draw_polyline(poly + PackedVector2Array([poly[0]]), Color(kc[key], 0.6), 1.5)
		k += 1

	# selected artifact
	var items := player.inventory_list()
	var ax := sz.x - 260.0
	_text(Vector2(ax, y0 + 40), "ARTIFACT   [ ] select   R use", 12, DIM)
	if not items.is_empty():
		var sel: String = items[clampi(player.inv_sel, 0, items.size() - 1)]
		_text(Vector2(ax, y0 + 64), GameData.ARTIFACT_NAMES[sel], 18, GOLD)
		_text(Vector2(ax, base + 6), "x%d" % player.inventory[sel], 16, DIM)
		if items.size() > 1:
			_text(Vector2(ax + 40, base + 6), "(%d kinds)" % items.size(), 13, DIM)
	else:
		_text(Vector2(ax, y0 + 64), "none", 16, DIM)

	# active powers
	var px := sz.x - 24.0
	var py := y0 - 14.0
	for pw in [["TOME OF POWER", player.powered, Color(1.0, 0.75, 0.3)], ["WINGS", player.flight, Color(0.9, 0.9, 0.6)],
			["INVINCIBLE", player.invuln, Color(1, 1, 1)], ["SHADOW", player.invis, Color(0.7, 0.6, 1.0)],
			["TORCH", player.torch, Color(1.0, 0.7, 0.4)]]:
		if pw[1] > 0.0:
			_text(Vector2(px - 300, py), "%s  %d" % [pw[0], ceili(pw[1])], 16, pw[2], HORIZONTAL_ALIGNMENT_RIGHT, 300)
			py -= 22.0
