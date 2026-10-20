extends StaticBody2D
## Дорожное ограждение (ремонтные работы). Твёрдое препятствие:
## в него нельзя проехать, удар наносит серьёзный урон.
## Находится на 2-м слое коллизий, поэтому встречные машины его не задевают.

@export var width: float = 320.0
@export var height: float = 36.0

var _blink: float = 0.0


func _ready() -> void:
	add_to_group("obstacles")
	collision_layer = 2
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	$CollisionShape2D.shape = shape


func _process(delta: float) -> void:
	_blink += delta
	queue_redraw()


func _draw() -> void:
	var half := Vector2(width, height) / 2.0
	draw_rect(Rect2(-half + Vector2(4, 6), Vector2(width, height)), Color(0, 0, 0, 0.35))  # тень
	draw_rect(Rect2(-half, Vector2(width, height)), Color(0.95, 0.95, 0.95))
	# Красные диагональные полосы
	var stripe := 28.0
	var x := -half.x
	var i := 0
	while x < half.x:
		if i % 2 == 0:
			var x2 := minf(x + stripe, half.x)
			draw_rect(Rect2(x, -half.y, x2 - x, height), Color(0.85, 0.1, 0.1))
		x += stripe
		i += 1
	draw_rect(Rect2(-half, Vector2(width, height)), Color(0.2, 0.2, 0.2), false, 3.0)
	# Мигающие фонари по краям
	var on := int(_blink * 3.0) % 2 == 0
	var lamp := Color(1.0, 0.75, 0.1) if on else Color(0.4, 0.3, 0.1)
	draw_circle(Vector2(-half.x + 10, -half.y - 6), 7.0, lamp)
	draw_circle(Vector2(half.x - 10, -half.y - 6), 7.0, lamp)


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			queue_free()
