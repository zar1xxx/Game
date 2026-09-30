extends CharacterBody2D

# --- Настройки движения ---
@export var max_speed: float = 600.0      # Максимальная скорость
@export var acceleration: float = 200.0   # Постоянное ускорение в секунду
@export var steering_angle: float = 15.0  # Сила поворота (в градусах)
@export var braking_friction: float = 0.95# Трение при торможении/дрифте

# --- Внутренние переменные ---
var current_speed: float = 0.0
var steer_direction: float = 0.0

func _physics_process(delta: float) -> void:
	# 1. Считываем ввод игрока (только руление)
	get_input()

	# 2. Постоянное ускорение вперед
	if current_speed < max_speed:
		current_speed += acceleration * delta
	else:
		current_speed = max_speed

	# 3. Расчет поворота колес
	# Поворачивать можно только в движении
	var turn = steer_direction * deg_to_rad(steering_angle) * (current_speed / max_speed)
	rotation += turn * delta

	# 4. Физика движения и дрифта (Top-Down Physics)
	# Направление, куда смотрит машина
	var forward_velocity = transform.x * current_speed
	
	# Направление, куда машина фактически движется в данный момент
	# Смешиваем текущую скорость и вектор направления для эффекта скольжения
	velocity = velocity.lerp(forward_velocity, braking_friction * delta * 10)

	# Обновляем скорость для расчетов на следующем кадре на основе реального вектора движения
	current_speed = velocity.dot(transform.x)

	# 5. Встроенный метод Godot для перемещения с учетом коллизий
	move_and_slide()

func get_input() -> void:
	steer_direction = 0.0
	if Input.is_action_pressed("ui_left"):
		steer_direction -= 1.0
	if Input.is_action_pressed("ui_right"):
		steer_direction += 1.0
