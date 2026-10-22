extends CharacterBody2D

# --- Настройки движения врага ---
@export var max_speed: float = 400.0       
@export var acceleration: float = 100.0     

# --- Тип поведения (задаётся спавнером перед добавлением в сцену) ---
# NORMAL  — обычная машина, едет прямо
# ZIGZAG  — «лихач», виляет из стороны в сторону
# TRUCK   — грузовик: крупнее, медленнее и сильнее отбрасывает игрока
enum Behavior { NORMAL, ZIGZAG, TRUCK }
@export var behavior: Behavior = Behavior.NORMAL
@export var zigzag_amplitude: float = 260.0   # Скорость бокового смещения лихача
@export var zigzag_frequency: float = 2.2

# Границы, за которые «лихач» не уезжает (позиция корня узла по X).
# Спавнер выставляет их по краям дороги; по умолчанию ограничений нет.
var min_x: float = -INF
var max_x: float = INF

# Множитель урона, который получает игрок при столкновении с этой машиной
var damage_multiplier: float = 1.0

var _time: float = 0.0
var _zigzag_phase: float = 0.0

# --- Состояния машины врага ---
enum States { DRIVING, KNOCKBACK, PAUSED, ACCELERATING }
var current_state: States = States.DRIVING

# --- Внутренние переменные ---
var current_speed: float = 800.0

var knockback_timer: SceneTreeTimer = null
var pause_timer: SceneTreeTimer = null

func _ready() -> void:
	add_to_group("enemies")
	_zigzag_phase = randf() * TAU
	match behavior:
		Behavior.ZIGZAG:
			modulate = Color(1.0, 0.85, 0.35)  # жёлтый оттенок
		Behavior.TRUCK:
			max_speed *= 0.55
			damage_multiplier = 1.3
			modulate = Color(0.65, 0.75, 1.0)  # синеватый оттенок
			# Увеличиваем спрайт и коллизию (каждый узел масштабируется вокруг своего центра)
			for child in get_children():
				if child is Node2D:
					child.scale *= 1.6
	current_speed = max_speed

func _physics_process(delta: float) -> void:
	match current_state:
		States.DRIVING:
			current_speed = max_speed
			velocity = Vector2(0, current_speed)
			if behavior == Behavior.ZIGZAG:
				_time += delta
				velocity.x = sin(_time * zigzag_frequency + _zigzag_phase) * zigzag_amplitude
			
		States.KNOCKBACK:
			# Плавно гасим скорость отскока до нуля по обеим осям
			current_speed = move_toward(current_speed, 0.0, 2000.0 * delta)
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			velocity.y = current_speed
			
		States.PAUSED:
			current_speed = 0.0
			velocity = Vector2.ZERO
			
		States.ACCELERATING:
			current_speed = move_toward(current_speed, max_speed, acceleration * delta)
			velocity = Vector2(0, current_speed)

	move_and_slide()
	if behavior == Behavior.ZIGZAG:
		# Не даём лихачу уехать за пределы дороги
		global_position.x = clamp(global_position.x, min_x, max_x)
	keep_clean_outside_screen()

# Функция получения удара (Доработано: зависит от скорости игрока)
func get_hit(push_direction: Vector2 = Vector2.ZERO, player_speed: float = 0.0) -> void:
	current_state = States.KNOCKBACK
	
	# --- РАСЧЕТ ДИНАМИЧЕСКОГО ОТБРОСА ---
	# Базовая минимальная сила отскока (чтобы враг отлетал, даже если игрок ехал медленно)
	var base_knockback = 400.0 
	
	# Вычисляем финальную силу удара: базовое значение + часть от скорости игрока
	# Коэффициент 0.4 можно настроить (чем он выше, тем сильнее влияние скорости игрока)
	var final_force = base_knockback + (player_speed * 0.4)
	if behavior == Behavior.TRUCK:
		final_force *= 0.75  # Грузовик тяжёлый — отлетает слабее
	
	# Вектор скорости отброса: 
	# По Y — со знаком минус (вверх против движения)
	# По X — зависит от нормали столкновения
	current_speed = -final_force
	velocity = Vector2(push_direction.x * final_force, -final_force)
	
	# Таймер текущего отскока
	knockback_timer = get_tree().create_timer(0.3)
	await knockback_timer.timeout
	if current_state == States.KNOCKBACK:
		_enter_paused_state()

func _enter_paused_state() -> void:
	current_state = States.PAUSED
	pause_timer = get_tree().create_timer(0.5)
	await pause_timer.timeout
	if current_state == States.PAUSED:
		_enter_accelerating_state()

func _enter_accelerating_state() -> void:
	current_state = States.ACCELERATING
	current_speed = 0.0
	
	var acceleration_time = max_speed / acceleration
	await get_tree().create_timer(acceleration_time).timeout
	if current_state == States.ACCELERATING:
		current_state = States.DRIVING

func keep_clean_outside_screen() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var screen_size = get_viewport_rect().size
		var zoom = camera.zoom
		var view_height = screen_size.y / zoom.y
		if global_position.y > camera.global_position.y + (view_height / 2.0) + 200.0:
			queue_free()
