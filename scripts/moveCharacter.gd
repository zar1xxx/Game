extends CharacterBody2D

# --- Настройки движения ---
@export var max_speed: float = 3000.0      # Максимальная скорость
@export var acceleration: float = 100.0   # Постоянное ускорение в секунду
@export var steering_angle: float = 1000.0  # Сила поворота (в градусах)
@export var braking_friction: float = 2 # Трение при торможении/дрифте

# --- Внутренние переменные ---
var current_speed: float = 400.0
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
	var turn = steer_direction * deg_to_rad(steering_angle) * (current_speed / max_speed)
	rotation += turn * delta

	# 4. Физика движения и дрифта
	var forward_velocity = -transform.y * current_speed
	velocity = velocity.lerp(forward_velocity, braking_friction * delta * 10)
	current_speed = velocity.dot(-transform.y)

	# 5. Встроенный метод Godot для перемещения с учетом коллизий
	move_and_slide()

	# 6. Ограничение движения границами камеры
	keep_inside_camera()

func get_input() -> void:
	steer_direction = 0.0
	if Input.is_action_pressed("ui_left"):
		steer_direction -= 1.0
	if Input.is_action_pressed("ui_right"):
		steer_direction += 1.0

# Функция удержания машины в экране
func keep_inside_camera() -> void:
	# Получаем текущую активную камеру 2D
	var camera = get_viewport().get_camera_2d()
	
	if camera:
		# Получаем размер экрана игрока
		var screen_size = get_viewport_rect().size
		
		# Вычисляем границы камеры с учетом ее позиции и зума (масштаба)
		var cam_pos = camera.global_position
		var zoom = camera.zoom
		
		# Реальный размер видимой области с учетом зума
		var view_width = screen_size.x / zoom.x
		var view_height = screen_size.y / zoom.y
		
		# Находим крайние точки (лево, право, верх, низ)
		# Сделаем небольшой отступ (например, 32 пикселя), чтобы машина не прилипала центром
		var margin = 32.0 
		var min_x = cam_pos.x - (view_width / 2.0) + margin
		var max_x = cam_pos.x + (view_width / 2.0) - margin
		var min_y = cam_pos.y - (view_height / 2.0) + margin
		var max_y = cam_pos.y + (view_height / 2.0) - margin
		
		# Ограничиваем позицию машины встроенной функцией clamp
		global_position.x = clamp(global_position.x, min_x, max_x)
		global_position.y = clamp(global_position.y, min_y, max_y)
