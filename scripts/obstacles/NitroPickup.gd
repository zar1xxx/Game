extends Area2D
## Бонус «Нитро»: на короткое время резко разгоняет машину
## и поднимает предел скорости.

@export var boost_duration: float = 2.5

var _t: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var glow := 0.35 + 0.25 * sin(_t * 6.0)
	draw_circle(Vector2.ZERO, 30.0, Color(0.2, 0.7, 1.0, glow * 0.5))
	draw_rect(Rect2(-12, -22, 24, 40), Color(0.1, 0.45, 0.95))      # баллон
	draw_rect(Rect2(-6, -28, 12, 7), Color(0.75, 0.75, 0.8))         # вентиль
	draw_rect(Rect2(-12, -22, 24, 40), Color(0.85, 0.95, 1.0), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-8, 6), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("start_nitro"):
		body.start_nitro(boost_duration)
	queue_free()


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			queue_free()
