extends Node2D
## Главное меню: показывает рекорд до начала гонки и запускает игру.

const GAME_SCENE := "res://scenes/node_2d.tscn"

@onready var best_value: Label = %BestValue
@onready var stats_label: Label = %StatsLabel
@onready var start_button: Button = %StartButton
@onready var reset_button: Button = %ResetButton
@onready var quit_button: Button = %QuitButton
@onready var title_label: Label = %TitleLabel
@onready var ui_root: Control = %UIRoot
@onready var settings_button: Button = %SettingsButton
@onready var settings_overlay: Control = %SettingsOverlay
@onready var mode_buttons: Button = %ModeButtons
@onready var mode_tilt: Button = %ModeTilt
@onready var tilt_box: Control = %TiltBox
@onready var sens_caption: Label = %SensCaption
@onready var sens_slider: HSlider = %SensSlider
@onready var invert_check: CheckButton = %InvertCheck
@onready var vibration_check: CheckButton = %VibrationCheck
@onready var done_button: Button = %DoneButton
@onready var controls_label: Label = %Controls
@onready var shop_button: Button = %ShopButton
@onready var shop: Control = %ShopOverlay
@onready var selection_label: Label = %SelectionLabel

var _reset_armed: bool = false
var _time: float = 0.0
var _tip_label: Label
var _tip_index: int = -1
var _controls_text: String = ""
var _missions_card: Control = null

## Подсказки и омские факты внизу экрана меню
const TIPS := [
	"Совет: пролетите вплотную к встречной — «На волоске!» даёт бонусные очки",
	"Омск основан в 1716 году — на 7 лет раньше Екатеринбурга. Омичи об этом напомнят",
	"Совет: красная стрелка сверху — встречная прямо на вашей полосе. Уходите!",
	"В Омске одна станция метро — «Библиотека имени Пушкина». Зато какая!",
	"Совет: нитро пробивает поток, но рулить на скорости сложнее",
	"Омская птица живёт везде, где есть омичи. Берегите лобовое стекло",
	"Совет: на зимней трассе тормозите заранее — лёд не прощает",
	"Омск стоит на Иртыше и Оми. Отсюда и название: Ом-ск",
	"Сантехник Степаныч смотрит из люка на улице Ленина с 2001 года",
	"Совет: скорая помощь чинится сама, а такси приносит больше монет",
	"Если вы видите табличку «Омск 0 км» — поздравляем, вы всё ещё в Омске",
	"Любочка сидит на скамейке на Ленина и ждёт, когда вы побьёте рекорд",
	"Совет: в магазине на вкладке трасс можно послушать музыку каждой трассы",
	"Тарские ворота — остатки Омской крепости. Проезд через них бесплатный",
]


func _enter_tree() -> void:
	# Фон меню показывает выбранную трассу
	Art.theme = GameData.get_location(SaveManager.selected_location).theme
	Art.night = 0.45


func _ready() -> void:
	get_tree().paused = false
	shop_button.pressed.connect(func():
		$UI/UIRoot/Center.hide()
		if _missions_card:
			_missions_card.hide()
		shop.open("car"))
	shop.closed.connect(func():
		$UI/UIRoot/Center.show()
		if _missions_card:
			_missions_card.show()
		_refresh()
		shop_button.grab_focus())
	SaveManager.selection_changed.connect(_on_selection_changed)
	SaveManager.coins_changed.connect(func(_c): _refresh())
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_setup_settings()
	if MobileInput.is_touch_device():
		controls_label.text = "Управление: кнопки ◀ ▶ и ТОРМОЗ" + \
			(" или наклон — в настройках" if MobileInput.has_tilt() else "")
	SaveManager.best_score_changed.connect(func(_v): _refresh())
	_refresh()
	start_button.grab_focus()

	# Плавное появление меню: панель, затем кнопки «выезжают» по очереди
	ui_root.modulate.a = 0.0
	create_tween().tween_property(ui_root, "modulate:a", 1.0, 0.5)
	var delay := 0.15
	for b in [start_button, shop_button, settings_button, reset_button, quit_button]:
		b.modulate.a = 0.0
		var tw: Tween = b.create_tween().set_parallel(true)
		tw.tween_property(b, "modulate:a", 1.0, 0.3).set_delay(delay)
		b.pivot_offset = b.size / 2.0
		b.scale = Vector2(0.8, 0.8)
		tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.07
	Sound.music("menu")
	Sound.set_music_filter(0.0)
	Sound.duck(false)
	_build_tips()
	_build_missions_card()


