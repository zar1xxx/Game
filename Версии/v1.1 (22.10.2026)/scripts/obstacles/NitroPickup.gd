extends Area2D
## Бонус «Нитро»: на короткое время резко разгоняет машину
## и поднимает предел скорости.

@export var boost_duration: float = 2.5

var _t: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	Pickup.draw_halo(self, Art.TEAL, _t)
	var bob := sin(_t * 3.0) * 3.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	Art.rrect(self, Rect2(Vector2(-12, -20) + Art.SHADOW_OFFSET * 0.7, Vector2(24, 40)), Art.SHADOW, 10)
	Art.rrect(self, Rect2(-12, -20, 24, 40), Art.BLUE, 10, 2, Art.BLUE.darkened(0.45))
	draw_rect(Rect2(-5, -27, 10, 8), Art.SILVER)
	Art.text_center(self, Vector2(0, 1), "N", 20, Art.LINE_WHITE, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("start_nitro"):
		body.start_nitro(boost_duration)
	Pickup.burst(self, Art.TEAL, "Нитро!")
	queue_free()


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			queue_free()
