extends Area2D
## Масляное пятно. Урона нет, но машина теряет сцепление и её заносит.

@export var slip_duration: float = 1.6

var _blobs: Array = []   # [центр, радиус]
var _used: bool = false


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	for i in 6:
		_blobs.append([Vector2(randf_range(-40, 40), randf_range(-22, 22)), randf_range(18, 32)])


func _draw() -> void:
	for b in _blobs:
		draw_circle(b[0], b[1], Color(0.03, 0.03, 0.05, 0.92))
	# Радужные блики на масле
	for i in range(0, _blobs.size(), 2):
		var b = _blobs[i]
		draw_arc(b[0], b[1] * 0.6, 0.3, 2.2, 12, Color(0.4, 0.3, 0.9, 0.55), 3.0)
		draw_arc(b[0], b[1] * 0.45, 3.4, 5.0, 12, Color(0.2, 0.8, 0.7, 0.45), 2.0)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	if body.has_method("apply_slip"):
		body.apply_slip(slip_duration)


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			queue_free()
