class_name LineSpecials
## Linedef specials: doors, lifts, floors, stairs, teleports and exits.
## Numbers follow Heretic (which shares most of them with Doom).
## trig: "use" (press E on it), "cross" (walk over it), "shoot".

const TABLE := {
	# manual doors (open the sector on the far side of the line)
	1: {"trig": "use", "repeat": true, "act": "door_manual", "mode": "owc"},
	26: {"trig": "use", "repeat": true, "act": "door_manual", "mode": "owc", "key": "blue"},
	27: {"trig": "use", "repeat": true, "act": "door_manual", "mode": "owc", "key": "yellow"},
	28: {"trig": "use", "repeat": true, "act": "door_manual", "mode": "owc", "key": "green"},
	31: {"trig": "use", "repeat": false, "act": "door_manual", "mode": "open"},
	32: {"trig": "use", "repeat": false, "act": "door_manual", "mode": "open", "key": "blue"},
	33: {"trig": "use", "repeat": false, "act": "door_manual", "mode": "open", "key": "green"},
	34: {"trig": "use", "repeat": false, "act": "door_manual", "mode": "open", "key": "yellow"},
	# tagged doors
	2: {"trig": "cross", "repeat": false, "act": "door", "mode": "open"},
	3: {"trig": "cross", "repeat": false, "act": "door", "mode": "close"},
	4: {"trig": "cross", "repeat": false, "act": "door", "mode": "owc"},
	16: {"trig": "cross", "repeat": false, "act": "door", "mode": "close"},
	29: {"trig": "use", "repeat": false, "act": "door", "mode": "owc"},
	42: {"trig": "use", "repeat": true, "act": "door", "mode": "close"},
	46: {"trig": "shoot", "repeat": true, "act": "door", "mode": "open"},
	50: {"trig": "use", "repeat": false, "act": "door", "mode": "close"},
	61: {"trig": "use", "repeat": true, "act": "door", "mode": "open"},
	63: {"trig": "use", "repeat": true, "act": "door", "mode": "owc"},
	75: {"trig": "cross", "repeat": true, "act": "door", "mode": "close"},
	76: {"trig": "cross", "repeat": true, "act": "door", "mode": "close"},
	86: {"trig": "cross", "repeat": true, "act": "door", "mode": "open"},
	90: {"trig": "cross", "repeat": true, "act": "door", "mode": "owc"},
	103: {"trig": "use", "repeat": false, "act": "door", "mode": "open"},
	# lifts
	10: {"trig": "cross", "repeat": false, "act": "lift"},
	21: {"trig": "use", "repeat": false, "act": "lift"},
	62: {"trig": "use", "repeat": true, "act": "lift"},
	88: {"trig": "cross", "repeat": true, "act": "lift"},
	# floors
	5: {"trig": "cross", "repeat": false, "act": "floor", "mode": "raise_lowest_ceiling"},
	91: {"trig": "cross", "repeat": true, "act": "floor", "mode": "raise_lowest_ceiling"},
	101: {"trig": "use", "repeat": false, "act": "floor", "mode": "raise_lowest_ceiling"},
	19: {"trig": "cross", "repeat": false, "act": "floor", "mode": "lower_highest"},
	83: {"trig": "cross", "repeat": true, "act": "floor", "mode": "lower_highest"},
	102: {"trig": "use", "repeat": false, "act": "floor", "mode": "lower_highest"},
	36: {"trig": "cross", "repeat": false, "act": "floor", "mode": "lower_highest8"},
	70: {"trig": "use", "repeat": true, "act": "floor", "mode": "lower_highest8"},
	71: {"trig": "use", "repeat": false, "act": "floor", "mode": "lower_highest8"},
	98: {"trig": "cross", "repeat": true, "act": "floor", "mode": "lower_highest8"},
	23: {"trig": "use", "repeat": false, "act": "floor", "mode": "lower_lowest"},
	38: {"trig": "cross", "repeat": false, "act": "floor", "mode": "lower_lowest"},
	60: {"trig": "use", "repeat": true, "act": "floor", "mode": "lower_lowest"},
	82: {"trig": "cross", "repeat": true, "act": "floor", "mode": "lower_lowest"},
	18: {"trig": "use", "repeat": false, "act": "floor", "mode": "raise_next"},
	20: {"trig": "use", "repeat": false, "act": "floor", "mode": "raise_next"},
	22: {"trig": "cross", "repeat": false, "act": "floor", "mode": "raise_next"},
	47: {"trig": "shoot", "repeat": false, "act": "floor", "mode": "raise_next"},
	68: {"trig": "use", "repeat": true, "act": "floor", "mode": "raise_next"},
	69: {"trig": "use", "repeat": true, "act": "floor", "mode": "raise_next"},
	# stairs
	7: {"trig": "use", "repeat": false, "act": "stairs", "step": 8.0},
	8: {"trig": "cross", "repeat": false, "act": "stairs", "step": 8.0},
	106: {"trig": "cross", "repeat": false, "act": "stairs", "step": 16.0},
	107: {"trig": "use", "repeat": false, "act": "stairs", "step": 16.0},
	# exits and teleports
	11: {"trig": "use", "repeat": false, "act": "exit"},
	52: {"trig": "cross", "repeat": false, "act": "exit"},
	51: {"trig": "use", "repeat": false, "act": "secret_exit"},
	105: {"trig": "cross", "repeat": false, "act": "secret_exit"},
	39: {"trig": "cross", "repeat": false, "act": "teleport"},
	97: {"trig": "cross", "repeat": true, "act": "teleport"},
}

