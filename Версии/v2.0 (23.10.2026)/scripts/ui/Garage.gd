extends Control
## Гараж: тюнинг, покраска, наклейки и номер для купленных машин.
## Тюнинг влияет на заезд (бак, тормоза, магнит для бонусов, прочность кузова),
## остальное — для красоты. Наклейка покупается один раз и клеится на любую машину.

signal closed

const PREVIEW_SIZE := Vector2(300, 440)

var tab: String = "tune"
var _cars: Array = []
var _index: int = 0
var _t: float = 0.0

var _coins: Label
var _car_name: Label
var _preview: Control
var _content: VBoxContainer
var _tabs: Dictionary = {}
var _select_btn: Button
var _flash: Label
var _plate_edit: LineEdit
var _plate_preview: Control
var _plate_msg: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	SaveManager.coins_changed.connect(func(_c): _refresh_header())


func open() -> void:
	_cars = SaveManager.owned_cars.duplicate()
	_index = maxi(0, _cars.find(SaveManager.selected_car))
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_switch_tab(tab)
	_tabs[tab].grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _car_id() -> String:
	return _cars[_index] if not _cars.is_empty() else SaveManager.selected_car


# ---------------------------------------------------------------------------
# Построение
# ---------------------------------------------------------------------------
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Art.INK, 0.78)
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

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var title := Label.new()
	title.text = "ГАРАЖ"
	title.add_theme_font_override("font", Art.font_title)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Art.ORANGE)
	top.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var prev := _button("◀", Vector2(52, 46), 22)
	prev.pressed.connect(func(): _step(-1))
	top.add_child(prev)
	_car_name = Label.new()
	_car_name.custom_minimum_size = Vector2(330, 0)
	_car_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_name.add_theme_font_override("font", Art.font_title)
	_car_name.add_theme_font_size_override("font_size", 22)
	top.add_child(_car_name)
	var next := _button("▶", Vector2(52, 46), 22)
	next.pressed.connect(func(): _step(1))
	top.add_child(next)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp2)
	_coins = Label.new()
	_coins.add_theme_font_override("font", Art.font_title)
	_coins.add_theme_font_size_override("font_size", 26)
	_coins.add_theme_color_override("font_color", Art.YELLOW)
	top.add_child(_coins)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 16)
	root.add_child(mid)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	mid.add_child(left)
	_preview = Control.new()
	_preview.custom_minimum_size = PREVIEW_SIZE
	_preview.clip_contents = true
	_preview.draw.connect(_draw_preview)
	left.add_child(_preview)
	_select_btn = _button("Выбрать для заезда", Vector2(PREVIEW_SIZE.x, 46), 18)
	_select_btn.pressed.connect(func():
		SaveManager.select("car", _car_id())
		Sound.play("coin", -6.0, 1.3)
		_refresh_header())
	left.add_child(_select_btn)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	panel.add_child(pv)
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 8)
	pv.add_child(tabs_row)
	var group := ButtonGroup.new()
	for item in [["tune", "Тюнинг"], ["paint", "Покраска"], ["decal", "Наклейки"], ["plate", "Номер"], ["style", "Стиль"]]:
		var b := _button(item[1], Vector2(0, 44), 18)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = item[0]
		b.pressed.connect(func(): _switch_tab(id))
		tabs_row.add_child(b)
		_tabs[id] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	var hint := Label.new()
	hint.text = "Тюнинг действует только на эту машину. Наклейки покупаются один раз — для всех машин."
	hint.add_theme_color_override("font_color", Art.UI_MUTED)
	hint.add_theme_font_size_override("font_size", 14)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(hint)
	var back := _button("Назад", Vector2(200, 50), 20)
	back.pressed.connect(close)
	bottom.add_child(back)

	_flash = Label.new()
	_flash.add_theme_font_override("font", Art.font_title)
	_flash.add_theme_font_size_override("font_size", 40)
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


func _button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	return b


