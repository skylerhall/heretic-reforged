class_name Menus
extends Control
## Title, pause, settings, map select, loading and intermission screens.

signal play_builtin
signal play_map(map_name: String)
signal resume
signal restart
signal quit_to_title
signal continue_next

const GOLD := Color(0.86, 0.68, 0.3)
const SKILLS := ["THOU NEEDETH A WET-NURSE", "YELLOWBELLIES-R-US", "BRINGEST THEM ONETH", "THOU ART A SMITE-MEISTER", "BLACK PLAGUE POSSESSES THEE"]
const QUALITY_NAMES := ["LOW", "HIGH", "ULTRA"]

var _bg: ColorRect
var _panel: VBoxContainer
var _screen := ""
var _back_target := "title"
var _status := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.material = _background_material()
	add_child(_bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 10)
	_panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(_panel)
	theme = _make_theme()


func current() -> String:
	return _screen if visible else ""


func hide_all() -> void:
	visible = false
	_screen = ""


func _begin(screen: String, opaque := true) -> void:
	visible = true
	_screen = screen
	_bg.visible = true
	_bg.color = Color(0, 0, 0, 1.0 if opaque else 0.6)
	(_bg.material as ShaderMaterial).set_shader_parameter("opacity", 1.0 if opaque else 0.0)
	for c in _panel.get_children():
		c.queue_free()


func _title(text: String, size := 64) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.02))
	l.add_theme_constant_override("outline_size", 12)
	_panel.add_child(l)


func _note(text: String, size := 16, color := Color(0.7, 0.62, 0.5)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_panel.add_child(l)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func():
		Sfx.play("switch", null, -6.0)
		action.call())
	_panel.add_child(b)
	return b


func _spacer(h := 12.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_panel.add_child(c)


# --- Screens -----------------------------------------------------------------

func show_title() -> void:
	_begin("title")
	_title("HERETIC", 96)
	_note("R E F O R G E D", 22, Color(0.9, 0.55, 0.25))
	_note("A fan remake of Raven Software's 1994 classic", 14)
	_spacer(18)
	_button("PLAY: THE SUNKEN KEEP", func(): play_builtin.emit())
	if Game.wad != null:
		_button("PLAY HERETIC  (your WAD)", show_maps)
	else:
		_button("LOAD YOUR HERETIC.WAD ...", _pick_wad)
	_button("SKILL:  " + SKILLS[Game.skill], _cycle_skill)
	_button("SETTINGS", func(): show_settings("title"))
	if not Game.is_web():
		_button("QUIT", func(): get_tree().quit())
	_spacer(10)
	if _status != "":
		_note(_status, 15, Color(1.0, 0.5, 0.4))
	_note("WASD move · Mouse look · Click fire · E open/use · Space jump/fly up · C fly down\n1-7 / wheel weapons · [ ] or Q/Tab pick artifact · R or right-click use it · Esc pause", 13)


func _cycle_skill() -> void:
	Game.skill = (Game.skill + 1) % SKILLS.size()
	Game.save_settings()
	show_title()


func _pick_wad() -> void:
	Game.pick_wad(func(err: String):
		_status = err
		if err == "":
			show_maps()
		else:
			show_title())


func show_maps() -> void:
	_begin("maps")
	_title("CHOOSE A MAP", 44)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_panel.add_child(grid)
	for n in Game.wad.map_names():
		var b := Button.new()
		b.text = n
		b.custom_minimum_size = Vector2(96, 42)
		b.pressed.connect(func(): play_map.emit(n))
		grid.add_child(b)
	_spacer()
	_note("Your WAD stays on this device; it is never uploaded anywhere.", 13)
	_button("FORGET THIS WAD", func():
		Game.forget_wad()
		show_title())
	_button("BACK", show_title)


func show_pause() -> void:
	_begin("pause", false)
	_title("PAUSED", 56)
	_button("RESUME", func(): resume.emit())
	_button("RESTART LEVEL", func(): restart.emit())
	_button("SETTINGS", func(): show_settings("pause"))
	_button("QUIT TO TITLE", func(): quit_to_title.emit())


func show_settings(back: String) -> void:
	_back_target = back
	_begin("settings", back == "title")
	_title("SETTINGS", 48)
	var q_text: String = "GRAPHICS:  " + QUALITY_NAMES[Game.quality]
	_button(q_text, _cycle_quality)
	if not Game.is_forward_plus():
		_note("Browser builds use the lighter web renderer; the desktop build adds volumetric fog, SSAO and global illumination.", 13)
	else:
		_note("Graphics changes apply when the next level starts.", 13)
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "MOUSE SPEED"
	lbl.custom_minimum_size = Vector2(170, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.03
	slider.max_value = 0.5
	slider.step = 0.01
	slider.value = Game.mouse_sensitivity
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float):
		Game.mouse_sensitivity = v
		Game.save_settings())
	row.add_child(slider)
	_panel.add_child(row)
	_button("INVERT MOUSE:  " + ("ON" if Game.invert_mouse else "OFF"), func():
		Game.invert_mouse = not Game.invert_mouse
		Game.save_settings()
		show_settings(_back_target))
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_button("FULLSCREEN:  " + ("ON" if fs else "OFF"), func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		show_settings(_back_target))
	_button("BACK", func():
		if _back_target == "pause":
			show_pause()
		else:
			show_title())


