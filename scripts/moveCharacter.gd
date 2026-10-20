extends CharacterBody2D

# --- Ссылка на экран Game Over (Добавить к остальным @onready переменным вверху) ---
@onready var game_over_screen: Control = %GameOverScreen
@onready var sprite: Sprite2D = $Sprite2D

# --- Настройки топлива (Добавить в начало скрипта к переменным) ---
@export var max_fuel: float = 100.0
@export var fuel_consumption_rate: float = 10.0 # Базовый расход топлива в секунду
@onready var fuel_bar: ProgressBar = %FuelBar

var current_fuel: float = 100.0
# --- Настройки движения ---
@export var max_speed: float = 3000.0      # Максимальная скорость
@export var acceleration: float = 200.0   # Постоянное ускорение в секунду
@export var steering_angle: float = 1000.0  # Сила поворота (в градусах)
@export var braking_friction: float = 2.0 # Трение при торможении/дрифте

# --- Настройки прочности (Новое) ---
@export var max_health: float = 100.0      # Максимальная прочность машины
@export var damage_divider: float = 15.0   # Делитель урона (чем выше, тем меньше урона наносится при ударе)

# --- Ссылки на интерфейс (Новое) ---
@onready var health_bar: ProgressBar = %HealthBar

@export var post_hit_invulnerability_time: float = 0.3 # Время неуязвимости в секундах (например, полсекунды)
var is_invulnerable: bool = false # Защищен ли игрок в данный момент

@export var fast_acceleration: float = 1000.0 # Временное ускорение после аварии (обычное 100.0)
@export var fast_accel_duration: float = 1.5  # Сколько секунд действует быстрое ускорение

var active_acceleration: float = 100.0       # Текущее рабочее ускорение
var is_fast_accelerating: bool = false       # Активен ли режим быстрого разгона

# --- Ограничение урона за один удар ---
# Раньше на большой скорости любое столкновение убивало мгновенно (3000 / 15 = 200 урона),
# из-за чего полоска прочности и гаечные ключи теряли смысл.
@export var max_damage_per_hit: float = 45.0
@export var min_damage_per_hit: float = 8.0

# --- Масляное пятно (занос) ---
@export var slip_grip_multiplier: float = 0.12   # Во сколько раз падает сцепление на масле
@export var slip_spin_speed: float = 0.8         # Скорость самопроизвольного разворота (рад/с)
var slip_time_left: float = 0.0
var slip_spin_dir: float = 1.0

# --- Нитро ---
@export var nitro_speed_multiplier: float = 1.35
@export var nitro_acceleration: float = 1800.0
var nitro_time_left: float = 0.0

var is_dead: bool = false


# --- Внутренние переменные ---
var current_speed: float = 400.0
var steer_direction: float = 0.0
var current_health: float = 100.0         # Текущее здоровье машины (Новое)

func _ready() -> void:
	add_to_group("player")
	# Слой 2 — твёрдые препятствия (ограждения). Игрок с ними сталкивается, встречные машины — нет.
	set_collision_mask_value(2, true)
	active_acceleration = acceleration # По умолчанию используем обычное ускорение
	
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	current_fuel = max_fuel
	if fuel_bar:
		fuel_bar.max_value = max_fuel
		fuel_bar.value = current_fuel
		
	if game_over_screen:
		game_over_screen.hide() # На всякий случай скрываем при старте
		# Кнопки экрана проигрыша теперь обрабатывает скрипт GameOver.gd



