extends CharacterBody2D
## Встречная машина. Рисуется кодом в общем стиле (Art.gd).

# --- Настройки движения ---
@export var max_speed: float = 230.0
@export var acceleration: float = 120.0

# --- Тип поведения (задаётся спавнером перед добавлением в сцену) ---
# NORMAL  — обычная машина, едет прямо по своей полосе
# ZIGZAG  — «лихач», красная спортивная машина, виляет между полосами
# TRUCK   — грузовик: длинный, медленный, удар о него больнее
enum Behavior { NORMAL, ZIGZAG, TRUCK }
@export var behavior: Behavior = Behavior.NORMAL
@export var zigzag_amplitude: float = 170.0
@export var zigzag_frequency: float = 1.8

# Множитель урона, который получает игрок при столкновении с этой машиной
var damage_multiplier: float = 1.0
var body_color: Color = Art.BLUE

enum States { DRIVING, KNOCKBACK, PAUSED, ACCELERATING }
var current_state: States = States.DRIVING
var current_speed: float = 240.0

var _time: float = 0.0
var _zigzag_phase: float = 0.0
var _spin: float = 0.0          # Визуальный разворот после удара
var _spin_speed: float = 0.0
var _target_x: float = NAN     # полоса, на которую машина уходит после удара
var _blocked: bool = false     # стоит перед ограждением
var _length: float = 100.0
var _width: float = 50.0
var _marshrutka: bool = false   # в Омске «лихачи» — это маршрутки
var _honked: bool = false
var phase_preset: float = NAN   # фаза виляния «лихача» (задаёт спавнер, чтобы трафик повторялся)
var no_yield: bool = false      # фуры колонны не разъезжаются даже перед мигалкой
var _player: Node2D = null
var _yielded: bool = false
# Картинка машины рисуется один раз в отдельный дочерний узел и перерисовывается,
# только когда что-то меняется (аварийка, цвет, освещение). Разворот после удара — поворотом узла.
var _vis: Node2D
var _d_hazard: bool = false
var _d_blink: bool = false
var _d_night: int = -1
var _d_color: Color = Color.TRANSPARENT


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING   # режим для вида сверху
	# Встречные машины останавливаются перед ограждениями (слой 2), а не проезжают сквозь них
	set_collision_mask_value(2, true)
	_zigzag_phase = phase_preset if not is_nan(phase_preset) else randf() * TAU
	body_color = Art.ENEMY_COLORS[randi() % Art.ENEMY_COLORS.size()]
	match behavior:
		Behavior.ZIGZAG:
			body_color = Art.RED
			max_speed *= 1.15
			if Art.theme == "omsk":
				_marshrutka = true
				body_color = Color("f2c230")
				_length = 136.0
				_width = 56.0
		Behavior.TRUCK:
			_length = 190.0
			_width = 66.0
			max_speed *= 0.6
			damage_multiplier = 1.3
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_width - 4, _length - 6)
	$CollisionShape2D.shape = shape
	current_speed = max_speed
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_vis = Node2D.new()
	_vis.draw.connect(_draw_vis)
	add_child(_vis)
	_update_visual()


func _physics_process(delta: float) -> void:
	_time += delta
	match current_state:
		States.DRIVING:
			current_speed = max_speed
			velocity = Vector2(0, current_speed)
			if behavior == Behavior.ZIGZAG:
				velocity.x = sin(_time * zigzag_frequency + _zigzag_phase) * zigzag_amplitude
		States.KNOCKBACK:
			current_speed = move_toward(current_speed, 0.0, 1600.0 * delta)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			velocity.y = current_speed
		States.PAUSED:
			current_speed = 0.0
			velocity = Vector2.ZERO
		States.ACCELERATING:
			current_speed = move_toward(current_speed, max_speed, acceleration * delta)
			velocity = Vector2(0, current_speed)

	# Мигалка у игрока: машины впереди на его полосе уходят в сторону
	if not _yielded and not no_yield and _player and is_instance_valid(_player) and _player.siren_left > 0.0 \
			and is_nan(_target_x) and current_state == States.DRIVING:
		var dy := _player.global_position.y - global_position.y
		if dy > 0.0 and dy < 1150.0 and absf(global_position.x - _player.global_position.x) < Art.LANE_W * 0.85:
			_yield_lane()

	# После удара машина плавно перестраивается на соседнюю полосу
	if not is_nan(_target_x) and current_state != States.KNOCKBACK:
		velocity.x = clampf((_target_x - global_position.x) * 4.0, -260.0, 260.0)
		if absf(_target_x - global_position.x) < 3.0:
			_target_x = NAN

	# Визуальное вращение после удара постепенно затухает
	_spin += _spin_speed * delta
	_spin_speed = move_toward(_spin_speed, 0.0, 6.0 * delta)
	if current_state == States.DRIVING or current_state == States.ACCELERATING:
		_spin = move_toward(_spin, 0.0, 1.5 * delta)

	move_and_slide()
	_blocked = false
	for i in get_slide_collision_count():
		var c = get_slide_collision(i).get_collider()
		if c and c.is_in_group("obstacles"):
			_blocked = true
	# Машины не выезжают за бордюры
	var half := _width / 2.0 + 14.0
	global_position.x = clampf(global_position.x, Art.ROAD_LEFT + half, Art.ROAD_RIGHT - half)
	keep_clean_outside_screen()
	_maybe_honk()
	_update_visual()


