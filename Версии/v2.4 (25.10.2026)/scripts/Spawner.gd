extends Node2D
## Спавнер: встречные машины, бонусы и препятствия.
## Всё появляется по полосам дороги (Art.LANES полос), новые типы препятствий
## открываются по мере роста счёта, а интервал спавна и скорость машин растут со сложностью.

@export var enemy_scene: PackedScene = preload("res://scenes/EnemyCar.tscn")
@export var wrench_scene: PackedScene = preload("res://scenes/Wrench.tscn")
@export var fuel_scene: PackedScene = preload("res://scenes/FuelCan.tscn")
@export var nitro_scene: PackedScene = preload("res://scenes/obstacles/NitroPickup.tscn")
@export var cone_scene: PackedScene = preload("res://scenes/obstacles/TrafficCone.tscn")
@export var pothole_scene: PackedScene = preload("res://scenes/obstacles/Pothole.tscn")
@export var oil_scene: PackedScene = preload("res://scenes/obstacles/OilSlick.tscn")
@export var barrier_scene: PackedScene = preload("res://scenes/obstacles/RoadBarrier.tscn")
@export var tumbleweed_scene: PackedScene = preload("res://scenes/obstacles/Tumbleweed.tscn")
@export var cow_scene: PackedScene = preload("res://scenes/obstacles/Cow.tscn")
@export var crab_scene: PackedScene = preload("res://scenes/obstacles/Crab.tscn")
@export var boulder_scene: PackedScene = preload("res://scenes/obstacles/Boulder.tscn")

# --- Шансы бонусов (проверяются первыми, остальное — препятствия) ---
@export_range(0.0, 1.0) var wrench_spawn_chance: float = 0.07
@export_range(0.0, 1.0) var fuel_spawn_chance: float = 0.17
@export_range(0.0, 1.0) var nitro_spawn_chance: float = 0.04

# --- Атакующий спавн: машина появляется на полосе игрока ---
@export_range(0.0, 1.0) var target_player_chance: float = 0.35

# --- Динамическая сложность (ступень = каждые difficulty_points очков) ---
@export var difficulty_points: int = 100
@export var base_spawn_time: float = 1.15
@export var difficulty_step: float = 0.06       # На сколько сокращается интервал за ступень
@export var min_spawn_time: float = 0.55
@export var enemy_speed_step: float = 12.0      # Прибавка к скорости встречных машин за ступень

@export var spawn_offset_y: float = -320.0      # Насколько выше верхнего края экрана появляются объекты
## Встречные машины появляются ещё выше: пока они не на экране, о них предупреждает стрелка
@export var enemy_spawn_offset_y: float = -1050.0

# Таблица препятствий: вес (как часто) и счёт, с которого открывается
var hazard_table: Array = [
	{"kind": "enemy",   "weight": 55, "unlock": 0},
	{"kind": "cones",   "weight": 10, "unlock": 40},
	{"kind": "pothole", "weight": 9,  "unlock": 90},
	{"kind": "oil",     "weight": 8,  "unlock": 150},
	{"kind": "zigzag",  "weight": 9,  "unlock": 220},
	{"kind": "barrier", "weight": 7,  "unlock": 300},
	{"kind": "truck",   "weight": 8,  "unlock": 380},
	{"kind": "gate",    "weight": 5,  "unlock": 500},
	{"kind": "tumbleweed", "weight": 12, "unlock": 30, "only": "desert"},
	{"kind": "cow", "weight": 10, "unlock": 25, "only": "village"},
	{"kind": "crab", "weight": 13, "unlock": 20, "only": "beach"},
	{"kind": "boulder", "weight": 11, "unlock": 50, "only": "mountain"},
]

var location: Dictionary = {}

@onready var spawn_timer: Timer = $SpawnTimer

