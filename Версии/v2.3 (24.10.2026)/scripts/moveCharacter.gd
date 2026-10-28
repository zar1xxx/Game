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
@export var steer_response: float = 11.0        # Как быстро руль доходит до упора (1/с)
@export var turn_rate_deg: float = 140.0        # Скорость поворота кузова при полном руле (°/с)
@export var max_heading_deg: float = 34.0       # Максимальный угол кузова относительно дороги
@export var recenter_rate_deg: float = 150.0    # Как быстро машина выравнивается без руля (°/с)
@export var grip: float = 2.7                   # Сцепление с дорогой (чем больше, тем меньше занос)
@export var lateral_assist: float = 330.0       # Доп. боковая скорость на малой скорости, чтобы можно было увернуться

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
var magnet_radius: float = 60.0          # бонусы ближе этого притягиваются к машине (тюнинг «Магнит»)
const TURN_BOOST := 1.3                  # все машины поворачивают на 30% резвее, чем в каталоге

var current_speed: float = 300.0
var _drawn_key: int = -1
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
var slow_excuse: float = 0.0           # > 0 — медленная езда сейчас оправдана (знак «60», АЗС, ремонт…)
var airborne: bool = false             # летим над разведённым мостом
var _drowned: bool = false

var _t: float = 0.0
var _invuln_left: float = 0.0
var _edge_rumble: float = 0.0
var _skid: Node2D = null
var _no_brakes: bool = false           # испытание «Без тормозов»
var _smoke_style: String = ""          # дым из выхлопа (уровень водителя)
var _exhaust_t: float = 0.0
var _horn_cd: float = 0.0
const ExhaustPuff := preload("res://scripts/visual/ExhaustPuff.gd")
var _score_counter: Node = null

# --- Звук ---
var _engine: AudioStreamPlayer
var _skid_snd: AudioStreamPlayer
var _siren: AudioStreamPlayer
var _engine_base_pitch: float = 1.0
var _skid_level: float = 0.0
var _heartbeat_t: float = 0.0
var _near_cd: Dictionary = {}        # кого уже засчитали как «на волоске»
var _smoke_t: float = 0.0

# --- Комбо опасных обгонов ---
## Каждый проход впритирку к встречной продлевает комбо и увеличивает множитель.
## Очки копятся «в банке» и зачисляются, только когда серия закончится спокойно
## (COMBO_WINDOW секунд без нового обгона). Удар — и весь банк сгорает.
const COMBO_WINDOW := 3.0
const COMBO_MAX_MULT := 8
const NEAR_GAP := 30.0              # зазор (px), который считается «впритирку»
const NEAR_GAP_CLOSE := 12.0        # совсем вплотную — очков вдвое больше
var combo: int = 0
var combo_time_left: float = 0.0
var combo_points: int = 0           # очки в банке текущей серии

signal near_miss(points: int, combo: int, close: bool)
signal combo_banked(combo: int, points: int)
signal combo_lost(combo: int, points: int)

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
	_setup_sounds()


## Мотор (тон зависит от машины и скорости), визг шин и сирена у спецмашин
func _setup_sounds() -> void:
	var kind: String = car.kind
	var engine_name := "engine_ev" if kind == "ev" else "engine"
	_engine_base_pitch = {"truck": 0.62, "bus": 0.68, "suv": 0.84, "racecar": 1.3,
		"scooter": 1.65, "ev": 1.0, "marshrutka": 0.74, "classic": 0.92, "tractor": 0.5,
		"sidecar": 1.35, "fire": 0.66, "limo": 0.88, "monster": 0.6}.get(kind, 1.0)
	_engine = Sound.make_loop(self, engine_name, -10.0)
	_skid_snd = Sound.make_loop(self, "skid", -80.0)
	if kind == "police" or kind == "ambulance" or kind == "fire":
		_siren = Sound.make_loop(self, "siren", -20.0)
		if kind == "ambulance":
			_siren.pitch_scale = 0.86


