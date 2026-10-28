extends Control
## Карта Омска: живая схема города — Иртыш и Омь, мосты, кварталы, парки, лодки и машины.
## На ней 16 достопримечательностей со своими значками. Найденные на трассе «Омск»
## точки цветные, остальные — серые со знаком «?». Нажмите на точку (или листайте ◀ ▶),
## чтобы увидеть её крупно и прочитать факт.

signal closed
signal drive_requested            # «Ехать в Омск» — меню выбирает трассу и запускает заезд

const MAP_SIZE := Vector2(540, 476)

var _map: Control
var _card: Control
var _title: Label
var _name: Label
var _desc: Label
var _count: Label
var _progress: Control
var _back: Button
var _how: Label
var _go: Button
var _panel: PanelContainer
var _selected: String = ""
var _t: float = 0.0
var _irtysh: PackedVector2Array
var _om: PackedVector2Array
var _blocks: Array = []           # кварталы правого и левого берега (рисуются один раз)


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
	center.add_child(_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_panel.add_child(hb)

	_map = Control.new()
	_map.custom_minimum_size = MAP_SIZE
	_map.clip_contents = true
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	hb.add_child(_map)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.add_theme_constant_override("separation", 7)
	hb.add_child(side)
	_title = Label.new()
	_title.text = "КАРТА ОМСКА"
	_title.add_theme_font_override("font", Art.font_title)
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Art.ORANGE)
	side.add_child(_title)
	_progress = Control.new()
	_progress.custom_minimum_size = Vector2(300, 30)
	_progress.draw.connect(_draw_progress)
	side.add_child(_progress)
	_count = Label.new()
	_count.add_theme_color_override("font_color", Art.UI_MUTED)
	_count.add_theme_font_size_override("font_size", 12)
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_count)
	# Карточка выбранной точки: крупный значок и листалка
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)
	side.add_child(card_row)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(44, 96)
	prev.pressed.connect(func(): _step(-1))
	card_row.add_child(prev)
	_card = Control.new()
	_card.custom_minimum_size = Vector2(196, 96)
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.draw.connect(_draw_card)
	card_row.add_child(_card)
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(44, 96)
	next.pressed.connect(func(): _step(1))
	card_row.add_child(next)
	_name = Label.new()
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_font_override("font", Art.font_title)
	_name.add_theme_font_size_override("font_size", 18)
	_name.add_theme_color_override("font_color", Art.YELLOW)
	side.add_child(_name)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc.custom_minimum_size.y = 96
	_desc.add_theme_font_size_override("font_size", 14)
	side.add_child(_desc)
	_how = Label.new()
	_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_how.add_theme_font_size_override("font_size", 13)
	_how.add_theme_color_override("font_color", Art.TEAL)
	side.add_child(_how)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	side.add_child(buttons)
	_go = Button.new()
	_go.custom_minimum_size = Vector2(0, 46)
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go.add_theme_font_size_override("font_size", 15)
	_go.pressed.connect(_on_go_pressed)
	buttons.add_child(_go)
	_back = Button.new()
	_back.text = "Назад"
	_back.custom_minimum_size = Vector2(96, 46)
	_back.pressed.connect(close)
	buttons.add_child(_back)
	_build_geometry()
	hide()


## Реки и кварталы — один раз
func _build_geometry() -> void:
	var sz := MAP_SIZE
	_irtysh = PackedVector2Array()
	for k in 25:
		var v := k / 24.0
		_irtysh.append(Vector2(sz.x * (0.42 - 0.08 * sin(v * PI * 1.3) + 0.03 * sin(v * 9.0)), sz.y * (1.04 - v * 1.08)))
	_om = PackedVector2Array()
	for k in 15:
		var v := k / 14.0
		_om.append(Vector2(sz.x * lerpf(0.43, 1.04, v), sz.y * (0.47 + 0.05 * sin(v * 6.0) + 0.04 * v)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	_blocks.clear()
	var step := 34.0
	var y := 6.0
	while y < sz.y:
		var x := 6.0
		while x < sz.x:
			var p := Vector2(x + 12, y + 12)
			var near := _dist_to_river(p)
			if near > 26.0:
				var right_bank := p.x > _river_x(p.y)
				var col := Color("4a5163") if right_bank else Color("3f4a3a")
				if rng.randf() < 0.14:
					col = Color("3f6b3f")          # парк
				elif right_bank and rng.randf() < 0.25:
					col = Color("575e72")
				_blocks.append({"r": Rect2(x, y, step - 8, step - 8), "c": col})
			x += step
		y += step


func _river_x(y: float) -> float:
	var best := 0.0
	var bd := 1e9
	for p in _irtysh:
		var d := absf(p.y - y)
		if d < bd:
			bd = d
			best = p.x
	return best


func _dist_to_river(p: Vector2) -> float:
	var d := 1e9
	for line in [_irtysh, _om]:
		var w := 22.0 if line == _irtysh else 12.0
		for i in line.size() - 1:
			d = minf(d, Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1]).distance_to(p) - w)
	return d


