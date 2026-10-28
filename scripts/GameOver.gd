extends Control
## Экран проигрыша: причина, итоговый счёт, рекорд и кнопки.

const MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var reason_label: Label = $Center/Panel/VBox/ReasonLabel
@onready var score_label: Label = $Center/Panel/VBox/ScoreResult
@onready var best_label: Label = $Center/Panel/VBox/BestResult
@onready var new_record_label: Label = $Center/Panel/VBox/NewRecordLabel
@onready var coins_label: Label = $Center/Panel/VBox/CoinsResult
@onready var restart_button: Button = $Center/Panel/VBox/Buttons/RestartButton
@onready var menu_button: Button = $Center/Panel/VBox/Buttons/MenuButton

var _time: float = 0.0
var _coins_total: int = 0
var _coins_earned: int = 0
var _last_coin_tick: int = -1
var _intro_done: bool = false


func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	new_record_label.hide()


func show_result(reason: String, score: int, best: int, is_new_record: bool) -> void:
	reason_label.text = reason
	score_label.text = "Ваш счёт: 0"
	best_label.text = "Рекорд трассы: %d" % SaveManager.get_location_best()
	if SaveManager.daily_mode:
		best_label.text = "Рекорд дня: %d%s   •   трассы: %d" % [SaveManager.get_daily_best(),
			" (новый!)" if SaveManager.daily_last_new_record else "", SaveManager.get_location_best()]
	elif SaveManager.weekly_mode:
		best_label.text = "Рекорд недели: %d%s   •   целей: %d/%d" % [SaveManager.get_weekly_best(),
			" (новый!)" if SaveManager.weekly_last_new_record else "", SaveManager.get_weekly_reached(),
			GameData.WEEKLY_GOALS.size()]
	elif SaveManager.challenge_mode:
		best_label.text = "Результат друга: %d" % int(SaveManager.challenge.get("score", 0))
	elif SaveManager.party_mode:
		best_label.text = "«Кто дальше» • круг %d из %d" % [mini(int(SaveManager.party.round) + (0 if SaveManager.party_finished() else 1),
			SaveManager.PARTY_ROUNDS), SaveManager.PARTY_ROUNDS]
	elif SaveManager.difficulty_id() != "normal":
		best_label.text = "Рекорд трассы (%s): %d" % [SaveManager.difficulty().name, SaveManager.get_location_best()]
	_setup_buttons()
	coins_label.text = "+0 монет"
	new_record_label.visible = false
	show()
	modulate.a = 0.0
	Sound.stop_music(1.5)
	var panel := $Center/Panel as Control
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func(): _intro_done = true)
	restart_button.grab_focus()
	await get_tree().create_timer(0.5).timeout
	Sound.play("gameover", -3.0, 1.0, 0.0)
	# Счёт и монеты «набегают» на глазах
	var earned: int = SaveManager.last_coins_earned
	var total: int = SaveManager.coins
	_coins_total = total
	_coins_earned = earned
	var ct := create_tween()
	ct.tween_method(_set_score_text, 0.0, float(score), clampf(score / 400.0, 0.4, 1.4)) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ct.tween_method(_set_coins_text, 0.0, float(earned), clampf(earned / 60.0, 0.3, 1.0))
	await ct.finished
	coins_label.text = "+%d монет   •   всего %d" % [earned, total]
	_show_missions()
	_show_driver_level()
	_show_leaderboard_entry()
	_show_challenge(score)
	_show_party()
	if is_new_record:
		new_record_label.visible = true
		new_record_label.pivot_offset = new_record_label.size / 2.0
		new_record_label.scale = Vector2(2.0, 2.0)
		create_tween().tween_property(new_record_label, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sound.play("record", 0.0, 1.0, 0.0)
		var fx = get_parent().get_node_or_null("HudFX")
		if fx:
			fx.confetti(180)


## Итоги заданий заезда и лучшее комбо
func _show_missions() -> void:
	var vbox := coins_label.get_parent() as VBoxContainer
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	vbox.add_child(box)
	vbox.move_child(box, coins_label.get_index() + 1)
	var lines: Array = []
	if Missions.run_best_combo >= 2:
		lines.append(["Лучшее комбо: ×%d" % Missions.run_best_combo, Art.ORANGE])
	for m in Missions.last_run_summary:
		if m.done:
			lines.append(["✓ %s   +%d" % [m.text, m.reward], Art.GREEN])
		else:
			lines.append(["○ %s   %d/%d" % [m.text, m.progress, m.target], Art.UI_MUTED])
	if Missions.run_rewards > 0:
		lines.append(["Задания принесли +%d монет" % Missions.run_rewards, Art.YELLOW])
	if SaveManager.weekly_mode:
		for i in SaveManager.weekly_last_goals:
			lines.append(["★ Цель недели %d очков выполнена!   +%d" % [GameData.WEEKLY_GOALS[i], GameData.WEEKLY_REWARDS[i]], Art.YELLOW])
		if SaveManager.weekly_unclaimed_reward() > 0:
			lines.append(["Награда ждёт в меню: вкладка «Неделя» → «Забрать +%d»" % SaveManager.weekly_unclaimed_reward(), Art.TEAL])
		else:
			var reached := SaveManager.get_weekly_reached()
			if reached < GameData.WEEKLY_GOALS.size():
				lines.append(["Следующая цель недели: %d очков за заезд" % GameData.WEEKLY_GOALS[reached], Art.UI_MUTED])
	var delay := 0.0
	for ln in lines:
		var l := Label.new()
		l.text = ln[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", ln[1])
		l.modulate.a = 0.0
		box.add_child(l)
		var tw := l.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(l, "modulate:a", 1.0, 0.25)
		delay += 0.12


## Опыт водителя: полоска уровня заполняется, при новом уровне — фанфары и что открылось
func _show_driver_level() -> void:
	var earned := SaveManager.last_xp_earned
	if earned <= 0:
		return
	var vbox := coins_label.get_parent() as VBoxContainer
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var lvl_label := Label.new()
	lvl_label.add_theme_font_override("font", Art.font_title)
	lvl_label.add_theme_font_size_override("font_size", 16)
	lvl_label.add_theme_color_override("font_color", Art.TEAL)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 16)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = Art.TEAL
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	var xp_label := Label.new()
	xp_label.text = "+%d опыта" % earned
	xp_label.add_theme_font_size_override("font_size", 15)
	xp_label.add_theme_color_override("font_color", Art.TEAL)
	row.add_child(lvl_label)
	row.add_child(bar)
	row.add_child(xp_label)
	vbox.add_child(row)
	vbox.move_child(row, coins_label.get_index() + 2)
	var level_up := Label.new()
	level_up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_up.custom_minimum_size.x = 460
	level_up.add_theme_font_size_override("font_size", 15)
	level_up.add_theme_color_override("font_color", Art.YELLOW)
	level_up.hide()
	vbox.add_child(level_up)
	vbox.move_child(level_up, row.get_index() + 1)
	# Анимация: полоска растёт от прежнего опыта к новому, переливаясь через уровни
	var xp_from := SaveManager.xp - earned
	var set_xp := func(v: float):
		var x := int(v)
		var lvl := GameData.level_from_xp(x)
		var pr := GameData.level_progress(x)
		lvl_label.text = "Ур. %d" % lvl
		bar.max_value = pr.y
		bar.value = pr.x
	set_xp.call(float(xp_from))
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_method(set_xp, float(xp_from), float(SaveManager.xp), clampf(earned / 250.0, 0.5, 1.6)) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var now := SaveManager.get_level()
	if now > SaveManager.last_level_before:
		tw.tween_callback(func():
			var opened: Array = []
			for l in range(SaveManager.last_level_before + 1, now + 1):
				opened.append_array(GameData.level_unlocks(l))
			var txt := "НОВЫЙ УРОВЕНЬ %d — «%s»!   +%d монет" % [now, GameData.level_title(now), SaveManager.last_level_coins]
			if not opened.is_empty():
				txt += "\nОткрыто: " + ", ".join(opened)
			level_up.text = txt
			level_up.show()
			level_up.pivot_offset = Vector2(230, 10)
			level_up.scale = Vector2(1.3, 1.3)
			level_up.create_tween().tween_property(level_up, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Sound.play("levelup", -2.0, 1.0, 0.0)
			var fx = get_parent().get_node_or_null("HudFX")
			if fx:
				fx.confetti(90))


## Попали в десятку — предлагаем вписать имя (запись уже сохранена под прошлым именем)
func _show_leaderboard_entry() -> void:
	var id := SaveManager.last_entry_id
	if id == -1:
		return
	var rank_all := SaveManager.get_rank(id)
	var rank_loc := SaveManager.get_rank(id, SaveManager.selected_location)
	if rank_all == 0 and rank_loc == 0:
		return
	var vbox := coins_label.get_parent() as VBoxContainer
	var caption := Label.new()
	if rank_all > 0:
		caption.text = "Место №%d в таблице рекордов!" % rank_all
	else:
		caption.text = "Место №%d в таблице трассы!" % rank_loc
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Art.YELLOW)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var edit := LineEdit.new()
	edit.text = SaveManager.player_name
	edit.max_length = SaveManager.NAME_MAX
	edit.placeholder_text = "Ваше имя"
	edit.custom_minimum_size = Vector2(240, 42)
	edit.select_all_on_focus = true
	var ok := Button.new()
	ok.text = "Сохранить имя"
	ok.custom_minimum_size = Vector2(0, 42)
	row.add_child(edit)
	row.add_child(ok)
	var at := restart_button.get_parent().get_index()
	vbox.add_child(caption)
	vbox.move_child(caption, at)
	vbox.add_child(row)
	vbox.move_child(row, at + 1)
	var save_name := func(_t = ""):
		SaveManager.rename_entry(id, edit.text)
		edit.text = SaveManager.player_name
		ok.text = "Сохранено ✓"
		ok.disabled = true
		restart_button.grab_focus()
	edit.text_submitted.connect(save_name)
	ok.pressed.connect(save_name)
	edit.text_changed.connect(func(_t):
		ok.disabled = false
		ok.text = "Сохранить имя")
	# На ПК сразу ставим курсор в поле имени; на телефоне клавиатура не выскакивает сама
	if not MobileInput.is_touch_device():
		edit.grab_focus()


func _set_score_text(v: float) -> void:
	score_label.text = "Ваш счёт: %d" % int(v)


func _set_coins_text(v: float) -> void:
	coins_label.text = "+%d монет   •   всего %d" % [int(v), _coins_total - _coins_earned + int(v)]
	# «Звон монет» — не на каждую монету, а с небольшим шагом
	var tick := int(v / maxf(_coins_earned / 12.0, 1.0))
	if tick != _last_coin_tick:
		_last_coin_tick = tick
		Sound.play("coin", -12.0, 1.0 + v / maxf(_coins_earned, 1.0) * 0.4, 0.0)


func _process(delta: float) -> void:
	# Панель итогов растёт (задания, цели недели, уровень, таблица рекордов) — ужимаем её под экран
	if visible and _intro_done:
		var panel := $Center/Panel as Control
		var vh := get_viewport_rect().size.y
		var k := minf(1.0, (vh - 16.0) / maxf(panel.size.y, 1.0))
		panel.pivot_offset = panel.size / 2.0
		panel.scale = panel.scale.lerp(Vector2(k, k), clampf(delta * 8.0, 0.0, 1.0))
	if visible and new_record_label.visible:
		_time += delta
		new_record_label.modulate.a = 0.6 + 0.4 * sin(_time * 6.0)


func _on_restart_pressed() -> void:
	# «Кто дальше» закончилась — новая партия с теми же игроками
	if SaveManager.party_finished():
		SaveManager.start_party(SaveManager.party.names)
	# Снимаем игру с паузы перед перезапуском, иначе новый уровень тоже запустится замороженным
	Transition.reload()


func _setup_buttons() -> void:
	if SaveManager.party_mode:
		if SaveManager.party_finished():
			restart_button.text = "Новая партия"
		else:
			restart_button.text = "Едет: %s" % SaveManager.party_current_name()
		menu_button.text = "В меню"


# ---------------------------------------------------------------------------
# Вызов по коду
# ---------------------------------------------------------------------------
func _show_challenge(score: int) -> void:
	if SaveManager.party_mode or SaveManager.tutorial_mode:
		return
	var vbox := coins_label.get_parent() as VBoxContainer
	var at := restart_button.get_parent().get_index()
	if SaveManager.challenge_mode:
		var friend := int(SaveManager.challenge.get("score", 0))
		var won := score > friend
		var res := Label.new()
		res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		res.add_theme_font_override("font", Art.font_title)
		res.add_theme_font_size_override("font_size", 22)
		res.add_theme_color_override("font_color", Art.GREEN if won else Art.RED)
		res.text = ("ВЫЗОВ ПРИНЯТ! Вы: %d  •  друг: %d" if won else "Друг впереди: %d против %d. Ещё разок?") % \
			([score, friend] if won else [friend, score])
		vbox.add_child(res)
		vbox.move_child(res, at)
		at += 1
		if won:
			Achievements.event("challenge_win")
			Sound.play("record", 0.0, 1.1, 0.0)
	var code := SaveManager.last_challenge_code()
	if code == "":
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var cap := Label.new()
	cap.text = "Ответный вызов:" if SaveManager.challenge_mode else "Вызов другу:"
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", Art.UI_MUTED)
	var code_l := Label.new()
	code_l.text = code
	code_l.add_theme_font_override("font", Art.font_title)
	code_l.add_theme_font_size_override("font_size", 20)
	code_l.add_theme_color_override("font_color", Art.TEAL)
	var copy := Button.new()
	copy.text = "Копировать"
	copy.custom_minimum_size = Vector2(0, 38)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(code)
		copy.text = "Скопировано ✓"
		MobileInput.vibrate(20))
	row.add_child(cap)
	row.add_child(code_l)
	row.add_child(copy)
	vbox.add_child(row)
	vbox.move_child(row, at)


