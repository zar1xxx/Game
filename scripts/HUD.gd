extends CanvasLayer
## Интерфейс во время гонки: рекорд, скорость, полоски прочности и топлива,
## отсчёт перед стартом, пауза и всплывающие сообщения.

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const KMH := 0.16   # перевод игровой скорости в «км/ч» для спидометра

@export var countdown_enabled: bool = true

@onready var best_label: Label = %BestLabel
@onready var speed_label: Label = %SpeedLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var fuel_bar: ProgressBar = %FuelBar
@onready var center_label: Label = %CenterLabel
@onready var hint_label: Label = %HintLabel
@onready var pause_button: Button = %PauseButton
@onready var toast_label: Label = %ToastLabel
var _toast_tween: Tween
@onready var pause_menu: Control = %PauseMenu
@onready var resume_button: Button = %ResumeButton
@onready var pause_restart_button: Button = %PauseRestartButton
@onready var pause_menu_button: Button = %PauseMenuButton

var player = null  # Машина игрока (moveCharacter.gd)
var _counting_down: bool = false
var _blink_time: float = 0.0
var _health_fill: StyleBoxFlat
var _fuel_fill: StyleBoxFlat
var fx: Control = null              # HudFX: линии скорости, виньетка, светофор, конфетти
var _speedo: Control = null
var _score_label: Label = null
var _last_hundred: int = 0
var _music_track: String = ""
var _was_night: bool = false
var _second_chance: Control = null
var _power_bar: Control = null
var _perf: Node = null
var _fps_label: Label = null
var _fps_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	player = get_tree().get_first_node_in_group("player")

	best_label.text = _goal_text(_goal_value())
	pause_menu.hide()
	# В «Кто дальше» перезапуск из паузы — это переигровка, её нет: только «В меню»
	if SaveManager.party_mode:
		pause_restart_button.hide()
	center_label.hide()

	resume_button.pressed.connect(_toggle_pause)
	pause_button.pressed.connect(func():
		if not _counting_down and not (player and player.is_dead):
			_toggle_pause())
	if MobileInput.is_touch_device():
		var side := "слева" if MobileInput.mirrored() else "справа"
		match MobileInput.get_mode():
			"tilt":
				hint_label.text = "Наклоняйте телефон, чтобы рулить   •   Касание %s — тормоз" % side
			"swipe":
				hint_label.text = "Свайп влево-вправо — сменить полосу   •   Держи палец — тормоз"
			"drag":
				hint_label.text = "Ведите пальцем влево-вправо — машина едет следом   •   ТОРМОЗ — %s" % side
			_:
				hint_label.text = "◀ ▶ — руль   •   ТОРМОЗ — %s" % side
		hint_label.position.y -= 150.0   # над сенсорными кнопками
	pause_restart_button.pressed.connect(_on_restart_pressed)
	pause_menu_button.pressed.connect(_on_menu_pressed)

	_style_bars()
	_build_fx()
	_build_pause_audio()
	# Автоматическое упрощение графики на слабых телефонах (режим «Авто») и статистика кадров
	_perf = preload("res://scripts/PerfGuard.gd").new()
	add_child(_perf)
	_build_power_bar()
	if SaveManager.settings.get("show_fps", false):
		_fps_label = Label.new()
		_fps_label.add_theme_font_size_override("font_size", 13)
		_fps_label.add_theme_color_override("font_color", Art.UI_TEXT)
		_fps_label.add_theme_color_override("font_outline_color", Art.INK)
		_fps_label.add_theme_constant_override("outline_size", 5)
		_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_fps_label.offset_top = -22
		_fps_label.offset_bottom = -4
		_fps_label.offset_left = -60
		_fps_label.offset_right = 60
		_fps_label.add_to_group("hide_on_game_over")
		add_child(_fps_label)
	toast_label.modulate.a = 0.0
	var world_fx = get_node_or_null("../WorldFX")
	if world_fx:
		world_fx.phase_changed.connect(func(ph: String):
			var msg := {"День": "Наступает день", "Закат": "Солнце садится…",
				"Ночь": "Ночь! Смотрите в свете фар", "Рассвет": "Рассвет"}
			toast(msg.get(ph, ph), Art.YELLOW))
		world_fx.event_message.connect(func(text: String): toast(text, Art.ORANGE))
	var loc := GameData.get_location(SaveManager.selected_location)
	_music_track = loc.get("music", loc.theme)
	Sound.music(_music_track)
	Sound.set_music_filter(0.0)
	if player:
		player.near_miss.connect(_on_near_miss)
		player.combo_banked.connect(_on_combo_banked)
		player.combo_lost.connect(_on_combo_lost)
	Missions.mission_completed.connect(_on_mission_completed)
	var mult: float = loc.score * GameData.get_car(SaveManager.selected_car).score
	var sc = get_tree().get_first_node_in_group("score_counter")
	if sc:
		mult = sc.score_multiplier
	var diff := SaveManager.difficulty()
	var diff_text := "" if diff.id == "normal" else "   •   " + str(diff.name)
	toast("%s%s   •   очки ×%s" % [loc.name, diff_text, str(snappedf(mult, 0.01)).replace(".", ",")], Art.UI_TEXT, 3.5)

	var counter = get_tree().get_first_node_in_group("score_counter")
	if counter:
		counter.new_record_reached.connect(_on_new_record)

	if SaveManager.weekly_mode:
		_build_weekly_badge()
	if countdown_enabled:
		_start_countdown()


