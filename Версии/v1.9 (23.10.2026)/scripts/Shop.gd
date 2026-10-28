extends Control
## Магазин: покупка и выбор машин и трасс.
## Открывается поверх главного меню. Интерфейс собирается кодом, оформление — из общей темы.
## Листать: кнопки ◀ ▶, стрелки клавиатуры или свайп по карточке.

signal closed

const CARD_SIZE := Vector2(820, 440)

var tab: String = "car"            # "car" или "location"
var index: int = 0

var _title: Label
var _coins: Label
var _tab_cars: Button
var _tab_locs: Button
var _preview: Control
var _name: Label
var _status: Label
var _desc: Label
var _stats_box: VBoxContainer
var _action: Button
var _counter: Label
var _flash: Label
var _t: float = 0.0
var _swipe_from: float = NAN


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	SaveManager.coins_changed.connect(func(_c): _refresh())


func open(start_tab: String = "car") -> void:
	tab = start_tab
	show()
	_jump_to_selected()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_action.grab_focus()


func close() -> void:
	Sound.music("menu", 0.8)
	hide()
	closed.emit()


func _items() -> Array:
	return GameData.CARS if tab == "car" else GameData.LOCATIONS


func _jump_to_selected() -> void:
	var sel := SaveManager.selected_car if tab == "car" else SaveManager.selected_location
	index = 0
	var items := _items()
	for i in items.size():
		if items[i].id == sel:
			index = i
	_refresh()


# ---------------------------------------------------------------------------
# Построение интерфейса
# ---------------------------------------------------------------------------
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Art.INK, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 14
	root.offset_bottom = -14
	add_child(root)

	# Верхняя строка: заголовок, вкладки, монеты
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	_title = Label.new()
	_title.text = "МАГАЗИН"
	_title.add_theme_font_override("font", Art.font_title)
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Art.ORANGE)
	top.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var group := ButtonGroup.new()
	_tab_cars = _make_button("Машины", Vector2(170, 48), 20)
	_tab_cars.toggle_mode = true
	_tab_cars.button_group = group
	_tab_cars.pressed.connect(func(): _switch_tab("car"))
	top.add_child(_tab_cars)
	_tab_locs = _make_button("Трассы", Vector2(170, 48), 20)
	_tab_locs.toggle_mode = true
	_tab_locs.button_group = group
	_tab_locs.pressed.connect(func(): _switch_tab("location"))
	top.add_child(_tab_locs)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer2)
	_coins = Label.new()
	_coins.add_theme_font_override("font", Art.font_title)
	_coins.add_theme_font_size_override("font_size", 26)
	_coins.add_theme_color_override("font_color", Art.YELLOW)
	top.add_child(_coins)

	# Центр: ◀ карточка ▶
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 14)
	root.add_child(mid)
	var prev := _make_button("◀", Vector2(64, 120), 30)
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev.pressed.connect(func(): _step(-1))
	mid.add_child(prev)

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	card.add_child(row)

	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(250, 380)
	_preview.clip_contents = true
	_preview.draw.connect(_draw_preview)
	_preview.gui_input.connect(_on_preview_input)
	row.add_child(_preview)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)
	_name = Label.new()
	_name.add_theme_font_override("font", Art.font_title)
	_name.add_theme_font_size_override("font_size", 30)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_name)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 17)
	info.add_child(_status)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 16)
	_desc.add_theme_color_override("font_color", Art.UI_MUTED)
	_desc.custom_minimum_size = Vector2(440, 0)
	info.add_child(_desc)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 4)
	_stats_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(_stats_box)
	_action = _make_button("Выбрать", Vector2(0, 56), 22)
	_action.pressed.connect(_on_action)
	info.add_child(_action)

	var next := _make_button("▶", Vector2(64, 120), 30)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(func(): _step(1))
	mid.add_child(next)

	# Нижняя строка: счётчик и «Назад»
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	_counter = Label.new()
	_counter.add_theme_color_override("font_color", Art.UI_MUTED)
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_counter)
	var back := _make_button("Назад", Vector2(200, 50), 20)
	back.pressed.connect(close)
	bottom.add_child(back)

	# Всплывающая надпись «Куплено!»
	_flash = Label.new()
	_flash.add_theme_font_override("font", Art.font_title)
	_flash.add_theme_font_size_override("font_size", 44)
	_flash.add_theme_color_override("font_color", Art.YELLOW)
	_flash.add_theme_color_override("font_outline_color", Art.INK)
	_flash.add_theme_constant_override("outline_size", 12)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.set_anchors_preset(Control.PRESET_CENTER)
	_flash.offset_left = -300
	_flash.offset_right = 300
	_flash.offset_top = -40
	_flash.offset_bottom = 40
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _make_button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	return b


