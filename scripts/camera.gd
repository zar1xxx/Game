extends Camera2D

@export var player: Node2D # Перетащите игрока в это поле в инспекторе
@export var smooth_speed: float = 100.0

# --- НАСТРОЙКА СМЕЩЕНИЯ ИГРОКА ---
# Чем больше это число, тем ниже будет находиться машина игрока на экране.
@export var camera_offset_y: float = 230.0

# --- Отъезд камеры на скорости ---
# Чем быстрее едешь, тем шире обзор: встречные видно заранее. Машина игрока при этом
# остаётся на том же месте экрана, просто мир чуть «уменьшается».
@export var zoom_far: float = 0.84          # самый дальний вид (1.0 — обычный)
@export var zoom_speed_from: float = 520.0  # с какой скорости камера начинает отъезжать
@export var zoom_speed_to: float = 1250.0   # на какой скорости отъезжает полностью
var _zoom: float = 1.0

# --- Тряска камеры при ударах ---
@export var shake_decay: float = 40.0   # Как быстро затухает тряска
var shake_strength: float = 0.0
var chase_k: float = 0.0          # 0 — обычный вид, 1 — вид с погоней (выставляет PoliceChase)
var chase_target: float = 0.0
var chase_sources: Dictionary = {}   # кто просит «вид с погоней»: {"police": 1.0, "tck": 0.0}


func set_chase(source: String, value: float) -> void:
	chase_sources[source] = value
	var m := 0.0
	for v in chase_sources.values():
		m = maxf(m, v)
	chase_target = m


func _ready() -> void:
	add_to_group("game_camera")
	Art.view_h_world = get_viewport_rect().size.y


func _exit_tree() -> void:
	Art.view_h_world = Art.VIEW_H


func _physics_process(delta: float) -> void:
	if player:
		_update_zoom(delta)
		var off := camera_offset_y / _zoom
		# Целевая позиция камеры должна быть выше игрока на величину смещения
		# Во время погони камера опускает машину повыше, чтобы была видна полиция сзади
		chase_k = move_toward(chase_k, chase_target, delta * 1.5)
		var target_y = player.global_position.y - off + chase_k * 110.0 / _zoom
		if chase_k > 0.0 and target_y > global_position.y:
			global_position.y = lerp(global_position.y, target_y, min(1.0, 3.0 * delta))

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


func _update_zoom(delta: float) -> void:
	var spd: float = player.current_speed if "current_speed" in player else 0.0
	if "is_dead" in player and player.is_dead:
		spd = 0.0
	var k := clampf((spd - zoom_speed_from) / (zoom_speed_to - zoom_speed_from), 0.0, 1.0)
	var target := lerpf(1.0, zoom_far, k)
	# Отъезжает плавно, а после удара возвращается чуть быстрее
	_zoom = move_toward(_zoom, target, delta * (0.07 if target < _zoom else 0.11))
	zoom = Vector2(_zoom, _zoom)
	Art.view_h_world = get_viewport_rect().size.y / _zoom


## Встряхнуть камеру (вызывается игроком при столкновениях)
func shake(amount: float) -> void:
	shake_strength = max(shake_strength, amount)
