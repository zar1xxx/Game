class_name Pickup
extends RefCounted
## Общие функции бонусов: подсветка, эффект подбора, удаление за экраном.


static func draw_halo(ci: CanvasItem, color: Color, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	Art.glow(ci, Vector2.ZERO, 38 + pulse * 6, Color(color, 0.35), 6)
	ci.draw_arc(Vector2.ZERO, 30 + pulse * 3, 0, TAU, 32, Color(color, 0.7), 2.5)


## Всплывающая надпись при подборе
static func burst(node: Node2D, color: Color, text: String, sound: String = "pickup") -> void:
	MobileInput.vibrate(20)
	if sound != "":
		Sound.play(sound, -2.0)
	_ring(node, color)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Art.font_title)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Art.INK)
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 20
	label.position = node.global_position + Vector2(-50, -50)
	var parent := node.get_parent()
	parent.add_child(label)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 90, 0.9)
	tw.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)


## Разлетающееся кольцо и искорки цвета бонуса
static func _ring(node: Node2D, color: Color) -> void:
	var ring := Sprite2D.new()
	ring.texture = Art.glow_texture()
	ring.modulate = Color(color, 0.9)
	ring.scale = Vector2.ONE * 0.4
	ring.z_index = 19
	node.get_parent().add_child(ring)
	ring.global_position = node.global_position
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2.ZERO
	p.damping_min = 200.0
	p.damping_max = 300.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = color
	p.z_index = 19
	node.get_parent().add_child(p)
	p.global_position = node.global_position
	p.emitting = true
	node.get_tree().create_timer(1.0).timeout.connect(p.queue_free)


static func cleanup_if_behind(node: Node2D) -> void:
	var camera := node.get_viewport().get_camera_2d()
	if camera and node.global_position.y > camera.global_position.y + Art.VIEW_H / 2.0 + 200.0:
		node.queue_free()
