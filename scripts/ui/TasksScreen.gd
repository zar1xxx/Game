extends Control
## Экран «Задания» (открывается из главного меню). Раньше задания на заезд, заезд дня,
## испытание недели и награда за вход висели карточками по краям меню и перегружали его,
## а на узких экранах наезжали на кнопки и уезжали за край. Теперь всё здесь, во вкладках.

signal closed
signal daily_requested            # «Ехать» в заезде дня — меню запускает заезд
signal weekly_requested           # «Принять вызов» — меню запускает испытание недели
signal message(text: String)      # всплывающее сообщение в меню (награда получена и т.п.)

var _tab: String = "missions"     # "missions", "day", "week"
var _tabs: Dictionary = {}
var _body: VBoxContainer
var _login: VBoxContainer
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
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "ЗАДАНИЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Art.font_title)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Art.ORANGE)
	vb.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	var group := ButtonGroup.new()
	for item in [["missions", "На заезд"], ["day", "Заезд дня"], ["week", "Неделя"]]:
		var tb := Button.new()
		tb.text = item[1]
		tb.toggle_mode = true
		tb.button_group = group
		tb.custom_minimum_size = Vector2(0, 42)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 17)
		var id: String = item[0]
		tb.pressed.connect(func():
			_tab = id
			Sound.play("click", -8.0)
			_refresh())
		tabs.add_child(tb)
		_tabs[id] = tb

	# Содержимое вкладки — фиксированной высоты, чтобы окно не прыгало при переключении
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.custom_minimum_size = Vector2(0, 250)
	vb.add_child(_body)

	vb.add_child(HSeparator.new())
	_login = VBoxContainer.new()
	_login.add_theme_constant_override("separation", 6)
	vb.add_child(_login)

	_back = Button.new()
	_back.text = "Назад"
	_back.custom_minimum_size = Vector2(220, 48)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	vb.add_child(_back)
	hide()


func open() -> void:
	# Есть невыданная награда недели — сразу на вкладку «Неделя»
	if SaveManager.weekly_unclaimed_reward() > 0:
		_tab = "week"
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


## Есть что забрать (награда за вход или награда недели) — меню подсвечивает кнопку
static func has_reward() -> bool:
	return SaveManager.login_reward_available() or SaveManager.weekly_unclaimed_reward() > 0


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for id in _tabs.keys():
		var tb: Button = _tabs[id]
		tb.set_pressed_no_signal(id == _tab)
	var wk: Button = _tabs["week"]
	var star := SaveManager.weekly_unclaimed_reward() > 0
	wk.text = "Неделя ★" if star else "Неделя"
	if star:
		wk.add_theme_color_override("font_color", Art.YELLOW)
	else:
		wk.remove_theme_color_override("font_color")
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match _tab:
		"day":
			_fill_daily()
		"week":
			_fill_weekly()
		_:
			_fill_missions()
	_fill_login()