func open() -> void:
	_selected = ""
	# Сразу показываем первую найденную точку — экран не пустой
	for lm in GameData.LANDMARKS:
		if lm.id in SaveManager.omsk_seen:
			_selected = lm.id
			break
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
		_card.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		get_viewport().set_input_as_handled()


func _pin_pos(lm: Dictionary) -> Vector2:
	return lm.pos * MAP_SIZE


func _on_map_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var best := ""
	var best_d := 36.0
	for lm in GameData.LANDMARKS:
		var d: float = _pin_pos(lm).distance_to(event.position)
		if d < best_d:
			best_d = d
			best = lm.id
	if best != "":
		_selected = best
		Sound.play("click", -4.0)
		_refresh_info()


func _step(dir: int) -> void:
	var list: Array = GameData.LANDMARKS
	var i := 0
	for k in list.size():
		if list[k].id == _selected:
			i = k
	i = (i + dir + list.size()) % list.size()
	_selected = list[i].id
	Sound.play("whoosh", -12.0, 1.3)
	_refresh_info()


func _refresh_info() -> void:
	var found := SaveManager.omsk_seen.size()
	var total := GameData.LANDMARKS.size()
	_count.text = "Найдено %d из %d  •  за новую точку +%d монет, за всю карту +%d. Схема не в масштабе." % [
		found, total, GameData.LANDMARK_REWARD, GameData.LANDMARKS_ALL_REWARD]
	_progress.queue_redraw()
	var omsk := GameData.get_location("omsk")
	var owned := SaveManager.is_owned("location", "omsk")
	_go.disabled = false
	if found >= total:
		_how.text = "Вы нашли весь Омск! Теперь вы почётный омич."
		_go.text = "Ехать в Омск"
	elif owned:
		_how.text = "Как открыть: езжайте по трассе «Омск» и смотрите по сторонам — точки у дороги отмечаются сами. Ненайденные попадаются чаще."
		_go.text = "Ехать в Омск"
	else:
		_how.text = "Как открыть: купите трассу «Омск» в магазине и езжайте по ней — точки у дороги отмечаются сами."
		_go.text = "Купить «Омск» за %d" % omsk.price
		_go.disabled = SaveManager.coins < int(omsk.price)
		if _go.disabled:
			_go.text = "«Омск» — %d (у вас %d)" % [omsk.price, SaveManager.coins]
	if _selected == "":
		_name.text = "Нажмите на точку на карте"
		_desc.text = "Или листайте стрелками ◀ ▶."
		return
	var lm := GameData.get_landmark(_selected)
	if _selected in SaveManager.omsk_seen:
		_name.text = lm.name
		_desc.text = lm.desc
	else:
		_name.text = "??? — ещё не найдено"
		_desc.text = "Эта точка пока скрыта. Проедьте трассу «Омск» и смотрите по сторонам: когда она мелькнёт у дороги, здесь появится её история."


func _on_go_pressed() -> void:
	if not SaveManager.is_owned("location", "omsk"):
		if not SaveManager.buy("location", "omsk"):
			return
		Sound.play("buy", 0.0, 1.0, 0.0)
		_refresh_info()
		return
	Sound.play("click", -4.0)
	drive_requested.emit()