var last_difficulty_milestone: int = 0
var current_score: int = 0
var _last_lane: int = -1
var _gates: Array = []          # ворота на дороге: {"y": ...} — для задания «ворота на нитро»
var _nitro_gate_mission: bool = false
var _loop_level: int = 0       # «Омск не отпускает»: номер круга (больше абсурда)
var _events: Node = null        # RoadEvents — подсказывает, где сейчас нельзя ничего ставить
var _diff: Dictionary = {}      # выбранная сложность (GameData.DIFFICULTIES)
## Свой генератор случайных чисел: перед каждым тактом он заново «засевается» номером такта
## и зерном заезда. Поэтому в вызове по коду и в «Кто дальше» трафик совпадает.
var _rng := RandomNumberGenerator.new()
var _tick: int = 0
var enemy_speed_k: float = 1.0  # мигалка и т.п. могут временно менять скорость новых машин

# --- Проверка «проезд есть всегда» ---
# Для каждого объекта на дороге считаем, КОГДА он окажется на уровне игрока
# (с учётом скорости игрока и встречной машины). Новый объект ставится, только если
# в это время остаётся свободная полоса (на «Спокойно» — две), с запасом на перестроение.
var _occ: Array = []            # [первая полоса, последняя полоса, t0, t1]
var _p_y: float = 0.0
var _v_p: float = 0.0
var _car_half: float = 50.0
var _event_lanes: Array = []


func _ready() -> void:
	location = GameData.get_location(SaveManager.selected_location)
	_diff = SaveManager.difficulty()
	# Заезд дня, испытание недели, вызов и «Кто дальше»: одинаковый «случайный» расклад
	if SaveManager.daily_mode or SaveManager.weekly_mode or SaveManager.challenge_mode or SaveManager.party_mode:
		seed(SaveManager.run_seed)
	_rng.seed = SaveManager.run_seed
	# В Омске ям больше, и они начинаются сразу (исторические, не трогать!)
	var holes: float = location.get("potholes", 1.0)
	if holes != 1.0:
		for entry in hazard_table:
			if entry.kind == "pothole":
				entry.weight = int(entry.weight * holes)
				entry.unlock = 15
			elif entry.kind == "zigzag":
				entry.unlock = 120
	# Испытание «Двойные ямы»: ям вдвое больше, и они с самого старта
	if SaveManager.rule_active("potholes"):
		for entry in hazard_table:
			if entry.kind == "pothole":
				entry.weight *= 2
				entry.unlock = 0
	# Плотный трафик на сложных трассах — спавн чаще; сложность — реже или чаще
	base_spawn_time *= float(_diff.spawn) / location.traffic
	min_spawn_time *= float(_diff.spawn) / location.traffic
	target_player_chance = float(_diff.target)
	# Испытание «Час пик»: встречных больше
	if SaveManager.rule_active("rush"):
		base_spawn_time /= 1.35
		min_spawn_time /= 1.2
		for entry in hazard_table:
			if entry.kind == "enemy":
				entry.weight = int(entry.weight * 1.5)
	spawn_timer.wait_time = base_spawn_time
	# Активно задание «ворота на нитро» — ворота появляются раньше и чаще
	_nitro_gate_mission = Missions.is_active("nitro_gate")
	if _nitro_gate_mission:
		for entry in hazard_table:
			if entry.kind == "gate":
				entry.unlock = 80
				entry.weight *= 3
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	# Полиция, которая гонится за слишком медленными водителями
	get_parent().add_child.call_deferred(preload("res://scripts/PoliceChase.gd").new())
	# Коллекторы: фургон и дроны
	get_parent().add_child.call_deferred(preload("res://scripts/TckChase.gd").new())
	# Соперник «Колян на девятке»
	if not SaveManager.tutorial_mode:
		get_parent().add_child.call_deferred(preload("res://scripts/Rival.gd").new())
	# Призрак рекорда: записывает заезд и показывает лучший (в обучении не нужен)
	if not SaveManager.tutorial_running and SaveManager.records_enabled():
		get_parent().add_child.call_deferred(preload("res://scripts/Ghost.gd").new())
	# Обучение: подсказки по шагам, пока они идут — обычный спавн выключен
	if SaveManager.tutorial_running:
		get_parent().add_child.call_deferred(preload("res://scripts/Tutorial.gd").new())
	# Дорожные события: АЗС, камеры, колонны фур, ремонт, мост и половодье
	_events = preload("res://scripts/events/RoadEvents.gd").new()
	get_parent().add_child.call_deferred(_events)
	# «Омск не отпускает»: арка «ОМСК» каждые несколько километров и нарастающий абсурд
	if location.get("loop", false):
		get_parent().add_child.call_deferred(preload("res://scripts/OmskLoop.gd").new())
	var score_node := get_tree().get_first_node_in_group("score_counter")
	if score_node and score_node.has_signal("score_changed"):
		score_node.score_changed.connect(_on_player_score_changed)