func _label(text: String, size_px: int, color: Color, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 540
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", Art.font_title)
	return l


func _big_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	return b


func _fill_missions() -> void:
	_body.add_child(_label("ЗАДАНИЯ НА ЗАЕЗД", 20, Art.ORANGE, true))
	for i in Missions.SLOTS:
		var m := Missions.get_slot(i)
		if m.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := _label("•  " + Missions.full_text(m), 16,
			Art.UI_TEXT if Missions.is_available_here(m) else Art.UI_MUTED)
		l.custom_minimum_size.x = 400
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var r := _label("+%d монет" % Missions.reward_of(m), 15, Art.YELLOW)
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		r.custom_minimum_size.x = 0
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(r)
		_body.add_child(row)
	_body.add_child(_label("Все три за один заезд: +%d монет" % Missions.HATTRICK_REWARD, 15, Art.TEAL))
	_body.add_child(_label("Выполнено: %d   •   Лучшее комбо: ×%d" % [
		SaveManager.missions_done, SaveManager.best_combo], 13, Art.UI_MUTED))


func _fill_daily() -> void:
	var loc := GameData.get_location(SaveManager.daily_location_id())
	var d := Time.get_date_dict_from_system()
	_body.add_child(_label("ЗАЕЗД ДНЯ", 20, Art.ORANGE, true))
	_body.add_child(_label("%02d.%02d  •  одна трасса для всех" % [d.day, d.month], 13, Art.UI_MUTED))
	_body.add_child(_label(loc.name, 22, Art.UI_TEXT, true))
	var bonus := ("%.2f" % SaveManager.DAILY_BONUS).replace(".", ",").trim_suffix("0")
	_body.add_child(_label("Очки ×%s  •  рекорд дня: %d" % [bonus, SaveManager.get_daily_best()], 15, Art.YELLOW))
	if not SaveManager.is_owned("location", loc.id):
		_body.add_child(_label("Трасса не куплена — сегодня можно попробовать бесплатно!", 14, Art.TEAL))
	_body.add_child(_big_button("Ехать", func(): daily_requested.emit()))


## Испытание недели: правило, трасса, рекорд недели и три цели
func _fill_weekly() -> void:
	var rule := SaveManager.weekly_rule()
	var loc := GameData.get_location(SaveManager.weekly_location_id())
	_body.add_child(_label("ИСПЫТАНИЕ НЕДЕЛИ  •  «%s»" % rule.name, 19, Art.ORANGE, true))
	_body.add_child(_label("%s  •  %s" % [SaveManager.week_dates_text(), loc.name], 13, Art.UI_MUTED))
	_body.add_child(_label(rule.desc, 14, Art.TEAL))
	var mult := ("%.2f" % rule.score).replace(".", ",").trim_suffix("0")
	_body.add_child(_label("Очки ×%s  •  рекорд недели: %d" % [mult, SaveManager.get_weekly_best()], 15, Art.YELLOW))
	var claimed := SaveManager.get_weekly_claimed()
	var reached := SaveManager.get_weekly_reached()
	var goals := "Цели за один заезд:   "
	for i in GameData.WEEKLY_GOALS.size():
		var mark := "✓" if i < claimed else ("★" if i < reached else "○")
		goals += "%s %d очков (+%d)     " % [mark, GameData.WEEKLY_GOALS[i], GameData.WEEKLY_REWARDS[i]]
	_body.add_child(_label(goals.strip_edges(), 14, Art.UI_TEXT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	var unclaimed := SaveManager.weekly_unclaimed_reward()
	if unclaimed > 0:
		var take := _big_button("Забрать +%d" % unclaimed, _on_weekly_claim)
		take.add_theme_color_override("font_color", Art.YELLOW)
		row.add_child(take)
	row.add_child(_big_button("Принять вызов", func(): weekly_requested.emit()))


func _fill_login() -> void:
	for c in _login.get_children():
		_login.remove_child(c)
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_login.add_child(row)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var head := _label("НАГРАДА ЗА ВХОД", 16, Art.ORANGE, true)
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.custom_minimum_size.x = 0
	texts.add_child(head)
	var claim := Button.new()
	claim.custom_minimum_size = Vector2(200, 44)
	claim.add_theme_font_size_override("font_size", 17)
	var info: Label
	if SaveManager.login_reward_available():
		var streak := (SaveManager.login_streak + 1) if SaveManager.login_day == SaveManager.today() - 1 else 1
		info = _label("День %d подряд" % streak, 14, Art.UI_TEXT)
		claim.text = "Забрать +%d" % SaveManager.login_reward_amount()
		claim.add_theme_color_override("font_color", Art.YELLOW)
		claim.pressed.connect(_on_claim_pressed)
	else:
		info = _label("День %d подряд. Завтра: +%d" % [SaveManager.login_streak,
			SaveManager.login_reward_amount(SaveManager.login_streak + 1)], 14, Art.UI_MUTED)
		claim.text = "Получено ✓"
		claim.disabled = true
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.custom_minimum_size.x = 0
	texts.add_child(info)
	row.add_child(claim)


func _on_claim_pressed() -> void:
	var amount := SaveManager.claim_login_reward()
	if amount <= 0:
		return
	Sound.play("buy", 0.0, 1.0, 0.0)
	Sound.play("coin", -2.0, 1.2, 0.0)
	_refresh()
	message.emit("Награда за вход: +%d монет!" % amount)


func _on_weekly_claim() -> void:
	var amount := SaveManager.claim_weekly()
	if amount <= 0:
		return
	Sound.play("buy", 0.0, 1.0, 0.0)
	Sound.play("record", -4.0, 1.1, 0.0)
	_refresh()
	message.emit("Награда недели: +%d монет!" % amount)