func _update_visual() -> void:
	if _vis == null:
		return
	_vis.rotation = _spin
	var hazard := behavior == Behavior.NORMAL and (current_state != States.DRIVING or _blocked)
	var blink := hazard and fmod(_time, 0.8) < 0.4
	var nq := int(Art.night * 20.0)
	if hazard != _d_hazard or blink != _d_blink or nq != _d_night or body_color != _d_color:
		_d_hazard = hazard
		_d_blink = blink
		_d_night = nq
		_d_color = body_color
		_vis.queue_redraw()


## Лихачи сигналят, когда проносятся рядом с игроком
func _maybe_honk() -> void:
	if _honked or behavior != Behavior.ZIGZAG:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and absf(player.global_position.y - global_position.y) < 420.0:
		_honked = true
		Sound.play("horn", -9.0, 1.25 if _marshrutka else 1.05)


func _draw_vis() -> void:
	# Время подбирается так, чтобы аварийка рисовалась в том же состоянии, что запомнено в _d_blink
	var opts := {"flip": true, "lights": true, "time": 0.0 if _d_blink else 0.5}
	match behavior:
		Behavior.TRUCK:
			Art.draw_truck(_vis, _length, _width, body_color, Art.SILVER, opts)
		Behavior.ZIGZAG when _marshrutka:
			opts.base = Transform2D(PI, Vector2.ZERO)
			opts.erase("flip")
			Art.draw_marshrutka(_vis, _length, _width, body_color, opts)
		Behavior.ZIGZAG:
			opts.stripes = true
			opts.spoiler = true
			Art.draw_car(_vis, _length, _width, body_color, opts)
		_:
			opts.hazard = _d_hazard
			Art.draw_car(_vis, _length, _width, body_color, opts)


## Удар от игрока: машину отбрасывает вперёд (вверх) и в сторону, после чего она
## ненадолго останавливается и снова разгоняется.
## Удар от игрока: машину отбрасывает вперёд (вверх) и в сторону ОТ игрока,
## после чего она уходит на соседнюю полосу, освобождая игроку дорогу.
func get_hit(_push_direction: Vector2 = Vector2.ZERO, player_speed: float = 0.0) -> void:
	current_state = States.KNOCKBACK
	var final_force := 380.0 + player_speed * 0.35
	if behavior == Behavior.TRUCK:
		final_force *= 0.7  # Грузовик тяжёлый — отлетает слабее
	var side := 1.0 if randf() < 0.5 else -1.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and absf(global_position.x - player.global_position.x) > 6.0:
		side = signf(global_position.x - player.global_position.x)
	# Соседняя полоса в сторону отлёта (у края дороги — в другую сторону)
	var lane := clampi(int((global_position.x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)
	var new_lane := lane + int(side)
	if new_lane < 0 or new_lane >= Art.LANES:
		new_lane = lane - int(side)
		side = -side
	_target_x = Art.ROAD_LEFT + Art.LANE_W * (new_lane + 0.5)
	current_speed = -final_force
	velocity = Vector2(side * final_force * 0.6, -final_force)
	_spin_speed = side * 4.0
	await get_tree().create_timer(0.3, false).timeout
	if current_state == States.KNOCKBACK:
		_enter_paused_state()


func _yield_lane() -> void:
	_yielded = true
	var lane := clampi(int((global_position.x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)
	var p_lane := clampi(int((_player.global_position.x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)
	var side := signf(global_position.x - _player.global_position.x)
	if side == 0.0:
		side = 1.0 if randf() < 0.5 else -1.0
	for nl in [lane + int(side), lane - int(side), lane + 2 * int(side)]:
		if nl >= 0 and nl < Art.LANES and nl != p_lane:
			_target_x = Art.ROAD_LEFT + Art.LANE_W * (nl + 0.5)
			zigzag_amplitude = 0.0              # лихач тоже перестаёт вилять
			return


func _enter_paused_state() -> void:
	current_state = States.PAUSED
	await get_tree().create_timer(0.6, false).timeout
	if current_state == States.PAUSED:
		_enter_accelerating_state()


func _enter_accelerating_state() -> void:
	current_state = States.ACCELERATING
	current_speed = 0.0
	await get_tree().create_timer(max_speed / acceleration, false).timeout
	if current_state == States.ACCELERATING:
		current_state = States.DRIVING


func keep_clean_outside_screen() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and global_position.y > camera.global_position.y + Art.half_view_h() + 260.0:
		queue_free()
