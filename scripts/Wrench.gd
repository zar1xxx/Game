extends Area2D

func _ready() -> void:
	# Подключаем встроенный сигнал касания тела к нашей функции
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Проверяем, что в ключ врезался именно игрок
	if body.is_in_group("player"):
		# Если у игрока есть метод полного лечения, вызываем его
		if body.has_method("heal_full"):
			body.heal_full()
		
		# Удаляем ключ с карты после подбора
		queue_free()

func _physics_process(_delta: float) -> void:
	# Защита: если игрок проехал мимо и ключ остался далеко позади, удаляем его
	keep_clean_outside_screen()

func keep_clean_outside_screen() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var screen_size = get_viewport_rect().size
		var zoom = camera.zoom
		var view_height = screen_size.y / zoom.y
		# Если ключ оказался сильно ниже экрана (игрок уехал вверх)
		if global_position.y > camera.global_position.y + (view_height / 2.0) + 200.0:
			queue_free()
