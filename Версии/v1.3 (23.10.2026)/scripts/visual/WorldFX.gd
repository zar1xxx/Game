extends CanvasLayer
## Время суток и погода трассы.
##  • Смена времени суток прямо во время гонки: день → закат → ночь → рассвет.
##    Ночью мир темнеет, а видно только то, что освещено: фонари, фары, вывески, бонусы.
##  • Погода зависит от трассы: снегопад, ливень с молниями, песчаные бури.
## Узел должен стоять в сцене ПЕРВЫМ: он выставляет тему трассы до создания города.

signal phase_changed(phase_name: String)
signal event_message(text: String)

@export var cycle_length: float = 150.0      # длительность полного цикла суток, сек

const PHASES := [
	# [начало (доля цикла), название]
	[0.00, "День"],
	[0.40, "Закат"],
	[0.55, "Ночь"],
	[0.90, "Рассвет"],
]
const MAX_LIGHTS := 40

var location: Dictionary = {}
var cycle_pos: float = 0.0
var darkness: float = 0.0
var _phase_name: String = ""
var _light_rect: ColorRect
var _mat: ShaderMaterial
var _weather: Control
var _t: float = 0.0

# Погода
var _particles: Array = []
var _flash: float = 0.0
var _next_lightning: float = 6.0
var _storm: float = 0.0          # сила песчаной бури 0..1
var _storm_timer: float = 18.0
var _storm_left: float = 0.0

# Фоновые звуки трассы
var _amb_main: AudioStreamPlayer
var _amb_wind: AudioStreamPlayer


func _enter_tree() -> void:
	location = GameData.get_location(SaveManager.selected_location)
	Art.theme = location.theme
	layer = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cycle_pos = location.get("start", 0.0)
	_light_rect = ColorRect.new()
	_light_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_light_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/lighting.gdshader")
	_light_rect.material = _mat
	add_child(_light_rect)
	_weather = Control.new()
	_weather.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather.draw.connect(_draw_weather)
	add_child(_weather)
	_init_particles()
	_update_time(0.0)
	_setup_ambience()


## Шум города, дождь, ветер — в зависимости от трассы
func _setup_ambience() -> void:
	match Art.theme:
		"rain":
			_amb_main = Sound.make_loop(self, "rain", -8.0)
		"winter":
			_amb_wind = Sound.make_loop(self, "wind", -12.0)
		"desert":
			_amb_wind = Sound.make_loop(self, "wind", -16.0)
		_:
			_amb_main = Sound.make_loop(self, "city", -14.0)


func _process(delta: float) -> void:
	var paused := get_tree().paused
	if not paused:
		_t += delta
		_update_time(delta)
		_update_weather(delta)
	_update_lights()
	_weather.queue_redraw()


# ---------------------------------------------------------------------------
# Время суток
# ---------------------------------------------------------------------------
func _update_time(delta: float) -> void:
	var grade := Vector3.ONE
	if location.time == "night":
		darkness = 0.86
	else:
		cycle_pos = fmod(cycle_pos + delta / cycle_length, 1.0)
		var c := cycle_pos
		if c < 0.40:
			darkness = 0.0
		elif c < 0.55:
			var k := (c - 0.40) / 0.15
			darkness = smoothstep(0.0, 1.0, k) * 0.8
			var warm := sin(k * PI)
			grade = Vector3(1.0, 1.0 - 0.22 * warm, 1.0 - 0.4 * warm)
		elif c < 0.90:
			darkness = 0.8
		else:
			var k := (c - 0.90) / 0.10
			darkness = (1.0 - smoothstep(0.0, 1.0, k)) * 0.8
			var pink := sin(k * PI)
			grade = Vector3(1.0, 1.0 - 0.12 * pink, 1.0 - 0.05 * pink)
	# Молния на миг делает ночь светлой
	var dark := darkness * (1.0 - _flash)
	_mat.set_shader_parameter("darkness", dark)
	_mat.set_shader_parameter("grade", grade)
	_mat.set_shader_parameter("rect_size", _light_rect.size)
	Art.night = clampf(darkness / 0.8, 0.0, 1.0)
	var ph := get_phase_name()
	if ph != _phase_name:
		if _phase_name != "":
			phase_changed.emit(ph)
		_phase_name = ph


func get_phase_name() -> String:
	if location.time == "night":
		return "Ночь"
	var n: String = PHASES[0][1]
	for p in PHASES:
		if cycle_pos >= p[0]:
			n = p[1]
	return n


