extends Camera2D

@export var player: Node2D # Перетащите игрока в это поле в инспекторе
@export var smooth_speed: float = 100.0

# --- НАСТРОЙКА СМЕЩЕНИЯ ИГРОКА (Новое!) ---
# Чем больше это число, тем ниже будет находиться машина игрока на экране.
# По умолчанию поставим 300 пикселей (настройте под свой экран).
@export var camera_offset_y: float = 220.0

func _physics_process(delta: float) -> void:
	if player:
		# Целевая позиция камеры должна быть выше игрока на величину смещения
		var target_y = player.global_position.y - camera_offset_y
		
		# Проверяем, поднялся ли игрок выше текущей точки фокуса камеры
		if target_y < global_position.y:
			# Плавно двигаем камеру вверх к целевой позиции
			global_position.y = lerp(global_position.y, target_y, smooth_speed * delta)
