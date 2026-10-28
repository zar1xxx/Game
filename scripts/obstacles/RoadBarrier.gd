extends StaticBody2D
## Дорожное ограждение (ремонтные работы). Твёрдое препятствие:
## в него нельзя проехать, удар наносит серьёзный урон.
## Находится на 2-м слое коллизий, поэтому встречные машины его не задевают.

@export var width: float = 320.0
@export var height: float = 36.0
## Вид: "default" — дорожное ограждение, "scaffold" — строительные леса (метро),
## "hummock" — торос (лёд), "wooden" — деревянные козлы (Омск-1985)
var style: String = "default"

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
	if style == "default" or style == "scaffold":
		queue_redraw()


func _draw() -> void:
	var half := Vector2(width, height) / 2.0
	var rect := Rect2(-half, Vector2(width, height))
	match style:
		"scaffold":
			_draw_scaffold(rect)
			return
		"hummock":
			_draw_hummock(rect)
			return
		"wooden":
			_draw_wooden(rect)
			return
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


## Строительные леса (метро): решётка из труб и доски настила
func _draw_scaffold(rect: Rect2) -> void:
	Art.rrect(self, Rect2(rect.position + Art.SHADOW_OFFSET, rect.size), Art.SHADOW, 4)
	draw_rect(rect, Color("8a6a3e"))
	var x := rect.position.x
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("6b4f2a"), 2.0)
		x += 22.0
	for yy in [rect.position.y + 3, rect.end.y - 3]:
		draw_line(Vector2(rect.position.x, yy), Vector2(rect.end.x, yy), Color("c9cdd6"), 4.0)
	x = rect.position.x + 6
	var i := 0
	while x < rect.end.x - 6:
		draw_line(Vector2(x, rect.position.y + 3), Vector2(x + 30, rect.end.y - 3), Color("c9cdd6"), 3.0)
		draw_circle(Vector2(x, rect.position.y + 3), 3.5, Color("8a8f9c"))
		x += 44.0
		i += 1
	var on := int(_blink * 3.0) % 2 == 0
	draw_circle(Vector2(rect.position.x + 10, rect.position.y - 6), 5, Art.ORANGE if on else Color("5a3a10"))
	draw_circle(Vector2(rect.end.x - 10, rect.position.y - 6), 5, Color("5a3a10") if on else Art.ORANGE)
	if on:
		Art.glow(self, Vector2(rect.position.x + 10, rect.position.y - 6), 24, Color(1, 0.6, 0.2, 0.45))


## Торос: нагромождение ледяных глыб
func _draw_hummock(rect: Rect2) -> void:
	var n := int(rect.size.x / 34.0) + 1
	for k in n:
		var c := Vector2(rect.position.x + 17 + k * (rect.size.x - 34) / maxf(n - 1, 1), sin(k * 2.3) * 5.0)
		var s := 20.0 + Art.hash01(k * 7 + int(width)) * 8.0
		var pts := PackedVector2Array()
		for j in 6:
			var a := j * TAU / 6.0 + k
			pts.append(c + Vector2(cos(a), sin(a)) * s * (0.75 + 0.25 * sin(k + j * 2.0)))
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + Vector2(5, 7))
		draw_colored_polygon(sh, Color(0.25, 0.4, 0.55, 0.3))
		draw_colored_polygon(pts, Color("bfe0f0"))
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], c]), Color("eaf7fd"))
		draw_line(c, pts[4], Color(1, 1, 1, 0.8), 1.5)


## Деревянные козлы в бело-красную полоску (как в 80-е)
func _draw_wooden(rect: Rect2) -> void:
	Art.rrect(self, Rect2(rect.position + Art.SHADOW_OFFSET, rect.size), Art.SHADOW, 3)
	for lx in [rect.position.x + 14, rect.end.x - 14]:
		draw_line(Vector2(lx - 8, rect.end.y + 4), Vector2(lx, rect.position.y), Color("6b4526"), 4.0)
		draw_line(Vector2(lx + 8, rect.end.y + 4), Vector2(lx, rect.position.y), Color("6b4526"), 4.0)
	var plank := Rect2(rect.position.x, rect.get_center().y - 9, rect.size.x, 18)
	draw_rect(plank, Color("efe6d0"))
	var x := plank.position.x
	var i := 0
	while x < plank.end.x:
		if i % 2 == 0:
			draw_rect(Rect2(x, plank.position.y, minf(26.0, plank.end.x - x), plank.size.y), Color("b8483e"))
		x += 26.0
		i += 1
	draw_rect(plank, Color(0, 0, 0, 0), false, 2.0)