## Плашка испытания недели справа (правило видно весь заезд)
func _build_weekly_badge() -> void:
	var rule := SaveManager.weekly_rule()
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mult := ("%.2f" % rule.score).replace(".", ",").trim_suffix("0")
	badge.draw.connect(func():
		var vs := badge.get_viewport_rect().size
		var r := Rect2(vs.x - 214 - MobileInput.safe_insets(get_viewport()).z, right_slot_y("weekly"), 200, 50)
		Art.rrect(badge, r, Color(Art.UI_PANEL, 0.88), 10, 2, Color(Art.ORANGE, 0.8))
		Art.text_center(badge, r.position + Vector2(100, 15), "НЕДЕЛЯ  •  очки ×" + mult, 12, Art.ORANGE, true)
		Art.text_center(badge, r.position + Vector2(100, 34), "«%s»" % rule.name, 14, Art.UI_TEXT, true))
	add_child(badge)
	move_child(badge, 0)


## Спидометр со стрелкой и слой экранных эффектов
func _build_fx() -> void:
	fx = preload("res://scripts/ui/HudFX.gd").new()
	fx.name = "HudFX"
	fx.omsk = GameData.get_location(SaveManager.selected_location).theme == "omsk"
	add_child(fx)
	move_child(fx, $LaneWarning.get_index())
	var speed_panel := speed_label.get_parent().get_parent() as Control
	speed_panel.hide()
	_speedo = preload("res://scripts/ui/Speedometer.gd").new()
	_speedo.position = Vector2(14, 112)
	_speedo.size = Vector2(172, 104)
	add_child(_speedo)
	move_child(_speedo, speed_panel.get_index())
	_score_label = %ScoreLabel
	# Задания на заезд — под спидометром
	var missions_panel := preload("res://scripts/ui/MissionPanel.gd").new()
	missions_panel.name = "MissionPanel"
	missions_panel.position = Vector2(14, 224)
	add_child(missions_panel)
	move_child(missions_panel, _speedo.get_index() + 1)
	# Отступы от выреза под камеру на телефонах
	var ins := MobileInput.safe_insets(get_viewport())
	for n in [$ScorePanel, _speedo, missions_panel]:
		(n as Control).position.x += ins.x
	for n in [$StatusPanel, pause_button]:
		(n as Control).position.x -= ins.z
	# Плавное появление панелей при старте
	for n in [$ScorePanel, $StatusPanel, _speedo, missions_panel]:
		var c := n as Control
		var target_y := c.position.y
		c.position.y -= 140.0
		c.modulate.a = 0.0
		var tw := c.create_tween().set_parallel(true)
		tw.tween_property(c, "position:y", target_y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
		tw.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(0.15)


## Ползунки громкости в меню паузы
func _build_pause_audio() -> void:
	var vbox := %ResumeButton.get_parent() as VBoxContainer
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	for item in [["Музыка", "music_volume"], ["Звуки", "sfx_volume"]]:
		var cap := Label.new()
		cap.text = item[0]
		cap.add_theme_color_override("font_color", Art.UI_MUTED)
		grid.add_child(cap)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(200, 32)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.value = SaveManager.settings.get(item[1], 0.8)
		var key: String = item[1]
		sl.value_changed.connect(func(v: float):
			SaveManager.settings[key] = v
			Sound.apply_volumes()
			if key == "sfx_volume":
				Sound.play("click", -4.0))
		sl.drag_ended.connect(func(_c): SaveManager.save_data())
		grid.add_child(sl)
	vbox.add_child(grid)
	vbox.move_child(grid, 1)


func _style_bars() -> void:
	# Цвета заливки берутся из общей палитры Art.gd
	_health_fill = StyleBoxFlat.new()
	_health_fill.bg_color = Art.GREEN
	_health_fill.set_corner_radius_all(6)
	health_bar.add_theme_stylebox_override("fill", _health_fill)
	_fuel_fill = StyleBoxFlat.new()
	_fuel_fill.bg_color = Art.ORANGE
	# Троллейбус едет от проводов: вместо бензина — ток
	if GameData.get_car(SaveManager.selected_car).get("electric", false):
		_fuel_fill.bg_color = Art.TEAL
		var cap := fuel_bar.get_parent().get_node_or_null("FuelCaption") as Label
		if cap:
			cap.text = "ТОК ОТ ПРОВОДОВ"
	_fuel_fill.set_corner_radius_all(6)
	fuel_bar.add_theme_stylebox_override("fill", _fuel_fill)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Музыка «зависит от событий»: ночью звучит мягче, при нитро громче, после аварии приглушается
	if not get_tree().paused:
		var night := Art.night > 0.6
		Sound.set_music_filter(0.35 if night else 0.0)
		Sound.duck(player.current_health < player.max_health * 0.25)

	# Скорость в «км/ч» (1 км/ч = 10 единиц скорости движка)
	speed_label.text = str(int(player.current_speed * KMH))
	if player.nitro_time_left > 0.0:
		speed_label.modulate = Art.TEAL
	elif player.is_braking:
		speed_label.modulate = Art.RED
	else:
		speed_label.modulate = Color.WHITE

	# Цвет прочности: зелёный -> жёлтый -> красный
	var hp_ratio: float = health_bar.value / max(health_bar.max_value, 1.0)
	_health_fill.bg_color = Art.RED.lerp(Art.GREEN, hp_ratio)

	# Мигание полоски топлива, когда его меньше 25%
	var fuel_ratio: float = fuel_bar.value / max(fuel_bar.max_value, 1.0)
	if fuel_ratio < 0.25 and not player.is_dead:
		_blink_time += delta
		fuel_bar.modulate = Color(1.6, 0.6, 0.6) if int(_blink_time * 4.0) % 2 == 0 else Color.WHITE
	else:
		fuel_bar.modulate = Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _counting_down or (player and player.is_dead):
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()


## Кнопка «Назад» на Android и сворачивание приложения
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _second_chance and _second_chance.is_offering():
			_second_chance.decline()
			return
		if player and player.is_dead:
			_on_menu_pressed()
		elif not _counting_down:
			_toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		# Свернули игру — ставим на паузу, чтобы не разбиться «вслепую»
		if not _counting_down and player and not player.is_dead and not get_tree().paused:
			_toggle_pause()


func _toggle_pause() -> void:
	MobileInput.release_all()
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_menu.visible = paused
	Sound.set_music_filter(1.0 if paused else 0.0)
	if paused:
		resume_button.grab_focus()
		var panel := resume_button.get_parent().get_parent() as Control
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2(0.85, 0.85)
		panel.modulate.a = 0.0
		var tw := panel.create_tween().set_parallel(true)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, 0.15)