func _on_player_score_changed(new_score: int) -> void:
	current_score = new_score
	var milestone: int = new_score / difficulty_points
	if milestone > last_difficulty_milestone:
		last_difficulty_milestone = milestone
		spawn_timer.wait_time = maxf(min_spawn_time, base_spawn_time - milestone * difficulty_step * float(_diff.spawn))


## Прибавка к скорости встречных: растёт со счётом, но не бесконечно
## (иначе на огромном счёте машины летят быстрее, чем на них можно среагировать)
func enemy_speed_bonus() -> float:
	return mini(last_difficulty_milestone, int(_diff.enemy_steps_max)) * enemy_speed_step * float(_diff.enemy_step)


# ---------------------------------------------------------------------------
# Полосы
# ---------------------------------------------------------------------------
static func lane_center(lane: int) -> float:
	return Art.ROAD_LEFT + Art.LANE_W * (lane + 0.5)


static func lane_of(x: float) -> int:
	return clampi(int((x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)


## Случайная полоса, по возможности не та же, что в прошлый раз
## (и не занятая дорожным событием — ремонтом, колонной, «карманом» АЗС)
func _random_lane() -> int:
	var lane := _rng.randi() % Art.LANES
	if lane == _last_lane:
		lane = (lane + 1 + _rng.randi() % (Art.LANES - 1)) % Art.LANES
	for i in Art.LANES:
		if not _lane_blocked(lane):
			break
		lane = (lane + 1) % Art.LANES
	_last_lane = lane
	return lane


func _lane_blocked(lane: int) -> bool:
	return _events != null and is_instance_valid(_events) and _events.is_lane_blocked(lane)


func _event_policy() -> String:
	if _events != null and is_instance_valid(_events):
		return _events.spawn_policy()
	return "all"


# ---------------------------------------------------------------------------
# «Проезд есть всегда»
# ---------------------------------------------------------------------------
func _prepare_occupancy() -> void:
	_occ.clear()
	_v_p = 0.0
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.is_dead:
		return
	_p_y = p.global_position.y
	# Если игрок притормозил, считаем по крейсерской: тормозить вечно он не будет
	_v_p = maxf(p.current_speed, 0.8 * p.get_cruise_speed())
	_car_half = p.CAR_LENGTH / 2.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		var hw: float = e._width / 2.0 + (ZIGZAG_SWAY if e.behavior == 1 else 0.0)
		var v: float = 0.0 if e._blocked or e.current_state != 0 else maxf(e.current_speed, 0.0)
		_push(e.global_position, hw, e._length / 2.0, v)
	for o in get_tree().get_nodes_in_group("obstacles"):
		_push(o.global_position, o.width / 2.0, o.height / 2.0, 0.0)
	for h in get_tree().get_nodes_in_group("hazards"):
		var hw := 26.0
		if "width" in h:
			hw = maxf(hw, float(h.width) / 2.0)
		_push(h.global_position, hw, 28.0, 0.0)
	_event_lanes = []
	if _events != null and is_instance_valid(_events) and _events.busy():
		_event_lanes = _events.current.lanes_blocked


const ZIGZAG_SWAY := 100.0        # насколько «лихач» уходит в стороны от своей полосы


func _push(pos: Vector2, hw: float, hl: float, v: float) -> void:
	var t := _when(pos.y, hl, v)
	if t.y < -0.2:
		return                      # уже позади игрока
	_occ.append([lane_of(pos.x - hw + 8.0), lane_of(pos.x + hw - 8.0), t.x, t.y])


## Когда объект (центр y, половина длины hl, скорость вниз v) будет на уровне игрока: (t0, t1)
func _when(y: float, hl: float, v: float) -> Vector2:
	var c := maxf(_v_p + v, 60.0)
	var t := (_p_y - y) / c
	var h := (hl + _car_half) / c
	return Vector2(t - h, t + h)


func _count_free(blocked: Array, a: int, b: int) -> int:
	var n := 0
	for l in range(a, b + 1):
		if not blocked[l]:
			n += 1
	return n


## Можно ли занять полосы lanes на время t (не отнимет ли это последний проезд)
func _fair(lanes: Array, t: Vector2) -> bool:
	if _v_p <= 0.0:
		return true
	var w: float = _diff.window
	var base: Array = []
	base.resize(Art.LANES)
	base.fill(false)
	for o in _occ:
		if o[3] + w > t.x and o[2] - w < t.y:
			for l in range(o[0], o[1] + 1):
				base[l] = true
	var with_c := base.duplicate()
	for l in lanes:
		with_c[clampi(l, 0, Art.LANES - 1)] = true
	if _event_lanes.is_empty():
		var need: int = _diff.free_lanes
		return _count_free(with_c, 0, Art.LANES - 1) >= mini(need, _count_free(base, 0, Art.LANES - 1))
	# Полосы события (колонна, ремонт) делят дорогу на части — в каждой должен остаться проезд
	var seg := 0
	for l in Art.LANES + 1:
		if l == Art.LANES or l in _event_lanes:
			if l > seg and _count_free(with_c, seg, l - 1) < mini(1, _count_free(base, seg, l - 1)):
				return false
			seg = l + 1
	return true


## Полосы от a до b включительно
static func _span(a: int, b: int) -> Array:
	var out: Array = []
	for l in range(maxi(a, 0), mini(b, Art.LANES - 1) + 1):
		out.append(l)
	return out


## Случайный порядок полос (своим генератором)
func _shuffled_lanes(count: int = Art.LANES) -> Array:
	var order: Array = range(count)
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


## Полоса для объекта шириной n полос (первая полоса) так, чтобы проезд остался; −1 — некуда
func _fair_lane(y: float, hl: float, v: float, n: int = 1, prefer: int = -1, sway: int = 0) -> int:
	var t := _when(y, hl, v)
	var order := _shuffled_lanes(Art.LANES - n + 1)
	if order.size() > 1 and order[0] == _last_lane:
		order.push_back(order.pop_front())
	if prefer >= 0 and prefer <= Art.LANES - n:
		order.erase(prefer)
		order.push_front(prefer)
	for first in order:
		var bad := false
		for l in range(first, first + n):
			if _lane_blocked(l):
				bad = true
		if bad:
			continue
		if _fair(_span(first - sway, first + n - 1 + sway), t):
			_last_lane = first
			return first
	return -1


func _note(lanes: Array, y: float, hl: float, v: float) -> void:
	if lanes.is_empty():
		return
	var t := _when(y, hl, v)
	var sorted := lanes.duplicate()
	sorted.sort()
	# Несмежные полосы (ворота) записываем отдельными кусками, чтобы проезд между ними не «закрылся»
	var a: int = sorted[0]
	var prev: int = a
	for i in range(1, sorted.size() + 1):
		if i == sorted.size() or sorted[i] != prev + 1:
			_occ.append([a, prev, t.x, t.y])
			if i < sorted.size():
				a = sorted[i]
		if i < sorted.size():
			prev = sorted[i]


# ---------------------------------------------------------------------------
# Основной цикл спавна
# ---------------------------------------------------------------------------
func _on_spawn_timer_timeout() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var top := camera.global_position.y - Art.half_view_h()
	var policy := _event_policy()
	if policy == "none" or SaveManager.tutorial_running:
		return
	_tick += 1
	_rng.seed = (SaveManager.run_seed * 1000003 + _tick * 7919 + 12345) & 0x7fffffff
	_prepare_occupancy()
	# С ростом счёта «спавнеров» становится больше: за один такт появляется
	# сразу несколько объектов (каждый — со своей случайной ролью: бонус или препятствие).
	var slots := spawner_count()
	for i in slots:
		var off := -i * 270.0
		var picked := _spawn_once(top + spawn_offset_y + off, top + enemy_spawn_offset_y + off, policy, i > 0)
		if picked == "gate":
			break                       # ворота перекрывают почти всю дорогу — больше ничего не ставим


## Сколько объектов появляется за один такт: 1 → 2 → 3 с ростом счёта (на плотных трассах раньше).
## Потолок зависит от сложности; в «Омск не отпускает» на «Жёстко» с кругами — до 4
func spawner_count() -> int:
	var k: float = current_score * location.get("traffic", 1.0)
	var n := 1 + int(k / float(_diff.slot_points))
	var loop_bonus: int = _loop_level / 4 if _loop_level > 0 and _diff.id == "hard" else 0
	return clampi(mini(n, int(_diff.slots)) + loop_bonus, 1, 4)


## Один объект. extra — дополнительный «спавнер»: он чаще ставит бонусы и не ставит глухих перегородок
func _spawn_once(spawn_y: float, enemy_y: float, policy: String, extra: bool) -> String:
	var r := _rng.randf()
	var bonus_k := 1.6 if extra else 1.0
	if policy == "pickups":
		# Идёт колонна фур: сама колонна и есть испытание, остальная дорога — только бонусы
		bonus_k = 2.0
	if r < wrench_spawn_chance * bonus_k:
		_spawn_in_lane(wrench_scene, spawn_y)
		return "wrench"
	r -= wrench_spawn_chance * bonus_k
	if r < fuel_spawn_chance * bonus_k:
		_spawn_in_lane(fuel_scene, spawn_y)
		return "fuel"
	r -= fuel_spawn_chance * bonus_k
	if current_score >= 60 and r < nitro_spawn_chance * bonus_k:
		_spawn_in_lane(nitro_scene, spawn_y)
		return "nitro"
	r -= nitro_spawn_chance * bonus_k
	if r < powerup_chance() * bonus_k:
		_spawn_powerup(spawn_y)
		return "powerup"
	if policy == "pickups":
		return ""

	var hazard := _pick_hazard()
	if extra and hazard in ["gate", "barrier"]:
		hazard = ["enemy", "pothole", "oil"][_rng.randi() % 3]
	if policy == "enemies":
		hazard = "enemy"
	# Во время события не перегораживаем дорогу ещё и своими ограждениями
	if hazard in ["cones", "barrier", "gate"] and _events != null and is_instance_valid(_events) and _events.busy():
		hazard = "enemy"
	match hazard:
		"enemy":
			_spawn_enemy(enemy_y, 0)
		"zigzag":
			_spawn_enemy(enemy_y, 1)
		"truck":
			_spawn_enemy(enemy_y - 60, 2)
		"tumbleweed":
			var from_left := _rng.randf() < 0.5
			_add(tumbleweed_scene.instantiate(), Vector2(Art.ROAD_LEFT - 30.0 if from_left else Art.ROAD_RIGHT + 30.0, spawn_y + 120.0))
		"cow":
			# Корова выходит заранее, чтобы успеть дойти до дороги, пока игрок подъезжает
			var from_left := _rng.randf() < 0.5
			_add(cow_scene.instantiate(), Vector2(Art.ROAD_LEFT - 60.0 if from_left else Art.ROAD_RIGHT + 60.0, spawn_y - 200.0))
		"crab":
			var from_left := _rng.randf() < 0.5
			_add(crab_scene.instantiate(), Vector2(Art.ROAD_LEFT - 30.0 if from_left else Art.ROAD_RIGHT + 30.0, spawn_y + 60.0))
		"boulder":
			# Камень скатывается со скалы слева
			var lane := _fair_lane(spawn_y - 120.0, 30.0, 0.0)
			if lane < 0:
				return ""
			var boulder = boulder_scene.instantiate()
			boulder.lane = lane
			_add(boulder, Vector2(Art.ROAD_LEFT - 60.0, spawn_y - 120.0))
			_note([lane], spawn_y - 120.0, 30.0, 0.0)
		"cones":
			_spawn_cone_row(spawn_y)
		"pothole":
			var hole = pothole_scene.instantiate()
			if location.theme == "winter":
				hole.variant = "snowdrift"
			elif location.theme == "rain" and not SaveManager.rule_active("potholes"):
				hole.free()
				hole = oil_scene.instantiate()
				hole.variant = "puddle"
			_add_fair(hole, spawn_y)
		"oil":
			var slick = oil_scene.instantiate()
			if location.theme == "winter":
				slick.variant = "ice"
			elif location.theme == "rain":
				slick.variant = "puddle"
			_add_fair(slick, spawn_y)
		"barrier":
			_spawn_barrier(spawn_y)
		"gate":
			_spawn_gate(spawn_y)
	return hazard


func _pick_hazard() -> String:
	var total := 0
	for entry in hazard_table:
		if _available(entry):
			total += entry.weight
	var roll: int = _rng.randi() % maxi(total, 1)
	for entry in hazard_table:
		if not _available(entry):
			continue
		if roll < entry.weight:
			return entry.kind
		roll -= entry.weight
	return "enemy"


# ---------------------------------------------------------------------------
# Вспомогательные функции спавна
# ---------------------------------------------------------------------------
func _add(obj: Node, pos: Vector2) -> void:
	var node := obj as Node2D
	if node == null:
		return
	node.global_position = pos
	get_tree().current_scene.add_child(node)


func _available(entry: Dictionary) -> bool:
	if entry.has("only") and entry.only != location.theme:
		return false
	return current_score >= entry.unlock


## Яма, масло и т.п. на одну полосу — только туда, где не отнимет последний проезд
func _add_fair(obj: Node, y: float) -> void:
	var lane := _fair_lane(y, 30.0, 0.0)
	if lane < 0:
		obj.free()
		return
	_add(obj, Vector2(lane_center(lane) + _rng.randf_range(-25.0, 25.0), y))
	_note([lane], y, 30.0, 0.0)


func _spawn_in_lane(scene: PackedScene, y: float) -> void:
	if scene == null:
		return
	var x := lane_center(_random_lane()) + _rng.randf_range(-25.0, 25.0)
	_add(scene.instantiate(), Vector2(x, y))


## Скорость встречной машины (как её посчитает EnemyCar при появлении)
func _enemy_speed(behavior: int) -> float:
	var v := (230.0 + enemy_speed_bonus()) * float(location.enemy_speed) * enemy_speed_k
	if behavior == 1:
		v *= 1.15
	elif behavior == 2:
		v *= 0.6
	return v


func _spawn_enemy(y: float, behavior: int) -> void:
	if enemy_scene == null:
		return
	var hl := 95.0 if behavior == 2 else 50.0
	var v := _enemy_speed(behavior)
	# Часть машин выезжает прямо на полосу игрока
	var prefer := -1
	if behavior == 0 and _rng.randf() < target_player_chance:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			prefer = lane_of(player.global_position.x)
	var lane := _fair_lane(y, hl, v, 1, prefer, 1 if behavior == 1 else 0)
	if lane < 0:
		return                      # сейчас любая полоса закрыла бы проезд — пропускаем
	var enemy = enemy_scene.instantiate()
	enemy.behavior = behavior
	enemy.max_speed = (enemy.max_speed + enemy_speed_bonus()) * location.enemy_speed * enemy_speed_k
	if behavior == 1:
		# Фаза подобрана так, чтобы «лихач» вилял вокруг своей полосы, а не уезжал в сторону
		enemy.phase_preset = PI / 2.0 if _rng.randf() < 0.5 else -PI / 2.0
	_add(enemy, Vector2(lane_center(lane), y))
	_note(_span(lane - (1 if behavior == 1 else 0), lane + (1 if behavior == 1 else 0)), y, hl, v)


func _spawn_cone_row(y: float) -> void:
	# Конусы перекрывают одну-две полосы: прямо или по диагонали
	var lanes := _rng.randi_range(1, 2)
	var diagonal := _rng.randf() < 0.5
	var x_span := lanes * Art.LANE_W - 48.0
	var count := int(x_span / 56.0) + 1
	var spread := (count - 1) * 34.0 if diagonal else 0.0
	var first := _fair_lane(y - spread / 2.0, 20.0 + spread / 2.0, 0.0, lanes)
	if first < 0:
		return
	var x0 := Art.ROAD_LEFT + first * Art.LANE_W + 24.0
	var x1 := Art.ROAD_LEFT + (first + lanes) * Art.LANE_W - 24.0
	for i in count:
		var x := lerpf(x0, x1, float(i) / max(count - 1, 1))
		_add(cone_scene.instantiate(), Vector2(x, y - (i * 34.0 if diagonal else 0.0)))
	_note(_span(first, first + lanes - 1), y - spread / 2.0, 20.0 + spread / 2.0, 0.0)


func _spawn_barrier(y: float) -> void:
	# Ограждение на 1–2 полосы
	var lanes := 1 if _rng.randf() < 0.6 else 2
	var first := _fair_lane(y, 18.0, 0.0, lanes)
	if first < 0 and lanes == 2:
		lanes = 1
		first = _fair_lane(y, 18.0, 0.0, 1)
	if first < 0:
		return
	var barrier = barrier_scene.instantiate()
	barrier.width = lanes * Art.LANE_W - 24.0
	_add(barrier, Vector2(Art.ROAD_LEFT + (first + lanes / 2.0) * Art.LANE_W, y))
	_note(_span(first, first + lanes - 1), y, 18.0, 0.0)


func _spawn_gate(y: float) -> void:
	# «Ворота»: перекрыты все полосы, кроме одной — и эта одна должна быть свободна
	var t := _when(y, 18.0, 0.0)
	var open_lane := -1
	for lane in _shuffled_lanes():
		var closed: Array = range(Art.LANES)
		closed.erase(lane)
		if _fair(closed, t):
			open_lane = lane
			break
	if open_lane < 0:
		_spawn_barrier(y)
		return
	# Для задания — нитро прямо перед проездом в воротах
	if _nitro_gate_mission and Missions.is_active("nitro_gate") and _rng.randf() < 0.75:
		_add(nitro_scene.instantiate(), Vector2(lane_center(open_lane), y))
		y -= 650.0
	_gates.append({"y": y})
	if open_lane > 0:
		var left = barrier_scene.instantiate()
		left.width = open_lane * Art.LANE_W - 10.0
		_add(left, Vector2(Art.ROAD_LEFT + open_lane * Art.LANE_W / 2.0 - 5.0, y))
	if open_lane < Art.LANES - 1:
		var right = barrier_scene.instantiate()
		var lanes_right := Art.LANES - 1 - open_lane
		right.width = lanes_right * Art.LANE_W - 10.0
		_add(right, Vector2(Art.ROAD_RIGHT - lanes_right * Art.LANE_W / 2.0 + 5.0, y))
	var closed_lanes: Array = range(Art.LANES)
	closed_lanes.erase(open_lane)
	_note(closed_lanes, y, 18.0, 0.0)


# ---------------------------------------------------------------------------
# Бонусы на дороге: щит, мигалка, двойные очки
# ---------------------------------------------------------------------------
const PowerUpScript := preload("res://scripts/obstacles/PowerUp.gd")


func powerup_chance() -> float:
	if current_score < 120 or _player_has_all_powerups():
		return 0.0
	return 0.035


func _player_has_all_powerups() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	return p != null and p.shield and p.siren_left > 0.0 and p.double_points_left > 0.0


func _spawn_powerup(y: float) -> void:
	var p = PowerUpScript.new()
	var roll := _rng.randi() % 10
	p.kind = "shield" if roll < 4 else ("siren" if roll < 7 else "double")
	_add(p, Vector2(lane_center(_random_lane()) + _rng.randf_range(-20.0, 20.0), y))


## Проверка проезда через ворота (для задания «пролети ворота на нитро»)
func _physics_process(_delta: float) -> void:
	if _gates.is_empty():
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead:
		return
	for g in _gates.duplicate():
		if player.global_position.y < g.y - 40.0:
			_gates.erase(g)
			if player.nitro_time_left > 0.0:
				Missions.event("nitro_gate")
				Sound.play("whoosh", -2.0, 1.3)
				var hud = get_tree().get_first_node_in_group("hud")
				if hud:
					hud.toast("Ворота на нитро!", Art.TEAL, 1.8)
