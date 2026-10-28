extends Area2D
## Краб (Морское побережье): быстро бежит боком поперёк дороги, петляя.
## Если наехать — щёлкает клешнями и отпрыгивает, немного сбивая скорость.

var _dir: float = 1.0
var _speed: float = 180.0
var _t: float = 0.0
var _hit: bool = false


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	_dir = 1.0 if global_position.x < Art.ROAD_LEFT + Art.ROAD_W / 2.0 else -1.0
	_speed = randf_range(150.0, 230.0)
	_t = randf() * TAU
	($CollisionShape2D.shape as CircleShape2D).radius = 18.0


func _physics_process(delta: float) -> void:
	_t += delta
	position.x += _dir * _speed * delta
	position.y += sin(_t * 3.0) * 40.0 * delta
	queue_redraw()
	var camera := get_viewport().get_camera_2d()
	if (camera and global_position.y > camera.global_position.y + Art.VIEW_H / 2.0 + 200.0) \
			or global_position.x < Art.ROAD_LEFT - 300.0 or global_position.x > Art.ROAD_RIGHT + 300.0:
		queue_free()


func _draw() -> void:
	var leg := sin(_t * 22.0) * 3.0
	draw_circle(Vector2(4, 6), 16, Color(0, 0, 0, 0.25))
	for side in [-1.0, 1.0]:
		for k in 3:
			var y := -8.0 + k * 8.0
			draw_line(Vector2(side * 10, y), Vector2(side * 22, y + (leg if k % 2 == 0 else -leg)), Color("c2412d"), 3.0)
	draw_circle(Vector2.ZERO, 15, Color("e8573f"))
	draw_circle(Vector2(-3, -4), 6, Color("f07a5f"))
	# Клешни вперёд
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 10, -18)
		draw_circle(c, 6, Color("e8573f"))
		var open := 0.4 + 0.3 * sin(_t * 9.0 + side)
		draw_line(c, c + Vector2(side * 4, -6).rotated(open * side), Color("c2412d"), 2.5)
	draw_circle(Vector2(-5, -12), 3, Color.WHITE)
	draw_circle(Vector2(5, -12), 3, Color.WHITE)
	draw_circle(Vector2(-5, -12), 1.5, Art.INK)
	draw_circle(Vector2(5, -12), 1.5, Art.INK)


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	Sound.play("crab", -2.0, randf_range(0.9, 1.2), 0.0)
	if body.has_method("hit_hazard"):
		body.hit_hazard(2.0, 0.9, 2.0, "crab")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(_dir * 160.0, -60.0), 0.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)
