extends Area2D
## Дорожный конус. Небольшой урон и потеря скорости, после удара отлетает в сторону.
## Спавнится рядами (см. Spawner.gd).

@export var damage: float = 4.0
@export var speed_multiplier: float = 0.85   # Сколько скорости остаётся после удара
@export var shake_strength: float = 4.0

var _hit: bool = false


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	draw_circle(Vector2(3, 4), 17.0, Color(0, 0, 0, 0.3))                   # тень
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.12, 0.12, 0.12))              # основание
	draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.45, 0.05))                   # конус
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color(0.95, 0.95, 0.95), 4.0)   # светоотражающая полоса
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.65, 0.3))                     # верхушка


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	set_deferred("monitoring", false)
	if body.has_method("hit_hazard"):
		body.hit_hazard(damage, speed_multiplier, shake_strength)

	# Конус отлетает от машины, крутится и исчезает
	var dir := (global_position - body.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", global_position + dir * 220.0 + Vector2(0, -120), 0.6)
	tw.tween_property(self, "rotation", rotation + randf_range(6.0, 10.0), 0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(queue_free)


func _physics_process(_delta: float) -> void:
	_cleanup_if_behind()


func _cleanup_if_behind() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			queue_free()
