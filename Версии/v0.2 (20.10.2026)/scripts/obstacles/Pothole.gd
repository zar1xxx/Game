extends Area2D
## Яма на дороге. Ощутимая тряска, урон и резкая потеря скорости.

@export var damage: float = 8.0
@export var speed_multiplier: float = 0.6
@export var shake_strength: float = 12.0
@export var radius: Vector2 = Vector2(46, 30)

var _hit: bool = false
var _points: PackedVector2Array


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	rotation = randf_range(-0.4, 0.4)
	# Неровный край ямы
	for i in 18:
		var a := TAU * i / 18.0
		var r := randf_range(0.8, 1.1)
		_points.append(Vector2(cos(a) * radius.x * r, sin(a) * radius.y * r))


func _draw() -> void:
	var outer := PackedVector2Array()
	for p in _points:
		outer.append(p * 1.15)
	draw_colored_polygon(outer, Color(0.35, 0.33, 0.3))   # раскрошенный асфальт по краю
	draw_colored_polygon(_points, Color(0.06, 0.05, 0.05)) # сама яма
	draw_circle(Vector2(-radius.x * 0.3, -radius.y * 0.25), radius.y * 0.25, Color(0.12, 0.1, 0.1))


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("hit_hazard"):
		body.hit_hazard(damage, speed_multiplier, shake_strength)


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			queue_free()
