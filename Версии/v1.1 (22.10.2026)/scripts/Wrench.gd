extends Area2D
## Гаечный ключ — полностью ремонтирует машину.

var _t: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	_t = randf() * TAU


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("heal_full"):
			body.heal_full()
		Pickup.burst(self, Art.GREEN, "Ремонт!")
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _physics_process(_delta: float) -> void:
	Pickup.cleanup_if_behind(self)


func _draw() -> void:
	Pickup.draw_halo(self, Art.GREEN, _t)
	var ang := 0.6 + sin(_t * 2.0) * 0.25
	draw_set_transform(Art.SHADOW_OFFSET * 0.6, ang, Vector2.ONE)
	_wrench_shape(Art.SHADOW)
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	_wrench_shape(Art.SILVER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _wrench_shape(col: Color) -> void:
	draw_rect(Rect2(-4, -14, 8, 30), col)
	draw_circle(Vector2(0, -16), 10, col)
	draw_circle(Vector2(0, 18), 7, col)
	if col != Art.SHADOW:
		# Отверстия накидного ключа
		draw_circle(Vector2(0, -16), 5, Art.INK)
		draw_circle(Vector2(0, 18), 3, Art.INK)
