extends Area2D
## Брёвна, упавшие с лесовоза (тайга). Лежат поперёк одной-двух полос.
## Наехать — тряска, урон и сильная потеря скорости; монстр-трак и трактор их не замечают.

var width: float = 150.0          # ширина завала (задаёт спавнер)
var _hit: bool = false
var _logs: Array = []             # [смещение по y, длина, сдвиг по x, угол]


func _ready() -> void:
	add_to_group("hazards")
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width - 12.0, 40.0)
	shape.shape = r
	add_child(shape)
	body_entered.connect(_on_body_entered)
	for i in randi_range(2, 3):
		_logs.append([randf_range(-14.0, 14.0), width * randf_range(0.75, 0.98), randf_range(-12.0, 12.0), randf_range(-0.08, 0.08)])


func _draw() -> void:
	for l in _logs:
		draw_set_transform(Vector2(l[2], l[0]), l[3], Vector2.ONE)
		var half: float = l[1] / 2.0
		Art.rrect(self, Rect2(Vector2(-half, -9) + Vector2(5, 7), Vector2(l[1], 18)), Color(0, 0, 0, 0.3), 8)
		Art.rrect(self, Rect2(-half, -9, l[1], 18), Color("8a5a32"), 8, 2, Color("5a3a1e"))
		draw_line(Vector2(-half + 10, -3), Vector2(half - 14, -4), Color("6b4526"), 2.0)
		draw_circle(Vector2(half - 2, 0), 8, Color("d9b07a"))
		draw_arc(Vector2(half - 2, 0), 5, 0, TAU, 12, Color("b8925a"), 1.5)
		draw_circle(Vector2(-half + 2, 0), 8, Color("d9b07a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	Sound.play("bump", 0.0, 0.7)
	if body.has_method("hit_hazard"):
		body.hit_hazard(10.0, 0.5, 11.0, "pothole")


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and global_position.y > camera.global_position.y + Art.half_view_h() + 200.0:
		if not _hit:
			Missions.event("holes")
		queue_free()