# ---------------------------------------------------------------------------
# «Кто дальше»: таблица после каждого заезда, итог после третьего круга
# ---------------------------------------------------------------------------
func _show_party() -> void:
	if not SaveManager.party_mode:
		return
	var vbox := coins_label.get_parent() as VBoxContainer
	var at := restart_button.get_parent().get_index()
	var done := SaveManager.party_finished()
	var head := Label.new()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", Art.font_title)
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", Art.YELLOW if done else Art.TEAL)
	var table := SaveManager.party_table()
	if done:
		head.text = "ПОБЕДИТЕЛЬ: %s — %d очков!" % [table[0].name, table[0].best]
		Achievements.event("party_done")
		var fx = get_parent().get_node_or_null("HudFX")
		if fx:
			fx.confetti(160)
		Sound.play("record", 0.0, 1.0, 0.0)
	else:
		head.text = "Следующий: %s  •  круг %d из %d" % [SaveManager.party_current_name(),
			int(SaveManager.party.round) + 1, SaveManager.PARTY_ROUNDS]
	vbox.add_child(head)
	vbox.move_child(head, at)
	var grid := GridContainer.new()
	grid.columns = 2 + SaveManager.PARTY_ROUNDS
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 2)
	var hdr := ["Игрок", "Лучший"]
	for r in SaveManager.PARTY_ROUNDS:
		hdr.append("Круг %d" % (r + 1))
	for h in hdr:
		grid.add_child(_cell(h, Art.UI_MUTED, 13))
	for i in table.size():
		var row: Dictionary = table[i]
		var col: Color = Art.YELLOW if i == 0 else Art.UI_TEXT
		grid.add_child(_cell(("★ " if done and i == 0 else "%d. " % (i + 1)) + row.name, col, 16))
		grid.add_child(_cell(str(row.best), col, 16, true))
		for r in SaveManager.PARTY_ROUNDS:
			grid.add_child(_cell(str(row.scores[r]) if r < row.scores.size() else "—", Art.UI_MUTED, 14))
	var center := CenterContainer.new()
	center.add_child(grid)
	vbox.add_child(center)
	vbox.move_child(center, at + 1)


func _cell(text: String, color: Color, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", Art.font_title)
	return l


func _on_menu_pressed() -> void:
	Transition.go(MENU_SCENE)
