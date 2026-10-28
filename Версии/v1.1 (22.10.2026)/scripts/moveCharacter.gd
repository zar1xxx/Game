extends CharacterBody2D
## Машина игрока.
## Управление: ←/→ или A/D — руль, ↓ или S — тормоз.
## Машина сама разгоняется до крейсерской скорости, которая растёт вместе со счётом.

@onready var game_over_screen: Control = %GameOverScreen
@onready var fuel_bar: ProgressBar = %FuelBar
@onready var health_bar: ProgressBar = %HealthBar

# --- Скорость ---
@export_group("Скорость")
@export var start_speed: float = 300.0          # Скорость на старте
@export var base_max_speed: float = 740.0       # Крейсерская скорость в начале заезда
@export var max_speed_cap: float = 1250.0       # Предел крейсерской скорости
@export var speed_step_per_100: float = 35.0    # Прибавка к крейсерской скорости за каждые 100 очков
@export var acceleration: float = 110.0         # Обычный разгон (ед./с²)
@export var brake_deceleration: float = 750.0   # Сила тормоза
@export var min_speed: float = 150.0            # Ниже этой скорости тормоз не опускает

# --- Руль ---
@export_group("Руль")
@export var steer_response: float = 7.0         # Как быстро руль доходит до упора (1/с)
@export var turn_rate_deg: float = 140.0        # Скорость поворота кузова при полном руле (°/с)
@export var max_heading_deg: float = 30.0       # Максимальный угол кузова относительно дороги
@export var recenter_rate_deg: float = 110.0    # Как быстро машина выравнивается без руля (°/с)
@export var grip: float = 2.2                   # Сцепление с дорогой (чем больше, тем меньше занос)
@export var lateral_assist: float = 240.0       # Доп. боковая скорость на малой скорости, чтобы можно было увернуться

# --- Прочность и столкновения ---
@export_group("Прочность")
@export var max_health: float = 100.0
@export var damage_divider: float = 22.0        # Урон = скорость / делитель
@export var min_damage_per_hit: float = 6.0
@export var max_damage_per_hit: float = 40.0
@export var post_hit_invulnerability_time: float = 1.0

# --- Восстановление после удара ---
# После столкновения машина теряет большую часть скорости, а затем быстрее обычного
# набирает её обратно. Сила этого «рывка» зависит от того, как быстро игрок ехал до удара:
# медленный удар — мягкое восстановление, быстрый — восстановление посильнее, но в разумных пределах.
@export_group("Восстановление после удара")
@export var speed_kept_after_hit: float = 0.35  # Какая доля скорости остаётся сразу после удара
@export var recovery_target: float = 0.85       # До какой доли прежней скорости действует ускорение
@export var recovery_accel_factor: float = 0.5  # Ускорение = скорость до удара × коэффициент
@export var recovery_accel_min: float = 140.0
@export var recovery_accel_max: float = 380.0
@export var recovery_duration: float = 1.8

# --- Топливо ---
@export_group("Топливо")
@export var max_fuel: float = 100.0
@export var fuel_consumption_rate: float = 4.0  # Расход в секунду на крейсерской скорости

# --- Масло и нитро ---
@export_group("Эффекты")
@export var slip_grip_multiplier: float = 0.15
@export var slip_spin_speed: float = 0.9
@export var nitro_speed_multiplier: float = 1.35
@export var nitro_acceleration: float = 900.0

# --- Внешний вид ---
# Размеры и характеристики берутся из выбранной в магазине машины (GameData.CARS)
var CAR_LENGTH := 104.0
var CAR_WIDTH := 52.0
var car: Dictionary = {}
var location: Dictionary = {}
var damage_multiplier: float = 1.0      # получаемый урон (у грузовика меньше, у болида больше)
var regen_per_second: float = 0.0       # самопочинка (скорая помощь)
var nitro_multiplier: float = 1.0

var current_speed: float = 300.0
var current_health: float = 100.0
var current_fuel: float = 100.0
var steer: float = 0.0               # Текущее положение руля (-1..1), плавно следует за вводом
var steer_input: float = 0.0
var is_braking: bool = false
var is_invulnerable: bool = false
var is_dead: bool = false
var slip_time_left: float = 0.0
var slip_spin_dir: float = 1.0
var nitro_time_left: float = 0.0
var recovery_time_left: float = 0.0
var recovery_accel: float = 0.0
var recovery_speed: float = 0.0

