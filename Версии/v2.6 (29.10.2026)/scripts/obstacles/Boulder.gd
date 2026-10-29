extends Area2D
## Камнепад (Горный серпантин): валун скатывается со скалы слева и замирает на одной из полос.
## Врезаться — больно; валун разлетается на куски.

@export var damage: float = 14.0
var _target_x: float = 0.0
var lane: int = -1                     # полосу задаёт спавнер (свободную от дорожных событий)
var _rolling: bool = true
var _spin: float = 0.0
var _size: float = 1.0
var _hit: bool = false
var _shape: PackedVector2Array


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	_size = randf_range(0.85, 1.25)
	if lane < 0:
		lane = randi() % Art.LANES
	_target_x = Art.ROAD_LEFT + Art.LANE_W * (lane + 0.5) + randf_range(-15.0, 15.0)
	for k in 9:
		var a := TAU * k / 9.0
		_shape.append(Vector2(cos(a), sin(a)) * 26.0 * _size * randf_range(0.8, 1.1))
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	($CollisionShape2D.shape as CircleShape2D).radius = 24.0 * _size
	Sound.play("rockfall", -4.0, randf_range(0.9, 1.1), 0.0)


func _physics_process(delta: float) -> void:
	if _rolling:
		var step := 420.0 * delta
		position.x = move_toward(position.x, _target_x, step)
		_spin += step / (26.0 * _size)
		if absf(position.x - _target_x) < 1.0:
			_rolling = false
	queue_redraw()
	var camera := get_viewport().get_camera_2d()
	if camera and global_position.y > camera.global_position.y + Art.half_view_h() + 200.0:
		queue_free()


func _draw() -> void:
	draw_set_transform(Vector2(7, 9), 0, Vector2.ONE)
	draw_colored_polygon(_shape, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
	draw_colored_polygon(_shape, Color("8a8580"))
	var inner := PackedVector2Array()
	for v in _shape:
		inner.append(v * 0.6 + Vector2(-4, -4))
	draw_colored_polygon(inner, Color("a29d97"))
	draw_line(Vector2(-10, 4) * _size, Vector2(8, 10) * _size, Color("6b6762"), 2.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _rolling:
		for k in 3:
			draw_circle(Vector2(-30 - k * 16, 10 + sin(_spin + k) * 6), 8 - k * 2, Color(0.75, 0.7, 0.62, 0.4))


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("hit_hazard"):
		body.hit_hazard(damage, 0.45, 12.0, "rock")
	Sound.play("crash", -3.0, 0.7)
	# Валун разлетается на куски
	for k in 6:
		var piece := Polygon2D.new()
		piece.polygon = PackedVector2Array([Vector2(-6, -5), Vector2(6, -4), Vector2(4, 6), Vector2(-5, 5)])
		piece.color = Color("8a8580")
		piece.global_position = global_position
		get_parent().add_child(piece)
		var dir := Vector2.from_angle(TAU * k / 6.0 + randf() * 0.5)
		var tw := piece.create_tween().set_parallel(true)
		tw.tween_property(piece, "global_position", global_position + dir * randf_range(60, 120), 0.5)
		tw.tween_property(piece, "rotation", randf_range(-6, 6), 0.5)
		tw.tween_property(piece, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(piece.queue_free)
	queue_free()