func _on_restart_pressed() -> void:
	# Прерванный заезд тоже засчитывается в статистику и может стать рекордом
	if player and player.has_node("scoreComponent"):
		SaveManager.finish_run(player.get_node("scoreComponent").max_score)
	Transition.reload()


func _on_menu_pressed() -> void:
	if player and player.has_node("scoreComponent"):
		SaveManager.finish_run(player.get_node("scoreComponent").max_score)
	Transition.go(MENU_SCENE)


# --- Отсчёт 3-2-1 перед стартом ---
func _start_countdown() -> void:
	_counting_down = true
	get_tree().paused = true
	await get_tree().create_timer(0.35).timeout
	var step := 0
	for text in ["3", "2", "1", "ВПЕРЁД!"]:
		_pop_center(text, [Art.RED, Art.YELLOW, Art.YELLOW, Art.GREEN][step])
		if fx:
			fx.light_state = [0, 1, 1, 2][step]
		Sound.play("go" if text == "ВПЕРЁД!" else "beep", -2.0, 1.0, 0.0)
		step += 1
		if text == "ВПЕРЁД!":
			if fx:
				get_tree().create_timer(0.6).timeout.connect(func(): fx.light_state = -1)
			get_tree().paused = false
			_counting_down = false
			MobileInput.calibrate_tilt()
			if SaveManager.daily_mode:
				toast("Заезд дня: %s • очки ×1,25 • рекорд дня %d" % [
					GameData.get_location(SaveManager.selected_location).name, SaveManager.get_daily_best()], Art.ORANGE, 3.0)
			elif SaveManager.weekly_mode:
				var rule := SaveManager.weekly_rule()
				toast("Испытание недели: «%s»\n%s" % [rule.name, rule.desc], Art.ORANGE, 4.5)
			elif SaveManager.challenge_mode:
				toast("Вызов: друг проехал %d очков. Обгони!" % int(SaveManager.challenge.get("score", 0)), Art.TEAL, 3.5)
			elif SaveManager.party_mode:
				toast("%s, твой заезд!  Круг %d из %d" % [SaveManager.party_current_name(),
					int(SaveManager.party.round) + 1, SaveManager.PARTY_ROUNDS], Art.TEAL, 3.5)
			var tw := create_tween()
			tw.tween_interval(3.5)
			tw.tween_property(hint_label, "modulate:a", 0.0, 1.0)
		await get_tree().create_timer(0.7).timeout
	center_label.hide()