var _t: float = 0.0
var _invuln_left: float = 0.0
var _edge_rumble: float = 0.0
var _skid: Node2D = null
var _score_counter: Node = null

const SkidMarks := preload("res://scripts/visual/SkidMarks.gd")


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING   # режим для вида сверху
	# Слой 2 — твёрдые препятствия (ограждения). Игрок с ними сталкивается, встречные машины — нет.
	set_collision_mask_value(2, true)
	_apply_car_and_location()
	current_speed = start_speed
	current_health = max_health
	current_fuel = max_fuel
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if fuel_bar:
		fuel_bar.max_value = max_fuel
		fuel_bar.value = current_fuel
	if game_over_screen:
		game_over_screen.hide()
	_score_counter = get_node_or_null("scoreComponent")
	# Следы шин рисуются отдельным узлом под машинами
	_skid = SkidMarks.new()
	get_parent().call_deferred("add_child", _skid)


## Характеристики машины из магазина + модификаторы трассы
func _apply_car_and_location() -> void:
	car = GameData.get_car(SaveManager.selected_car)
	location = GameData.get_location(SaveManager.selected_location)
	CAR_LENGTH = car.length
	CAR_WIDTH = car.width
	base_max_speed = car.speed
	max_speed_cap = car.speed * 1.65
	acceleration = car.accel
	turn_rate_deg = car.turn
	max_health = car.health
	damage_multiplier = car.damage
	regen_per_second = car.regen
	nitro_multiplier = car.nitro
	fuel_consumption_rate *= car.fuel * location.fuel
	grip *= location.grip
	# На скользкой дороге тормоза и выравнивание тоже хуже
	brake_deceleration *= 0.45 + 0.55 * location.grip
	recenter_rate_deg *= 0.5 + 0.5 * location.grip
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CAR_WIDTH - 6.0, CAR_LENGTH - 8.0)
	$CollisionShape2D.shape = shape


## Текущая крейсерская скорость (растёт со счётом)
func get_cruise_speed() -> float:
	var score := 0
	if _score_counter:
		score = _score_counter.max_score
	return minf(max_speed_cap, base_max_speed + floorf(score / 100.0) * speed_step_per_100)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_t += delta
	if regen_per_second > 0.0 and current_health < max_health:
		current_health = minf(max_health, current_health + regen_per_second * delta)
		if health_bar:
			health_bar.value = current_health
	get_input()
	steer = move_toward(steer, steer_input, steer_response * delta)

	# --- Скорость ---
	var cruise := get_cruise_speed()
	var target_speed := cruise
	var accel := acceleration
	if nitro_time_left > 0.0:
		nitro_time_left -= delta
		target_speed = cruise * nitro_speed_multiplier
		accel = nitro_acceleration
	if recovery_time_left > 0.0:
		recovery_time_left -= delta
		if current_speed < recovery_speed:
			accel = maxf(accel, recovery_accel)

	if is_braking:
		current_speed = move_toward(current_speed, min_speed, brake_deceleration * delta)
	elif current_speed < target_speed:
		current_speed = minf(current_speed + accel * delta, target_speed)
	else:
		current_speed = move_toward(current_speed, target_speed, 500.0 * delta)

	# --- Поворот кузова ---
	var max_heading := deg_to_rad(max_heading_deg)
	var speed_k := clampf(current_speed / 600.0, 0.6, 1.15)
	var road_grip := grip
	if slip_time_left > 0.0:
		# На масле: машину крутит, руль слушается хуже, скорость падает
		slip_time_left -= delta
		road_grip *= slip_grip_multiplier
		rotation += (slip_spin_dir * slip_spin_speed + steer * deg_to_rad(turn_rate_deg) * 0.4) * delta
		rotation = clampf(rotation, -1.1, 1.1)
		current_speed *= 1.0 - 0.35 * delta
	elif absf(rotation) > max_heading + 0.01:
		# После заноса на масле угол плавно возвращается в допустимые пределы
		rotation = move_toward(rotation, clampf(rotation, -max_heading, max_heading), 2.5 * delta)
	else:
		# Руль задаёт целевой угол кузова: полный руль — max_heading, половина — половина угла.
		# Так одинаково хорошо работают и клавиши, и плавный наклон телефона.
		var target_heading := steer * max_heading
		var rate := deg_to_rad(turn_rate_deg) * speed_k
		if absf(steer) < 0.05:
			rate = deg_to_rad(recenter_rate_deg)
		rotation = move_toward(rotation, target_heading, rate * delta)
		rotation = clampf(rotation, -max_heading, max_heading)

	# --- Движение ---
	var forward := -transform.y * current_speed
	# Помощь при уклонении: на малой скорости (например, после удара) машина
	# всё равно может быстро сместиться вбок
	var slow_k := 1.0 - clampf(current_speed / cruise, 0.0, 1.0)
	forward.x += steer * lateral_assist * slow_k
	velocity = velocity.lerp(forward, clampf(road_grip * delta * 10.0, 0.0, 1.0))

	move_and_slide()
	check_collisions()
	keep_on_road(delta)
	_update_skidmarks()

	# --- Топливо ---
	if current_speed > 0.0:
		current_fuel -= fuel_consumption_rate * (current_speed / base_max_speed) * delta
		current_fuel = clampf(current_fuel, 0.0, max_fuel)
		if fuel_bar:
			fuel_bar.value = current_fuel
		if current_fuel <= 0.0:
			out_of_fuel()