func _label(text: String, size_px: int, color: Color = Art.UI_TEXT, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", Art.font_title)
	return l


# ---------------------------------------------------------------------------
# Логика
# ---------------------------------------------------------------------------
func _step(dir: int) -> void:
	if _cars.size() <= 1:
		return
	_index = (_index + dir + _cars.size()) % _cars.size()
	Sound.play("whoosh", -10.0, 1.2)
	_switch_tab(tab)


func _switch_tab(t: String) -> void:
	tab = t
	for k in _tabs.keys():
		_tabs[k].set_pressed_no_signal(k == tab)
	_refresh_header()
	for c in _content.get_children():
		c.queue_free()
	match tab:
		"tune":
			_build_tune()
		"paint":
			_build_paint()
		"decal":
			_build_decals()
		"plate":
			_build_plate()
		"style":
			_build_style()


func _refresh_header() -> void:
	if _coins == null:
		return
	_coins.text = "%d монет" % SaveManager.coins
	var car := GameData.get_car(_car_id())
	_car_name.text = car.name
	var selected: bool = _car_id() == SaveManager.selected_car
	_select_btn.text = "Выбрана для заезда ✓" if selected else "Выбрать для заезда"
	_select_btn.disabled = selected


func _flash_text(text: String, color: Color = Art.YELLOW) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", color)
	_flash.pivot_offset = _flash.size / 2.0
	_flash.scale = Vector2(1.4, 1.4)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_flash, "modulate:a", 1.0, 0.12)
	tw.tween_property(_flash, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.5)
	tw.chain().tween_property(_flash, "modulate:a", 0.0, 0.4)


func _bought(text: String) -> void:
	MobileInput.vibrate(40)
	Sound.play("buy", -2.0, 1.0, 0.0)
	_flash_text(text)
	_switch_tab(tab)


func _no_money() -> void:
	Sound.play("beep", -6.0, 0.7)
	_flash_text("Не хватает монет", Art.RED)


# --- Тюнинг ---
func _build_tune() -> void:
	var id := _car_id()
	for up in GameData.UPGRADES:
		var lvl: int = SaveManager.get_mod(id, up.id, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_content.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(_label("%s  •  уровень %d/%d" % [up.name, lvl, GameData.UPGRADE_MAX], 18, Art.UI_TEXT, true))
		info.add_child(_label(_upgrade_effect(up.id, lvl), 14, Art.UI_MUTED))
		var pips := Control.new()
		pips.custom_minimum_size = Vector2(GameData.UPGRADE_MAX * 20, 24)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.draw.connect(func():
			for i in GameData.UPGRADE_MAX:
				var r := Rect2(i * 20, 4, 16, 16)
				Art.rrect(pips, r, Art.ORANGE if i < lvl else Art.UI_PANEL_LIGHT, 4))
		row.add_child(pips)
		var btn := _button("", Vector2(190, 48), 16)
		if lvl >= GameData.UPGRADE_MAX:
			btn.text = "Максимум"
			btn.disabled = true
		else:
			var price := GameData.upgrade_price(lvl)
			btn.text = "Улучшить — %d" % price
			btn.disabled = SaveManager.coins < price
			var key: String = up.id
			btn.pressed.connect(func():
				if SaveManager.buy_upgrade(id, key):
					_bought("%s: уровень %d!" % [up.name, lvl + 1])
				else:
					_no_money())
		row.add_child(btn)


func _upgrade_effect(key: String, lvl: int) -> String:
	match key:
		"tank":
			return "Бак больше на %d%% — дольше без заправки" % (lvl * 12)
		"brakes":
			return "Тормоза сильнее на %d%% — легче оттормозиться у камер и АЗС" % (lvl * 15)
		"magnet":
			if lvl == 0:
				return "Бонусы рядом с машиной сами подлетают к ней. Улучшение — притягивает издалека"
			return "Бонусы притягиваются в %s раза дальше обычного" % ("%.1f" % ((60.0 + 42.0 * lvl) / 60.0)).replace(".", ",")
		"armor":
			return "Прочность выше на %d%%" % (lvl * 12)
	return ""


# --- Покраска ---
func _build_paint() -> void:
	var id := _car_id()
	var cur: String = SaveManager.get_mod(id, "paint", "")
	_content.add_child(_label("Перекраска — %d монет. Вернуть заводской цвет — бесплатно." % GameData.PAINT_PRICE, 15, Art.UI_MUTED))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for col in GameData.PAINTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		var html: String = col.to_html(false)
		var selected := cur == html
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col if st != "hover" else col.lightened(0.15)
			sb.set_corner_radius_all(10)
			sb.set_border_width_all(4 if selected or st == "focus" else 2)
			sb.border_color = Art.LINE_WHITE if selected or st == "focus" else Art.INK
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func():
			if html == SaveManager.get_mod(id, "paint", ""):
				return
			if SaveManager.buy_paint(id, html):
				_bought("Покрашено!")
			else:
				_no_money())
		grid.add_child(b)
	var gold := _button("Позолота «Контракт» — 900 000 монет" if cur != GameData.GOLD_PAINT else "Позолота ✓", Vector2(0, 46), 17)
	gold.disabled = cur == GameData.GOLD_PAINT
	gold.add_theme_color_override("font_color", Art.YELLOW)
	gold.pressed.connect(func():
		if SaveManager.buy_paint(id, GameData.GOLD_PAINT):
			_bought("Как у олигарха!")
		else:
			_no_money())
	_content.add_child(gold)
	var factory := _button("Заводской цвет", Vector2(0, 46), 17)
	factory.disabled = cur == ""
	factory.pressed.connect(func():
		SaveManager.buy_paint(id, "")
		_bought("Как с завода!"))
	_content.add_child(factory)