func _on_new_record(_score: int) -> void:
	_pop_center("ДРУГ ПОЗАДИ!" if SaveManager.challenge_mode else ("ТЫ ЛИДЕР!" if SaveManager.party_mode else "НОВЫЙ РЕКОРД!"), Art.ORANGE)
	Sound.play("record", 0.0, 1.0, 0.0)
	if fx:
		fx.confetti(140)
	best_label.modulate = Art.YELLOW
	await get_tree().create_timer(1.5).timeout
	center_label.hide()


func _physics_process(delta: float) -> void:
	_process_power_bar()
	if _fps_label:
		_fps_t -= delta
		if _fps_t <= 0.0:
			_fps_t = 0.5
			var f := Engine.get_frames_per_second()
			_fps_label.text = "%d FPS" % f
			_fps_label.add_theme_color_override("font_color", Art.GREEN if f >= 55 else (Art.YELLOW if f >= 40 else Art.RED))
	# Если текущий счёт выше рекорда — показываем его как рекорд в реальном времени
	var counter = get_tree().get_first_node_in_group("score_counter")
	if counter and not SaveManager.challenge_mode and not SaveManager.party_mode and counter.max_score > _goal_value():
		best_label.text = _goal_text(counter.max_score)
	# Каждые 100 очков счёт «подпрыгивает»
	if counter and counter.max_score / 100 > _last_hundred:
		_last_hundred = counter.max_score / 100
		_bump_score(Art.YELLOW)
		Sound.play("coin", -10.0, 1.0 + minf(_last_hundred * 0.02, 0.5), 0.0)


## Что показано под счётом: рекорд трассы, результат друга (вызов) или лидера партии
func _goal_value() -> int:
	var counter = get_tree().get_first_node_in_group("score_counter")
	if counter and (SaveManager.challenge_mode or SaveManager.party_mode):
		return counter._record_to_beat
	return SaveManager.get_location_best()


