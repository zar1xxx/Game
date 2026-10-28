extends Node2D
## Клуб дыма из выхлопной трубы (косметика за уровень водителя).
## Стили: grey — сизый дымок, black — дизельный, rainbow — радуга,
## hearts — сердечки, fire — выхлоп с огнём.

var style: String = "grey"
var hue: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var life: float = 0.0
var max_life: float = 0.7
var _seed: float = 0.0


func _ready() -> void:
	z_index = 1
	_seed = randf() * TAU
	max_life = {"hearts": 1.1, "fire": 0.35, "black": 0.9}.get(style, 0.7)


func _process(delta: float) -> void:
	life += delta
	if life >= max_life:
		queue_free()
		return
	position += velocity * delta
	queue_redraw()


func _draw() -> void:
	var k := life / max_life          # 0 → 1
	var a := 1.0 - k
	match style:
		"grey":
			draw_circle(Vector2.ZERO, 5.0 + 16.0 * k, Color(0.78, 0.8, 0.86, 0.38 * a))
		"black":
			draw_circle(Vector2.ZERO, 6.0 + 20.0 * k, Color(0.12, 0.12, 0.14, 0.55 * a))
			draw_circle(Vector2(3, -2), 3.0 + 10.0 * k, Color(0.25, 0.25, 0.28, 0.4 * a))
		"rainbow":
			var c := Color.from_hsv(hue, 0.75, 1.0, 0.7 * a)
			draw_circle(Vector2.ZERO, 5.0 + 9.0 * k, c)
		"hearts":
			var s := 0.6 + 0.6 * k
			var wob := Vector2(sin(life * 6.0 + _seed) * 6.0, 0)
			_heart(wob, 9.0 * s, Color(1.0, 0.36, 0.55, 0.85 * a))
		"fire":
			var r := 4.0 + 10.0 * k
			draw_circle(Vector2.ZERO, r + 4.0, Color(1.0, 0.35, 0.05, 0.45 * a))
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.75, 0.2, 0.8 * a))
			draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.97, 0.8, 0.9 * a))


func _heart(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.55, col)
	draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.55, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, 0), c + Vector2(r * 1.02, 0), c + Vector2(0, r * 1.05)]), col)