# --- Наклейки ---
func _build_decals() -> void:
	var id := _car_id()
	var cur: String = SaveManager.get_mod(id, "decal", "")
	_content.add_child(_label("Купленная наклейка остаётся у вас навсегда и клеится на любую машину бесплатно.", 15, Art.UI_MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for d in GameData.DECALS:
		var owned: bool = d.id in SaveManager.owned_decals
		var b := _button("", Vector2(176, 58), 15)
		var price_txt := "" if owned else "\n%d монет" % d.price
		var need: int = d.get("level", 0)
		if need > 0:
			price_txt = "\nза уровень %d" % need
		b.text = ("✓ " if d.id == cur else "") + d.name + price_txt
		b.disabled = d.id == cur or not SaveManager.is_cosmetic_unlocked("decal", d.id)
		if need > 0:
			b.add_theme_color_override("font_color", Art.TEAL)
		var did: String = d.id
		b.pressed.connect(func():
			if SaveManager.apply_decal(id, did):
				_bought("Наклеено!" if did != "" else "Чисто!")
			else:
				_no_money())
		grid.add_child(b)


# --- Стиль: гудок и дым из выхлопа (открываются с уровнем водителя, общие для всех машин) ---
func _build_style() -> void:
	var lvl := SaveManager.get_level()
	_content.add_child(_label("Уровень водителя %d — «%s». Гудок и дым — для всех машин сразу." % [lvl, GameData.level_title(lvl)], 15, Art.UI_MUTED))
	_content.add_child(_label("Гудок", 20, Art.ORANGE, true))
	_style_grid("horn", GameData.HORNS)
	_content.add_child(_label("Дым из выхлопа", 20, Art.ORANGE, true))
	_style_grid("smoke", GameData.SMOKES)


func _style_grid(kind: String, items: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	var cur: String = SaveManager.cosmetics.get(kind, "")
	for it in items:
		var open := SaveManager.is_cosmetic_unlocked(kind, it.id)
		var b := _button("", Vector2(176, 58), 15)
		b.text = ("✓ " if it.id == cur else "") + it.name + ("" if open else "\nс уровня %d" % it.level)
		b.disabled = not open
		if it.id == cur:
			b.add_theme_color_override("font_color", Art.GREEN)
		var id: String = it.id
		b.pressed.connect(func():
			if kind == "horn":
				Sound.play(GameData.get_horn(id).sound, -3.0, 1.0, 0.0)
			if SaveManager.set_cosmetic(kind, id):
				_switch_tab(tab))
		grid.add_child(b)


# --- Номер ---
func _build_plate() -> void:
	var id := _car_id()
	var letters := ""
	for ch in GameData.PLATE_LETTERS:
		letters += ch + " "
	_content.add_child(_label("Свой номер — %d монет. Регион всегда 55. Буквы: %s" % [GameData.PLATE_PRICE,
		letters.strip_edges()], 15, Art.UI_MUTED))
	var pp := Control.new()
	_plate_preview = pp
	pp.custom_minimum_size = Vector2(0, 110)
	pp.draw.connect(func():
		var w := minf(pp.size.x - 20, 420.0)
		var r := Rect2((pp.size.x - w) / 2.0, 8, w, w * 0.22)
		var p := _normalize_plate(_plate_edit.text) if is_instance_valid(_plate_edit) else SaveManager.get_plate(id)
		Art.draw_plate_big(pp, r, p if p.length() == 6 else SaveManager.get_plate(id)))
	_content.add_child(pp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	_plate_edit = LineEdit.new()
	_plate_edit.max_length = 6
	_plate_edit.placeholder_text = "А123ВС"
	_plate_edit.text = SaveManager.get_plate(id)
	_plate_edit.custom_minimum_size = Vector2(180, 46)
	_plate_edit.add_theme_font_size_override("font_size", 22)
	_plate_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plate_edit.text_changed.connect(func(_t2):
		_plate_preview.queue_redraw()
		_update_plate_msg())
	row.add_child(_plate_edit)
	var rnd := _button("Случайный", Vector2(150, 46), 16)
	rnd.pressed.connect(func():
		_plate_edit.text = _random_plate()
		_plate_preview.queue_redraw()
		_update_plate_msg())
	row.add_child(rnd)
	var buy := _button("Поставить номер — %d" % GameData.PLATE_PRICE, Vector2(0, 50), 18)
	buy.pressed.connect(func():
		var p := _normalize_plate(_plate_edit.text)
		if not GameData.is_valid_plate(p):
			_plate_msg.text = "Номер должен быть вида А123ВС"
			Sound.play("beep", -6.0, 0.7)
			return
		if p == SaveManager.get_plate(id):
			_plate_msg.text = "Этот номер уже стоит на машине"
			return
		if SaveManager.buy_plate(id, p):
			_bought("Номер %s 55!" % p)
		else:
			_no_money())
	_content.add_child(buy)
	_plate_msg = _label("", 15, Art.UI_MUTED)
	_content.add_child(_plate_msg)
	_update_plate_msg()


## Латиница и строчные буквы превращаются в «номерные» кириллические
func _normalize_plate(t: String) -> String:
	var map := {"A": "А", "B": "В", "E": "Е", "K": "К", "M": "М", "H": "Н", "O": "О", "P": "Р",
		"C": "С", "T": "Т", "Y": "У", "X": "Х"}
	var out := ""
	for ch in t.strip_edges().to_upper():
		out += map.get(ch, ch)
	return out


func _update_plate_msg() -> void:
	if _plate_msg == null:
		return
	var p := _normalize_plate(_plate_edit.text)
	if GameData.is_valid_plate(p):
		_plate_msg.text = "Отличный номер!" if p.substr(1, 3) in ["555", "777", "001", "055", "100"] else "Номер подходит"
		_plate_msg.add_theme_color_override("font_color", Art.GREEN)
	else:
		_plate_msg.text = "Формат: буква, три цифры, две буквы (например, О555МС)"
		_plate_msg.add_theme_color_override("font_color", Art.UI_MUTED)


func _random_plate() -> String:
	var L := GameData.PLATE_LETTERS
	var lucky := randf() < 0.3
	var num: String = ["555", "777", "055", "123", "001"].pick_random() if lucky else "%03d" % randi_range(1, 999)
	return L[randi() % L.length()] + num + L[randi() % L.length()] + L[randi() % L.length()]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Превью
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if visible:
		_t += delta
		_preview.queue_redraw()


func _draw_preview() -> void:
	var sz := _preview.size
	var old := Art.theme
	Art.theme = "city"
	Art.rrect(_preview, Rect2(Vector2.ZERO, sz), Color("2a2d3a"), 12)
	# Пол гаража: плитка и разметка бокса
	var y := 0.0
	while y < sz.y:
		_preview.draw_line(Vector2(0, y), Vector2(sz.x, y), Color(1, 1, 1, 0.04), 2.0)
		y += 40.0
	_preview.draw_rect(Rect2(24, 20, sz.x - 48, sz.y - 120), Art.YELLOW, false, 3.0)
	Art.theme = old
	var car := SaveManager.custom_car(_car_id())
	var sc := minf(2.0, (sz.y - 150.0) / car.length)
	var c := Vector2(sz.x / 2.0, (sz.y - 100.0) / 2.0 + 10.0)
	var rot := sin(_t * 0.6) * 0.12
	Art.draw_player_car(_preview, car, {"lights": false, "time": _t, "plate": true,
		"base": Transform2D(rot, Vector2(sc, sc), 0.0, c)})
	_draw_preview_smoke(c + Vector2(0, car.length * sc / 2.0), sc)
	# Номер крупно под машиной
	var pw := sz.x - 60.0
	Art.draw_plate_big(_preview, Rect2(30, sz.y - 86, pw, pw * 0.22), car.plate)


## Дым в превью: несколько клубов позади машины, «бегут» назад
func _draw_preview_smoke(pipe: Vector2, sc: float) -> void:
	var style: String = SaveManager.cosmetics.get("smoke", "")
	if style == "":
		return
	for i in 7:
		var k := fmod(_t * 1.2 + i / 7.0, 1.0)
		var p := pipe + Vector2(sin(i * 2.3 + _t) * 10.0 * k + (i % 2 * 2 - 1) * 10.0, 6.0 + k * 90.0)
		var a := 1.0 - k
		match style:
			"grey":
				_preview.draw_circle(p, (5.0 + 16.0 * k) * sc * 0.6, Color(0.78, 0.8, 0.86, 0.38 * a))
			"black":
				_preview.draw_circle(p, (6.0 + 20.0 * k) * sc * 0.6, Color(0.12, 0.12, 0.14, 0.55 * a))
			"rainbow":
				_preview.draw_circle(p, (5.0 + 9.0 * k) * sc * 0.7, Color.from_hsv(fmod(_t * 0.6 + i * 0.12, 1.0), 0.75, 1.0, 0.75 * a))
			"hearts":
				var r := 9.0 * sc * 0.6 * (0.6 + 0.6 * k)
				var col := Color(1.0, 0.36, 0.55, 0.85 * a)
				_preview.draw_circle(p + Vector2(-r * 0.5, -r * 0.2), r * 0.55, col)
				_preview.draw_circle(p + Vector2(r * 0.5, -r * 0.2), r * 0.55, col)
				_preview.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.02, 0), p + Vector2(r * 1.02, 0), p + Vector2(0, r * 1.05)]), col)
			"fire":
				var r := (4.0 + 10.0 * k) * sc * 0.6
				_preview.draw_circle(p, r + 4.0, Color(1.0, 0.35, 0.05, 0.45 * a))
				_preview.draw_circle(p, r, Color(1.0, 0.75, 0.2, 0.8 * a))
