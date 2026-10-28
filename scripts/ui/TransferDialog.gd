extends Control
## Перенос прогресса: сохранение превращается в текст, который можно переслать себе
## (например, в «Избранное» в Telegram) и вставить на новом телефоне.

signal closed

var _panel: PanelContainer
var _my_code: TextEdit
var _copy: Button
var _in_code: TextEdit
var _info: Label
var _load: Button
var _confirm: bool = false
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "ПЕРЕНОС ПРОГРЕССА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Art.font_title)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Art.ORANGE)
	vb.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 380
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(_caption("1. НА СТАРОМ ТЕЛЕФОНЕ"))
	left.add_child(_text("Скопируйте код и перешлите его себе — например, в «Избранное» в Telegram."))
	_my_code = TextEdit.new()
	_my_code.editable = false
	_my_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_my_code.custom_minimum_size = Vector2(0, 150)
	_my_code.add_theme_font_size_override("font_size", 11)
	left.add_child(_my_code)
	_copy = Button.new()
	_copy.text = "Скопировать код"
	_copy.custom_minimum_size = Vector2(0, 46)
	_copy.pressed.connect(func():
		DisplayServer.clipboard_set(_my_code.text)
		_copy.text = "Скопировано ✓"
		MobileInput.vibrate(20))
	left.add_child(_copy)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 380
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	right.add_child(_caption("2. НА НОВОМ ТЕЛЕФОНЕ"))
	right.add_child(_text("Вставьте код целиком. Прогресс на этом телефоне заменится."))
	_in_code = TextEdit.new()
	_in_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_in_code.custom_minimum_size = Vector2(0, 104)
	_in_code.placeholder_text = "BENZIN1-…"
	_in_code.add_theme_font_size_override("font_size", 11)
	_in_code.text_changed.connect(_check)
	right.add_child(_in_code)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var paste := Button.new()
	paste.text = "Вставить"
	paste.custom_minimum_size = Vector2(130, 46)
	paste.pressed.connect(func():
		_in_code.text = DisplayServer.clipboard_get()
		_check())
	row.add_child(paste)
	_load = Button.new()
	_load.text = "Загрузить"
	_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load.custom_minimum_size = Vector2(0, 46)
	_load.pressed.connect(_on_load)
	row.add_child(_load)
	right.add_child(row)
	_info = _text("")
	_info.custom_minimum_size.y = 40
	right.add_child(_info)

	_back = Button.new()
	_back.text = "Готово"
	_back.custom_minimum_size = Vector2(220, 46)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	vb.add_child(_back)
	hide()


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Art.font_title)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Art.TEAL)
	return l


func _text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Art.UI_MUTED)
	return l


func open() -> void:
	_my_code.text = SaveManager.export_code()
	_copy.text = "Скопировать код (%d символов)" % _my_code.text.length()
	_in_code.text = ""
	_confirm = false
	_check()
	show()
	_back.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _check() -> void:
	_confirm = false
	_load.text = "Загрузить"
	var t := _in_code.text.strip_edges()
	if t == "":
		_info.text = ""
		_load.disabled = true
		return
	var info := SaveManager.peek_code(t)
	_load.disabled = info.is_empty()
	if info.is_empty():
		_info.text = "Код не подходит: скопируйте его полностью, без лишних символов."
		_info.add_theme_color_override("font_color", Art.RED)
	else:
		_info.text = "В коде: уровень %d, %d монет, машин %d, трасс %d, заездов %d." % [info.level, info.coins,
			info.cars, info.tracks, info.games]
		_info.add_theme_color_override("font_color", Art.GREEN)


func _on_load() -> void:
	if not _confirm:
		_confirm = true
		_load.text = "Точно заменить? Нажмите ещё раз"
		return
	if SaveManager.import_code(_in_code.text):
		_info.text = "Готово! Прогресс перенесён."
		_info.add_theme_color_override("font_color", Art.GREEN)
		_load.disabled = true
		_load.text = "Загружено ✓"
		_my_code.text = SaveManager.export_code()
		Sound.play("record", -4.0, 1.0, 0.0)
	else:
		_info.text = "Не получилось загрузить код."
		_info.add_theme_color_override("font_color", Art.RED)