func _process(delta: float) -> void:
	# Лёгкая «пульсация» заголовка
	_time += delta
	start_button.pivot_offset = start_button.size / 2.0
	if not start_button.has_focus() and not start_button.is_hovered() and start_button.modulate.a >= 1.0:
		var bs := 1.0 + maxf(0.0, sin(_time * 3.0)) * 0.025
		start_button.scale = Vector2(bs, bs)
	var s := 1.0 + sin(_time * 2.5) * 0.03
	title_label.pivot_offset = title_label.size / 2.0
	title_label.scale = Vector2(s, s)


func _refresh() -> void:
	best_value.text = str(SaveManager.get_location_best())
	var loc := GameData.get_location(SaveManager.selected_location)
	var car := GameData.get_car(SaveManager.selected_car)
	selection_label.text = "%s   •   %s   •   %d монет" % [car.name, loc.name, SaveManager.coins]
	if _missions_card:
		_fill_missions_card()
	if SaveManager.games_played == 0:
		stats_label.text = "Сыграйте первый заезд, чтобы установить рекорд!"
	else:
		stats_label.text = "Последний заезд: %d   •   Заездов: %d   •   В среднем: %d" % [
			SaveManager.last_score, SaveManager.games_played, SaveManager.get_average_score()]


func _on_start_pressed() -> void:
	start_button.disabled = true
	Sound.play("horn", -6.0, 1.0, 0.0)
	Transition.go(GAME_SCENE)


func _on_reset_pressed() -> void:
	# Двойное подтверждение, чтобы не сбросить рекорд случайно
	if not _reset_armed:
		_reset_armed = true
		reset_button.text = "Точно сбросить? Нажмите ещё раз"
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(reset_button) and _reset_armed:
			_reset_armed = false
			reset_button.text = "Сбросить рекорд"
		return
	_reset_armed = false
	SaveManager.reset_records()
	reset_button.text = "Рекорд сброшен"
	_refresh()


func _on_quit_pressed() -> void:
	get_tree().quit()


# ---------------------------------------------------------------------------
# Настройки
# ---------------------------------------------------------------------------
func _setup_settings() -> void:
	var group := ButtonGroup.new()
	mode_buttons.button_group = group
	mode_tilt.button_group = group
	settings_button.pressed.connect(_open_settings)
	done_button.pressed.connect(_close_settings)
	mode_buttons.pressed.connect(func(): _set_mode("buttons"))
	mode_tilt.pressed.connect(func(): _set_mode("tilt"))
	sens_slider.value_changed.connect(func(v: float):
		SaveManager.set_setting("tilt_sensitivity", v)
		sens_caption.text = "Чувствительность наклона: %.1f" % v)
	invert_check.toggled.connect(func(on: bool): SaveManager.set_setting("tilt_invert", on))
	vibration_check.toggled.connect(func(on: bool):
		SaveManager.set_setting("vibration", on)
		if on:
			MobileInput.vibrate(60))
	# На устройствах без датчика наклона (ПК, Аврора) выбор управления не нужен,
	# без вибромотора — переключатель вибрации
	var has_tilt := MobileInput.has_tilt()
	mode_buttons.get_parent().visible = has_tilt
	var caption := mode_buttons.get_parent().get_parent().get_node_or_null("ControlCaption")
	if caption:
		caption.visible = has_tilt
	vibration_check.visible = MobileInput.has_vibration()
	_build_volume_sliders()


func _build_volume_sliders() -> void:
	var vbox := done_button.get_parent() as VBoxContainer
	for item in [["Громкость музыки", "music_volume"], ["Громкость звуков", "sfx_volume"]]:
		var cap := Label.new()
		cap.text = item[0]
		vbox.add_child(cap)
		vbox.move_child(cap, done_button.get_index())
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(320, 32)
		sl.value = SaveManager.settings.get(item[1], 0.8)
		var key: String = item[1]
		sl.value_changed.connect(func(v: float):
			SaveManager.settings[key] = v
			Sound.apply_volumes()
			if key == "sfx_volume":
				Sound.play("coin", -6.0))
		sl.drag_ended.connect(func(_c): SaveManager.save_data())
		vbox.add_child(sl)
		vbox.move_child(sl, done_button.get_index())


