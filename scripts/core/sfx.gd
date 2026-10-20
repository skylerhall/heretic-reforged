extends Node
## Sound effects synthesised at runtime, so no audio files ship with the game.
## Each definition is a tiny recipe: an oscillator sweeping between two
## pitches, mixed with filtered noise, shaped by an attack/decay envelope.

const RATE := 22050

const DEFS := {
	"staff": {"dur": 0.22, "f0": 220.0, "f1": 90.0, "wave": "tri", "noise": 0.55, "lp": 0.25, "vol": 0.6},
	"staff_hit": {"dur": 0.18, "f0": 140.0, "f1": 60.0, "wave": "square", "noise": 0.5, "lp": 0.3, "vol": 0.7},
	"gauntlets": {"dur": 0.16, "f0": 900.0, "f1": 1300.0, "wave": "saw", "noise": 0.6, "lp": 0.9, "vol": 0.35, "vib": 60.0},
	"wand": {"dur": 0.2, "f0": 1500.0, "f1": 380.0, "wave": "square", "noise": 0.15, "lp": 0.8, "vol": 0.35, "curve": 0.5},
	"crossbow": {"dur": 0.32, "f0": 340.0, "f1": 110.0, "wave": "saw", "noise": 0.35, "lp": 0.4, "vol": 0.5},
	"claw": {"dur": 0.14, "f0": 2100.0, "f1": 700.0, "wave": "square", "noise": 0.3, "lp": 0.9, "vol": 0.3},
	"hellstaff": {"dur": 0.16, "f0": 600.0, "f1": 180.0, "wave": "saw", "noise": 0.3, "lp": 0.6, "vol": 0.4},
	"phoenix": {"dur": 0.5, "f0": 180.0, "f1": 60.0, "wave": "tri", "noise": 0.75, "lp": 0.35, "vol": 0.6},
	"flame": {"dur": 0.12, "f0": 120.0, "f1": 90.0, "wave": "tri", "noise": 0.9, "lp": 0.5, "vol": 0.25},
	"mace": {"dur": 0.2, "f0": 260.0, "f1": 520.0, "wave": "sine", "noise": 0.2, "lp": 0.5, "vol": 0.45},
	"bounce": {"dur": 0.08, "f0": 900.0, "f1": 600.0, "wave": "sine", "noise": 0.1, "lp": 0.5, "vol": 0.25},
	"explode": {"dur": 0.9, "f0": 90.0, "f1": 30.0, "wave": "tri", "noise": 0.85, "lp": 0.12, "vol": 0.9, "decay": 1.6},
	"hit": {"dur": 0.09, "f0": 300.0, "f1": 120.0, "wave": "square", "noise": 0.7, "lp": 0.5, "vol": 0.3},
	"pickup": {"dur": 0.22, "f0": 700.0, "f1": 1400.0, "wave": "sine", "noise": 0.0, "lp": 1.0, "vol": 0.4, "vib": 18.0},
	"weapon_up": {"dur": 0.5, "f0": 300.0, "f1": 900.0, "wave": "tri", "noise": 0.05, "lp": 1.0, "vol": 0.45, "vib": 7.0},
	"artifact": {"dur": 0.6, "f0": 500.0, "f1": 1600.0, "wave": "sine", "noise": 0.0, "lp": 1.0, "vol": 0.4, "vib": 11.0},
	"powerup": {"dur": 1.0, "f0": 200.0, "f1": 800.0, "wave": "saw", "noise": 0.1, "lp": 0.3, "vol": 0.45, "vib": 5.0},
	"door_open": {"dur": 0.9, "f0": 70.0, "f1": 110.0, "wave": "saw", "noise": 0.6, "lp": 0.08, "vol": 0.55, "decay": 0.6},
	"door_close": {"dur": 0.9, "f0": 110.0, "f1": 60.0, "wave": "saw", "noise": 0.6, "lp": 0.08, "vol": 0.55, "decay": 0.6},
	"door_slam": {"dur": 0.3, "f0": 80.0, "f1": 40.0, "wave": "square", "noise": 0.7, "lp": 0.15, "vol": 0.7},
	"lift": {"dur": 1.0, "f0": 55.0, "f1": 65.0, "wave": "saw", "noise": 0.5, "lp": 0.06, "vol": 0.5, "decay": 0.3},
	"switch": {"dur": 0.12, "f0": 500.0, "f1": 200.0, "wave": "square", "noise": 0.4, "lp": 0.6, "vol": 0.45},
	"noway": {"dur": 0.25, "f0": 160.0, "f1": 120.0, "wave": "square", "noise": 0.1, "lp": 0.3, "vol": 0.35},
	"teleport": {"dur": 0.9, "f0": 1600.0, "f1": 200.0, "wave": "sine", "noise": 0.3, "lp": 0.7, "vol": 0.45, "vib": 25.0},
	"pain": {"dur": 0.3, "f0": 260.0, "f1": 160.0, "wave": "saw", "noise": 0.25, "lp": 0.3, "vol": 0.5, "vib": 9.0},
	"death": {"dur": 1.2, "f0": 300.0, "f1": 60.0, "wave": "saw", "noise": 0.3, "lp": 0.25, "vol": 0.6, "vib": 6.0},
	"secret": {"dur": 0.9, "f0": 400.0, "f1": 1200.0, "wave": "tri", "noise": 0.0, "lp": 1.0, "vol": 0.4, "vib": 4.0},
	"gargoyle": {"dur": 0.45, "f0": 1100.0, "f1": 500.0, "wave": "saw", "noise": 0.35, "lp": 0.6, "vol": 0.4, "vib": 30.0},
	"golem": {"dur": 0.8, "f0": 90.0, "f1": 60.0, "wave": "saw", "noise": 0.4, "lp": 0.15, "vol": 0.6, "vib": 5.0},
	"warrior": {"dur": 0.6, "f0": 140.0, "f1": 80.0, "wave": "square", "noise": 0.35, "lp": 0.2, "vol": 0.5, "vib": 3.0},
	"disciple": {"dur": 0.7, "f0": 420.0, "f1": 380.0, "wave": "sine", "noise": 0.2, "lp": 0.4, "vol": 0.4, "vib": 14.0},
	"beast": {"dur": 0.8, "f0": 70.0, "f1": 45.0, "wave": "saw", "noise": 0.5, "lp": 0.12, "vol": 0.7, "vib": 4.0},
	"monster_pain": {"dur": 0.22, "f0": 380.0, "f1": 200.0, "wave": "saw", "noise": 0.3, "lp": 0.35, "vol": 0.45},
	"monster_death": {"dur": 0.9, "f0": 240.0, "f1": 50.0, "wave": "saw", "noise": 0.5, "lp": 0.2, "vol": 0.6},
	"monster_swing": {"dur": 0.2, "f0": 200.0, "f1": 90.0, "wave": "tri", "noise": 0.7, "lp": 0.3, "vol": 0.45},
	"monster_shoot": {"dur": 0.35, "f0": 250.0, "f1": 500.0, "wave": "saw", "noise": 0.4, "lp": 0.3, "vol": 0.45},
	"wings": {"dur": 0.25, "f0": 80.0, "f1": 60.0, "wave": "tri", "noise": 0.8, "lp": 0.1, "vol": 0.35},
}