# ---------------------------------------------------------------------------
# Логика
# ---------------------------------------------------------------------------
func _switch_tab(t: String) -> void:
	tab = t
	_jump_to_selected()


func _step(dir: int) -> void:
	var n := _items().size()
	index = (index + dir + n) % n
	Sound.play("whoosh", -10.0, 1.2)
	_refresh()
	# Карточка «въезжает» с той стороны, куда листаем
	if _preview:
		_preview.pivot_offset = _preview.size / 2.0
		_preview.scale = Vector2(0.86, 0.86)
		_preview.modulate.a = 0.3
		var tw := _preview.create_tween().set_parallel(true)
		tw.tween_property(_preview, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_preview, "modulate:a", 1.0, 0.18)


func _current() -> Dictionary:
	return _items()[index]


func _refresh() -> void:
	if _name == null:
		return
	var it := _current()
	# На вкладке трасс играет музыка выбранной трассы — можно «послушать» перед покупкой
	if visible:
		Sound.music(it.get("music", it.theme) if tab == "location" else "menu", 0.6)
	_tab_cars.set_pressed_no_signal(tab == "car")
	_tab_locs.set_pressed_no_signal(tab == "location")
	_coins.text = "%d монет" % SaveManager.coins
	_name.text = it.name
	_desc.text = it.desc
	_counter.text = "%d / %d   •   ◀ ▶ — листать" % [index + 1, _items().size()]
	var owned := SaveManager.is_owned(tab, it.id)
	var selected: bool = it.id == (SaveManager.selected_car if tab == "car" else SaveManager.selected_location)
	for c in _stats_box.get_children():
		c.queue_free()
	if tab == "car":
		for st in GameData.car_stats(it):
			_add_stat(st[0], st[1])
		if it.perk != "":
			_add_line("★ " + it.perk, Art.TEAL)
	else:
		var score_txt := str(snappedf(it.score, 0.1)).replace(".", ",")
		_add_line("Очки и монеты ×%s" % score_txt, Art.YELLOW)
		for m in it.mods:
			_add_line("• " + m, Art.UI_TEXT)
		var best := SaveManager.get_location_best(it.id)
		if best > 0:
			_add_line("Ваш рекорд здесь: %d" % best, Art.UI_MUTED)
	if selected:
		_status.text = "Выбрано"
		_status.add_theme_color_override("font_color", Art.GREEN)
		_action.text = "Выбрано ✓"
		_action.disabled = true
	elif owned:
		_status.text = "Куплено"
		_status.add_theme_color_override("font_color", Art.TEAL)
		_action.text = "Выбрать"
		_action.disabled = false
	else:
		_status.text = "Цена: %d монет" % it.price
		_status.add_theme_color_override("font_color", Art.YELLOW)
		if SaveManager.coins >= it.price:
			_action.text = "Купить за %d" % it.price
			_action.disabled = false
		else:
			_action.text = "Не хватает %d монет" % (it.price - SaveManager.coins)
			_action.disabled = true


