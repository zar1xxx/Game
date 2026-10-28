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
	_show_leaderboard_entry()
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
	if visible and new_record_label.visible:
		_time += delta
		new_record_label.modulate.a = 0.6 + 0.4 * sin(_time * 6.0)


func _on_restart_pressed() -> void:
	# Снимаем игру с паузы перед перезапуском, иначе новый уровень тоже запустится замороженным
	Transition.reload()


func _on_menu_pressed() -> void:
	Transition.go(MENU_SCENE)
