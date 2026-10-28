extends Area2D
## Скользкое пятно. Урона нет, но машина теряет сцепление и её заносит.
## Варианты: «oil» — масло, «ice» — гололёд (зима), «puddle» — лужа (ливень).

@export_enum("oil", "ice", "puddle", "mud") var variant: String = "oil"
@export var slip_duration: float = 1.6
var _t: float = 0.0

var _blobs: Array = []   # [центр, радиус]
var _used: bool = false


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	for i in 6:
		_blobs.append([Vector2(randf_range(-40, 40), randf_range(-22, 22)), randf_range(18, 32)])
	match variant:
		"ice":
			slip_duration = 1.3
		"puddle":
			slip_duration = 0.8


func _process(delta: float) -> void:
	if variant == "puddle":
		_t += delta
		queue_redraw()


func _draw() -> void:
	if variant == "mud":
		for b in _blobs:
			draw_circle(b[0], b[1], Color(0.33, 0.24, 0.15, 0.92))
		for k in 3:
			draw_circle(_blobs[k][0] + Vector2(4, -3), _blobs[k][1] * 0.35, Color(0.45, 0.34, 0.22, 0.9))
		return
	if variant == "ice":
		for b in _blobs:
			draw_circle(b[0], b[1], Color(0.72, 0.86, 0.97, 0.85))
		for b in _blobs:
			draw_line(b[0] - Vector2(b[1] * 0.5, 0), b[0] + Vector2(b[1] * 0.3, -b[1] * 0.3), Color(1, 1, 1, 0.8), 2.0)
		return
	if variant == "puddle":
		for b in _blobs:
			draw_circle(b[0], b[1], Color(0.25, 0.32, 0.45, 0.85))
		for k in 3:
			var rr := fmod(_t * 18.0 + k * 9.0, 26.0)
			draw_arc(_blobs[k][0], rr, 0, TAU, 20, Color(0.75, 0.85, 1.0, 0.5 * (1.0 - rr / 26.0)), 1.5)
		return
	for b in _blobs:
		draw_circle(b[0], b[1], Color(0.04, 0.04, 0.07, 0.94))
	# Радужные блики на масле
	for i in range(0, _blobs.size(), 2):
		var b = _blobs[i]
		draw_arc(b[0], b[1] * 0.6, 0.3, 2.2, 12, Color(Art.PURPLE, 0.6), 3.0)
		draw_arc(b[0], b[1] * 0.45, 3.4, 5.0, 12, Color(Art.TEAL, 0.5), 2.0)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	# Трактор по лужам едет как ни в чём не бывало
	if variant == "puddle" and "car" in body and body.car.get("offroad", false):
		return
	# Снегоходу гололёд не страшен
	if variant == "ice" and "car" in body and body.car.get("snow", false):
		return
	# Грязь не заносит, а вязко тормозит
	if variant == "mud":
		Sound.play("splash", -4.0, 0.7)
		if body.has_method("hit_hazard"):
			body.hit_hazard(0.0, 0.62, 4.0, "mud")
		return
	if body.has_method("apply_slip"):
		body.apply_slip(slip_duration)


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			if not _used and (variant == "puddle" or variant == "mud"):
				Missions.event("holes")      # лужи на мокрой трассе играют роль ям
			queue_free()
