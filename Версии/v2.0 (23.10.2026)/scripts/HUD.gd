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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	player = get_tree().get_first_node_in_group("player")

	best_label.text = "Рекорд: %d" % SaveManager.get_location_best()
	pause_menu.hide()
	center_label.hide()

	resume_button.pressed.connect(_toggle_pause)
	pause_button.pressed.connect(func():
		if not _counting_down and not (player and player.is_dead):
			_toggle_pause())
	if MobileInput.is_touch_device():
		if MobileInput.get_mode() == "tilt":
			hint_label.text = "Наклоняйте телефон, чтобы рулить   •   Касание справа — тормоз"
		else:
			hint_label.text = "◀ ▶ — руль   •   ТОРМОЗ — справа"
		hint_label.position.y -= 150.0   # над сенсорными кнопками
	pause_restart_button.pressed.connect(_on_restart_pressed)
	pause_menu_button.pressed.connect(_on_menu_pressed)

	_style_bars()
	_build_fx()
	_build_pause_audio()
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
	toast("%s   •   очки ×%s" % [loc.name, str(snappedf(mult, 0.01)).replace(".", ",")], Art.UI_TEXT, 3.5)

	var counter = get_tree().get_first_node_in_group("score_counter")
	if counter:
		counter.new_record_reached.connect(_on_new_record)

	if countdown_enabled:
		_start_countdown()


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
			var tw := create_tween()
			tw.tween_interval(3.5)
			tw.tween_property(hint_label, "modulate:a", 0.0, 1.0)
		await get_tree().create_timer(0.7).timeout
	center_label.hide()


func _on_new_record(_score: int) -> void:
	_pop_center("НОВЫЙ РЕКОРД!", Art.ORANGE)
	Sound.play("record", 0.0, 1.0, 0.0)
	if fx:
		fx.confetti(140)
	best_label.modulate = Art.YELLOW
	await get_tree().create_timer(1.5).timeout
	center_label.hide()


func _physics_process(_delta: float) -> void:
	# Если текущий счёт выше рекорда — показываем его как рекорд в реальном времени
	var counter = get_tree().get_first_node_in_group("score_counter")
	if counter and counter.max_score > SaveManager.get_location_best():
		best_label.text = "Рекорд: %d" % counter.max_score
	# Каждые 100 очков счёт «подпрыгивает»
	if counter and counter.max_score / 100 > _last_hundred:
		_last_hundred = counter.max_score / 100
		_bump_score(Art.YELLOW)
		Sound.play("coin", -10.0, 1.0 + minf(_last_hundred * 0.02, 0.5), 0.0)


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
func toast(text: String, color: Color = Art.UI_TEXT, duration: float = 2.5) -> void:
	if text == "":
		return
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)
