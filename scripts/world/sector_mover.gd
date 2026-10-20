class_name SectorMover
extends RefCounted
## Moves one sector's floor or ceiling over time (doors, lifts, floors).
## Speeds are map units per second (the original moved 2 units per tic).

enum Kind { DOOR, LIFT, FLOOR }
enum State { OPENING, WAITING, CLOSING, DONE }

const DOOR_SPEED := 70.0
const DOOR_WAIT := 4.2
const LIFT_SPEED := 140.0
const LIFT_WAIT := 3.0

var kind: Kind
var sector := -1
var state: State = State.OPENING
var mode := "owc"
var low := 0.0
var high := 0.0
var target := 0.0
var speed := DOOR_SPEED
var wait := 0.0


static func door(s: int, floor_h: float, top: float, door_mode: String, closing: bool) -> SectorMover:
	var m := SectorMover.new()
	m.kind = Kind.DOOR
	m.sector = s
	m.low = floor_h
	m.high = top
	m.mode = door_mode
	m.state = State.CLOSING if closing else State.OPENING
	return m


static func lift(s: int, bottom: float, top: float) -> SectorMover:
	var m := SectorMover.new()
	m.kind = Kind.LIFT
	m.sector = s
	m.low = bottom
	m.high = top
	m.speed = LIFT_SPEED
	return m


static func floor_move(s: int, to: float, units_per_sec: float) -> SectorMover:
	var m := SectorMover.new()
	m.kind = Kind.FLOOR
	m.sector = s
	m.target = to
	m.speed = units_per_sec
	return m


func key() -> String:
	return "%d:%s" % [sector, "ceil" if kind == Kind.DOOR else "floor"]


func started(w: World) -> void:
	match kind:
		Kind.DOOR:
			_sound(w, "door_open" if state == State.OPENING else "door_close")
		Kind.LIFT, Kind.FLOOR:
			_sound(w, "lift")


## A second press on a manual door reverses it, like the original.
func toggle_door() -> void:
	if state == State.CLOSING:
		state = State.OPENING
	else:
		state = State.CLOSING


## Advances the movement. Returns true when finished.
func update(w: World, dt: float) -> bool:
	var sec: Dictionary = w.map.sectors[sector]
	match kind:
		Kind.DOOR:
			match state:
				State.OPENING:
					sec.ceil = move_toward(sec.ceil, high, speed * dt)
					if sec.ceil >= high:
						if mode == "owc":
							state = State.WAITING
							wait = DOOR_WAIT
						else:
							state = State.DONE
				State.WAITING:
					wait -= dt
					if wait <= 0.0:
						state = State.CLOSING
						_sound(w, "door_close")
				State.CLOSING:
					var next := move_toward(sec.ceil, low, speed * dt)
					if w.ceiling_blocked(sector, next):
						state = State.OPENING
						_sound(w, "door_open")
					else:
						sec.ceil = next
						if sec.ceil <= low:
							_sound(w, "door_slam")
							state = State.DONE
		Kind.LIFT:
			match state:
				State.OPENING:
					sec.floor = move_toward(sec.floor, low, speed * dt)
					if sec.floor <= low:
						state = State.WAITING
						wait = LIFT_WAIT
				State.WAITING:
					wait -= dt
					if wait <= 0.0:
						state = State.CLOSING
						_sound(w, "lift")
				State.CLOSING:
					sec.floor = move_toward(sec.floor, high, speed * dt)
					if sec.floor >= high:
						state = State.DONE
		Kind.FLOOR:
			sec.floor = move_toward(sec.floor, target, speed * dt)
			if is_equal_approx(sec.floor, target):
				state = State.DONE
	w.sector_changed(sector)
	return state == State.DONE


func _sound(w: World, name: String) -> void:
	var tris: PackedVector2Array = w.geo.sector_tris[sector]
	if tris.is_empty():
		return
	var r: Rect2 = w.geo.sector_bounds[sector]
	var sec: Dictionary = w.map.sectors[sector]
	Sfx.play(name, GeometryBuilder.to_world(r.get_center(), (sec.floor + sec.ceil) * 0.5))
