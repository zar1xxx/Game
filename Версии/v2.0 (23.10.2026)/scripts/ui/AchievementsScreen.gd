extends Control
## Экран достижений (открывается из главного меню).
## Открытые — яркие, с наградой; закрытые — приглушённые, но условие видно сразу.

signal closed

var _list: VBoxContainer
var _count: Label
var _back: Button
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(760, 600)
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = "ДОСТИЖЕНИЯ"
	title.add_theme_font_override("font", Art.font_title)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Art.ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = Label.new()
	_count.add_theme_font_override("font", Art.font_title)
	_count.add_theme_font_size_override("font_size", 20)
	_count.add_theme_color_override("font_color", Art.YELLOW)
	head.add_child(_count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_back = Button.new()
	_back.text = "Назад"
	_back.custom_minimum_size = Vector2(220, 48)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	vb.add_child(_back)
	hide()


func open() -> void:
	Achievements.check_static()
	_fill()
	show()
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.92, 0.92)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_back.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var total := Achievements.LIST.size()
	_count.text = "%d / %d" % [Achievements.unlocked_count(), total]
	# Сначала открытые, потом остальные — в исходном порядке
	var ordered: Array = []
	for d in Achievements.LIST:
		if Achievements.is_unlocked(d.id):
			ordered.append(d)
	for d in Achievements.LIST:
		if not Achievements.is_unlocked(d.id):
			ordered.append(d)
	for d in ordered:
		var row := Control.new()
		row.custom_minimum_size = Vector2(0, 62)
		var def: Dictionary = d
		var got: bool = Achievements.is_unlocked(def.id)
		row.draw.connect(func():
			var r := Rect2(Vector2.ZERO, row.size)
			Art.rrect(row, r, Color(Art.UI_PANEL_LIGHT, 1.0 if got else 0.55), 10, 2,
				Color(Art.YELLOW, 0.9) if got else Color(Art.UI_MUTED, 0.25))
			var c := Vector2(34, r.size.y / 2.0)
			row.draw_circle(c, 23, Art.YELLOW if got else Color("3a3f52"))
			row.draw_circle(c, 19, Art.ORANGE if got else Color("2c3040"))
			var icon: String = def.icon
			Art.text_center(row, c, icon, 15 if icon.length() <= 2 else 11, Art.INK if got else Art.UI_MUTED, true)
			var f := Art.font_title
			row.draw_string(f, Vector2(70, 26), def.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				Art.UI_TEXT if got else Art.UI_MUTED)
			row.draw_string(Art.font_bold, Vector2(70, 47), def.desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 220, 13,
				Color(Art.UI_TEXT, 0.85) if got else Color(Art.UI_MUTED, 0.85))
			var rw := "✓ получено" if got else "+%d монет" % def.reward
			var tw := f.get_string_size(rw, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			row.draw_string(f, Vector2(r.size.x - tw - 16, r.size.y / 2.0 + 6), rw, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Art.GREEN if got else Art.YELLOW))
		_list.add_child(row)
