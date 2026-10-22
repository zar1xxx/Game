extends Node2D
## Спавнер: создаёт встречные машины, бонусы и препятствия.
## Новые типы препятствий открываются по мере роста счёта,
## а интервал спавна и скорость встречных машин растут со сложностью.

@export var enemy_scene: PackedScene = preload("res://scenes/EnemyCar.tscn")
@export var wrench_scene: PackedScene = preload("res://scenes/Wrench.tscn")
@export var fuel_scene: PackedScene = preload("res://scenes/FuelCan.tscn")
@export var nitro_scene: PackedScene = preload("res://scenes/obstacles/NitroPickup.tscn")
@export var cone_scene: PackedScene = preload("res://scenes/obstacles/TrafficCone.tscn")
@export var pothole_scene: PackedScene = preload("res://scenes/obstacles/Pothole.tscn")
@export var oil_scene: PackedScene = preload("res://scenes/obstacles/OilSlick.tscn")
@export var barrier_scene: PackedScene = preload("res://scenes/obstacles/RoadBarrier.tscn")

# --- Шансы бонусов (проверяются первыми, остальное — препятствия) ---
@export_range(0.0, 1.0) var wrench_spawn_chance: float = 0.08
@export_range(0.0, 1.0) var fuel_spawn_chance: float = 0.15
@export_range(0.0, 1.0) var nitro_spawn_chance: float = 0.04

# --- Атакующий спавн: машина появляется прямо на полосе игрока ---
@export_range(0.0, 1.0) var target_player_chance: float = 0.4

# --- Динамическая сложность ---
@export var base_spawn_time: float = 1.0
@export var difficulty_step: float = 0.05     # На сколько уменьшается интервал каждые 20 очков
@export var min_spawn_time: float = 0.4
@export var enemy_speed_step: float = 15.0    # Прибавка к скорости встречных машин каждые 20 очков

# --- Область спавна ---
@export var spawn_offset_y: float = -700
# Границы дороги в мировых координатах (по центру объекта)
@export var road_left_x: float = 80.0
@export var road_right_x: float = 1080.0

# В некоторых сценах спрайт сдвинут относительно корня (у встречной машины он в точке 506,
# у ключа и канистры — около 36). Смещение вычисляется автоматически по позиции Sprite2D
# (см. visual_offset_x), поэтому при замене спрайта ничего в коде править не нужно.

# Таблица препятствий: вес (как часто) и счёт, с которого открывается
var hazard_table: Array = [
	{"kind": "enemy",   "weight": 55, "unlock": 0},
	{"kind": "cones",   "weight": 10, "unlock": 5},
	{"kind": "pothole", "weight": 9,  "unlock": 15},
	{"kind": "oil",     "weight": 8,  "unlock": 25},
	{"kind": "zigzag",  "weight": 9,  "unlock": 35},
	{"kind": "barrier", "weight": 7,  "unlock": 45},
	{"kind": "truck",   "weight": 7,  "unlock": 60},
	{"kind": "gate",    "weight": 5,  "unlock": 80},
]

@onready var spawn_timer: Timer = $SpawnTimer

var last_difficulty_milestone: int = 0
var current_score: int = 0


func _ready() -> void:
	spawn_timer.wait_time = base_spawn_time
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	# ИСПРАВЛЕНО: раньше сигнал искался у ScoreLabel (это Label, у него нет такого сигнала),
	# поэтому сложность никогда не повышалась. Сигнал есть у счётчика очков игрока.
	var score_node := get_tree().get_first_node_in_group("score_counter")
	if score_node and score_node.has_signal("score_changed"):
		score_node.score_changed.connect(_on_player_score_changed)


func _on_player_score_changed(new_score: int) -> void:
	current_score = new_score
	var current_milestone: int = new_score / 20
	if current_milestone > last_difficulty_milestone:
		last_difficulty_milestone = current_milestone
		var new_time = base_spawn_time - (current_milestone * difficulty_step)
		_update_timer_speed(new_time)


func _update_timer_speed(new_time: float) -> void:
	var final_time = max(min_spawn_time, new_time)
	if spawn_timer.wait_time != final_time:
		spawn_timer.wait_time = final_time