func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1. Считываем ввод игрока (только руление)
	get_input()

	# Таймеры эффектов
	var effective_max_speed := max_speed
	var accel := active_acceleration
	if nitro_time_left > 0.0:
		nitro_time_left -= delta
		effective_max_speed = max_speed * nitro_speed_multiplier
		accel = max(accel, nitro_acceleration)
		if nitro_time_left <= 0.0:
			sprite.modulate = Color.WHITE
	var grip := braking_friction
	if slip_time_left > 0.0:
		slip_time_left -= delta
		grip *= slip_grip_multiplier
		rotation += slip_spin_dir * slip_spin_speed * delta

	# 2. Постоянное ускорение вперед (после нитро скорость плавно возвращается к норме)
	if current_speed < effective_max_speed:
		current_speed = min(current_speed + accel * delta, effective_max_speed)
	else:
		current_speed = move_toward(current_speed, effective_max_speed, 800.0 * delta)


		# 3. Расчет поворота колес (Доработано)
	# Машина может поворачивать только если она реально движется вперед (скорость больше 50)
	if current_speed > 50.0:
		var turn = steer_direction * deg_to_rad(steering_angle) * (current_speed / max_speed)
		rotation += turn * delta
	else:
		# Если машина стоит или только начинает трогаться, руль заблокирован,
		# и вращение узла не будет толкать и разворачивать стоящего врага
		pass


		# 4. Физика движения и дрифта (Доработано: мягкая потеря скорости в повороте)
	var forward_velocity = -transform.y * current_speed
	velocity = velocity.lerp(forward_velocity, clamp(grip * delta * 10, 0.0, 1.0))
	
	# Вычисляем физическую скорость с учетом угла заноса
	var drift_speed = velocity.dot(-transform.y)
	
	# --- НАСТРОЙКА ПЛАВНОСТИ (Новое) ---
	# Коэффициент удержания скорости: 0.0 — скорость вообще не падает, 1.0 — падает как раньше.
	# Значение 0.3 означает, что машина потеряет лишь 30% от стандартного падения скорости.
	var turn_resistance: float = 0.5
	
	# Плавно смешиваем полную текущую скорость и скорость с учетом заноса
	var calculated_speed = lerp(current_speed, drift_speed, turn_resistance)
	
	# Записываем результат, не позволяя скорости уйти в минус
	current_speed = max(0.0, calculated_speed)


	# 5. Встроенный метод Godot для перемещения с учетом коллизий
	move_and_slide()

	# 6. Проверка столкновений со встречными машинами (Новое)
	check_collisions()

	# 7. Ограничение движения границами камеры
	keep_inside_camera()
	
	# Расход топлива зависит от текущей скорости машины
	# Если машина стоит (скорость 0), топливо не тратится. Если едет — тратится пропорционально скорости.
	if current_speed > 0 and not is_dead:
		var speed_factor = current_speed / max_speed
		current_fuel -= fuel_consumption_rate * speed_factor * delta
		current_fuel = clamp(current_fuel, 0.0, max_fuel)
		
		if fuel_bar:
			fuel_bar.value = current_fuel
			
		if current_fuel <= 0.0:
			out_of_fuel()
			
func out_of_fuel() -> void:
	print("Топливо закончилось!")
	current_speed = 0.0
	velocity = Vector2.ZERO
	trigger_game_over("У вас закончилось топливо!")
	
func add_fuel(amount: float) -> void:
	current_fuel += amount
	current_fuel = clamp(current_fuel, 0.0, max_fuel)
	if fuel_bar:
		fuel_bar.value = current_fuel
	print("Топливо пополнено на: ", amount, " литров!")

func get_input() -> void:
	steer_direction = 0.0
	# Стрелки или A / D
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		steer_direction -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		steer_direction += 1.0

# Функция проверки столкновений (Новое)
func check_collisions() -> void:
	if is_invulnerable:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("obstacles"):
			# Удар о твёрдое препятствие (ограждение)
			var barrier_damage = clamp(abs(current_speed) / damage_divider, 2.0, max_damage_per_hit)
			take_damage(barrier_damage)
			shake_camera(14.0)
			start_invulnerability()
			current_speed *= 0.2
			velocity = collision.get_normal() * 250.0
			start_fast_acceleration()
			break

		if collider and collider.is_in_group("enemies"):
			# Расчет урона (выполняется только если враг ехал навстречу)
			var impact_force = abs(current_speed)
			var damage = impact_force / damage_divider
			damage = clamp(damage, min_damage_per_hit, max_damage_per_hit)
			if "damage_multiplier" in collider:
				damage *= collider.damage_multiplier
			take_damage(damage)
			shake_camera(10.0)
			
			# Включаем временную неуязвимость игрока
			start_invulnerability()
			
			# Отбрасываем врага. Передаем направление удара и текущую скорость игрока
			if collider.has_method("get_hit"):
				# Считаем силу импульса на основе скорости игрока (берем по модулю)
				var player_impulse = abs(current_speed)
				collider.get_hit(collision.get_normal(), player_impulse)

			
			# Коррекция скорости игрока (теряет 70%)
			var speed_loss = current_speed * 0.7
			current_speed = max(0.0, current_speed - speed_loss)
			velocity = Vector2.ZERO
			
			# Включаем быстрый разгон
			start_fast_acceleration()
			
			break 