const MAX_3D_VOICES := 28

var _cache := {}
var _voices_2d: Array[AudioStreamPlayer] = []
var _warm_queue: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices_2d.append(p)
	_warm_queue = DEFS.keys()


func _process(_dt: float) -> void:
	# Build sounds a few per frame at startup so the first shot doesn't hitch.
	for i in 2:
		if _warm_queue.is_empty():
			set_process(false)
			return
		stream(_warm_queue.pop_back())


func stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = _synth(DEFS.get(name, DEFS["hit"]), name.hash())
	return _cache[name]


## Plays a sound. With `at`, it is positioned in the 3D world.
func play(name: String, at = null, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	if not DEFS.has(name):
		return
	var pitch := 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	if at is Vector3 and Game.world != null and is_instance_valid(Game.world):
		var world: Node = Game.world
		if world.get_tree().get_nodes_in_group("sfx3d").size() >= MAX_3D_VOICES:
			return
		var p := AudioStreamPlayer3D.new()
		p.stream = stream(name)
		p.volume_db = volume_db + 4.0
		p.pitch_scale = pitch
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.attenuation_filter_cutoff_hz = 6000.0
		p.add_to_group("sfx3d")
		world.add_child(p)
		p.global_position = at
		p.finished.connect(p.queue_free)
		p.play()
		return
	for v in _voices_2d:
		if not v.playing:
			v.stream = stream(name)
			v.volume_db = volume_db
			v.pitch_scale = pitch
			v.play()
			return


func _synth(d: Dictionary, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(d.dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var noise := 0.0
	var f0: float = d.f0
	var f1: float = d.f1
	var curve: float = d.get("curve", 1.0)
	var vib: float = d.get("vib", 0.0)
	var mix: float = d.noise
	var lp: float = d.lp
	var vol: float = d.vol
	var decay: float = d.get("decay", 1.0)
	var attack := 0.01
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, pow(t, curve))
		if vib > 0.0:
			f *= 1.0 + 0.06 * sin(TAU * vib * i / RATE)
		phase = fmod(phase + f / RATE, 1.0)
		var osc := 0.0
		match d.wave:
			"sine":
				osc = sin(TAU * phase)
			"square":
				osc = 1.0 if phase < 0.5 else -1.0
			"saw":
				osc = phase * 2.0 - 1.0
			_:
				osc = 1.0 - 4.0 * absf(phase - 0.5)
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), lp)
		var env := minf(t / attack, 1.0) * pow(1.0 - t, decay)
		var s := (osc * (1.0 - mix) + noise * mix * 1.6) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
