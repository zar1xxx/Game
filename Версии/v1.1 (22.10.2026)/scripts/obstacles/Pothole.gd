extends Area2D
## Яма на дороге. Ощутимая тряска, урон и резкая потеря скорости.

## Варианты: «pothole» — яма, «snowdrift» — сугроб (зима: урона меньше, но вязнет)
@export_enum("pothole", "snowdrift") var variant: String = "pothole"
@export var damage: float = 8.0
@export var speed_multiplier: float = 0.6
@export var shake_strength: float = 12.0
@export var radius: Vector2 = Vector2(46, 30)

var _hit: bool = false
var _points: PackedVector2Array


func _ready() -> void:
	add_to_group("hazards")
	_apply_variant()
	body_entered.connect(_on_body_entered)
	rotation = randf_range(-0.4, 0.4)
	# Неровный край ямы
	for i in 18:
		var a := TAU * i / 18.0
		var r := randf_range(0.8, 1.1)
		_points.append(Vector2(cos(a) * radius.x * r, sin(a) * radius.y * r))


func _draw() -> void:
	if variant == "snowdrift":
		var pts := PackedVector2Array()
		for p in _points:
			pts.append(p * 1.1)
		draw_colored_polygon(PackedVector2Array(Array(pts).map(func(v): return v + Vector2(8, 10))), Color(0.3, 0.35, 0.45, 0.35))
		draw_colored_polygon(pts, Color("eef3f8"))
		draw_colored_polygon(PackedVector2Array(Array(_points).map(func(v): return v * 0.55 + Vector2(-6, -6))), Color("ffffff"))
		return
	var outer := PackedVector2Array()
	for p in _points:
		outer.append(p * 1.18)
	draw_colored_polygon(outer, Art.ASPHALT_PATCH.lightened(0.08))  # раскрошенный край
	draw_colored_polygon(_points, Art.INK)                          # сама яма
	var inner := PackedVector2Array()
	for p in _points:
		inner.append(p * 0.6 + Vector2(radius.x * 0.12, radius.y * 0.15))
	draw_colored_polygon(inner, Color("0f1118"))
	draw_polyline(outer + PackedVector2Array([outer[0]]), Art.ASPHALT_CRACK, 2.0)


func _apply_variant() -> void:
	if variant == "snowdrift":
		damage = 3.0
		speed_multiplier = 0.5
		shake_strength = 6.0


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