func _cycle_quality() -> void:
	var top := Game.Quality.ULTRA if Game.is_forward_plus() else Game.Quality.HIGH
	Game.quality = (Game.quality + 1) % (top + 1)
	Game.save_settings()
	show_settings(_back_target)


func show_loading(text: String) -> void:
	_begin("loading")
	_title("LOADING", 48)
	_note(text, 18)


func show_message(title: String, text: String) -> void:
	_begin("message")
	_title(title, 48)
	_note(text, 16)
	_button("BACK", show_title)


func show_intermission(title: String, w: World, next_label: String) -> void:
	_begin("intermission", false)
	_title(title, 48)
	var mins := int(w.time) / 60
	var secs := int(w.time) % 60
	_note("KILLS   %d / %d" % [w.kills, w.total_kills], 22, GOLD)
	_note("ITEMS   %d / %d" % [w.items, w.total_items], 22, GOLD)
	_note("SECRETS   %d / %d" % [w.secrets, w.total_secrets], 22, GOLD)
	_note("TIME   %d:%02d" % [mins, secs], 22, GOLD)
	_spacer()
	_button(next_label, func(): continue_next.emit())


# --- Look ----------------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.08, 0.06, 0.92)
	normal.border_color = Color(0.45, 0.33, 0.15)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.12, 0.06, 0.95)
	hover.border_color = GOLD
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.4, 0.15, 0.05, 1.0)
	pressed.border_color = Color(1.0, 0.8, 0.4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", hover)
	t.set_color("font_color", "Button", Color(0.9, 0.8, 0.6))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.9, 0.6))
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Label", Color(0.85, 0.75, 0.55))
	t.set_font_size("font_size", "Label", 18)
	return t


func _background_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float opacity = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float glow = smoothstep(1.1, 0.0, distance(uv, vec2(0.5, 1.05)));
	vec3 col = mix(vec3(0.03, 0.015, 0.02), vec3(0.45, 0.12, 0.03), glow * 0.8);
	// rising embers
	for (int i = 0; i < 3; i++) {
		vec2 g = uv * vec2(40.0 + float(i) * 13.0, 22.0) + vec2(0.0, TIME * (1.5 + float(i)));
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(id + float(i) * 7.0);
		float e = smoothstep(0.08, 0.0, length(f - vec2(h - 0.5, 0.0) * 0.6)) * step(0.88, h);
		col += vec3(1.0, 0.45, 0.1) * e * glow * 1.6;
	}
	COLOR = vec4(col, opacity < 0.5 ? 0.65 : 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