const KEY_NAMES := {"green": "GREEN", "blue": "BLUE", "yellow": "YELLOW"}


static func info(special: int) -> Dictionary:
	return TABLE.get(special, {})


static func activate(w: World, li: int, trig: String, who: Node, from_front := true) -> bool:
	var line: Dictionary = w.map.lines[li]
	var inf := info(line.special)
	if inf.is_empty() or inf.trig != trig:
		return false
	if not (who is Player):
		return false
	var p: Player = who
	if not inf.repeat and w.used_once.has(li):
		return false
	if inf.has("key") and not p.keys.get(inf.key, false):
		p.show_message("YOU NEED A %s KEY TO OPEN THIS DOOR" % KEY_NAMES[inf.key])
		Sfx.play("noway")
		return false
	var ok := false
	match inf.act:
		"door_manual":
			ok = _manual_door(w, line, inf, p)
		"door":
			for s in w.tag_sectors.get(line.tag, []):
				ok = _tagged_door(w, s, inf.mode) or ok
		"lift":
			for s in w.tag_sectors.get(line.tag, []):
				ok = _lift(w, s) or ok
		"floor":
			for s in w.tag_sectors.get(line.tag, []):
				ok = _floor(w, s, inf.mode) or ok
		"stairs":
			for s in w.tag_sectors.get(line.tag, []):
				ok = _stairs(w, s, inf.step) or ok
		"exit":
			w.exit_level(false)
			ok = true
		"secret_exit":
			w.exit_level(true)
			ok = true
		"teleport":
			if from_front:
				ok = w.teleport(p, line.tag)
	if ok:
		if not inf.repeat:
			w.used_once[li] = true
		if trig == "use":
			flip_switch(w, li, inf.repeat)
	return ok


static func _manual_door(w: World, line: Dictionary, inf: Dictionary, p: Player) -> bool:
	var v1 := w.map.vertices[line.v1]
	var v2 := w.map.vertices[line.v2]
	var pos := World.to_map(p.global_position)
	var on_front := (v2 - v1).cross(pos - v1) <= 0.0
	var s := w.map.back_sector(line) if on_front else w.map.front_sector(line)
	if s < 0:
		return false
	var existing: SectorMover = w.movers.get("%d:ceil" % s)
	if existing != null:
		if inf.mode == "owc":
			existing.toggle_door()
		return true
	var sec: Dictionary = w.map.sectors[s]
	var top := w.lowest_neighbor_ceiling(s) - 4.0
	if top <= sec.floor or sec.ceil >= top:
		return false
	_start(w, SectorMover.door(s, sec.floor, top, inf.mode, false))
	return true


