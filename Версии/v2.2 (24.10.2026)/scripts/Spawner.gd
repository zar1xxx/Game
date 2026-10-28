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


func _ready() -> void:
	location = GameData.get_location(SaveManager.selected_location)
	# Заезд дня: одинаковый «случайный» расклад у всех игроков в этот день
	if SaveManager.daily_mode:
		seed(SaveManager.daily_seed())
	# Испытание недели — тоже одинаковый расклад у всех
	if SaveManager.weekly_mode:
		seed(SaveManager.weekly_seed())
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
	# Плотный трафик на сложных трассах — спавн чаще
	base_spawn_time /= location.traffic
	min_spawn_time /= location.traffic
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
	# Призрак рекорда: записывает заезд и показывает лучший (в обучении не нужен)
	if not SaveManager.tutorial_running:
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
		spawn_timer.wait_time = maxf(min_spawn_time, base_spawn_time - milestone * difficulty_step)


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
	var lane := randi() % Art.LANES
	if lane == _last_lane:
		lane = (lane + 1 + randi() % (Art.LANES - 1)) % Art.LANES
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
# Основной цикл спавна
# ---------------------------------------------------------------------------
func _on_spawn_timer_timeout() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var top := camera.global_position.y - get_viewport_rect().size.y / 2.0
	var policy := _event_policy()
	if policy == "none" or SaveManager.tutorial_running:
		return
	# С ростом сложности «спавнеров» становится больше: за один такт появляется
	# сразу несколько объектов (каждый — со своей случайной ролью: бонус или препятствие).
	var slots := spawner_count()
	for i in slots:
		var off := -i * 270.0
		var picked := _spawn_once(top + spawn_offset_y + off, top + enemy_spawn_offset_y + off, policy, i > 0)
		if picked == "gate":
			break                       # ворота перекрывают почти всю дорогу — больше ничего не ставим


## Сколько объектов появляется за один такт: 1 → 2 → 3 с ростом счёта (на плотных трассах раньше,
## в «Омск не отпускает» с кругами — до 4)
func spawner_count() -> int:
	var k: float = current_score * location.get("traffic", 1.0)
	var n := 1 + int(k / 500.0)
	var loop_bonus: int = _loop_level / 4 if _loop_level > 0 else 0
	return clampi(mini(n, 3) + loop_bonus, 1, 4)


## Один объект. extra — дополнительный «спавнер»: он чаще ставит бонусы и не ставит глухих перегородок
func _spawn_once(spawn_y: float, enemy_y: float, policy: String, extra: bool) -> String:
	var r := randf()
	var bonus_k := 1.6 if extra else 1.0
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

	var hazard := _pick_hazard()
	if extra and hazard in ["gate", "barrier"]:
		hazard = ["enemy", "pothole", "oil"].pick_random()
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
			var from_left := randf() < 0.5
			_add(tumbleweed_scene.instantiate(), Vector2(Art.ROAD_LEFT - 30.0 if from_left else Art.ROAD_RIGHT + 30.0, spawn_y + 120.0))
		"cow":
			# Корова выходит заранее, чтобы успеть дойти до дороги, пока игрок подъезжает
			var from_left := randf() < 0.5
			_add(cow_scene.instantiate(), Vector2(Art.ROAD_LEFT - 60.0 if from_left else Art.ROAD_RIGHT + 60.0, spawn_y - 200.0))
		"crab":
			var from_left := randf() < 0.5
			_add(crab_scene.instantiate(), Vector2(Art.ROAD_LEFT - 30.0 if from_left else Art.ROAD_RIGHT + 30.0, spawn_y + 60.0))
		"boulder":
			# Камень скатывается со скалы слева
			var boulder = boulder_scene.instantiate()
			boulder.lane = _random_lane()
			_add(boulder, Vector2(Art.ROAD_LEFT - 60.0, spawn_y - 120.0))
		"cones":
			_spawn_cone_row(spawn_y)
		"pothole":
			var hole = pothole_scene.instantiate()
			if location.theme == "winter":
				hole.variant = "snowdrift"
			elif location.theme == "rain" and not SaveManager.rule_active("potholes"):
				hole = oil_scene.instantiate()
				hole.variant = "puddle"
			_add_in_lane(hole, spawn_y)
		"oil":
			var slick = oil_scene.instantiate()
			if location.theme == "winter":
				slick.variant = "ice"
			elif location.theme == "rain":
				slick.variant = "puddle"
			_add_in_lane(slick, spawn_y)
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
	var roll: int = randi() % maxi(total, 1)
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


func _add_in_lane(obj: Node, y: float) -> void:
	_add(obj, Vector2(lane_center(_random_lane()) + randf_range(-25.0, 25.0), y))


func _spawn_in_lane(scene: PackedScene, y: float) -> void:
	if scene == null:
		return
	var x := lane_center(_random_lane()) + randf_range(-25.0, 25.0)
	_add(scene.instantiate(), Vector2(x, y))


func _spawn_enemy(y: float, behavior: int) -> void:
	if enemy_scene == null:
		return
	var enemy = enemy_scene.instantiate()
	enemy.behavior = behavior
	enemy.max_speed = (enemy.max_speed + last_difficulty_milestone * enemy_speed_step) * location.enemy_speed
	var lane := _random_lane()
	# Часть машин выезжает прямо на полосу игрока
	if behavior == 0 and randf() < target_player_chance:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and not _lane_blocked(lane_of(player.global_position.x)):
			lane = lane_of(player.global_position.x)
	_add(enemy, Vector2(lane_center(lane), y))


func _spawn_cone_row(y: float) -> void:
	# Конусы перекрывают одну-две полосы: прямо или по диагонали
	var lanes := randi_range(1, 2)
	var first := randi() % (Art.LANES - lanes + 1)
	var x0 := Art.ROAD_LEFT + first * Art.LANE_W + 24.0
	var x1 := Art.ROAD_LEFT + (first + lanes) * Art.LANE_W - 24.0
	var diagonal := randf() < 0.5
	var count := int((x1 - x0) / 56.0) + 1
	for i in count:
		var x := lerpf(x0, x1, float(i) / max(count - 1, 1))
		_add(cone_scene.instantiate(), Vector2(x, y - (i * 34.0 if diagonal else 0.0)))


func _spawn_barrier(y: float) -> void:
	# Ограждение на 1–2 полосы
	var lanes := 1 if randf() < 0.6 else 2
	var first := randi() % (Art.LANES - lanes + 1)
	var barrier = barrier_scene.instantiate()
	barrier.width = lanes * Art.LANE_W - 24.0
	_add(barrier, Vector2(Art.ROAD_LEFT + (first + lanes / 2.0) * Art.LANE_W, y))


func _spawn_gate(y: float) -> void:
	# «Ворота»: перекрыты все полосы, кроме одной
	var open_lane := randi() % Art.LANES
	# Для задания — нитро прямо перед проездом в воротах
	if _nitro_gate_mission and Missions.is_active("nitro_gate") and randf() < 0.75:
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