func _open_settings() -> void:
	var st: Dictionary = SaveManager.settings
	mode_buttons.button_pressed = st.control_mode != "tilt"
	mode_tilt.button_pressed = st.control_mode == "tilt"
	sens_slider.set_value_no_signal(st.tilt_sensitivity)
	sens_caption.text = "Чувствительность наклона: %.1f" % st.tilt_sensitivity
	invert_check.set_pressed_no_signal(st.tilt_invert)
	vibration_check.set_pressed_no_signal(st.vibration)
	tilt_box.visible = st.control_mode == "tilt" and MobileInput.has_tilt()
	settings_overlay.show()
	var panel := done_button.get_parent().get_parent() as Control
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.88, 0.88)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	done_button.grab_focus()


func _close_settings() -> void:
	SaveManager.save_data()
	settings_overlay.hide()
	settings_button.grab_focus()


func _set_mode(mode: String) -> void:
	MobileInput.set_mode(mode)
	tilt_box.visible = mode == "tilt"


## Кнопка «Назад» на Android: закрывает настройки, а в меню — выходит из игры
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if shop.visible:
			shop.close()
		elif settings_overlay.visible:
			_close_settings()
		else:
			get_tree().quit()


func _on_selection_changed() -> void:
	var theme_id: String = GameData.get_location(SaveManager.selected_location).theme
	if theme_id != Art.theme:
		Art.theme = theme_id
		# У пустыни и Омска свои кварталы — пересобираем город на фоне
		$City.rebuild()
	_refresh()


# ---------------------------------------------------------------------------
# Бегущая строка с подсказками и фактами про Омск
# ---------------------------------------------------------------------------
func _build_tips() -> void:
	# Подсказки чередуются с подсказкой по управлению в нижней строке меню
	_tip_label = controls_label
	_controls_text = controls_label.text
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(0, 40)
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_index = randi() % TIPS.size()
	_next_tip()


func _next_tip() -> void:
	if not is_instance_valid(_tip_label):
		return
	_tip_index = (_tip_index + 1) % TIPS.size()
	var tw := _tip_label.create_tween()
	tw.tween_property(_tip_label, "modulate:a", 0.0, 0.3)
	var txt: String = _controls_text if _tip_index % 3 == 0 else TIPS[_tip_index]
	tw.tween_callback(func(): _tip_label.text = txt)
	tw.tween_property(_tip_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(6.0)
	tw.tween_callback(_next_tip)


# ---------------------------------------------------------------------------
# Карточка «Задания на заезд» слева от меню
# ---------------------------------------------------------------------------
func _build_missions_card() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(262, 0)
	panel.position = Vector2(14, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	ui_root.add_child(panel)
	ui_root.move_child(panel, $UI/UIRoot/Center.get_index())
	_missions_card = panel
	_fill_missions_card()
	panel.modulate.a = 0.0
	panel.position.x -= 60.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.4).set_delay(0.35)
	tw.tween_property(panel, "position:x", 14.0, 0.5).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fill_missions_card() -> void:
	var vb := _missions_card.get_node("VB")
	for c in vb.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "ЗАДАНИЯ НА ЗАЕЗД"
	title.add_theme_font_override("font", Art.font_title)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Art.ORANGE)
	vb.add_child(title)
	for i in Missions.SLOTS:
		var m := Missions.get_slot(i)
		if m.is_empty():
			continue
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var l := Label.new()
		l.text = "•  " + Missions.full_text(m)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 232
		l.add_theme_font_size_override("font_size", 15)
		if not Missions.is_available_here(m):
			l.add_theme_color_override("font_color", Art.UI_MUTED)
		row.add_child(l)
		var r := Label.new()
		r.text = "    награда: %d монет" % Missions.reward_of(m)
		r.add_theme_font_size_override("font_size", 13)
		r.add_theme_color_override("font_color", Art.YELLOW)
		row.add_child(r)
		vb.add_child(row)
	var foot := Label.new()
	foot.text = "Все три за один заезд: +%d монет\nВыполнено: %d   •   Лучшее комбо: ×%d" % [
		Missions.HATTRICK_REWARD, SaveManager.missions_done, SaveManager.best_combo]
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size.x = 232
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Art.UI_MUTED)
	vb.add_child(foot)