# ---------------------------------------------------------------------------
# Рисование карты
# ---------------------------------------------------------------------------
func _draw_map() -> void:
	var sz := MAP_SIZE
	var ci := _map
	Art.rrect(ci, Rect2(Vector2.ZERO, sz), Color("353c4c"), 14)
	# Кварталы и парки
	for b in _blocks:
		Art.rrect(ci, b.r, b.c, 5)
	# Главные улицы: Ленина (к Тарским воротам) и проспект Маркса
	var lenina := [Vector2(0.50, 0.36), Vector2(0.56, 0.52), Vector2(0.64, 0.86)]
	var marx := [Vector2(0.58, 0.60), Vector2(0.72, 0.98)]
	for road in [lenina, marx]:
		var pts := PackedVector2Array()
		for p in road:
			pts.append(p * sz)
		ci.draw_polyline(pts, Color("e9d9a6", 0.55), 6.0, true)
		ci.draw_polyline(pts, Color("f6e7b8", 0.85), 2.0, true)
	Art.text_center(ci, Vector2(sz.x * 0.70, sz.y * 0.88) + Vector2(14, 0), "ул. Ленина", 10, Color(1, 0.9, 0.6, 0.75))
	# Машины ползут по Ленина
	for k in 3:
		var v := fmod(_t * 0.06 + k / 3.0, 1.0)
		var p := _along(lenina, v) * sz
		ci.draw_circle(p, 3.0, [Art.ORANGE, Art.TEAL, Art.YELLOW][k])
	# Железная дорога на левом берегу
	var rail := PackedVector2Array([Vector2(0.0, 0.62) * sz, Vector2(0.22, 0.48) * sz, Vector2(0.30, 0.0) * sz])
	ci.draw_polyline(rail, Color("1f2430"), 5.0, true)
	for i in rail.size() - 1:
		var a: Vector2 = rail[i]
		var b: Vector2 = rail[i + 1]
		var n := int(a.distance_to(b) / 10.0)
		for k in n:
			var p := a.lerp(b, float(k) / n)
			var perp := (b - a).normalized().orthogonal() * 4.0
			ci.draw_line(p - perp, p + perp, Color("8a8f9c"), 1.5)
	# Реки
	ci.draw_polyline(_irtysh, Color("27507a"), 48.0, true)
	ci.draw_polyline(_irtysh, Color("3c74a6"), 38.0, true)
	ci.draw_polyline(_om, Color("27507a"), 22.0, true)
	ci.draw_polyline(_om, Color("3c74a6"), 15.0, true)
	# Блики на воде
	for k in 10:
		var v := fmod(k / 10.0 + _t * 0.012, 1.0)
		var p := _along_line(_irtysh, v)
		ci.draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), Color(1, 1, 1, 0.25), 2.0)
	# Мосты: Ленинградский, Метромост, Юбилейный
	_draw_bridge(ci, _along_line(_irtysh, 0.10), 0.12, 58.0, Color("c9cdd6"))
	_draw_bridge(ci, _along_line(_irtysh, 0.30), 0.18, 58.0, Color("a9b8d6"))
	_draw_bridge(ci, _along_line(_om, 0.17), PI / 2.0 - 0.1, 30.0, Color("d6cfb8"))
	# Теплоход идёт по Иртышу
	var bv := fmod(_t * 0.025, 1.0)
	var bp := _along_line(_irtysh, bv)
	var bd := (_along_line(_irtysh, minf(bv + 0.01, 1.0)) - bp).normalized()
	ci.draw_set_transform(bp, bd.angle(), Vector2.ONE)
	Art.rrect(ci, Rect2(-11, -5, 22, 10), Color("eef0f6"), 5)
	ci.draw_rect(Rect2(-3, -3, 8, 6), Art.RED)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Art.text_center(ci, _along_line(_irtysh, 0.62) + Vector2(-34, 0), "Иртыш", 12, Color("bfe0ff"), true)
	Art.text_center(ci, _along_line(_om, 0.7) + Vector2(0, -16), "Омь", 11, Color("bfe0ff"), true)
	# Роза ветров
	var cp := Vector2(sz.x - 34, 34)
	ci.draw_circle(cp, 20, Color(Art.UI_PANEL, 0.85))
	ci.draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -16), cp + Vector2(5, 0), cp + Vector2(-5, 0)]), Art.RED)
	ci.draw_colored_polygon(PackedVector2Array([cp + Vector2(0, 16), cp + Vector2(5, 0), cp + Vector2(-5, 0)]), Art.UI_MUTED)
	Art.text_center(ci, cp + Vector2(0, -26), "С", 11, Art.UI_TEXT, true)
	# Точки: сначала линии-выноски у выбранной, затем значки
	for lm in GameData.LANDMARKS:
		_draw_pin(ci, lm)
	# Подпись выбранной точки
	if _selected != "":
		var lm := GameData.get_landmark(_selected)
		var p := _pin_pos(lm)
		var found: bool = _selected in SaveManager.omsk_seen
		var text: String = lm.name if found else "???"
		var w := Art.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
		var lp := Vector2(clampf(p.x, w / 2.0 + 4.0, sz.x - w / 2.0 - 4.0), p.y - 34.0 if p.y > 50.0 else p.y + 34.0)
		Art.rrect(ci, Rect2(lp - Vector2(w / 2.0, 11), Vector2(w, 22)), Color(Art.INK, 0.9), 8, 2, Art.YELLOW)
		Art.text_center(ci, lp, text, 13, Art.YELLOW, true)
	Art.rrect(ci, Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0), 14, 3, Color("586079"))