func _goal_text(v: int) -> String:
	if SaveManager.challenge_mode:
		return "Друг: %d" % v
	if SaveManager.party_mode:
		return "Лидер: %d" % v
	return "Рекорд: %d" % v


func _bump_score(color: Color) -> void:
	_score_label.pivot_offset = _score_label.size / 2.0
	_score_label.scale = Vector2(1.35, 1.35)
	_score_label.modulate = color
	var tw := _score_label.create_tween().set_parallel(true)
	tw.tween_property(_score_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_label, "modulate", Color.WHITE, 0.5)


func _on_near_miss(points: int, combo: int, close: bool) -> void:
	if fx == null or player == null:
		return
	var sp: Vector2 = player.get_global_transform_with_canvas().origin
	var word := "ВПРИТИРКУ!" if close else "НА ВОЛОСКЕ!"
	fx.popup("%s +%d" % [word, points], sp + Vector2(0, -90), Art.YELLOW if close else Art.TEAL)


func _on_combo_banked(combo: int, points: int) -> void:
	if points <= 0:
		return
	if combo >= 2 and fx:
		fx.popup("КОМБО ×%d  +%d" % [combo, points], Vector2(get_viewport().get_visible_rect().size.x / 2.0, 190), Art.ORANGE, 32)
	_bump_score(Art.ORANGE)


func _on_combo_lost(combo: int, points: int) -> void:
	if fx and points > 0:
		fx.popup("Комбо ×%d сорвано: −%d" % [combo, points], Vector2(get_viewport().get_visible_rect().size.x / 2.0, 190), Art.RED, 24)


func _on_mission_completed(slot: int, text: String, reward: int) -> void:
	if fx:
		fx.banner("ЗАДАНИЕ ВЫПОЛНЕНО" if slot >= 0 else "ВСЕ ЗАДАНИЯ ЗАЕЗДА!", text, reward)
	Sound.play("buy", -2.0, 1.0, 0.0)
	MobileInput.vibrate(40)