static func _tagged_door(w: World, s: int, mode: String) -> bool:
	if w.movers.has("%d:ceil" % s):
		return false
	var sec: Dictionary = w.map.sectors[s]
	var top := w.lowest_neighbor_ceiling(s) - 4.0
	if mode == "close":
		if sec.ceil <= sec.floor:
			return false
		_start(w, SectorMover.door(s, sec.floor, sec.ceil, mode, true))
		return true
	if top <= sec.ceil:
		return false
	_start(w, SectorMover.door(s, sec.floor, top, mode, false))
	return true


static func _lift(w: World, s: int) -> bool:
	if w.movers.has("%d:floor" % s):
		return false
	var sec: Dictionary = w.map.sectors[s]
	var low := w.lowest_neighbor_floor(s)
	if low >= sec.floor:
		return false
	_start(w, SectorMover.lift(s, low, sec.floor))
	return true


static func _floor(w: World, s: int, mode: String) -> bool:
	if w.movers.has("%d:floor" % s):
		return false
	var sec: Dictionary = w.map.sectors[s]
	var target: float = sec.floor
	var speed := 35.0
	match mode:
		"raise_lowest_ceiling":
			target = minf(w.lowest_neighbor_ceiling(s), sec.ceil)
		"lower_highest":
			target = w.highest_neighbor_floor(s)
		"lower_highest8":
			target = w.highest_neighbor_floor(s) + 8.0
			speed = 140.0
		"lower_lowest":
			target = w.lowest_neighbor_floor(s)
		"raise_next":
			target = w.next_higher_floor(s)
	if is_equal_approx(target, sec.floor):
		return false
	_start(w, SectorMover.floor_move(s, target, speed))
	return true


static func _stairs(w: World, s: int, step: float) -> bool:
	var chain := stair_chain(w.map, s)
	var h: float = w.map.sectors[s].floor
	var started := false
	for c in chain:
		h += step
		if w.movers.has("%d:floor" % c):
			continue
		_start(w, SectorMover.floor_move(c, h, 35.0))
		started = true
	return started


## The sectors a stair builder raises: from `start`, follow front-facing
## lines into neighbours that share the start sector's floor texture.
static func stair_chain(m: MapData, start: int) -> Array:
	var chain := [start]
	var flat: String = m.sectors[start].floor_tex
	var cur := start
	var guard := 0
	while guard < 64:
		guard += 1
		var next := -1
		for line in m.lines:
			if line.front < 0 or line.back < 0 or m.front_sector(line) != cur:
				continue
			var b := m.back_sector(line)
			if b in chain or m.sectors[b].floor_tex != flat:
				continue
			next = b
			break
		if next < 0:
			break
		chain.append(next)
		cur = next
	return chain


static func _start(w: World, m: SectorMover) -> void:
	w.movers[m.key()] = m
	m.started(w)


## Swaps SWxxOFF <-> SWxxON style textures on the line's front side.
static func flip_switch(w: World, li: int, revert: bool) -> void:
	var line: Dictionary = w.map.lines[li]
	if line.front < 0:
		return
	var side: Dictionary = w.map.sides[line.front]
	var changed := false
	for field in ["upper", "middle", "lower"]:
		var n: String = side[field]
		var swapped := ""
		if n.ends_with("OFF"):
			swapped = n.substr(0, n.length() - 3) + "ON"
		elif n.ends_with("ON"):
			swapped = n.substr(0, n.length() - 2) + "OFF"
		elif n.begins_with("SW1"):
			swapped = "SW2" + n.substr(3)
		elif n.begins_with("SW2"):
			swapped = "SW1" + n.substr(3)
		if swapped != "" and w.tex.has_wall(swapped):
			side[field] = swapped
			changed = true
	if not changed:
		return
	Sfx.play("switch", GeometryBuilder.to_world((w.map.vertices[line.v1] + w.map.vertices[line.v2]) * 0.5, w.map.sectors[side.sector].floor + 32.0))
	var gid := w._group_for_line(li)
	if gid != "":
		w.dirty_groups[gid] = true
	if revert:
		w.switch_reverts.append([1.0, li])