func _add_stat(caption: String, value: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = caption
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 15)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 0.0
	# Полоски характеристик «наполняются» при показе
	bar.create_tween().tween_property(bar, "value", value, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	_stats_box.add_child(row)


func _add_line(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	_stats_box.add_child(l)


func _on_action() -> void:
	var it := _current()
	if SaveManager.is_owned(tab, it.id):
		SaveManager.select(tab, it.id)
		Sound.play("coin", -6.0, 1.3)
		_show_flash("Выбрано!")
	elif SaveManager.buy(tab, it.id):
		MobileInput.vibrate(60)
		Sound.play("buy", -2.0, 1.0, 0.0)
		_show_flash("Куплено!")
	_refresh()


func _show_flash(text: String) -> void:
	_flash.text = text
	_flash.scale = Vector2(1.4, 1.4)
	_flash.pivot_offset = _flash.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_flash, "modulate:a", 1.0, 0.12)
	tw.tween_property(_flash, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.6)
	tw.chain().tween_property(_flash, "modulate:a", 0.0, 0.4)


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


## Свайп по превью — листать
func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_swipe_from = event.position.x
		elif not is_nan(_swipe_from):
			var dx: float = event.position.x - _swipe_from
			if absf(dx) > 50.0:
				_step(-1 if dx > 0 else 1)
			_swipe_from = NAN


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_preview.queue_redraw()


# ---------------------------------------------------------------------------
# Превью
# ---------------------------------------------------------------------------
func _draw_preview() -> void:
	var sz := _preview.size
	var it := _current()
	var owned := SaveManager.is_owned(tab, it.id)
	if tab == "car":
		_draw_car_preview(sz, it)
	else:
		_draw_location_preview(sz, it)
	if not owned:
		# Замок в углу
		var c := Vector2(sz.x - 30, 30)
		Art.rrect(_preview, Rect2(c - Vector2(14, 6), Vector2(28, 22)), Art.YELLOW, 4)
		_preview.draw_arc(c - Vector2(0, 6), 9, PI, TAU, 12, Art.YELLOW, 4.0)


func _draw_car_preview(sz: Vector2, car: Dictionary) -> void:
	# Кусочек дороги
	var old := Art.theme
	Art.theme = "city"
	_preview.draw_rect(Rect2(Vector2.ZERO, sz), Art.pal("asphalt"))
	var off := fmod(_t * 160.0, 80.0)
	var y := -80.0 + off
	while y < sz.y:
		_preview.draw_rect(Rect2(14, y, 5, 40), Art.pal("line_white"))
		_preview.draw_rect(Rect2(sz.x - 19, y, 5, 40), Art.pal("line_white"))
		y += 80.0
	Art.theme = old
	var sc := minf(2.2, (sz.y - 40.0) / car.length)
	var c := sz / 2.0 + Vector2(sin(_t * 1.3) * 6.0, 10.0)
	# Art рисует с абсолютной матрицей base, поэтому масштаб передаём прямо в неё
	var drawn: Dictionary = SaveManager.custom_car(car.id) if SaveManager.is_owned("car", car.id) else car
	Art.draw_player_car(_preview, drawn, {"lights": true, "time": _t, "steer": sin(_t * 1.3),
		"base": Transform2D(sin(_t * 1.3) * 0.06, Vector2(sc, sc), 0.0, c)})


## Миниатюра трассы, нарисованная в её стиле
func _draw_location_preview(sz: Vector2, loc: Dictionary) -> void:
	var old := Art.theme
	var old_night := Art.night
	Art.theme = loc.theme
	Art.night = 1.0 if loc.time == "night" else 0.3
	var road := Rect2(sz.x * 0.25, 0, sz.x * 0.5, sz.y)
	_preview.draw_rect(Rect2(Vector2.ZERO, sz), Art.pal("lot"))
	_preview.draw_rect(Rect2(road.position.x - 14, 0, road.size.x + 28, sz.y), Art.pal("sidewalk"))
	_preview.draw_rect(road, Art.pal("asphalt"))
	var off := fmod(_t * 140.0, 70.0)
	var y := -70.0 + off
	while y < sz.y:
		_preview.draw_rect(Rect2(sz.x / 2.0 - 3, y, 6, 35), Art.pal("line_yellow"))
		y += 70.0
	# Обочины в стиле трассы
	for i in 4:
		var yy := fmod(i * 110.0 + _t * 140.0, sz.y + 110.0) - 60.0
		for side in [0, 1]:
			var x := 4.0 if side == 0 else sz.x * 0.75 + 18.0
			var w := sz.x * 0.25 - 22.0
			match loc.theme:
				"desert":
					_preview.draw_circle(Vector2(x + w / 2.0, yy + 30), 22, Color("e2c28c"))
					_preview.draw_circle(Vector2(x + w / 2.0, yy + 70), 9, Color("4f8f4a"))
				"neon":
					var nc: Color = [Color("ff4fd8"), Color("6ff2ff"), Color("ffe66d")][(i + side) % 3]
					Art.rrect(_preview, Rect2(x, yy, w, 80), Color("23233a"), 4)
					_preview.draw_rect(Rect2(x + 3, yy + 3, w - 6, 74), nc, false, 2.0)
					Art.glow(_preview, Vector2(x + w / 2.0, yy + 40), 50, Color(nc, 0.25))
				"omsk":
					# Синяя табличка «ОМСК 0 км» и факел НПЗ
					if (i + side) % 2 == 0:
						Art.rrect(_preview, Rect2(x, yy + 20, w, 36), Color("2a5bd7"), 4, 2, Color("eef0f6"))
						Art.text_center(_preview, Vector2(x + w / 2.0, yy + 32), "ОМСК", 11, Color("eef0f6"), true)
						Art.text_center(_preview, Vector2(x + w / 2.0, yy + 46), "0 км", 10, Color("eef0f6"))
					else:
						var fc := Vector2(x + w / 2.0, yy + 40)
						_preview.draw_circle(fc, 14, Color("c9cdd6"))
						Art.glow(_preview, fc + Vector2(0, -24), 30, Color(1, 0.55, 0.15, 0.6))
						_preview.draw_circle(fc + Vector2(0, -24), 5 + sin(_t * 12.0 + i) * 1.5, Art.ORANGE)
				_:
					var col: Color = Art.ROOF_COLORS[(i * 2 + side) % Art.ROOF_COLORS.size()]
					if loc.theme == "winter":
						col = col.lerp(Color("eef3f8"), 0.8)
					elif loc.theme == "rain":
						col = col.darkened(0.3)
					Art.rrect(_preview, Rect2(x, yy, w, 80), col, 4, 3, col.darkened(0.3))
	Art.draw_player_car(_preview, SaveManager.custom_car(SaveManager.selected_car),
		{"lights": true, "time": _t, "base": Transform2D(0, Vector2(sz.x * 0.62, sz.y * 0.72))})
	# Погода и время суток
	match loc.theme:
		"winter":
			for i in 40:
				var p := Vector2(fmod(i * 53.0 + sin(_t + i) * 10.0, sz.x), fmod(i * 37.0 + _t * 90.0, sz.y))
				_preview.draw_circle(p, 2.2, Color(1, 1, 1, 0.9))
		"rain":
			_preview.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.1, 0.12, 0.2, 0.3))
			for i in 50:
				var p := Vector2(fmod(i * 47.0, sz.x), fmod(i * 61.0 + _t * 700.0, sz.y))
				_preview.draw_line(p, p + Vector2(-3, 18), Color(0.75, 0.82, 1, 0.45), 1.5)
		"desert":
			_preview.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.75, 0.4, 0.12))
		"neon":
			_preview.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.05, 0.2, 0.35))
	Art.theme = old
	Art.night = old_night
