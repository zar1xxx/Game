extends Node
## Звук и музыка (Autoload "Sound").
##   Sound.play("crash")              — короткий эффект
##   Sound.music("city")              — музыка с плавной сменой трека
##   Sound.make_loop(node, "engine")  — зацикленный звук, привязанный к узлу (мотор, шины, сирена)
##   Sound.set_music_filter(0.5)      — «приглушить» музыку (ночь, пауза): 0 — чисто, 1 — глухо
## Громкость музыки и эффектов хранится в настройках (SaveManager.settings).

const SFX_PATH := "res://audio/sfx/%s.ogg"
const MUSIC_PATH := "res://audio/music/%s.ogg"
const POOL_SIZE := 14

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_track: String = ""
var _lowpass: AudioEffectLowPassFilter
var _filter_target: float = 0.0
var _filter_value: float = 0.0
var _duck_db: float = 0.0
var _last_played: Dictionary = {}     # защита от «пулемёта» одинаковых звуков


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	apply_volumes()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _lowpass)


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


## Громкость из настроек (0..1)
func apply_volumes() -> void:
	var st: Dictionary = SaveManager.settings
	_set_bus_volume("Music", st.get("music_volume", 0.7))
	_set_bus_volume("SFX", st.get("sfx_volume", 0.9))


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(idx, v <= 0.01)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func get_stream(name: String, music: bool = false) -> AudioStream:
	var key := ("m:" if music else "s:") + name
	if not _cache.has(key):
		var path := (MUSIC_PATH if music else SFX_PATH) % name
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


# ---------------------------------------------------------------------------
# Эффекты
# ---------------------------------------------------------------------------
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0, random_pitch: float = 0.06) -> void:
	var stream := get_stream(name)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 40:
		return
	_last_played[name] = now
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-random_pitch, random_pitch)))
	p.play()


## Зацикленный звук, «живущий» в узле (удаляется вместе с ним)
func make_loop(owner_node: Node, name: String, volume_db: float = -80.0) -> AudioStreamPlayer:
	var stream := get_stream(name)
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	if stream:
		var s := stream.duplicate()
		if s is AudioStreamOggVorbis:
			s.loop = true
		p.stream = s
	p.volume_db = volume_db
	p.autoplay = false
	owner_node.add_child(p)
	if stream:
		p.play()
	return p


# ---------------------------------------------------------------------------
# Музыка
# ---------------------------------------------------------------------------
func music(track: String, fade: float = 1.2) -> void:
	if track == _current_track and _music_a.playing:
		return
	_current_track = track
	var stream := get_stream(track, true)
	if stream == null:
		return
	var s := stream.duplicate()
	if s is AudioStreamOggVorbis:
		s.loop = true
	# Новый трек играет в «B», старый в «A» плавно затухает, потом меняем их местами
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = s
	_music_a.volume_db = -40.0
	_music_a.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_music_a, "volume_db", 0.0, fade)
	tw.tween_property(_music_b, "volume_db", -80.0, fade)
	tw.chain().tween_callback(_music_b.stop)


func stop_music(fade: float = 1.0) -> void:
	_current_track = ""
	var tw := create_tween()
	tw.tween_property(_music_a, "volume_db", -80.0, fade)
	tw.tween_callback(_music_a.stop)


## Насколько «глухо» звучит музыка: 0 — обычно, 1 — как из-за стены (пауза, ночь)
func set_music_filter(amount: float) -> void:
	_filter_target = clampf(amount, 0.0, 1.0)


func duck(on: bool) -> void:
	_duck_db = -9.0 if on else 0.0


func _process(delta: float) -> void:
	_filter_value = move_toward(_filter_value, _filter_target, delta * 1.5)
	_lowpass.cutoff_hz = lerpf(20000.0, 700.0, pow(_filter_value, 0.6))
	var idx := AudioServer.get_bus_index("Music")
	var base := linear_to_db(maxf(SaveManager.settings.get("music_volume", 0.7), 0.001))
	AudioServer.set_bus_volume_db(idx, move_toward(AudioServer.get_bus_volume_db(idx), base + _duck_db, delta * 30.0))
