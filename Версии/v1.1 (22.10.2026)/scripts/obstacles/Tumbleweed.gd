extends Area2D
## Перекати-поле (пустыня): катится поперёк дороги. Урон маленький, но сбивает скорость.

@export var damage: float = 3.0
var _dir: float = 1.0
var _speed: float = 160.0
var _spin: float = 0.0
var _hit: bool = false


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	_dir = 1.0 if global_position.x < Art.ROAD_LEFT + Art.ROAD_W / 2.0 else -1.0
	_speed = randf_range(120.0, 220.0)


func _physics_process(delta: float) -> void:
	position.x += _dir * _speed * delta
	_spin += _dir * _speed * delta / 22.0
	queue_redraw()
	var camera := get_viewport().get_camera_2d()
	if (camera and global_position.y > camera.global_position.y + Art.VIEW_H / 2.0 + 200.0) \
			or global_position.x < Art.ROAD_LEFT - 300.0 or global_position.x > Art.ROAD_RIGHT + 300.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2(6, 8), 22, Color(0.4, 0.25, 0.1, 0.3))
	draw_circle(Vector2.ZERO, 22, Color(0.62, 0.48, 0.28, 0.55))
	for k in 7:
		var a := _spin + k * TAU / 7.0
		draw_arc(Vector2(cos(a), sin(a)) * 6.0, 15.0, a, a + 2.4, 10, Color("8a6a3e"), 2.5)
	draw_arc(Vector2.ZERO, 21.0, 0, TAU, 24, Color("a07a46"), 2.0)


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("hit_hazard"):
		body.hit_hazard(damage, 0.88, 3.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)