func start_fast_acceleration() -> void:
	# Если разгон уже активен (например, врезались повторно), перезапускать таймер не будем
	if is_fast_accelerating:
		return
		
	is_fast_accelerating = true
	active_acceleration = fast_acceleration # Включаем бешеное ускорение (600.0)
	
	# Ждем пару секунд
	await get_tree().create_timer(fast_accel_duration).timeout
	
	# Возвращаем обычное стандартное ускорение (100.0)
	active_acceleration = acceleration
	is_fast_accelerating = false



## Небольшие препятствия (конусы, ямы): урон, потеря скорости, тряска камеры
func hit_hazard(damage: float, speed_multiplier: float, shake: float = 6.0) -> void:
	if is_dead:
		return
	take_damage(damage)
	current_speed *= speed_multiplier
	shake_camera(shake)


## Масляное пятно: машину заносит в случайную сторону
func apply_slip(duration: float) -> void:
	if is_dead:
		return
	slip_time_left = duration
	slip_spin_dir = -1.0 if randf() < 0.5 else 1.0
	shake_camera(3.0)


## Бонус нитро
func start_nitro(duration: float) -> void:
	nitro_time_left = duration
	sprite.modulate = Color(0.6, 0.9, 1.6)


func shake_camera(amount: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(amount)


func start_invulnerability() -> void:
	is_invulnerable = true
	
	# Необязательно: можно сделать машину игрока слегка прозрачной, 
	# чтобы визуально показать игроку, что он временно неуязвим
	modulate.a = 0.5
	
	# Ждем указанное количество секунд
	await get_tree().create_timer(post_hit_invulnerability_time).timeout
	
	is_invulnerable = false
	# Возвращаем обычную видимость машины
	modulate.a = 1.0


# Функция расчета физического урона (Новое)
func calculate_collision_damage(enemy: CharacterBody2D, collision: KinematicCollision2D) -> void:
	# Получаем векторы скоростей обоих автомобилей в момент удара
	var player_velocity = velocity
	var enemy_velocity = enemy.velocity if "velocity" in enemy else Vector2.ZERO
	
	# Направление вектора удара (нормаль коллизии)
	var collision_normal = collision.get_normal()
	
	# Разница скоростей машин
	var relative_velocity = player_velocity - enemy_velocity
	
	# Скалярное произведение определяет скорость сближения именно «лоб в лоб» [1]
	var approach_speed = relative_velocity.dot(collision_normal)
	
	# Если машины сближаются (approach_speed отрицательный), наносим урон [1]
	if approach_speed < 0:
		# Высчитываем чистый урон на основе скорости сближения и нашего делителя баланса
		var damage = abs(approach_speed) / damage_divider
		take_damage(damage)

# Функция применения урона и обновления UI (Новое)
func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = clamp(current_health, 0.0, max_health)
	
	if health_bar:
		health_bar.value = current_health
	
	if current_health <= 0:
		die()

# Функция смерти игрока (Новое)
func die() -> void:
	print("Машина игрока полностью уничтожена!")
	trigger_game_over("Ваш автомобиль полностью уничтожен!")
	# Сюда можно вставить вызов экрана Game Over или перезапуск сцены:
	# get_tree().reload_current_scene()

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
# Добавить в Player.gd
func heal_full() -> void:
	current_health = max_health
	if health_bar:
		health_bar.value = current_health
	print("Машина полностью отремонтирована гаечным ключом!")
# --- НОВАЯ ЛОГИКА ЕДИНАЯ ДЛЯ ПРОИГРЫША ---
func trigger_game_over(reason_text: String) -> void:
	# Защита от двойного вызова (например, кончилось топливо и машина разбилась в одном кадре)
	if is_dead:
		return
	is_dead = true
	print(reason_text)

	# Полностью останавливаем машину
	current_speed = 0.0
	velocity = Vector2.ZERO

	# Сохраняем результат заезда
	var score := 0
	var counter = get_node_or_null("scoreComponent")
	if counter:
		score = counter.max_score
	var is_new_record := SaveManager.finish_run(score)

	# Активируем экран проигрыша
	if game_over_screen:
		if game_over_screen.has_method("show_result"):
			game_over_screen.show_result(reason_text, score, SaveManager.best_score, is_new_record)
		else:
			game_over_screen.show()

	# Ставим игру на паузу, чтобы встречные машины перестали спавниться и ехать
	get_tree().paused = true