# ---------------------------------------------------------------------------
# Основной цикл спавна
# ---------------------------------------------------------------------------
func _on_spawn_timer_timeout() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var view_height := get_viewport_rect().size.y / camera.zoom.y
	var spawn_y := camera.global_position.y - view_height / 2.0 + spawn_offset_y

	# 1. Бонусы
	var r := randf()
	if r < wrench_spawn_chance:
		_spawn_simple(wrench_scene, spawn_y)
		return
	r -= wrench_spawn_chance
	if r < fuel_spawn_chance:
		_spawn_simple(fuel_scene, spawn_y)
		return
	r -= fuel_spawn_chance
	if current_score >= 15 and r < nitro_spawn_chance:
		_spawn_simple(nitro_scene, spawn_y)
		return

	# 2. Препятствия
	match _pick_hazard():
		"enemy":
			_spawn_enemy(spawn_y, 0)
		"zigzag":
			_spawn_enemy(spawn_y, 1)
		"truck":
			_spawn_enemy(spawn_y, 2)
		"cones":
			_spawn_cone_row(spawn_y)
		"pothole":
			_spawn_simple(pothole_scene, spawn_y)
		"oil":
			_spawn_simple(oil_scene, spawn_y)
		"barrier":
			_spawn_barrier(spawn_y)
		"gate":
			_spawn_gate(spawn_y)


func _pick_hazard() -> String:
	var total := 0
	for entry in hazard_table:
		if current_score >= entry.unlock:
			total += entry.weight
	var roll: int = randi() % maxi(total, 1)
	for entry in hazard_table:
		if current_score < entry.unlock:
			continue
		if roll < entry.weight:
			return entry.kind
		roll -= entry.weight
	return "enemy"


# ---------------------------------------------------------------------------
# Вспомогательные функции спавна
# ---------------------------------------------------------------------------
func _random_road_x(margin: float = 0.0) -> float:
	return randf_range(road_left_x + margin, road_right_x - margin)


## Насколько видимая часть объекта (его Sprite2D) сдвинута по X относительно корня сцены.
## Если спрайта нет (объект рисуется кодом в _draw), смещение равно нулю.
static func visual_offset_x(node: Node) -> float:
	for child in node.get_children():
		if child is Sprite2D:
			return child.position.x
	return 0.0


## Ставит объект так, чтобы его видимая часть оказалась в точке center_x
func _add(obj: Node, center_x: float, y: float) -> void:
	var node := obj as Node2D
	if node == null:
		return
	node.global_position = Vector2(center_x - visual_offset_x(node), y)
	get_tree().current_scene.add_child(node)


func _spawn_simple(scene: PackedScene, y: float) -> void:
	if scene == null:
		return
	_add(scene.instantiate(), _random_road_x(40.0), y)


func _spawn_enemy(y: float, behavior: int) -> void:
	if enemy_scene == null:
		return
	var enemy = enemy_scene.instantiate()
	if "behavior" in enemy:
		enemy.behavior = behavior
	if "max_speed" in enemy:
		enemy.max_speed += last_difficulty_milestone * enemy_speed_step

	# Границы дороги для «лихача» в координатах корня машины
	var offset := visual_offset_x(enemy)
	if "min_x" in enemy:
		enemy.min_x = road_left_x - offset
		enemy.max_x = road_right_x - offset

	var x := _random_road_x(30.0)
	# Часть машин появляется прямо на полосе игрока
	if behavior == 0 and randf() < target_player_chance:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			var player_x := player.global_position.x + visual_offset_x(player)
			x = clamp(player_x, road_left_x, road_right_x)
	_add(enemy, x, y)


func _spawn_cone_row(y: float) -> void:
	# Ряд из 3–6 конусов: поперёк дороги или по диагонали
	var count := randi_range(3, 6)
	var step := 70.0
	var diagonal := randf() < 0.5
	var start_x := _random_road_x(0.0)
	start_x = clamp(start_x, road_left_x, road_right_x - step * (count - 1))
	for i in count:
		var dy := -i * 60.0 if diagonal else 0.0
		_add(cone_scene.instantiate(), start_x + i * step, y + dy)


func _spawn_barrier(y: float) -> void:
	var barrier = barrier_scene.instantiate()
	barrier.width = randf_range(240.0, 460.0)
	var half: float = barrier.width / 2.0
	_add(barrier, randf_range(road_left_x + half, road_right_x - half), y)


func _spawn_gate(y: float) -> void:
	# Два ограждения с узким проездом между ними
	var gap := randf_range(260.0, 340.0)
	var gap_center := randf_range(road_left_x + 200.0, road_right_x - 200.0)
	var left_w := (gap_center - gap / 2.0) - road_left_x + 60.0
	var right_w := road_right_x + 60.0 - (gap_center + gap / 2.0)
	if left_w > 40.0:
		var left = barrier_scene.instantiate()
		left.width = left_w
		_add(left, gap_center - gap / 2.0 - left_w / 2.0, y)
	if right_w > 40.0:
		var right = barrier_scene.instantiate()
		right.width = right_w
		_add(right, gap_center + gap / 2.0 + right_w / 2.0, y)
