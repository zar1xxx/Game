extends Camera2D

@export var player: Node2D # Перетащите игрока в это поле в инспекторе
@export var smooth_speed: float = 100.0

# --- НАСТРОЙКА СМЕЩЕНИЯ ИГРОКА ---
# Чем больше это число, тем ниже будет находиться машина игрока на экране.
@export var camera_offset_y: float = 230.0

# --- Тряска камеры при ударах ---
@export var shake_decay: float = 40.0   # Как быстро затухает тряска
var shake_strength: float = 0.0


func _ready() -> void:
	add_to_group("game_camera")


func _physics_process(delta: float) -> void:
	if player:
		# Целевая позиция камеры должна быть выше игрока на величину смещения
		var target_y = player.global_position.y - camera_offset_y

		# Проверяем, поднялся ли игрок выше текущей точки фокуса камеры
		if target_y < global_position.y:
			# ИСПРАВЛЕНО: коэффициент lerp ограничен единицей — раньше при 100 * delta (> 1)
			# камера «перелетала» цель и дрожала
			global_position.y = lerp(global_position.y, target_y, min(1.0, smooth_speed * delta))

	# Тряска
	if shake_strength > 0.0:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
	else:
		offset = Vector2.ZERO


## Встряхнуть камеру (вызывается игроком при столкновениях)
func shake(amount: float) -> void:
	shake_strength = max(shake_strength, amount)