func _process(delta: float) -> void:
	# Мигание во время неуязвимости
	if _invuln_left > 0.0:
		_invuln_left -= delta
		modulate.a = 0.45 if int(_invuln_left * 12.0) % 2 == 0 else 0.9
		if _invuln_left <= 0.0:
			modulate.a = 1.0
	queue_redraw()


func _draw() -> void:
	# Пламя нитро
	if nitro_time_left > 0.0 and not is_dead:
		for sx in [-1.0, 1.0]:
			var flick := 18.0 + sin(_t * 40.0 + sx) * 6.0
			var base := Vector2(sx * CAR_WIDTH * 0.25, CAR_LENGTH / 2.0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 0), base + Vector2(6, 0),
				base + Vector2(0, flick + 12)]), Color(0.3, 0.7, 1.0, 0.85))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(3, 0),
				base + Vector2(0, flick)]), Color(0.9, 0.97, 1.0))
	Art.draw_vehicle(self, car, {
		"steer": steer,
		"brake": is_braking or recovery_time_left > recovery_duration - 0.3,
		"lights": true,
		"time": _t,
	})


func get_input() -> void:
	# Клавиатура (стрелки / A D, тормоз ↓ / S) + сенсорное управление или наклон (MobileInput)
	var keys := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		keys -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		keys += 1.0
	steer_input = clampf(keys + MobileInput.steer_axis, -1.0, 1.0)
	is_braking = Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S) \
		or MobileInput.brake


# ---------------------------------------------------------------------------
# Столкновения
# ---------------------------------------------------------------------------
func check_collisions() -> void:
	if is_invulnerable:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		if collider == null:
			continue
		if collider.is_in_group("obstacles"):
			# Удар о твёрдое ограждение
			var dmg := clampf(current_speed / damage_divider, 2.0, max_damage_per_hit)
			_on_crash(dmg, collision, 14.0)
			velocity = collision.get_normal() * 220.0
			break
		if collider.is_in_group("enemies"):
			var damage := clampf(current_speed / damage_divider, min_damage_per_hit, max_damage_per_hit)
			if "damage_multiplier" in collider:
				damage *= collider.damage_multiplier
			if collider.has_method("get_hit"):
				collider.get_hit(collision.get_normal(), current_speed)
			_on_crash(damage, collision, 10.0)
			velocity = Vector2.ZERO
			break


## Общая реакция на аварию: урон, тряска, искры, потеря скорости и восстановление
func _on_crash(damage: float, collision: KinematicCollision2D, shake: float) -> void:
	var speed_before := current_speed
	MobileInput.vibrate(int(clampf(damage * 4.0, 40.0, 160.0)))
	take_damage(damage * damage_multiplier)
	shake_camera(shake)
	_spawn_sparks(collision.get_position(), collision.get_normal())
	start_invulnerability()
	current_speed = speed_before * speed_kept_after_hit
	# Чем быстрее ехали, тем сильнее (но в разумных пределах) рывок после удара
	recovery_speed = speed_before * recovery_target
	recovery_accel = clampf(speed_before * recovery_accel_factor, recovery_accel_min, recovery_accel_max)
	recovery_time_left = recovery_duration


