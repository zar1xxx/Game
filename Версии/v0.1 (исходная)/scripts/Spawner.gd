extends Node2D

@export var enemy_scene: PackedScene = preload("res://scenes/EnemyCar.tscn")
@export var wrench_scene: PackedScene = preload("res://scenes/wrench.tscn")
@export var fuel_scene: PackedScene = preload("res://scenes/FuelCan.tscn") # Путь к канистре

# Шансы появления предметов (в сумме должно быть меньше 1.0, остальное — враги)
@export_range(0.0, 1.0) var wrench_spawn_chance: float = 0.08  # 5% на гаечный ключ
@export_range(0.0, 1.0) var fuel_spawn_chance: float = 0.15    # 15% на канистру с топливом

# --- НАСТРОЙКА АТАКУЮЩЕГО СПАВНА ---
@export_range(0.0, 1.0) var target_player_chance: float = 0.4 

# --- НАСТРОЙКИ ДИНАМИЧЕСКОЙ СЛОЖНОСТИ ---
@export var base_spawn_time: float = 1.0     
@export var difficulty_step: float = 0.05     
@export var min_spawn_time: float = 0.4      

# Настройки области спавна
@export var spawn_offset_y: float = -700
@export var road_min_x: float = -460.0     
@export var road_max_x: float = 600.0     

@onready var spawn_timer: Timer = $SpawnTimer

var last_difficulty_milestone: int = 0

func _ready() -> void:
	spawn_timer.wait_time = base_spawn_time
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	var score_node = %ScoreLabel
	if score_node and score_node.has_signal("score_changed"):
		score_node.score_changed.connect(_on_player_score_changed)

func _on_player_score_changed(new_score: int) -> void:
	var current_milestone = new_score / 20
	if current_milestone > last_difficulty_milestone:
		last_difficulty_milestone = current_milestone
		var new_time = base_spawn_time - (current_milestone * difficulty_step)
		_update_timer_speed(new_time)

func _update_timer_speed(new_time: float) -> void:
	var final_time = max(min_spawn_time, new_time)
	if spawn_timer.wait_time != final_time:
		spawn_timer.wait_time = final_time
		print("Сложность повышена! Новый интервал спавна: ", final_time, " сек.")

func _on_spawn_timer_timeout() -> void:
	var rand_value = randf()
	var object_to_spawn: Node2D = null
	var is_enemy: bool = false
	
	# Распределяем шансы появления объектов
	if rand_value < wrench_spawn_chance and wrench_scene != null:
		object_to_spawn = wrench_scene.instantiate()
	elif rand_value < (wrench_spawn_chance + fuel_spawn_chance) and fuel_scene != null:
		object_to_spawn = fuel_scene.instantiate()
	elif enemy_scene != null:
		object_to_spawn = enemy_scene.instantiate()
		is_enemy = true
		
	if object_to_spawn == null:
		return
		
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
		
	var screen_size = get_viewport_rect().size
	var zoom = camera.zoom
	var view_height = screen_size.y / zoom.y
	var top_screen_y = camera.global_position.y - (view_height / 2.0)
	
	var random_x = randf_range(road_min_x, road_max_x)
	
	# Преследование игрока врагами
	if is_enemy and randf() < target_player_chance:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player_node = players[0] as Node2D
			if player_node:
				random_x = player_node.global_position.x
				random_x = clamp(random_x, road_min_x, road_max_x)
	
	var spawn_y = top_screen_y + spawn_offset_y
	object_to_spawn.global_position = Vector2(random_x, spawn_y)
	get_tree().current_scene.add_child(object_to_spawn)
