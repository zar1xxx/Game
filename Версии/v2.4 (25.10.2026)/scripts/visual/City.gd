extends Node2D
## Городской ландшафт по краям дороги.
## Кварталы (CityRow) создаются впереди камеры и удаляются позади,
## поэтому город бесконечный. Каждый квартал анимирован сам по себе.

const CityRow := preload("res://scripts/visual/CityRow.gd")
const SidewalkLife := preload("res://scripts/visual/SidewalkLife.gd")

@export var spawn_ahead: float = 900.0      # Насколько выше экрана создаются кварталы
@export var despawn_behind: float = 500.0   # Насколько ниже экрана они удаляются
@export var intersection_chance: float = 0.16

var _next_y: float = 0.0           # Нижняя граница следующего квартала (растёт вверх, т.е. уменьшается)
var _rows: Array = []
var _rng := RandomNumberGenerator.new()
var _since_intersection: int = 0


func _ready() -> void:
	z_index = -10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	var life := SidewalkLife.new()
	life.z_index = 2
	add_child(life)
	var cam := get_viewport().get_camera_2d()
	_next_y = (cam.global_position.y if cam else 0.0) + Art.view_h_world
	_fill()


func _process(_delta: float) -> void:
	_fill()
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var limit := cam.global_position.y + Art.half_view_h() + despawn_behind
	# Кварталы добавляются снизу вверх, поэтому самые старые (нижние) — в начале списка
	while _rows.size() > 0 and _rows[0].position.y > limit:
		_rows.pop_front().queue_free()


func _fill() -> void:
	var cam := get_viewport().get_camera_2d()
	var cam_y := cam.global_position.y if cam else 0.0
	while _next_y > cam_y - Art.half_view_h() - spawn_ahead:
		var row := CityRow.new()
		var chance: float = intersection_chance * {"desert": 0.3, "village": 0.45, "beach": 0.7, "mountain": 0.0}.get(Art.theme, 1.0)
		var intersection := _since_intersection >= 3 and _rng.randf() < chance
		_since_intersection = 0 if intersection else _since_intersection + 1
		var h := _rng.randf_range(130.0, 160.0) if intersection else _rng.randf_range(190.0, 360.0)
		row.setup(h, intersection, _rng.randi())
		row.position = Vector2(0, _next_y - h)
		row.z_index = 0
		add_child(row)
		_rows.append(row)
		_next_y -= h


## Пересобрать все кварталы (например, после смены трассы в меню)
func rebuild() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	var cam := get_viewport().get_camera_2d()
	_next_y = (cam.global_position.y if cam else 0.0) + Art.view_h_world
	_fill()
