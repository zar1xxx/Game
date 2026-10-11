extends Camera2D

@export var player: Node2D # Перетащите игрока в это поле в инспекторе
@export var smooth_speed: float = 100.0

func _physics_process(delta: float) -> void:
	if player:
		# Проверяем, поднялся ли игрок выше текущей позиции камеры
		if player.global_position.y< global_position.y:
			# Плавно двигаем камеру вверх к игроку
			global_position.y = lerp(global_position.y, player.global_position.y, smooth_speed * delta)
