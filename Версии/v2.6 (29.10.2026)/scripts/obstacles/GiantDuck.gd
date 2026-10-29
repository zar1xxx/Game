extends Area2D
## Гигантская резиновая уточка (режим «Омск не отпускает»): вперевалку переходит дорогу.
## Врезались — «КРЯ!», машину встряхивает и она теряет скорость.

const R := 44.0
var _dir: float = 1.0
var _speed: float = 110.0
var _t: float = 0.0
var _hit: bool = false


func _ready() -> void:
	add_to_group("hazards")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = R
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_dir = 1.0 if global_position.x < Art.ROAD_LEFT + Art.ROAD_W / 2.0 else -1.0
	_speed = randf_range(90.0, 150.0)
	_t = randf() * 10.0


func _physics_process(delta: float) -> void:
	_t += delta
	position.x += _dir * _speed * delta
	queue_redraw()
	var camera := get_viewport().get_camera_2d()
	if (camera and global_position.y > camera.global_position.y + Art.half_view_h() + 260.0) \
			or global_position.x < Art.ROAD_LEFT - 400.0 or global_position.x > Art.ROAD_RIGHT + 400.0:
		queue_free()


func _draw() -> void:
	var wob := sin(_t * 7.0) * 0.18
	draw_set_transform(Vector2.ZERO, wob + (0.0 if _dir > 0 else 0.0), Vector2(_dir, 1.0))
	draw_circle(Vector2(10, 14), R, Color(0, 0, 0, 0.3))
	# Тело, крылышко, голова и клюв (смотрит туда, куда идёт)
	draw_circle(Vector2.ZERO, R, Art.YELLOW)
	draw_circle(Vector2(-6, 6), R * 0.55, Art.YELLOW.darkened(0.08))
	draw_circle(Vector2(R * 0.55, -R * 0.15), R * 0.55, Art.YELLOW.lightened(0.05))
	draw_colored_polygon(PackedVector2Array([Vector2(R * 0.95, -R * 0.25), Vector2(R * 1.45, -R * 0.12),
		Vector2(R * 0.95, R * 0.02)]), Art.ORANGE)
	draw_circle(Vector2(R * 0.66, -R * 0.42), 5, Art.INK)
	draw_circle(Vector2(R * 0.66, R * 0.12), 5, Art.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("hit_hazard"):
		body.hit_hazard(6.0, 0.6, 9.0)
	Sound.play("horn", -2.0, 2.2, 0.0)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast(["КРЯ!", "Уточка обиделась", "КРЯ-КРЯ! Не дави уток!", "Утка: «Это мой Омск»"].pick_random(), Art.YELLOW, 1.6)
	_speed *= 2.5
