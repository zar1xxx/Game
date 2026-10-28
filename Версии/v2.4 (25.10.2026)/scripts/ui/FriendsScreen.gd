extends Control
## «С друзьями»: два режима без интернета.
##   «Кто дальше» — 2–4 игрока по очереди на одном телефоне, три круга, в зачёт лучший заезд.
##   «Вызов по коду» — друг прислал код вроде «ОМСК-7F3KQ-2ZDM8»: та же трасса, машина,
##   сложность и тот же трафик. Обгони его результат.

signal closed
signal start_requested        # меню запускает заезд (режим уже выставлен в SaveManager)

const ChallengeCode := preload("res://scripts/ChallengeCode.gd")

var _panel: PanelContainer
var _count: int = 2
var _count_btns: Array = []
var _names: Array = []
var _names_box: VBoxContainer
var _party_info: Label
var _code_edit: LineEdit
var _code_info: Label
var _go_challenge: Button
var _decoded: Dictionary = {}
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "С ДРУЗЬЯМИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Art.font_title)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Art.ORANGE)
	vb.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	vb.add_child(cols)

	# --- «Кто дальше» ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	left.add_child(_caption("КТО ДАЛЬШЕ? (НА ОДНОМ ТЕЛЕФОНЕ)"))
	left.add_child(_text("По очереди, три круга. В каждом круге у всех одинаковый трафик, в зачёт — лучший заезд.", 13, Art.UI_MUTED))
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	var cnt_l := _text("Игроков:", 15, Art.UI_TEXT)
	cnt_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	cnt_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_row.add_child(cnt_l)
	for n in [2, 3, 4]:
		var b := Button.new()
		b.text = str(n)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(56, 40)
		var nn: int = n
		b.pressed.connect(func(): _set_count(nn))
		count_row.add_child(b)
		_count_btns.append(b)
	left.add_child(count_row)
	_names_box = VBoxContainer.new()
	_names_box.add_theme_constant_override("separation", 4)
	left.add_child(_names_box)
	for i in 4:
		var e := LineEdit.new()
		e.text = "Игрок %d" % (i + 1)
		e.max_length = 14
		e.custom_minimum_size = Vector2(260, 36)
		e.select_all_on_focus = true
		_names_box.add_child(e)
		_names.append(e)
	_party_info = _text("", 13, Art.UI_MUTED)
	left.add_child(_party_info)
	var go_party := Button.new()
	go_party.text = "Начать партию"
	go_party.custom_minimum_size = Vector2(0, 50)
	go_party.add_theme_font_size_override("font_size", 19)
	go_party.pressed.connect(_start_party)
	left.add_child(go_party)

	# --- Вызов по коду ---
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 380
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	right.add_child(_caption("ВЫЗОВ ПО КОДУ"))
	right.add_child(_text("После каждого заезда игра показывает код. Перешли его другу — он поедет ту же трассу на той же машине с тем же трафиком. Интернет не нужен.", 13, Art.UI_MUTED))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "ОМСК-XXXXX-XXXXX"
	_code_edit.custom_minimum_size = Vector2(0, 44)
	_code_edit.add_theme_font_size_override("font_size", 19)
	_code_edit.text_changed.connect(func(_t): _check_code())
	_code_edit.text_submitted.connect(func(_t): _start_challenge())
	right.add_child(_code_edit)
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	var paste := Button.new()
	paste.text = "Вставить"
	paste.custom_minimum_size = Vector2(130, 42)
	paste.pressed.connect(func():
		_code_edit.text = DisplayServer.clipboard_get().strip_edges().left(40)
		_check_code())
	code_row.add_child(paste)
	_go_challenge = Button.new()
	_go_challenge.text = "Принять вызов"
	_go_challenge.custom_minimum_size = Vector2(0, 42)
	_go_challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go_challenge.pressed.connect(_start_challenge)
	code_row.add_child(_go_challenge)
	right.add_child(code_row)
	_code_info = _text("", 14, Art.UI_TEXT)
	_code_info.custom_minimum_size.y = 84
	right.add_child(_code_info)

	_back = Button.new()
	_back.text = "Назад"
	_back.custom_minimum_size = Vector2(220, 46)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	vb.add_child(_back)
	_set_count(2)
	_check_code()
	hide()


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Art.font_title)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Art.TEAL)
	return l


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func open() -> void:
	show()
	var loc := GameData.get_location(SaveManager.selected_location)
	var car := GameData.get_car(SaveManager.selected_car)
	_party_info.text = "Трасса: %s  •  машина: %s  •  сложность: %s" % [loc.name, car.name, SaveManager.difficulty().name]
	_check_code()
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


func _set_count(n: int) -> void:
	_count = n
	for i in _count_btns.size():
		_count_btns[i].set_pressed_no_signal(i + 2 == n)
	for i in _names.size():
		_names[i].visible = i < n


func _start_party() -> void:
	var names: Array = []
	for i in _count:
		var nm: String = _names[i].text.strip_edges()
		if nm == "":
			nm = "Игрок %d" % (i + 1)
		names.append(nm)
	SaveManager.start_party(names)
	hide()
	start_requested.emit()


func _check_code() -> void:
	var t := _code_edit.text.strip_edges()
	_decoded = ChallengeCode.decode(t) if t != "" else {}
	_go_challenge.disabled = _decoded.is_empty()
	if t == "":
		_code_info.text = "Введите или вставьте код от друга."
		_code_info.add_theme_color_override("font_color", Art.UI_MUTED)
	elif _decoded.is_empty():
		_code_info.text = "Код не распознан — проверьте буквы и цифры."
		_code_info.add_theme_color_override("font_color", Art.RED)
	else:
		var loc := GameData.get_location(_decoded.loc)
		var car := GameData.get_car(_decoded.car)
		_code_info.text = "Трасса: %s\nМашина: %s\nСложность: %s\nРезультат друга: %d очков" % [loc.name, car.name,
			GameData.get_difficulty(_decoded.diff).name, _decoded.score]
		_code_info.add_theme_color_override("font_color", Art.GREEN)


func _start_challenge() -> void:
	if _decoded.is_empty():
		return
	SaveManager.start_challenge(_decoded)
	hide()
	start_requested.emit()
