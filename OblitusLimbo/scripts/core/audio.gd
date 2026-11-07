extends Node
## Áudio: músicas em loop com crossfade + camadas sincronizadas; efeitos com variações.
## Arquivos gerados por tools/synth_audio.py em res://assets/audio/.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"

var vol := {"Master": 0.8, "Music": 0.6, "SFX": 0.9}
var current := ""
var _tracks := {}             # nome -> {main: AudioStreamPlayer, layers: {nome: player}}
var _layers_on := {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _sfx_cache := {}
var _loops := {}
var _fades: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 28:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		for n in ["Music", "SFX"]:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")
			var rv := AudioEffectReverb.new()
			rv.room_size = 0.7 if n == "Music" else 0.5
			rv.wet = 0.18 if n == "Music" else 0.12
			rv.dry = 1.0
			rv.damping = 0.5
			AudioServer.add_bus_effect(i, rv)
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -0.5
		lim.threshold_db = -4.0
		AudioServer.add_bus_effect(0, lim)
	for b in vol:
		set_volume(b, vol[b])

func set_volume(bus: String, v: float) -> void:
	vol[bus] = v
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(max(v, 0.0001)))

func _load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		var bytes_per := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
		w.loop_end = w.data.size() / bytes_per
	elif s is AudioStreamOggVorbis:
		s.loop = true
	return s

func _track(name: String) -> Dictionary:
	if _tracks.has(name):
		return _tracks[name]
	var tr := {"main": null, "layers": {}}
	var main := _load(MUSIC_DIR + name + ".wav")
	if main:
		var p := AudioStreamPlayer.new()
		p.stream = main
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		tr.main = p
		for layer in ["harmonic", "viktor", "intense"]:
			var ls := _load(MUSIC_DIR + name + "__" + layer + ".wav")
			if ls:
				var lp := AudioStreamPlayer.new()
				lp.stream = ls
				lp.bus = "Music"
				lp.volume_db = -80.0
				add_child(lp)
				tr.layers[layer] = lp
	_tracks[name] = tr
	return tr

func music(name: String, fade := 1.5) -> void:
	if name == current:
		return
	if current != "" and _tracks.has(current):
		var old: Dictionary = _tracks[current]
		if old.main:
			_fade(old.main, -80.0, fade, true)
		for l in old.layers.values():
			_fade(l, -80.0, fade, true)
	current = name
	var tr := _track(name)
	if tr.main:
		tr.main.play()
		_fade(tr.main, 0.0, fade, false)
		for k in tr.layers:
			var lp: AudioStreamPlayer = tr.layers[k]
			lp.play()
			_fade(lp, 0.0 if _layers_on.get(k, false) else -80.0, fade, false)

func set_layer(layer: String, on: bool, fade := 1.2) -> void:
	_layers_on[layer] = on
	if _tracks.has(current):
		var lp = _tracks[current].layers.get(layer)
		if lp:
			_fade(lp, 0.0 if on else -80.0, fade, false)

func intensity(v: float) -> void:
	set_layer("intense", v > 0.5)

func _fade(p: AudioStreamPlayer, to_db: float, dur: float, stop_after: bool, free_after := false) -> void:
	for f in _fades:
		if f.p == p:
			_fades.erase(f)
			break
	_fades.append({"p": p, "from": p.volume_db, "to": to_db, "t": 0.0, "dur": max(dur, 0.01), "stop": stop_after, "free": free_after})

func _process(_delta: float) -> void:
	var dt := 1.0 / 60.0
	if Engine.has_singleton("Game") or true:
		dt = get_node("/root/Game").real_dt() if has_node("/root/Game") else _delta
	for f in _fades.duplicate():
		if not is_instance_valid(f.p):
			_fades.erase(f)
			continue
		f.t += dt
		var k: float = min(1.0, f.t / f.dur)
		# interpola em amplitude para um fade natural
		var a: float = lerp(db_to_linear(f.from), db_to_linear(f.to), k)
		f.p.volume_db = linear_to_db(max(a, 0.00001))
		if k >= 1.0:
			_fades.erase(f)
			if f.stop:
				f.p.stop()
			if f.free:
				f.p.queue_free()

func sfx(name: String, v := 1.0, pitch := 1.0) -> void:
	var list: Array = _sfx_cache.get(name, [])
	if not _sfx_cache.has(name):
		for k in range(1, 6):
			var path := SFX_DIR + "%s_%d.wav" % [name, k]
			if ResourceLoader.exists(path):
				list.append(load(path))
		_sfx_cache[name] = list
	if list.is_empty():
		return
	var p := _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = list[randi() % list.size()]
	p.volume_db = linear_to_db(max(v, 0.0001))
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()

func chord(i: int) -> void:
	sfx("chord%d" % (i % 4))

func loop(name: String, on: bool, v := 1.0) -> void:
	if on:
		if _loops.has(name):
			_fade(_loops[name], linear_to_db(v), 0.5, false)
			return
		var s := _load(SFX_DIR + "loop_" + name + ".wav")
		if s == null:
			return
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.bus = "SFX"
		p.volume_db = -80.0
		add_child(p)
		p.play()
		_loops[name] = p
		_fade(p, linear_to_db(v), 1.0, false)
	elif _loops.has(name):
		var p: AudioStreamPlayer = _loops[name]
		_loops.erase(name)
		_fade(p, -80.0, 1.0, true, true)

func stop_loops() -> void:
	for k in _loops.keys():
		loop(k, false)
