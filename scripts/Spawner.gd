extends Node2D

# Подключаем сцены из папки scenes
@export var enemy_scene: PackedScene = preload("res://scenes/EnemyCar.tscn")
@export var wrench_scene: PackedScene = preload("res://scenes/wrench.tscn")

# Шанс появления гаечного ключа (0.2 означает 20% шанс, остальные 80% — враг)
@export_range(0.0, 1.0) var wrench_spawn_chance: float = 0.2

# Настройки области спавна
@export var spawn_offset_y: float = -150.0  
@export var road_min_x: float = 200.0       
@export var road_max_x: float = 800.0       

@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout() -> void:
	# Выбираем случайное число от 0.0 до 1.0, чтобы определить, что заспавнить
	var rand_value = randf()
	
	var object_to_spawn: Node2D = null
	
	# Проверяем шанс выпадения ключа
	if rand_value < wrench_spawn_chance and wrench_scene != null:
		object_to_spawn = wrench_scene.instantiate()
	elif enemy_scene != null:
		object_to_spawn = enemy_scene.instantiate()
		
	if object_to_spawn == null:
		return
		
	# Расчет позиции над верхним краем экрана на основе камеры
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
		
	var screen_size = get_viewport_rect().size
	var zoom = camera.zoom
	var view_height = screen_size.y / zoom.y
	var top_screen_y = camera.global_position.y - (view_height / 2.0)
	
	# Задаем случайные координаты
	var random_x = randf_range(road_min_x, road_max_x)
	var spawn_y = top_screen_y + spawn_offset_y
	
	object_to_spawn.global_position = Vector2(random_x, spawn_y)
	
	# Спавним в корень уровня
	get_tree().current_scene.add_child(object_to_spawn)
