extends Node
## Global state shared between levels: settings, input bindings, the loaded
## WAD and the player's inventory carried from one map to the next.

const SAVED_WAD := "user://heretic.wad"
const SETTINGS := "user://settings.cfg"

enum Quality { LOW, HIGH, ULTRA }

var wad: WadFile = null
var wad_textures: TextureLibrary = null
var quality: int = Quality.HIGH
var mouse_sensitivity := 0.15
var invert_mouse := false
var skill := 2              # 0..4, like the original's five skill levels
var carry: Dictionary = {}  # player state handed to the next map
var world = null            # the running World, if any
var main = null

var _js_callback = null
var _pending_pick: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	quality = Quality.HIGH if is_forward_plus() else Quality.LOW
	_load_settings()


func is_web() -> bool:
	return OS.has_feature("web")


func is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


# --- Settings -------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
	invert_mouse = cfg.get_value("input", "invert_mouse", invert_mouse)
	skill = cfg.get_value("game", "skill", skill)
	var q: int = cfg.get_value("video", "quality", quality)
	quality = q if is_forward_plus() else mini(q, Quality.HIGH)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_mouse", invert_mouse)
	cfg.set_value("game", "skill", skill)
	cfg.set_value("video", "quality", quality)
	cfg.save(SETTINGS)


# --- Input map ------------------------------------------------------------

const BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"turn_left": [KEY_LEFT],
	"turn_right": [KEY_RIGHT],
	"jump": [KEY_SPACE],
	"fly_down": [KEY_C, KEY_Z],
	"use": [KEY_E],
	"walk": [KEY_SHIFT],
	"fire": [MOUSE_BUTTON_LEFT],
	"inv_use": [KEY_ENTER, KEY_R, MOUSE_BUTTON_RIGHT],
	"inv_prev": [KEY_BRACKETLEFT, KEY_Q],
	"inv_next": [KEY_BRACKETRIGHT, KEY_TAB],
	"weapon_next": [MOUSE_BUTTON_WHEEL_DOWN],
	"weapon_prev": [MOUSE_BUTTON_WHEEL_UP],
	"pause": [KEY_ESCAPE, KEY_P],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"weapon_3": [KEY_3],
	"weapon_4": [KEY_4],
	"weapon_5": [KEY_5],
	"weapon_6": [KEY_6],
	"weapon_7": [KEY_7],
}

const MOUSE_CODES := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]


func _setup_input() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in BINDINGS[action]:
			var ev: InputEvent
			# Mouse button codes overlap small key codes, so mouse-only
			# actions are listed with MOUSE_BUTTON_* and detected here.
			if action in ["fire", "weapon_next", "weapon_prev"] or (action == "inv_use" and code == MOUSE_BUTTON_RIGHT):
				var mb := InputEventMouseButton.new()
				mb.button_index = code
				ev = mb
			else:
				var k := InputEventKey.new()
				k.physical_keycode = code
				ev = k
			InputMap.action_add_event(action, ev)


# --- WAD handling ---------------------------------------------------------

## Validates and adopts a WAD. Returns an error message, or "" on success.
func use_wad_bytes(bytes: PackedByteArray, remember := true) -> String:
	var w := WadFile.from_bytes(bytes)
	if w == null:
		return "That file is not a WAD."
	if not w.is_iwad or not w.has_lump("PLAYPAL") or not w.has_lump("TEXTURE1"):
		return "That looks like an add-on (PWAD). Load the full HERETIC.WAD."
	if not w.has_lump("FLTWAWA1"):
		return "That WAD doesn't look like Heretic."
	if w.map_names().is_empty():
		return "That WAD has no maps."
	wad = w
	wad_textures = null
	if remember:
		var f := FileAccess.open(SAVED_WAD, FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()
	return ""


## Picks up a WAD from earlier sessions, the command line or next to the game.
func find_existing_wad() -> void:
	var candidates: Array[String] = []
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--wad="):
			candidates.append(arg.substr(6))
	candidates.append(SAVED_WAD)
	if not is_web():
		var dir := OS.get_executable_path().get_base_dir()
		for n in ["HERETIC.WAD", "heretic.wad", "HERETIC1.WAD", "heretic1.wad"]:
			candidates.append(dir.path_join(n))
	for path in candidates:
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			if use_wad_bytes(bytes, path != SAVED_WAD) == "":
				return


func forget_wad() -> void:
	wad = null
	wad_textures = null
	if FileAccess.file_exists(SAVED_WAD):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED_WAD))


## Opens a file picker and calls `done(error_message)` once a WAD is chosen.
func pick_wad(done: Callable) -> void:
	_pending_pick = done
	if is_web():
		_pick_wad_web()
		return
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.wad, *.WAD ; WAD files"])
	dlg.use_native_dialog = true
	dlg.title = "Choose your HERETIC.WAD"
	add_child(dlg)
	dlg.file_selected.connect(func(path: String):
		dlg.queue_free()
		_finish_pick(FileAccess.get_file_as_bytes(path)))
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered_ratio(0.7)


func _finish_pick(bytes: PackedByteArray) -> void:
	var err := use_wad_bytes(bytes) if not bytes.is_empty() else "Couldn't read that file."
	if _pending_pick.is_valid():
		_pending_pick.call(err)


func _pick_wad_web() -> void:
	# Browsers only hand files to page script, so a hidden <input> reads the
	# file and passes it back base64-encoded.
	_js_callback = JavaScriptBridge.create_callback(_on_web_file)
	var window = JavaScriptBridge.get_interface("window")
	window.godotWadPicked = _js_callback
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.wad,.WAD';
			input.onchange = function () {
				var file = input.files[0];
				if (!file) return;
				var reader = new FileReader();
				reader.onload = function () {
					var bytes = new Uint8Array(reader.result);
					var chunks = [];
					for (var i = 0; i < bytes.length; i += 0x8000) {
						chunks.push(String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000)));
					}
					window.godotWadPicked(btoa(chunks.join('')));
				};
				reader.readAsArrayBuffer(file);
			};
			input.click();
		})();
	""", true)


func _on_web_file(args: Array) -> void:
	_finish_pick(Marshalls.base64_to_raw(str(args[0])))


func textures_for_wad() -> TextureLibrary:
	if wad_textures == null and wad != null:
		wad_textures = TextureLibrary.from_wad(wad)
	return wad_textures