func _spawn_sparks(pos: Vector2, normal: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 28
	p.lifetime = 0.45
	p.explosiveness = 0.95
	p.direction = normal
	p.spread = 70.0
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2.ZERO
	p.damping_min = 300.0
	p.damping_max = 500.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6))
	grad.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	p.color_ramp = grad
	p.z_index = 5
	get_parent().add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## Небольшие препятствия (конусы, ямы): урон, потеря скорости, тряска камеры
func hit_hazard(damage: float, speed_multiplier: float, shake: float = 6.0) -> void:
	if is_dead:
		return
	take_damage(damage * damage_multiplier)
	current_speed *= speed_multiplier
	shake_camera(shake)
	MobileInput.vibrate(35)


## Масляное пятно: машину заносит в случайную сторону
func apply_slip(duration: float) -> void:
	if is_dead:
		return
	slip_time_left = duration
	slip_spin_dir = -1.0 if randf() < 0.5 else 1.0
	shake_camera(3.0)
	MobileInput.vibrate(25)


## Бонус нитро
func start_nitro(duration: float) -> void:
	nitro_time_left = duration * nitro_multiplier


func shake_camera(amount: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(amount)


func start_invulnerability() -> void:
	is_invulnerable = true
	_invuln_left = post_hit_invulnerability_time
	await get_tree().create_timer(post_hit_invulnerability_time, false).timeout
	is_invulnerable = false


# ---------------------------------------------------------------------------
# Дорога, следы шин
# ---------------------------------------------------------------------------
## Машина не может выехать за бордюр; при касании бордюра её трясёт и выравнивает
func keep_on_road(delta: float) -> void:
	var half := CAR_WIDTH / 2.0 + absf(sin(rotation)) * CAR_LENGTH * 0.4 + 6.0
	var min_x := Art.ROAD_LEFT + half
	var max_x := Art.ROAD_RIGHT - half
	if global_position.x < min_x or global_position.x > max_x:
		global_position.x = clampf(global_position.x, min_x, max_x)
		velocity.x = 0.0
		rotation = move_toward(rotation, 0.0, 3.0 * delta)
		current_speed *= 1.0 - 0.4 * delta
		_edge_rumble -= delta
		if _edge_rumble <= 0.0:
			_edge_rumble = 0.15
			shake_camera(2.5)
	var camera := get_viewport().get_camera_2d()
	if camera:
		var cy := camera.global_position.y
		global_position.y = clampf(global_position.y, cy - Art.VIEW_H / 2.0 + 70.0, cy + Art.VIEW_H / 2.0 - 60.0)


func _update_skidmarks() -> void:
	if _skid == null or not is_instance_valid(_skid):
		return
	var skidding := slip_time_left > 0.0 or (is_braking and current_speed > min_speed + 40.0) \
		or (current_speed > 450.0 and absf(velocity.normalized().cross(-transform.y)) > 0.25)
	for sx in [-1.0, 1.0]:
		var wheel := to_global(Vector2(sx * CAR_WIDTH * 0.4, CAR_LENGTH * 0.3))
		_skid.add_point(int(sx), wheel, skidding)


# ---------------------------------------------------------------------------
# Топливо, ремонт, проигрыш
# ---------------------------------------------------------------------------
func out_of_fuel() -> void:
	current_speed = 0.0
	velocity = Vector2.ZERO
	trigger_game_over("Бензин закончился — погоня окончена!")


func add_fuel(amount: float) -> void:
	current_fuel = clampf(current_fuel + amount, 0.0, max_fuel)
	if fuel_bar:
		fuel_bar.value = current_fuel


func take_damage(amount: float) -> void:
	current_health = clampf(current_health - amount, 0.0, max_health)
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		die()


func die() -> void:
	trigger_game_over("Машина разбита вдребезги!")


func heal_full() -> void:
	current_health = max_health
	if health_bar:
		health_bar.value = current_health


func trigger_game_over(reason_text: String) -> void:
	# Защита от двойного вызова (например, кончилось топливо и машина разбилась в одном кадре)
	if is_dead:
		return
	is_dead = true
	MobileInput.vibrate(300)
	MobileInput.release_all()
	current_speed = 0.0
	velocity = Vector2.ZERO
	is_braking = true
	queue_redraw()

	var score := 0
	if _score_counter:
		score = _score_counter.max_score
	var is_new_record := SaveManager.finish_run(score)

	if game_over_screen:
		if game_over_screen.has_method("show_result"):
			game_over_screen.show_result(reason_text, score, SaveManager.best_score, is_new_record)
		else:
			game_over_screen.show()
	get_tree().paused = true
