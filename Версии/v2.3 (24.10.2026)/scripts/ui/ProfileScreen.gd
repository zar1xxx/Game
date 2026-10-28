extends Control
## Профиль водителя: уровень и звание, опыт, статистика за всё время
## и что открывается на следующих уровнях. Открывается нажатием на плашку уровня в меню.

signal closed
signal garage_requested

var _panel: PanelContainer
var _head: Control
var _stats: GridContainer
var _levels: VBoxContainer
var _back: Button
var _scroll: ScrollContainer


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
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	# Шапка: значок уровня, имя, звание, полоска опыта
	_head = Control.new()
	_head.custom_minimum_size = Vector2(820, 86)
	_head.draw.connect(_draw_head)
	vb.add_child(_head)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 380
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(_caption("СТАТИСТИКА"))
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 16)
	_stats.add_theme_constant_override("v_separation", 5)
	left.add_child(_stats)
	var how := Label.new()
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 370
	how.add_theme_font_size_override("font_size", 12)
	how.add_theme_color_override("font_color", Art.UI_MUTED)
	how.text = "Опыт даётся за каждый заезд: 15 + очки ÷ 8, ещё +25 за каждое выполненное задание " + \
		"и +30 за заезд дня или испытание недели. За новый уровень — монеты и косметика."
	left.add_child(how)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 416
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	right.add_child(_caption("ЧТО ОТКРЫВАЕТСЯ ЗА УРОВНИ"))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(416, 300)
	right.add_child(_scroll)
	preload("res://scripts/ui/TouchScroll.gd").attach(_scroll)
	_levels = VBoxContainer.new()
	_levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels.add_theme_constant_override("separation", 4)
	_scroll.add_child(_levels)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(buttons)
	var garage := Button.new()
	garage.text = "Гараж: гудки, дым, наклейки"
	garage.custom_minimum_size = Vector2(300, 48)
	garage.pressed.connect(func():
		hide()
		garage_requested.emit())
	buttons.add_child(garage)
	_back = Button.new()
	_back.text = "Назад"
	_back.custom_minimum_size = Vector2(200, 48)
	_back.pressed.connect(close)
	buttons.add_child(_back)
	hide()


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Art.font_title)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Art.ORANGE)
	return l


func open() -> void:
	_fill()
	show()
	# На низком экране список уровней короче, чтобы всё влезло без обрезки
	var vh := get_viewport().get_visible_rect().size.y
	_scroll.custom_minimum_size.y = clampf(vh - 340.0, 160.0, 320.0)
	_scroll.scroll_vertical = 0
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
	_head.queue_redraw()
	for c in _stats.get_children():
		c.queue_free()
	var best := SaveManager.best_score
	for k in SaveManager.best_by_location:
		best = maxi(best, int(SaveManager.best_by_location[k]))
	var rows := [
		["Заездов", str(SaveManager.games_played)],
		["Лучший результат", str(best)],
		["В среднем за заезд", str(SaveManager.get_average_score())],
		["Очков за всё время", str(SaveManager.total_score)],
		["Лучшее комбо", "×%d" % SaveManager.best_combo],
		["Машин в гараже", "%d из %d" % [SaveManager.owned_cars.size(), GameData.CARS.size()]],
		["Трасс открыто", "%d из %d" % [SaveManager.owned_locations.size(), GameData.LOCATIONS.size()]],
		["Достижений", "%d из %d" % [Achievements.unlocked_count(), Achievements.LIST.size()]],
		["Точек на карте Омска", "%d из %d" % [SaveManager.omsk_seen.size(), GameData.LANDMARKS.size()]],
		["Монет", str(SaveManager.coins)],
	]
	for r in rows:
		var k := Label.new()
		k.text = r[0]
		k.add_theme_font_size_override("font_size", 15)
		k.add_theme_color_override("font_color", Art.UI_MUTED)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(k)
		var v := Label.new()
		v.text = r[1]
		v.add_theme_font_override("font", Art.font_title)
		v.add_theme_font_size_override("font_size", 16)
		v.add_theme_color_override("font_color", Art.UI_TEXT)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stats.add_child(v)
	# Дорожка уровней: что даёт каждый уровень, открытые — с галочкой
	for c in _levels.get_children():
		c.queue_free()
	var lvl := SaveManager.get_level()
	for l in range(2, GameData.MAX_LEVEL + 1):
		var unlocks := GameData.level_unlocks(l)
		var got := l <= lvl
		var row := Control.new()
		row.custom_minimum_size = Vector2(0, 44 if unlocks.size() <= 1 else 60)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var level := l
		var items := unlocks
		row.draw.connect(func():
			var rr := Rect2(Vector2.ZERO, row.size)
			var cur := level == lvl + 1
			Art.rrect(row, rr, Color(Art.UI_PANEL_LIGHT, 1.0 if got or cur else 0.5), 8, 2 if cur else 0,
				Color(Art.TEAL, 0.9) if cur else Color.TRANSPARENT)
			var c := Vector2(24, rr.size.y / 2.0)
			row.draw_circle(c, 16, Art.YELLOW if got else Color("3a3f52"))
			row.draw_circle(c, 13, Art.ORANGE if got else Color("2c3040"))
			Art.text_center(row, c, str(level), 13, Art.INK if got else Art.UI_MUTED, true)
			var col := Art.UI_TEXT if got else (Art.UI_TEXT if cur else Art.UI_MUTED)
			var text := ", ".join(items) if not items.is_empty() else "только монеты"
			var y := 18.0
			for line in _wrap(text, rr.size.x - 150.0, 13):
				row.draw_string(Art.font_bold, Vector2(48, y), line, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 150.0, 13, col)
				y += 17.0
			var reward := "+%d монет" % GameData.level_reward(level)
			row.draw_string(Art.font_bold, Vector2(rr.size.x - 96, 18), reward, HORIZONTAL_ALIGNMENT_RIGHT, 86, 12,
				Art.YELLOW if not got else Art.UI_MUTED)
			if got:
				row.draw_string(Art.font_bold, Vector2(rr.size.x - 96, 36), "получено ✓", HORIZONTAL_ALIGNMENT_RIGHT, 86, 11, Art.GREEN)
			elif cur:
				row.draw_string(Art.font_bold, Vector2(rr.size.x - 96, 36), "следующий", HORIZONTAL_ALIGNMENT_RIGHT, 86, 11, Art.TEAL))
		_levels.add_child(row)


