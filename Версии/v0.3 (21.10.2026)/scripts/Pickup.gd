class_name Pickup
extends RefCounted
## Общие функции бонусов: подсветка, эффект подбора, удаление за экраном.


static func draw_halo(ci: CanvasItem, color: Color, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	Art.glow(ci, Vector2.ZERO, 38 + pulse * 6, Color(color, 0.35), 6)
	ci.draw_arc(Vector2.ZERO, 30 + pulse * 3, 0, TAU, 32, Color(color, 0.7), 2.5)


## Всплывающая надпись при подборе
static func burst(node: Node2D, color: Color, text: String) -> void:
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


static func cleanup_if_behind(node: Node2D) -> void:
	var camera := node.get_viewport().get_camera_2d()
	if camera and node.global_position.y > camera.global_position.y + Art.VIEW_H / 2.0 + 200.0:
		node.queue_free()
