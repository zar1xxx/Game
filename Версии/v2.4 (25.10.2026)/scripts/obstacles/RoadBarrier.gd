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
	var rect := Rect2(-half, Vector2(width, height))
	Art.rrect(self, Rect2(rect.position + Art.SHADOW_OFFSET, rect.size), Art.SHADOW, 6)
	Art.rrect(self, rect, Art.LINE_WHITE, 6)
	# Красные полосы
	var stripe := 28.0
	var x := -half.x + 6
	var i := 0
	while x < half.x - 6:
		if i % 2 == 0:
			var x2 := minf(x + stripe, half.x - 6)
			draw_rect(Rect2(x, -half.y + 4, x2 - x, height - 8), Art.RED)
		x += stripe
		i += 1
	Art.rrect(self, rect, Color(0, 0, 0, 0), 6, 3, Art.INK)
	# Мигающие фонари по краям
	var on := int(_blink * 3.0) % 2 == 0
	for px in [-half.x + 12, half.x - 12]:
		var p := Vector2(px, -half.y - 6)
		draw_circle(p, 6.0, Art.YELLOW if on else Color("5a5030"))
		if on:
			Art.glow(self, p, 26, Color(1, 0.75, 0.2, 0.45), 4)


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			queue_free()
