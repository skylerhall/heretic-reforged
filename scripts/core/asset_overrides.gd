class_name AssetOverrides
## Finds replacement art (yours, AI-generated or hand-made) and fits it into
## the game. Anything without a replacement keeps its built-in placeholder.
##
## Where files are found, first match wins:
##   res://assets/<kind>/      shipped with the game (imported when exporting)
##   --mods=<dir>/<kind>/      command-line folder
##   <game folder>/mods/<kind>/   next to the desktop executable
##   user://mods/<kind>/       the per-user data folder
## Kinds: monsters, weapons, items, decor (.glb/.gltf), textures (.png/.jpg/.webp).
## An optional <name>.json beside a model tweaks the fit, e.g.
##   {"height": 2.4, "yaw": 0, "scale": 1.0, "offset": [0, 0, 0],
##    "anims": {"walk": "Run_Forward"}}

const MODEL_EXT := ["glb", "gltf", "tscn", "scn"]
const IMAGE_EXT := ["png", "jpg", "jpeg", "webp"]

## Keywords that pick an animation clip for each game state.
const ANIM_KEYWORDS := {
	"idle": ["idle", "stand", "breath"],
	"walk": ["walk", "run", "move", "fly", "crawl"],
	"attack": ["attack", "punch", "swing", "slash", "cast", "shoot", "throw", "fire", "bite", "claw"],
	"pain": ["hit", "pain", "react", "hurt", "flinch", "damage"],
	"death": ["death", "die", "dying", "dead"],
	"fire": ["fire", "shoot", "attack", "recoil"],
}

static var _cache := {}


static func search_dirs() -> Array[String]:
	var dirs: Array[String] = ["res://assets"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mods="):
			dirs.append(a.substr(7))
	if not OS.has_feature("web") and not OS.has_feature("editor"):
		dirs.append(OS.get_executable_path().get_base_dir().path_join("mods"))
	dirs.append("user://mods")
	return dirs


## Path of the first file named `name` (any supported extension) in a kind
## folder, or "".
static func find(kind: String, name: String, exts: Array) -> String:
	var key := "%s/%s" % [kind, name]
	if _cache.has(key):
		return _cache[key]
	var found := ""
	for dir in search_dirs():
		for ext in exts:
			for n in [name, name.to_lower()]:
				var p: String = dir.path_join(kind).path_join("%s.%s" % [n, ext])
				if (p.begins_with("res://") and ResourceLoader.exists(p)) or FileAccess.file_exists(p):
					found = p
					break
			if found != "":
				break
		if found != "":
			break
	_cache[key] = found
	return found


static func _settings(path: String) -> Dictionary:
	var json_path := path.get_basename() + ".json"
	if not FileAccess.file_exists(json_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	return parsed if parsed is Dictionary else {}


## Loads a replacement model, facing -Z, and returns null when there is none.
## fit "height": `size` meters tall, standing on y=0 (characters, props).
## fit "length": `size` meters long, back end at the origin (weapons).
static func model(kind: String, names: Array, size: float, fit := "height") -> Node3D:
	var path := ""
	for n in names:
		path = find(kind, n, MODEL_EXT)
		if path != "":
			break
	if path == "":
		return null
	var scene := _load_scene(path)
	if scene == null:
		push_warning("couldn't load %s" % path)
		return null
	var cfg := _settings(path)
	var holder := Node3D.new()
	holder.name = "Custom_" + path.get_file().get_basename()
	holder.set_meta("source", path)
	holder.add_child(scene)
	var box := _bounds(scene)
	var target: float = cfg.get("height", cfg.get("length", size))
	var c := box.get_center()
	var s: float
	if fit == "length":
		s = target / maxf(box.get_longest_axis_size(), 0.001)
		scene.position = Vector3(-c.x, -c.y, -box.position.z) * s
	else:
		s = target / maxf(box.size.y, 0.001)
		scene.position = Vector3(-c.x, -box.position.y, -c.z) * s
	s *= float(cfg.get("scale", 1.0))
	scene.position *= float(cfg.get("scale", 1.0))
	scene.scale = Vector3.ONE * s
	holder.set_meta("size", box.size * s)
	# glTF models face +Z; the game's actors face -Z.
	holder.rotation_degrees.y = float(cfg.get("yaw", 180.0))
	var off = cfg.get("offset", null)
	if off is Array and off.size() == 3:
		scene.position += Vector3(off[0], off[1], off[2])
	var player := find_animation_player(scene)
	if player != null:
		holder.set_meta("anim_player", player)
		holder.set_meta("anims", _map_animations(player, cfg.get("anims", {})))
	for mi in holder.find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return holder


static func _load_scene(path: String) -> Node3D:
	if path.begins_with("res://"):
		var res = load(path)
		if res is PackedScene:
			return res.instantiate() as Node3D
		return null
	if path.get_extension() in ["glb", "gltf"]:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			return null
		return doc.generate_scene(state) as Node3D
	return null


static func find_animation_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var p := find_animation_player(c)
		if p != null:
			return p
	return null


## Bounding box of all meshes, in the space of `root`'s parent.
static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var xf := root.transform * _relative(root, m)
		var b := xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## state name -> clip name, from explicit settings or keyword matching.
static func _map_animations(player: AnimationPlayer, explicit: Dictionary) -> Dictionary:
	var out := {}
	var clips := player.get_animation_list()
	for state in ANIM_KEYWORDS:
		if explicit.has(state) and player.has_animation(explicit[state]):
			out[state] = explicit[state]
			continue
		for kw in ANIM_KEYWORDS[state]:
			for c in clips:
				if c.to_lower().contains(kw) and not out.has(state):
					out[state] = c
	for state in ["idle", "walk"]:
		if out.has(state):
			player.get_animation(out[state]).loop_mode = Animation.LOOP_LINEAR
	if not out.has("idle") and not clips.is_empty():
		out["idle"] = clips[0]
	return out


## Plays the clip mapped to a game state, if the model has one. Returns
## false when it doesn't, so callers can fall back.
static func play(model_root: Node3D, state: String, speed := 1.0, restart := false) -> bool:
	if model_root == null or not model_root.has_meta("anim_player"):
		return false
	var anims: Dictionary = model_root.get_meta("anims")
	if not anims.has(state):
		return false
	var p: AnimationPlayer = model_root.get_meta("anim_player")
	var clip: String = anims[state]
	if restart or p.current_animation != clip:
		p.play(clip, 0.15, speed)
		if restart:
			p.seek(0.0, true)
	else:
		p.speed_scale = speed
	return true


static func has_clip(model_root: Node3D, state: String) -> bool:
	return model_root != null and model_root.has_meta("anims") and (model_root.get_meta("anims") as Dictionary).has(state)


## A replacement texture set: {albedo, normal?, roughness?} or {}.
static func texture(name: String) -> Dictionary:
	var albedo := find("textures", name, IMAGE_EXT)
	if albedo == "":
		return {}
	var out := {"albedo": _load_texture(albedo)}
	for suffix in ["normal", "roughness"]:
		var p := find("textures", "%s_%s" % [name, suffix], IMAGE_EXT)
		if p != "":
			out[suffix] = _load_texture(p)
	var cfg := _settings(albedo)
	if cfg.has("width"):
		out["width"] = float(cfg.width)
	if cfg.has("height"):
		out["height"] = float(cfg.height)
	return out if out.albedo != null else {}


static func _load_texture(path: String) -> Texture2D:
	if path.begins_with("res://"):
		return load(path) as Texture2D
	var img := Image.load_from_file(path)
	if img == null:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
