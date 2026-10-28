extends Control
## Таблица 10 лучших результатов (открывается из главного меню).
## Переключатель ◀ ▶ — все трассы или конкретная трасса. Последний заезд подсвечен.

signal closed

var _filter_index: int = 0        # 0 — все трассы, дальше — трассы из GameData.LOCATIONS
var _filter_label: Label
var _grid: GridContainer
var _empty: Label
var _back: Button
var _panel: PanelContainer


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
	_panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "ТАБЛИЦА РЕКОРДОВ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Art.font_title)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Art.ORANGE)
	vb.add_child(title)

	var sel := HBoxContainer.new()
	sel.alignment = BoxContainer.ALIGNMENT_CENTER
	sel.add_theme_constant_override("separation", 12)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(56, 44)
	prev.pressed.connect(func(): _step(-1))
	sel.add_child(prev)
	_filter_label = Label.new()
	_filter_label.custom_minimum_size = Vector2(260, 0)
	_filter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_filter_label.add_theme_font_size_override("font_size", 20)
	sel.add_child(_filter_label)
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(56, 44)
	next.pressed.connect(func(): _step(1))
	sel.add_child(next)
	vb.add_child(sel)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(_grid)
	_empty = Label.new()
	_empty.text = "Здесь пока пусто — сыграйте заезд!"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_color_override("font_color", Art.UI_MUTED)
	vb.add_child(_empty)

	_back = Button.new()
	_back.text = "Назад"
	_back.custom_minimum_size = Vector2(220, 48)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	vb.add_child(_back)
	hide()


func open() -> void:
	# Открываем на трассе, выбранной сейчас
	_filter_index = 0
	for i in GameData.LOCATIONS.size():
		if GameData.LOCATIONS[i].id == SaveManager.selected_location and not SaveManager.get_leaderboard(GameData.LOCATIONS[i].id).is_empty():
			_filter_index = i + 1
	_refresh()
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


func _step(dir: int) -> void:
	var n := GameData.LOCATIONS.size() + 1
	_filter_index = (_filter_index + dir + n) % n
	Sound.play("whoosh", -12.0, 1.2)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var loc_id := ""
	if _filter_index == 0:
		_filter_label.text = "Все трассы"
	else:
		var loc: Dictionary = GameData.LOCATIONS[_filter_index - 1]
		loc_id = loc.id
		_filter_label.text = loc.name
	for c in _grid.get_children():
		c.queue_free()
	_grid.columns = 5 if loc_id == "" else 4
	var table := SaveManager.get_leaderboard(loc_id)
	_empty.visible = table.is_empty()
	_grid.visible = not table.is_empty()
	if table.is_empty():
		return
	var headers := ["#", "Имя", "Очки"]
	if loc_id == "":
		headers.append("Трасса")
	headers.append("Машина")
	for h in headers:
		_cell(h, Art.UI_MUTED, 13)
	var medals := [Color("ffd166"), Color("d7dce6"), Color("e0a36b")]
	for i in table.size():
		var e: Dictionary = table[i]
		var mine: bool = e.id == SaveManager.last_entry_id
		var col: Color = Art.ORANGE if mine else (medals[i] if i < 3 else Art.UI_TEXT)
		_cell(str(i + 1), col, 18, true)
		_cell(e.name, col, 17)
		_cell(str(e.score), col, 18, true)
		if loc_id == "":
			_cell(GameData.get_location(e.location).name, Art.UI_MUTED, 14)
		_cell(GameData.get_car(e.car).name, Art.UI_MUTED, 14)


func _cell(text: String, color: Color, font_size: int, title: bool = false) -> void:
	var l := Label.new()
	l.text = text
	if text.length() > 14:
		# Длинные названия обрезаются многоточием
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = 150
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", Art.font_title)
	_grid.add_child(l)