func _update_sounds(delta: float) -> void:
	if _engine == null:
		return
	var k := clampf(current_speed / maxf(base_max_speed, 1.0), 0.0, 1.8)
	# Рёв мотора: выше тон и громче при разгоне, нитро добавляет «визга»
	var target_pitch := _engine_base_pitch * (0.6 + 0.62 * k)
	if nitro_time_left > 0.0:
		target_pitch *= 1.18
	if recovery_time_left > 0.0 and current_speed < recovery_speed:
		target_pitch *= 1.08          # мотор «рвётся» вперёд после удара
	_engine.pitch_scale = lerpf(_engine.pitch_scale, maxf(target_pitch, 0.2), clampf(delta * 6.0, 0.0, 1.0))
	_engine.volume_db = lerpf(-16.0, -6.0, clampf(k, 0.0, 1.0)) + (2.0 if nitro_time_left > 0.0 else 0.0)
	# Визг шин — пока машину заносит или она резко тормозит
	var skid_target := 0.0
	if slip_time_left > 0.0:
		skid_target = 1.0
	elif is_braking and current_speed > min_speed + 40.0:
		skid_target = 0.75
	elif current_speed > 450.0 and absf(velocity.normalized().cross(-transform.y)) > 0.22:
		skid_target = 0.55
	_skid_level = move_toward(_skid_level, skid_target, delta * 5.0)
	_skid_snd.volume_db = linear_to_db(maxf(_skid_level, 0.0001)) - 4.0
	_skid_snd.pitch_scale = 0.9 + 0.25 * k
	# Сердцебиение, когда машина почти развалилась
	if current_health < max_health * 0.25:
		_heartbeat_t -= delta
		if _heartbeat_t <= 0.0:
			_heartbeat_t = lerpf(0.55, 1.1, current_health / (max_health * 0.25))
			Sound.play("heartbeat", -6.0, 1.0, 0.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0      # на случай выхода из заезда прямо во время прыжка


func _stop_loops() -> void:
	for p in [_engine, _skid_snd, _siren]:
		if p and is_instance_valid(p):
			p.stop()


## Характеристики машины из магазина + модификаторы трассы
func _apply_car_and_location() -> void:
	car = SaveManager.custom_car(SaveManager.selected_car)
	location = GameData.get_location(SaveManager.selected_location)
	CAR_LENGTH = car.length
	CAR_WIDTH = car.width
	base_max_speed = car.speed
	max_speed_cap = car.speed * 1.65
	acceleration = car.accel
	turn_rate_deg = car.turn * TURN_BOOST
	max_health = car.health
	damage_multiplier = car.damage
	regen_per_second = car.regen
	nitro_multiplier = car.nitro
	fuel_consumption_rate *= car.fuel * location.fuel
	grip *= location.grip
	# На скользкой дороге тормоза и выравнивание тоже хуже
	brake_deceleration *= 0.45 + 0.55 * location.grip
	recenter_rate_deg *= 0.5 + 0.5 * location.grip
	# Тюнинг из гаража
	var id: String = car.id
	max_fuel *= 1.0 + 0.12 * SaveManager.get_mod(id, "tank", 0)
	brake_deceleration *= 1.0 + 0.15 * SaveManager.get_mod(id, "brakes", 0)
	max_health *= 1.0 + 0.12 * SaveManager.get_mod(id, "armor", 0)
	magnet_radius = 60.0 + 42.0 * SaveManager.get_mod(id, "magnet", 0)
	# Испытание недели
	if SaveManager.rule_active("glass"):
		damage_multiplier *= 2.0
	if SaveManager.rule_active("thirsty"):
		fuel_consumption_rate *= 1.5
	_no_brakes = SaveManager.rule_active("no_brakes")
	_smoke_style = SaveManager.cosmetics.get("smoke", "")
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
	slow_excuse = maxf(0.0, slow_excuse - delta)
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
	_update_sounds(delta)
	_check_near_miss()
	_pull_pickups(delta)
	_update_combo(delta)
	_update_damage_smoke(delta)
	_horn_cd = maxf(0.0, _horn_cd - delta)
	_update_exhaust(delta)

	# --- Топливо ---
	if current_speed > 0.0:
		current_fuel -= fuel_consumption_rate * (current_speed / base_max_speed) * delta
		current_fuel = clampf(current_fuel, 0.0, max_fuel)
		if fuel_bar:
			fuel_bar.value = current_fuel
		if current_fuel <= 0.0:
			out_of_fuel()


## Магнит: бонусы рядом с машиной сами подтягиваются к ней.
## Базовый радиус есть у всех машин, тюнинг «Магнит» его увеличивает.
func _pull_pickups(delta: float) -> void:
	for pk in get_tree().get_nodes_in_group("pickups"):
		var n := pk as Node2D
		if n == null:
			continue
		var d := n.global_position - global_position
		# Сильнее тянем то, что впереди: туда машина и едет
		var reach := magnet_radius * (1.6 if d.y < 0.0 else 1.0)
		var dist := d.length()
		if dist < reach + CAR_LENGTH * 0.5:
			var k := 1.0 - clampf(dist / (reach + CAR_LENGTH * 0.5), 0.0, 1.0)
			n.global_position = n.global_position.move_toward(global_position, (420.0 + 900.0 * k) * delta)


## «На волоске»: встречная пролетела совсем рядом и не задела — бонус очков
func _check_near_miss() -> void:
	if is_invulnerable or current_speed < 380.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		var id: int = e.get_instance_id()
		var dy: float = e.global_position.y - global_position.y
		var dx: float = absf(e.global_position.x - global_position.x)
		var gap: float = dx - (e._width + CAR_WIDTH) / 2.0
		# Встречная поравнялась с нами и прошла в паре десятков пикселей
		if absf(dy) < (e._length + CAR_LENGTH) / 2.0 and gap > 0.0 and gap < NEAR_GAP and not _near_cd.has(id):
			_near_cd[id] = true
			_on_near_miss(gap < NEAR_GAP_CLOSE)
	if _near_cd.size() > 40:
		_near_cd.clear()


func _on_near_miss(close: bool) -> void:
	combo += 1
	combo_time_left = COMBO_WINDOW
	var base := 20 if close else 10
	if nitro_time_left > 0.0:
		base = int(base * 1.5)       # обгон на нитро — ещё опаснее
	var points := base * mini(combo, COMBO_MAX_MULT)
	combo_points += points
	# Звук обгона повышается с каждым шагом комбо
	Sound.play("nearmiss", -3.0, 1.0 + minf(combo - 1, 8) * 0.07, 0.02)
	MobileInput.vibrate(12)
	Missions.event("near")
	Missions.event("combo", combo)
	if combo > SaveManager.best_combo:
		SaveManager.best_combo = combo
	near_miss.emit(points, combo, close)


func _update_combo(delta: float) -> void:
	if combo == 0:
		return
	combo_time_left -= delta
	if combo_time_left <= 0.0:
		_bank_combo()


## Серия закончилась без аварии — очки из банка зачисляются в счёт
func _bank_combo() -> void:
	if combo_points > 0 and _score_counter and _score_counter.has_method("add_bonus"):
		_score_counter.add_bonus(combo_points)
	if combo >= 2:
		Sound.play("coin", -2.0, 1.0 + minf(combo, 8) * 0.05, 0.0)
	combo_banked.emit(combo, combo_points)
	combo = 0
	combo_points = 0
	combo_time_left = 0.0


## Авария во время серии — банк сгорает
func _lose_combo() -> void:
	if combo == 0:
		return
	combo_lost.emit(combo, combo_points)
	combo = 0
	combo_points = 0
	combo_time_left = 0.0


## Повреждённая машина дымит (чем меньше прочности, тем гуще)
func _update_damage_smoke(delta: float) -> void:
	var hp_k := current_health / max_health
	if hp_k > 0.45:
		return
	_smoke_t -= delta
	if _smoke_t > 0.0:
		return
	_smoke_t = lerpf(0.04, 0.16, hp_k / 0.45)
	var puff := Sprite2D.new()
	puff.texture = Art.glow_texture()
	var dark := hp_k < 0.2
	puff.modulate = Color(0.15, 0.15, 0.17, 0.55) if dark else Color(0.7, 0.7, 0.72, 0.4)
	puff.scale = Vector2.ONE * 0.25
	puff.z_index = 4
	get_parent().add_child(puff)
	puff.global_position = to_global(Vector2(randf_range(-8, 8), -CAR_LENGTH * 0.3))
	var tw := puff.create_tween().set_parallel(true)
	tw.tween_property(puff, "scale", Vector2.ONE * randf_range(0.7, 1.1), 0.9)
	tw.tween_property(puff, "modulate:a", 0.0, 0.9)
	tw.tween_property(puff, "global_position", puff.global_position + Vector2(randf_range(-30, 30), 140), 0.9)
	tw.chain().tween_callback(puff.queue_free)


## Косметический дым из выхлопной трубы (за уровень водителя)
func _update_exhaust(delta: float) -> void:
	if _smoke_style == "" or airborne or current_speed < 60.0:
		return
	_exhaust_t -= delta
	if _exhaust_t > 0.0:
		return
	_exhaust_t = {"hearts": 0.12, "fire": 0.05, "rainbow": 0.035}.get(_smoke_style, 0.05)
	var puff := ExhaustPuff.new()
	puff.style = _smoke_style
	puff.hue = fmod(_t * 0.6, 1.0)
	get_parent().add_child(puff)
	var side := -1.0 if int(_t * 20.0) % 2 == 0 else 1.0
	puff.global_position = to_global(Vector2(side * CAR_WIDTH * 0.22, CAR_LENGTH / 2.0 + 4.0))
	# Дым летит почти вместе с машиной и понемногу отстаёт, расходясь в стороны —
	# иначе на скорости он сразу улетает за нижний край экрана
	puff.velocity = velocity * 0.8 + Vector2(randf_range(-25.0, 25.0) + side * 15.0, randf_range(10.0, 40.0))


func _process(delta: float) -> void:
	# Мигание во время неуязвимости
	if _invuln_left > 0.0:
		_invuln_left -= delta
		modulate.a = 0.45 if int(_invuln_left * 12.0) % 2 == 0 else 0.9
		if _invuln_left <= 0.0:
			modulate.a = 1.0
	# Машина перерисовывается только когда меняется её вид: руль, стоп-сигналы, освещение,
	# мигалки (≈12 раз в секунду). Пламя нитро — каждый кадр.
	var key := _visual_key()
	if key != _drawn_key or (nitro_time_left > 0.0 and not is_dead):
		_drawn_key = key
		queue_redraw()


func _visual_key() -> int:
	var k := int(roundf(steer * 10.0)) + 20
	k = k * 2 + int(is_braking or recovery_time_left > recovery_duration - 0.3)
	k = k * 32 + int(Art.night * 20.0)
	k = k * 2 + int(is_dead)
	k = k * 1000000 + int(_t * 12.0) % 1000000
	return k


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
	Art.draw_player_car(self, car, {
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
	if _no_brakes:
		is_braking = false
	# Гудок: H или пробел на клавиатуре, кнопка «БИП» на телефоне
	if Input.is_physical_key_pressed(KEY_H) or Input.is_physical_key_pressed(KEY_SPACE) or MobileInput.horn:
		honk()


## Гудок выбранного в гараже звука (кнопку можно держать — повторяется не чаще раза в 0,7 с)
func honk() -> void:
	if _horn_cd > 0.0 or is_dead:
		return
	_horn_cd = 0.7
	Sound.play(SaveManager.horn_sound(), -3.0, 1.0, 0.0)


# ---------------------------------------------------------------------------
# Столкновения
# ---------------------------------------------------------------------------
func check_collisions() -> void:
	if is_invulnerable or airborne:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		if collider == null:
			continue
		if collider.is_in_group("obstacles"):
			# Удар о твёрдое ограждение (пожарной машине — почти не страшно)
			var dmg := clampf(current_speed / damage_divider, 2.0, max_damage_per_hit) * float(car.get("obstacle_damage", 1.0))
			Sound.play("crash", -2.0, 0.9)
			_on_crash(dmg, collision, 14.0)
			velocity = collision.get_normal() * 220.0
			break
		if collider.is_in_group("enemies"):
			var damage := clampf(current_speed / damage_divider, min_damage_per_hit, max_damage_per_hit)
			if "damage_multiplier" in collider:
				damage *= collider.damage_multiplier
			if collider.has_method("get_hit"):
				collider.get_hit(collision.get_normal(), current_speed)
			Sound.play("crash" if current_speed > 450.0 else "hit", 0.0)
			if randf() < 0.5:
				get_tree().create_timer(0.15).timeout.connect(func(): Sound.play("horn", -8.0, 0.9))
			_on_crash(damage, collision, 10.0)
			velocity = Vector2.ZERO
			break


## Общая реакция на аварию: урон, тряска, искры, потеря скорости и восстановление
func _on_crash(damage: float, collision: KinematicCollision2D, shake: float) -> void:
	var speed_before := current_speed
	_lose_combo()
	Missions.event("hit")
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
func hit_hazard(damage: float, speed_multiplier: float, shake: float = 6.0, kind: String = "") -> void:
	if is_dead or airborne:
		return
	# Монстр-трак давит конусы и ямы — и получает за это очки
	if car.get("crush", false) and kind in ["pothole", "cone"]:
		Sound.play("bump", -6.0, 0.7)
		shake_camera(2.0)
		if _score_counter and _score_counter.has_method("add_bonus"):
			_score_counter.add_bonus(15)
		var hud = get_tree().get_first_node_in_group("hud")
		Achievements.event("crush")
		if hud and hud.fx:
			hud.fx.popup("РАЗДАВИЛ! +15", get_global_transform_with_canvas().origin + Vector2(0, -80), Art.ORANGE)
		return
	# Трактору ямы, сугробы и лужи нипочём
	if car.get("offroad", false) and kind == "pothole":
		Sound.play("bump", -12.0, 0.8)
		return
	if kind == "cone":
		damage *= float(car.get("obstacle_damage", 1.0))
	# После ямы или коровы машина медленно разгоняется — полиция это не считает «медленной ездой»
	slow_excuse = maxf(slow_excuse, 1.8)
	take_damage(damage * damage_multiplier)
	current_speed *= speed_multiplier
	Sound.play("bump", -2.0)
	_lose_combo()
	Missions.event("hit")
	shake_camera(shake)
	MobileInput.vibrate(35)


## Масляное пятно: машину заносит в случайную сторону
func apply_slip(duration: float) -> void:
	if is_dead or airborne:
		return
	slip_time_left = duration
	slip_spin_dir = -1.0 if randf() < 0.5 else 1.0
	Sound.play("splash", -4.0)
	shake_camera(3.0)
	MobileInput.vibrate(25)


## Бонус нитро
func start_nitro(duration: float) -> void:
	nitro_time_left = duration * nitro_multiplier
	Sound.play("nitro", -1.0)


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
			Sound.play("bump", -16.0, 0.7)
	var camera := get_viewport().get_camera_2d()
	if camera:
		var cy := camera.global_position.y
		global_position.y = clampf(global_position.y, cy - Art.VIEW_H / 2.0 + 70.0, cy + Art.VIEW_H / 2.0 - 60.0)


func _update_skidmarks() -> void:
	if _skid == null or not is_instance_valid(_skid) or airborne:
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
	if location.get("theme", "") == "omsk":
		trigger_game_over(["Бензин кончился. Похоже, вы остаётесь в Омске. Навсегда.",
			"Бензин закончился ровно на табличке «Омск 0 км»"].pick_random())
	else:
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


## Полиция догнала: штраф прочностью (30% от максимума), серия комбо сгорает
var _caught_by_police: bool = false

func police_catch() -> void:
	if is_dead:
		return
	_lose_combo()
	Missions.event("hit")
	shake_camera(14.0)
	MobileInput.vibrate(120)
	Sound.play("crash", -3.0, 0.8)
	current_speed *= 0.6
	_caught_by_police = true
	take_damage(max_health * 0.3)
	_caught_by_police = false
	start_invulnerability()


func die() -> void:
	if _drowned:
		trigger_game_over("Машина утонула в Иртыше. Мост развели строго по расписанию!")
		return
	if _caught_by_police:
		trigger_game_over("Вас догнала полиция. Права — на стол!")
		return
	if location.get("theme", "") == "omsk":
		trigger_game_over(["Машина разбита. Омские ямы снова победили!",
			"Подвеска осталась в яме на Ленина. Степаныч её сохранит."].pick_random())
	else:
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
	Engine.time_scale = 1.0
	MobileInput.vibrate(300)
	_stop_loops()
	# Бензин кончился спокойно — банк комбо засчитывается; авария — сгорает
	if current_health > 0.0:
		_bank_combo()
	else:
		_lose_combo()
	MobileInput.release_all()
	# Плашки поверх игры (круг Омска, призрак, подсказки обучения) прячем под итоги заезда
	get_tree().call_group("hide_on_game_over", "hide")
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


# ---------------------------------------------------------------------------
# Разведённый мост: прыжок или купание
# ---------------------------------------------------------------------------
## Прыжок через пролёт: машина «взлетает» (растёт в размерах), на время полёта
## ей не страшны препятствия. Короткое замедление времени — для красоты.
func jump(duration: float) -> void:
	if is_dead or airborne:
		return
	airborne = true
	_invuln_left = 0.0
	Sound.play("whoosh", 0.0, 0.8, 0.0)
	MobileInput.vibrate(30)
	Engine.time_scale = 0.6
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.4, duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_land)


func _land() -> void:
	airborne = false
	scale = Vector2.ONE
	Engine.time_scale = 1.0
	if is_dead:
		return
	Sound.play("bump", 0.0, 0.8)
	shake_camera(10.0)
	MobileInput.vibrate(60)


## Не допрыгнули: машина падает в воду, её вылавливают и ставят за пролётом.
## Прочность −40%, бензин −25%, скорость почти до нуля.
func fall_into_river(land_y: float) -> void:
	if is_dead:
		return
	_lose_combo()
	Missions.event("hit")
	Sound.play("splash", 2.0, 0.7, 0.0)
	Sound.play("splash", -2.0, 1.1, 0.0)
	MobileInput.vibrate(200)
	shake_camera(14.0)
	_splash_burst(global_position)
	current_fuel = maxf(0.0, current_fuel - max_fuel * 0.25)
	if fuel_bar:
		fuel_bar.value = current_fuel
	# Переносим машину за развод (и камеру вместе с ней, чтобы не было рывка назад)
	var dy := land_y - global_position.y
	global_position.y = land_y
	velocity = Vector2.ZERO
	current_speed = 260.0
	var camera := get_viewport().get_camera_2d()
	if camera:
		camera.global_position.y += dy
	modulate = Color(0.6, 0.8, 1.0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 1.2)
	_drowned = true
	take_damage(max_health * 0.4)
	_drowned = false
	if not is_dead:
		start_invulnerability()
		if current_fuel <= 0.0:
			out_of_fuel()


func _splash_burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 0.8
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 360.0
	p.gravity = Vector2.ZERO
	p.damping_min = 200.0
	p.damping_max = 320.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = Color(0.75, 0.88, 1.0, 0.9)
	p.z_index = 5
	get_parent().add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