func _draw_bridge(ci: CanvasItem, p: Vector2, angle: float, length: float, col: Color) -> void:
	ci.draw_set_transform(p, angle, Vector2.ONE)
	ci.draw_rect(Rect2(-length / 2.0, -4, length, 8), Color(0, 0, 0, 0.4))
	ci.draw_rect(Rect2(-length / 2.0, -3, length, 6), col)
	ci.draw_line(Vector2(-length / 2.0, 0), Vector2(length / 2.0, 0), Color(Art.INK, 0.5), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _along(pts: Array, v: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var want := v * total
	for i in pts.size() - 1:
		var seg: float = (pts[i] as Vector2).distance_to(pts[i + 1])
		if want <= seg:
			return (pts[i] as Vector2).lerp(pts[i + 1], want / maxf(seg, 0.001))
		want -= seg
	return pts[-1]


func _along_line(line: PackedVector2Array, v: float) -> Vector2:
	var idx := clampf(v, 0.0, 1.0) * (line.size() - 1)
	var i := mini(int(idx), line.size() - 2)
	return line[i].lerp(line[i + 1], idx - i)


func _draw_pin(ci: CanvasItem, lm: Dictionary) -> void:
	var p := _pin_pos(lm)
	var found: bool = lm.id in SaveManager.omsk_seen
	var sel: bool = lm.id == _selected
	var r := 15.0 if not sel else 18.0 + sin(_t * 6.0) * 1.5
	if found:
		Art.glow(ci, p, r * 2.4, Color(Art.YELLOW, 0.4 if sel else 0.18))
	ci.draw_circle(p + Vector2(2, 3), r, Color(0, 0, 0, 0.45))
	ci.draw_circle(p, r, Color("f6efe0") if found else Color("4a4f60"))
	if found:
		draw_icon(ci, lm.id, p, r / 15.0, _t, true)
	else:
		Art.text_center(ci, p + Vector2(0, 1), "?", 15, Color("aab0c0"), true)
	ci.draw_arc(p, r, 0, TAU, 28, Color.WHITE if sel else (Art.ORANGE if found else Color("6b7184")), 2.5 if sel else 2.0, true)


func _draw_progress() -> void:
	var ci := _progress
	var found := SaveManager.omsk_seen.size()
	var total := GameData.LANDMARKS.size()
	var w := ci.size.x
	var bar := Rect2(0, 8, w, 14)
	Art.rrect(ci, bar, Color(Art.UI_PANEL_LIGHT), 7)
	var k := clampf(float(found) / maxf(total, 1), 0.0, 1.0)
	if k > 0.0:
		Art.rrect(ci, Rect2(bar.position, Vector2(maxf(w * k, 14.0), bar.size.y)), Art.YELLOW, 7)
	for i in total:
		var x := w * (i + 1) / float(total)
		ci.draw_line(Vector2(x, bar.position.y + 2), Vector2(x, bar.end.y - 2), Color(Art.INK, 0.35), 1.0)
	Art.text_center(ci, bar.get_center() + Vector2(0, 0), "%d / %d" % [found, total], 11, Art.INK if k > 0.45 else Art.UI_TEXT, true)


func _draw_card() -> void:
	var ci := _card
	var sz := ci.size
	Art.rrect(ci, Rect2(Vector2.ZERO, sz), Color(Art.UI_PANEL_LIGHT), 12)
	if _selected == "":
		Art.text_center(ci, sz / 2.0, "?", 40, Art.UI_MUTED, true)
		return
	var found: bool = _selected in SaveManager.omsk_seen
	var c := sz / 2.0
	if found:
		Art.glow(ci, c, 70, Color(Art.YELLOW, 0.25))
		ci.draw_circle(c, 40, Color("f6efe0"))
		draw_icon(ci, _selected, c, 2.6, _t, true)
		ci.draw_arc(c, 40, 0, TAU, 40, Art.ORANGE, 3.0, true)
	else:
		ci.draw_circle(c, 40, Color("4a4f60"))
		Art.text_center(ci, c, "?", 40, Color("aab0c0"), true)
		ci.draw_arc(c, 40, 0, TAU, 40, Color("6b7184"), 3.0, true)


## Значок достопримечательности (центр c, масштаб s: 1 — для булавки радиусом 15)
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, t: float, color: bool) -> void:
	var ink := Art.INK
	match id:
		"npz":
			for k in 2:
				var bp := c + Vector2((-5 + k * 10) * s, 4 * s)
				ci.draw_rect(Rect2(bp - Vector2(2, 0) * s, Vector2(4, 8) * s), Color("8a8f9c"))
				var f := 0.8 + 0.2 * sin(t * 12.0 + k * 2.0)
				ci.draw_circle(bp + Vector2(0, -3) * s, 4.0 * s * f, Art.ORANGE)
				ci.draw_circle(bp + Vector2(0, -3) * s, 2.0 * s * f, Art.YELLOW)
		"tara":
			ci.draw_rect(Rect2(c + Vector2(-9, -5) * s, Vector2(18, 11) * s), Color("eeeae0"))
			ci.draw_rect(Rect2(c + Vector2(-9, -5) * s, Vector2(18, 11) * s), Color("b84c3a"), false, 1.5 * s)
			ci.draw_rect(Rect2(c + Vector2(-3, -1) * s, Vector2(6, 7) * s), Color("6e665a"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -5) * s, c + Vector2(0, -10) * s, c + Vector2(10, -5) * s]), Color("6d8a5a"))
		"dostoevsky":
			ci.draw_rect(Rect2(c + Vector2(-6, 3) * s, Vector2(12, 6) * s), Color("6e6a64"))
			ci.draw_circle(c + Vector2(0, -1) * s, 5 * s, Color("5c4a36"))
			ci.draw_circle(c + Vector2(0, -6) * s, 3.2 * s, Color("7a6248"))
		"sobor":
			ci.draw_rect(Rect2(c + Vector2(-8, -2) * s, Vector2(16, 10) * s), Color("eeeae0"))
			ci.draw_circle(c + Vector2(0, -3) * s, 5 * s, Color("e8b931"))
			ci.draw_circle(c + Vector2(-7, 0) * s, 2.6 * s, Color("2f5fa8"))
			ci.draw_circle(c + Vector2(7, 0) * s, 2.6 * s, Color("2f5fa8"))
			ci.draw_line(c + Vector2(0, -12) * s, c + Vector2(0, -7) * s, ink, 1.2 * s)
		"drama":
			# Театральная маска
			ci.draw_circle(c, 8 * s, Color("e9dcc0"))
			ci.draw_circle(c + Vector2(-3, -2) * s, 1.5 * s, ink)
			ci.draw_circle(c + Vector2(3, -2) * s, 1.5 * s, ink)
			ci.draw_arc(c + Vector2(0, 2) * s, 3.5 * s, 0.2, PI - 0.2, 8, ink, 1.4 * s)
		"lyubochka":
			ci.draw_rect(Rect2(c + Vector2(-9, 3) * s, Vector2(18, 4) * s), Color("6b4a32"))
			ci.draw_circle(c + Vector2(2, 0) * s, 5 * s, Color("a8743c"))
			ci.draw_circle(c + Vector2(2, -5) * s, 3 * s, Color("c08a4c"))
			ci.draw_arc(c + Vector2(2, -5) * s, 4.5 * s, PI, TAU, 8, Color("8a5a2c"), 1.6 * s)
		"stepanych":
			ci.draw_circle(c + Vector2(0, 3) * s, 8 * s, Color("3d4152"))
			ci.draw_circle(c + Vector2(0, 0) * s, 4.5 * s, Color("9a6a36"))
			ci.draw_arc(c + Vector2(0, 0) * s, 4.5 * s, PI * 1.05, PI * 1.95, 8, Color("f2c230"), 2.2 * s)
		"metro":
			ci.draw_circle(c, 8 * s, Art.RED)
			Art.text_center(ci, c + Vector2(0, 0.5) * s, "М", int(11 * s), Color.WHITE, true)
		"irtysh":
			for k in 3:
				ci.draw_arc(c + Vector2(-4 + k * 4, -3 + k * 3) * s, 4 * s, PI * 1.15, PI * 1.85, 6, Color("3c74a6"), 2.0 * s)
			Art.rrect(ci, Rect2(c + Vector2(-4, 1) * s, Vector2(10, 5) * s), Color("eef0f6"), 2 * s, 1, Color("8a8f9c"))
		"bridge":
			ci.draw_rect(Rect2(c + Vector2(-11, -2) * s, Vector2(22, 4) * s), Color("8a8f9c"))
			for k in 2:
				ci.draw_arc(c + Vector2(-5 + k * 10, 6) * s, 5 * s, PI, TAU, 8, Color("5e6272"), 1.6 * s)
		"krepost":
			var pts := PackedVector2Array()
			for k in 8:
				var rad := (9.0 if k % 2 == 0 else 5.5) * s
				pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 4) * rad)
			ci.draw_colored_polygon(pts, Color("7f8a55"))
			ci.draw_rect(Rect2(c + Vector2(-3, -3) * s, Vector2(6, 6) * s), Color("eeeae0"))
		"metromost":
			ci.draw_rect(Rect2(c + Vector2(-11, -4) * s, Vector2(22, 4) * s), Color("6f7484"))
			ci.draw_rect(Rect2(c + Vector2(-11, 1) * s, Vector2(22, 3) * s), Color("4b4f5c"))
			Art.text_center(ci, c + Vector2(0, -8) * s, "М", int(8 * s), Art.RED, true)
		"arena":
			Art.rrect(ci, Rect2(c + Vector2(-10, -7) * s, Vector2(20, 14) * s), Color("dfe4ec"), 6 * s, 1, Color("8a94a8"))
			Art.rrect(ci, Rect2(c + Vector2(-5, -3) * s, Vector2(10, 6) * s), Color("eef6ff"), 2 * s, 1, Color("e5533d"))
			ci.draw_circle(c + Vector2(6, 5) * s, 2.2 * s, ink)                     # шайба
		"vrubel":
			var cols := [Color("4b3b8f"), Color("2f6fa8"), Color("6a4fb3"), Color("2fa89a"), Color("b34f8f")]
			for k in 5:
				var p := c + Vector2.from_angle(k * TAU / 5.0 + 0.4) * 5.0 * s
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -2) * s, p + Vector2(3, -3) * s, p + Vector2(3, 3) * s,
					p + Vector2(-2, 3) * s]), cols[k])
			ci.draw_circle(c, 2.5 * s, Color("e0b84f"))
		"circus":
			for k in 8:
				var a0 := TAU * k / 8.0
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * 9 * s, c + Vector2.from_angle(a0 + TAU / 8.0) * 9 * s]),
					Art.RED if k % 2 == 0 else Art.YELLOW)
			ci.draw_circle(c, 2 * s, Color.WHITE)
		"yubileyny":
			ci.draw_rect(Rect2(c + Vector2(-11, 2) * s, Vector2(22, 6) * s), Color("3c74a6"))
			ci.draw_rect(Rect2(c + Vector2(-11, -3) * s, Vector2(22, 3) * s), Color("9a9fae"))
			for k in 3:
				ci.draw_arc(c + Vector2(-7 + k * 7, 2) * s, 3.3 * s, PI, TAU, 6, Color("eef0f6"), 1.4 * s)
		_:
			ci.draw_circle(c, 4 * s, Art.ORANGE)