## Перенос строки по ширине (для подписей внутри рисованных строк)
func _wrap(text: String, width: float, size: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if line != "" and Art.font_bold.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out.slice(0, 2)


func _draw_head() -> void:
	var ci := _head
	var lvl := SaveManager.get_level()
	var c := Vector2(40, 43)
	ci.draw_circle(c, 38, Art.YELLOW)
	ci.draw_circle(c, 32, Art.ORANGE)
	Art.text_center(ci, c, str(lvl), 30, Art.INK, true)
	ci.draw_string(Art.font_title, Vector2(96, 30), SaveManager.player_name, HORIZONTAL_ALIGNMENT_LEFT, 420, 26, Art.UI_TEXT)
	ci.draw_string(Art.font_bold, Vector2(96, 54), "Уровень %d  •  %s" % [lvl, GameData.level_title(lvl)],
		HORIZONTAL_ALIGNMENT_LEFT, 420, 17, Art.TEAL)
	# Полоска опыта
	var pr := GameData.level_progress(SaveManager.xp)
	var bar := Rect2(96, 64, 420, 12)
	Art.rrect(ci, bar, Color(Art.UI_PANEL_LIGHT), 6)
	var k := 1.0 if lvl >= GameData.MAX_LEVEL else clampf(float(pr.x) / maxf(pr.y, 1), 0.0, 1.0)
	if k > 0.0:
		Art.rrect(ci, Rect2(bar.position, Vector2(maxf(bar.size.x * k, 12.0), bar.size.y)), Art.TEAL, 6)
	var xp_text := "Максимальный уровень!" if lvl >= GameData.MAX_LEVEL else \
		"Опыт %d / %d  •  всего %d" % [pr.x, pr.y, SaveManager.xp]
	ci.draw_string(Art.font_bold, Vector2(530, 75), xp_text, HORIZONTAL_ALIGNMENT_LEFT, 290, 13, Art.UI_MUTED)
	var nxt := GameData.next_unlock_level(lvl)
	if nxt > 0:
		ci.draw_string(Art.font_bold, Vector2(530, 54), "Ур. %d: %s" % [nxt, GameData.level_unlocks(nxt)[0]],
			HORIZONTAL_ALIGNMENT_LEFT, 290, 13, Art.YELLOW)
	ci.draw_string(Art.font_bold, Vector2(530, 30), "Имя меняется в настройках", HORIZONTAL_ALIGNMENT_LEFT, 290, 12, Art.UI_MUTED)