# ---------------------------------------------------------------------------
# Источники света (в экранных координатах)
# ---------------------------------------------------------------------------
func _update_lights() -> void:
	if darkness <= 0.01:
		_mat.set_shader_parameter("light_count", 0)
		_mat.set_shader_parameter("cone", Vector4.ZERO)
		return
	var xf := get_viewport().get_canvas_transform()
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := _light_rect.size
	var lights: Array = []
	var add := func(world_pos: Vector2, radius: float, power: float) -> void:
		var sp: Vector2 = xf * world_pos
		if sp.x > -radius and sp.x < view.x + radius and sp.y > -radius and sp.y < view.y + radius:
			lights.append(Vector4(sp.x, sp.y, radius, power))

	# Фары игрока
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var fwd: Vector2 = -player.global_transform.y.normalized()
		var front: Vector2 = player.global_position + fwd * (player.CAR_LENGTH * 0.5)
		var sp: Vector2 = xf * front
		var tip: Vector2 = xf * (front + fwd * 460.0)
		_mat.set_shader_parameter("cone", Vector4(sp.x, sp.y, tip.x - sp.x, tip.y - sp.y))
		add.call(player.global_position, 95.0, 0.8)
	# Встречные машины: фары светят вниз
	for e in get_tree().get_nodes_in_group("enemies"):
		add.call(e.global_position + Vector2(0, 90), 150.0, 0.9)
		add.call(e.global_position, 70.0, 0.6)
	# Бонусы и ограждения подсвечены, чтобы их было видно в темноте
	for p in get_tree().get_nodes_in_group("pickups"):
		add.call(p.global_position, 70.0, 0.9)
	for o in get_tree().get_nodes_in_group("obstacles"):
		add.call(o.global_position, 120.0, 0.7)
	# Фонари вдоль дороги (те же позиции, что рисует SidewalkLife)
	if Art.theme != "desert":
		var step := 290.0
		var top := cam.global_position.y - view.y
		var y := floorf(top / step) * step
		while y < cam.global_position.y + view.y:
			add.call(Vector2(Art.ROAD_LEFT + 40, y), 170.0, 0.75)
			add.call(Vector2(Art.ROAD_RIGHT - 40, y), 170.0, 0.75)
			y += step
	# Вывески и огни города
	for c in get_tree().get_nodes_in_group("city"):
		for l in c.get_lights():
			add.call(l[0], l[1], l[2])
	if lights.size() > MAX_LIGHTS:
		lights.resize(MAX_LIGHTS)
	var arr := PackedVector4Array()
	for l in lights:
		arr.append(l)
	_mat.set_shader_parameter("lights", arr)
	_mat.set_shader_parameter("light_count", lights.size())


# ---------------------------------------------------------------------------
# Погода
# ---------------------------------------------------------------------------
func _init_particles() -> void:
	var count := 0
	match Art.theme:
		"winter":
			count = 140
		"rain":
			count = 170
		"desert":
			count = 60
	for i in count:
		_particles.append(_new_particle(true))


func _new_particle(anywhere: bool) -> Dictionary:
	var size := get_viewport().get_visible_rect().size
	return {
		"pos": Vector2(randf() * size.x, randf() * size.y if anywhere else randf_range(-60.0, -10.0)),
		"speed": randf_range(0.6, 1.4),
		"phase": randf() * TAU,
		"size": randf_range(1.5, 3.8),
	}


func _player_speed() -> float:
	var player = get_tree().get_first_node_in_group("player")
	return player.current_speed if player else 300.0


func _update_weather(delta: float) -> void:
	var size := _weather.size
	var spd := _player_speed()
	match Art.theme:
		"winter":
			for p in _particles:
				p.pos += Vector2(sin(_t * 1.3 + p.phase) * 25.0, 70.0 + spd * 0.35) * p.speed * delta
		"rain":
			for p in _particles:
				p.pos += Vector2(-120.0, 900.0 + spd * 0.5) * p.speed * delta
			_next_lightning -= delta
			if _next_lightning <= 0.0:
				_next_lightning = randf_range(7.0, 16.0)
				_flash = 1.0
				# Гром приходит чуть позже вспышки
				get_tree().create_timer(randf_range(0.3, 1.2)).timeout.connect(
					func(): Sound.play("thunder", -2.0, randf_range(0.8, 1.1)))
			_flash = move_toward(_flash, 0.0, delta * 2.2)
		"desert":
			_storm_timer -= delta
			if _storm_timer <= 0.0 and _storm_left <= 0.0:
				_storm_left = randf_range(6.0, 9.0)
				event_message.emit("Песчаная буря!")
			if _storm_left > 0.0:
				_storm_left -= delta
				_storm = move_toward(_storm, 1.0, delta * 0.6)
				if _storm_left <= 0.0:
					_storm_timer = randf_range(20.0, 32.0)
			else:
				_storm = move_toward(_storm, 0.0, delta * 0.5)
			if _amb_wind:
				_amb_wind.volume_db = lerpf(-16.0, -2.0, _storm)
				_amb_wind.pitch_scale = 1.0 + 0.3 * _storm
			for p in _particles:
				p.pos += Vector2(-500.0 - 900.0 * _storm, 120.0 + spd * 0.4) * p.speed * delta
	for p in _particles:
		if p.pos.y > size.y + 20 or p.pos.x < -40 or p.pos.x > size.x + 40:
			var np := _new_particle(false)
			if Art.theme == "desert":
				np.pos = Vector2(size.x + 20.0, randf() * size.y)
			p.pos = np.pos


func _draw_weather() -> void:
	var size := _weather.size
	match Art.theme:
		"winter":
			for p in _particles:
				_weather.draw_circle(p.pos, p.size, Color(1, 1, 1, 0.85))
		"rain":
			for p in _particles:
				var dir: Vector2 = Vector2(-0.13, 1.0) * (16.0 + p.size * 6.0)
				_weather.draw_line(p.pos, p.pos + dir, Color(0.75, 0.82, 1.0, 0.35), 1.5)
			if _flash > 0.0:
				var a := _flash * (0.55 if fmod(_flash, 0.3) > 0.12 else 0.25)
				_weather.draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.93, 1.0, a))
		"desert":
			if _storm > 0.0:
				# Песчаная мгла: сверху гуще — впереди почти ничего не видно
				var steps := 8
				for i in steps:
					var y0 := size.y * i / steps
					var a := _storm * (0.75 - 0.6 * float(i) / steps)
					_weather.draw_rect(Rect2(0, y0, size.x, size.y / steps + 1), Color(0.83, 0.66, 0.4, a))
			for p in _particles:
				var len := 10.0 + 40.0 * _storm
				_weather.draw_line(p.pos, p.pos + Vector2(len, -len * 0.12),
					Color(0.95, 0.82, 0.58, 0.25 + 0.4 * _storm), p.size * 0.8)
