extends Control
## Карта Омска: схема города с Иртышом и Омью, на ней — достопримечательности.
## Найденные на трассе «Омск» точки открываются, остальные помечены «?».
## Нажмите на точку, чтобы прочитать о ней.

signal closed

const MAP_SIZE := Vector2(520, 470)

var _map: Control
var _title: Label
var _name: Label
var _desc: Label
var _count: Label
var _back: Button
var _panel: PanelContainer
var _selected: String = ""
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	_panel.add_child(hb)

	_map = Control.new()
	_map.custom_minimum_size = MAP_SIZE
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	hb.add_child(_map)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(290, 0)
	side.add_theme_constant_override("separation", 10)
	hb.add_child(side)
	_title = Label.new()
	_title.text = "КАРТА ОМСКА"
	_title.add_theme_font_override("font", Art.font_title)
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Art.ORANGE)
	side.add_child(_title)
	_count = Label.new()
	_count.add_theme_color_override("font_color", Art.UI_MUTED)
	_count.add_theme_font_size_override("font_size", 14)
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_count)
	_name = Label.new()
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", Art.YELLOW)
	side.add_child(_name)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc.add_theme_font_size_override("font_size", 15)
	side.add_child(_desc)
	_back = Button.new()
	_back.text = "Назад"
	_back.custom_minimum_size = Vector2(0, 48)
	_back.pressed.connect(close)
	side.add_child(_back)
	hide()


func open() -> void:
	_selected = ""
	_refresh_info()
	show()
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_back.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_map.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _pin_pos(lm: Dictionary) -> Vector2:
	return lm.pos * MAP_SIZE


func _on_map_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var best := ""
	var best_d := 34.0
	for lm in GameData.LANDMARKS:
		var d: float = _pin_pos(lm).distance_to(event.position)
		if d < best_d:
			best_d = d
			best = lm.id
	if best != "":
		_selected = best
		Sound.play("click", -4.0)
		_refresh_info()


func _refresh_info() -> void:
	var found := SaveManager.omsk_seen.size()
	var total := GameData.LANDMARKS.size()
	_count.text = "Найдено %d из %d. За каждую новую точку +%d монет, за всю карту +%d.\nСхема не в масштабе." % [
		found, total, GameData.LANDMARK_REWARD, GameData.LANDMARKS_ALL_REWARD]
	if _selected == "":
		_name.text = "Нажмите на точку"
		_desc.text = "Достопримечательности открываются, когда вы проезжаете мимо них на трассе «Омск»." \
			if found < total else "Вы нашли весь Омск! Теперь вы почётный омич."
		return
	var lm := GameData.get_landmark(_selected)
	if _selected in SaveManager.omsk_seen:
		_name.text = lm.name
		_desc.text = lm.desc
	else:
		_name.text = "???"
		_desc.text = "Эта точка ещё не найдена. Проедьте трассу «Омск» и смотрите по сторонам."


func _draw_map() -> void:
	var sz := MAP_SIZE
	var ci := _map
	Art.rrect(ci, Rect2(Vector2.ZERO, sz), Color("3f4a3a"), 14)
	# Кварталы — сетка улиц
	for i in 14:
		var x := i * sz.x / 13.0
		ci.draw_line(Vector2(x, 0), Vector2(x + 30, sz.y), Color(1, 1, 1, 0.05), 2.0)
	for j in 12:
		var y := j * sz.y / 11.0
		ci.draw_line(Vector2(0, y), Vector2(sz.x, y - 20), Color(1, 1, 1, 0.05), 2.0)
	# Иртыш течёт с юга на север, Омь впадает в него справа
	var irtysh := PackedVector2Array()
	for k in 21:
		var v := k / 20.0
		irtysh.append(Vector2(sz.x * (0.42 - 0.08 * sin(v * PI * 1.3) + 0.03 * sin(v * 9.0)), sz.y * (1.0 - v)))
	ci.draw_polyline(irtysh, Color("2f5d86"), 34.0, true)
	ci.draw_polyline(irtysh, Color("3c74a6"), 22.0, true)
	var om := PackedVector2Array()
	for k in 13:
		var v := k / 12.0
		om.append(Vector2(sz.x * lerpf(0.43, 1.02, v), sz.y * (0.47 + 0.05 * sin(v * 6.0) + 0.04 * v)))
	ci.draw_polyline(om, Color("2f5d86"), 14.0, true)
	ci.draw_polyline(om, Color("3c74a6"), 8.0, true)
	Art.text_center(ci, Vector2(sz.x * 0.27, sz.y * 0.88), "Иртыш", 13, Color("9cc3e8"))
	Art.text_center(ci, Vector2(sz.x * 0.86, sz.y * 0.47), "Омь", 12, Color("9cc3e8"))
	# Улица Ленина
	ci.draw_line(Vector2(sz.x * 0.50, sz.y * 0.36), Vector2(sz.x * 0.64, sz.y * 0.86), Color(1, 0.9, 0.6, 0.35), 4.0)
	Art.text_center(ci, Vector2(sz.x * 0.75, sz.y * 0.9), "ул. Ленина", 11, Color(1, 0.9, 0.6, 0.6))
	# Точки
	for lm in GameData.LANDMARKS:
		var p := _pin_pos(lm)
		var found: bool = lm.id in SaveManager.omsk_seen
		var sel: bool = lm.id == _selected
		var r := 13.0 if not sel else 16.0 + sin(_t * 6.0) * 1.5
		if found:
			Art.glow(ci, p, r * 2.6, Color(Art.YELLOW, 0.35 if sel else 0.2))
		ci.draw_circle(p + Vector2(2, 3), r, Color(0, 0, 0, 0.4))
		ci.draw_circle(p, r, Art.ORANGE if found else Color("5e6272"))
		ci.draw_arc(p, r, 0, TAU, 24, Color.WHITE if sel else Art.INK, 2.5, true)
		if found:
			var star := PackedVector2Array()
			for k in 10:
				var rad := 7.0 if k % 2 == 0 else 3.0
				star.append(p + Vector2.from_angle(-PI / 2 + k * PI / 5) * rad)
			ci.draw_colored_polygon(star, Art.INK)
		else:
			Art.text_center(ci, p, "?", 13, Art.UI_TEXT, true)
		if found:
			var label: String = lm.name
			if label.length() > 18:
				label = label.left(17) + "…"
			Art.text_center(ci, p + Vector2(0, r + 12), label, 11, Art.UI_TEXT)