func _pop_center(text: String, color: Color) -> void:
	center_label.text = text
	center_label.modulate = color
	center_label.show()
	center_label.pivot_offset = center_label.size / 2.0
	center_label.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(center_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Короткое сообщение сверху по центру (смена времени суток, буря и т.п.)
## Правая колонка под полосками прочности: призрак рекорда (176), испытание недели,
## круг Омска и под ними — сообщения. Всё это стоит над кварталами, а не над дорогой:
## верх дороги должен оставаться свободным, чтобы видеть встречные машины.
func right_slot_y(id: String) -> float:
	var y := 176.0
	for it in [["ghost", 46.0], ["weekly", 58.0], ["omsk", 54.0], ["rival", 54.0], ["powerups", 50.0]]:
		if it[0] == id:
			return y
		if _right_slot_used(it[0]):
			y += it[1]
	return y


func _right_slot_used(id: String) -> bool:
	match id:
		"ghost":
			var g = get_tree().get_first_node_in_group("ghost")
			return g != null and g.has_ghost()
		"weekly":
			return SaveManager.weekly_mode
		"omsk":
			return get_tree().get_first_node_in_group("omsk_loop") != null
		"rival":
			var r = get_tree().get_first_node_in_group("rival")
			return r != null and r.is_racing()
		"powerups":
			return player != null and (player.shield or player.siren_left > 0.0 or player.double_points_left > 0.0)
	return false


# ---------------------------------------------------------------------------
# Второй шанс
# ---------------------------------------------------------------------------
func offer_second_chance(price: int, reason: String, cb: Callable) -> void:
	if _second_chance == null:
		_second_chance = preload("res://scripts/ui/SecondChance.gd").new()
		add_child(_second_chance)
	pause_menu.hide()
	_second_chance.offer(price, reason, cb)


# ---------------------------------------------------------------------------
# Активные бонусы: значки справа с кольцом оставшегося времени
# ---------------------------------------------------------------------------
const PowerUp := preload("res://scripts/obstacles/PowerUp.gd")


func _build_power_bar() -> void:
	_power_bar = Control.new()
	_power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_power_bar.draw.connect(_draw_power_bar)
	_power_bar.add_to_group("hide_on_game_over")
	add_child(_power_bar)
	move_child(_power_bar, 0)
	if player:
		player.powerup_changed.connect(func(): _place_toast())


func _draw_rival_pill() -> void:
	var r = get_tree().get_first_node_in_group("rival")
	if r == null or not r.is_racing() or player == null or player.is_dead:
		return
	var info: Array = r.hud_text()
	var vs := _power_bar.get_viewport_rect().size
	var right := vs.x - 14.0 - MobileInput.safe_insets(get_viewport()).z
	var rect := Rect2(right - 200.0, right_slot_y("rival"), 200.0, 48.0)
	var col: Color = info[2]
	Art.rrect(_power_bar, rect, Color(Art.UI_PANEL, 0.88), 10, 2, Color(col, 0.85))
	Art.text_center(_power_bar, rect.position + Vector2(100, 15), info[0], 12, Color("ff6b8a"), true)
	Art.text_center(_power_bar, rect.position + Vector2(100, 34), info[1], 14, col, true)


func _process_power_bar() -> void:
	var r = get_tree().get_first_node_in_group("rival")
	if _power_bar and r and r.is_racing():
		_power_bar.queue_redraw()
		return
	if _power_bar and player and (player.shield or player.siren_left > 0.0 or player.double_points_left > 0.0 \
			or _power_bar.get_meta("shown", false)):
		_power_bar.set_meta("shown", player.shield or player.siren_left > 0.0 or player.double_points_left > 0.0)
		_power_bar.queue_redraw()


func _draw_power_bar() -> void:
	_draw_rival_pill()
	if player == null or player.is_dead:
		return
	var items: Array = []
	if player.shield:
		items.append(["shield", 1.0, "щит"])
	if player.siren_left > 0.0:
		items.append(["siren", player.siren_left / 5.0, "%d с" % ceili(player.siren_left)])
	if player.double_points_left > 0.0:
		items.append(["double", player.double_points_left / 8.0, "%d с" % ceili(player.double_points_left)])
	if items.is_empty():
		return
	var vs := _power_bar.get_viewport_rect().size
	var right := vs.x - 14.0 - MobileInput.safe_insets(get_viewport()).z
	var y := right_slot_y("powerups")
	var w := 214.0
	var r := Rect2(right - w, y, w, 44)
	Art.rrect(_power_bar, r, Color(Art.UI_PANEL, 0.85), 10, 2, Color(Art.UI_PANEL_LIGHT, 0.9))
	var step := w / items.size()
	for i in items.size():
		var it: Array = items[i]
		var c := Vector2(r.position.x + step * i + 26.0, y + 22.0)
		var col: Color = PowerUp.KINDS[it[0]].color
		_power_bar.draw_circle(c, 18, Color(Art.INK, 0.6))
		_power_bar.draw_arc(c, 18, -PI / 2.0, -PI / 2.0 + TAU * clampf(it[1], 0.0, 1.0), 32, col, 3.5, true)
		PowerUp.draw_icon(_power_bar, it[0], c, 0.62, Time.get_ticks_msec() / 1000.0)
		_power_bar.draw_string(Art.font_bold, Vector2(c.x + 21.0, c.y + 5.0), it[2], HORIZONTAL_ALIGNMENT_LEFT, step - 46.0, 12, Art.UI_TEXT)


## Сообщения — справа, над кварталом, с переносом строк (раньше висели по центру над дорогой)
func _place_toast() -> void:
	var vs := get_viewport().get_visible_rect().size
	var right := vs.x - 14.0 - MobileInput.safe_insets(get_viewport()).z
	# Ширина — сколько есть места над правым кварталом (на узком экране ~200, на широком до 320)
	var w := clampf(right - (vs.x / 2.0 + (Art.ROAD_RIGHT - Art.VIEW_W / 2.0) + 20.0), 200.0, 320.0)
	toast_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 18 if w >= 250.0 else 16)
	toast_label.position = Vector2(right - w, right_slot_y("toast") + 6.0)
	toast_label.size = Vector2(w, 0)


func toast(text: String, color: Color = Art.UI_TEXT, duration: float = 2.5) -> void:
	if text == "":
		return
	toast_label.text = text
	_place_toast()
	toast_label.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)
