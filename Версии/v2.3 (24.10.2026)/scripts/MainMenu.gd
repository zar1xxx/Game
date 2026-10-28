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
var _daily_card: Control = null
var _settings_scroll: ScrollContainer = null
var _profile: Control = null
var _settings_cols: Control = null
var _graphics_buttons: Dictionary = {}
var _graphics_hint: Label = null
var _daily_tab: String = "day"          # вкладка правой карточки: "day" — заезд дня, "week" — испытание недели
var _level_card: Control = null
var _achievements: Control = null
var _leaderboard: Control = null
var _omsk_map: Control = null
var _garage: Control = null
var _cheat_buffer: String = ""
var _name_edit: LineEdit = null

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
	"Совет: на АЗС «Канистра» уйдите в правую полосу и затормозите в зоне — бак зальют на ходу",
	"Совет: у знака «60» сбросьте скорость до камеры — иначе штраф монетами",
	"Совет: колонну фур не обогнать. Уходите с её полос заранее",
	"Разводной мост через Иртыш перепрыгивают только на нитро. Остальных вылавливают",
	"Совет: в гараже прокачайте «Магнит» — бонусы сами полетят к машине",
	"Совет: тюнинг тормозов помогает вовремя оттормозиться у камер и на АЗС",
	"Омск не отпускает: каждые несколько км — снова табличка «ОМСК». Сколько кругов продержитесь?",
	"В селе Кукуево коровы переходят дорогу. Сигнальте — не поможет, но приятно",
	"Совет: монстр-трак давит конусы и ямы, а трактору ямы вообще нипочём",
	"На горном серпантине камни скатываются со скал слева — следите за склоном",
	"В гараже можно поставить свой номер. Регион, конечно, 55",
	"Совет: заезд дня — одна трасса для всех и очки ×1,25. А за вход каждый день — монеты",
	"Полупрозрачная машина «РЕКОРД» — это ваш лучший заезд. Обгоните себя!",
	"Совет: испытание недели — особое правило и три цели с наградой. Цели обновляются в понедельник",
	"Опыт копится за каждый заезд. С уровнем открываются гудки, дым из выхлопа и наклейки",
	"Совет: гудок — клавиша H или пробел, на телефоне — кнопка БИП над тормозом",
	"Забыли, что к чему? Обучение можно пройти ещё раз в настройках",
]


func _enter_tree() -> void:
	# Вернулись из заезда дня — возвращаем выбранную игроком трассу
	SaveManager.end_daily()
	# Фон меню показывает выбранную трассу
	Art.theme = GameData.get_location(SaveManager.selected_location).theme
	Art.night = 0.45


func _ready() -> void:
	get_tree().paused = false
	shop_button.pressed.connect(func():
		$UI/UIRoot/Center.hide()
		_side_cards(false)
		shop.open("car"))
	shop.closed.connect(func():
		$UI/UIRoot/Center.show()
		_side_cards(true)
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
	# Есть невыданная награда недели — сразу открываем вкладку «Неделя»
	if SaveManager.weekly_unclaimed_reward() > 0:
		_daily_tab = "week"
	_build_daily_card()
	_build_level_card()
	_build_button_rows()
	_layout_settings()
	# Контейнер по центру растянут на весь экран — он не должен перехватывать нажатия
	# у карточек по краям (из-за этого не нажимались «Ехать» и «Забрать» справа)
	$UI/UIRoot/Center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI/UIRoot/SettingsOverlay/Center.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	if _daily_card:
		_fill_daily_card()
	if _level_card:
		_fill_level_card()
	if SaveManager.games_played == 0:
		stats_label.text = "Сыграйте первый заезд, чтобы установить рекорд!"
	else:
		stats_label.text = "Последний заезд: %d   •   Заездов: %d   •   В среднем: %d" % [
			SaveManager.last_score, SaveManager.games_played, SaveManager.get_average_score()]


func _on_start_pressed() -> void:
	start_button.disabled = true
	# Самый первый заезд — с обучением
	if not SaveManager.tutorial_done:
		SaveManager.start_tutorial()
	Sound.play(SaveManager.horn_sound(), -6.0, 1.0, 0.0)
	Transition.go(GAME_SCENE)


func _on_tutorial_pressed() -> void:
	settings_overlay.hide()
	start_button.disabled = true
	SaveManager.start_tutorial()
	Sound.play(SaveManager.horn_sound(), -6.0, 1.0, 0.0)
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
	# Призрак рекорда — полупрозрачная машина лучшего заезда
	var ghost_check := CheckBox.new()
	ghost_check.text = "Призрак рекорда"
	ghost_check.button_pressed = SaveManager.settings.get("ghost", true)
	ghost_check.toggled.connect(func(on: bool): SaveManager.set_setting("ghost", on))
	vibration_check.get_parent().add_child(ghost_check)
	vibration_check.get_parent().move_child(ghost_check, vibration_check.get_index() + 1)
	_build_volume_sliders()
	_build_name_field()
	# Повторить обучение
	var tut := Button.new()
	tut.text = "Пройти обучение ещё раз"
	tut.pressed.connect(_on_tutorial_pressed)
	var svb := done_button.get_parent() as VBoxContainer
	svb.add_child(tut)
	svb.move_child(tut, done_button.get_index())
	# Номер версии — чтобы на телефоне было видно, какая сборка установлена
	var ver := Label.new()
	ver.text = "Версия %s" % ProjectSettings.get_setting("application/config/version", "")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Art.UI_MUTED)
	svb.add_child(ver)


## Настройки в две колонки и с прокруткой пальцем: на телефоне в одну колонку
## всё не помещалось по высоте, а листать вниз было нельзя
func _layout_settings() -> void:
	var svb := done_button.get_parent() as VBoxContainer
	svb.add_theme_constant_override("separation", 10)
	svb.custom_minimum_size.x = 0
	var title := svb.get_node("Title") as Label
	title.add_theme_font_size_override("font_size", 32)
	var version: Control = null
	var items: Array = []
	for c in svb.get_children():
		if c == title or c == done_button:
			continue
		if c is Label and (c as Label).text.begins_with("Версия"):
			version = c
			continue
		items.append(c)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for col in [left, right]:
		col.add_theme_constant_override("separation", 10)
		col.custom_minimum_size.x = 380
		cols.add_child(col)
	# Слева — управление и картинка, справа — звук, коды и сброс
	var to_right := false
	for c in items:
		if c is Label and (c as Label).text == "Громкость музыки":
			to_right = true
		svb.remove_child(c)
		(right if to_right else left).add_child(c)
	_build_graphics_setting(left)
	if version:
		svb.remove_child(version)
		right.add_child(version)
	_settings_scroll = ScrollContainer.new()
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_settings_scroll.follow_focus = true
	_settings_scroll.add_child(cols)
	svb.add_child(_settings_scroll)
	svb.move_child(_settings_scroll, title.get_index() + 1)
	preload("res://scripts/ui/TouchScroll.gd").attach(_settings_scroll)
	_settings_cols = cols


## Высота области прокрутки: сколько влезает на экран, но не больше содержимого
func _fit_settings_scroll() -> void:
	if _settings_scroll == null:
		return
	var vh := get_viewport().get_visible_rect().size.y
	var need := _settings_cols.get_combined_minimum_size().y
	# 52 — поля панели, 40 — заголовок, 54 — «Готово», 20 — промежутки, 24 — отступ от краёв экрана
	var room := vh - 52.0 - 40.0 - 54.0 - 20.0 - 24.0
	_settings_scroll.custom_minimum_size = Vector2(_settings_cols.get_combined_minimum_size().x + 14.0, minf(need, room))


## Качество графики: «Авто» сама упрощает картинку, если телефон не успевает
func _build_graphics_setting(box: VBoxContainer) -> void:
	var cap := Label.new()
	cap.text = "Графика"
	box.add_child(cap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var group := ButtonGroup.new()
	for item in [["auto", "Авто"], ["high", "Красиво"], ["eco", "Плавно"]]:
		var b := Button.new()
		b.text = item[1]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		var id: String = item[0]
		b.pressed.connect(func():
			SaveManager.set_setting("graphics", id)
			if id == "auto":
				# Заново даём «Авто» шанс на полную графику
				SaveManager.set_setting("auto_quality", 2)
			SaveManager.apply_graphics()
			_update_graphics_hint())
		row.add_child(b)
		_graphics_buttons[id] = b
	_graphics_hint = Label.new()
	_graphics_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_graphics_hint.custom_minimum_size.x = 360
	_graphics_hint.add_theme_font_size_override("font_size", 12)
	_graphics_hint.add_theme_color_override("font_color", Art.UI_MUTED)
	box.add_child(_graphics_hint)
	_update_graphics_hint()


func _update_graphics_hint() -> void:
	var mode: String = SaveManager.settings.get("graphics", "auto")
	if _graphics_buttons.has(mode):
		_graphics_buttons[mode].set_pressed_no_signal(true)
	var q := SaveManager.graphics_quality()
	var now: String = ["экономная", "облегчённая", "полная"][q]
	match mode:
		"auto":
			_graphics_hint.text = "Игра сама упростит картинку, если телефон не успевает. Сейчас: %s." % now
		"high":
			_graphics_hint.text = "Все эффекты и анимации. На слабых телефонах может притормаживать."
		_:
			_graphics_hint.text = "Меньше эффектов и ниже разрешение — зато плавно даже на слабых телефонах."


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
	if _name_edit:
		_name_edit.text = SaveManager.player_name
	invert_check.set_pressed_no_signal(st.tilt_invert)
	vibration_check.set_pressed_no_signal(st.vibration)
	tilt_box.visible = st.control_mode == "tilt" and MobileInput.has_tilt()
	if _graphics_hint:
		_update_graphics_hint()
	_fit_settings_scroll()
	_fit_settings_scroll.call_deferred()
	if _settings_scroll:
		_settings_scroll.scroll_vertical = 0
	settings_overlay.show()
	var panel := done_button.get_parent().get_parent() as Control
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.88, 0.88)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	done_button.grab_focus()


func _close_settings() -> void:
	if _name_edit:
		var n := _name_edit.text.strip_edges().left(SaveManager.NAME_MAX)
		SaveManager.player_name = n if n != "" else "Игрок"
	SaveManager.save_data()
	settings_overlay.hide()
	settings_button.grab_focus()


func _set_mode(mode: String) -> void:
	MobileInput.set_mode(mode)
	tilt_box.visible = mode == "tilt"
	_fit_settings_scroll.call_deferred()


## Кнопка «Назад» на Android: закрывает настройки, а в меню — выходит из игры
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _garage and _garage.visible:
			_garage.close()
		elif _profile and _profile.visible:
			_profile.close()
		elif _omsk_map and _omsk_map.visible:
			_omsk_map.close()
		elif _leaderboard and _leaderboard.visible:
			_leaderboard.close()
		elif _achievements and _achievements.visible:
			_achievements.close()
		elif shop.visible:
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
	panel.position = Vector2(14 + MobileInput.safe_insets(get_viewport()).x, 160)
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
	tw.tween_property(panel, "position:x", 14.0 + MobileInput.safe_insets(get_viewport()).x, 0.5).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


# ---------------------------------------------------------------------------
# Кнопки по две в ряд + таблица рекордов
# ---------------------------------------------------------------------------
func _build_button_rows() -> void:
	var vbox := start_button.get_parent() as VBoxContainer
	var lb_button := Button.new()
	lb_button.text = "Таблица рекордов"
	lb_button.add_theme_font_size_override("font_size", settings_button.get_theme_font_size("font_size"))
	lb_button.custom_minimum_size.y = settings_button.custom_minimum_size.y
	var map_button := Button.new()
	map_button.text = "Карта Омска"
	map_button.add_theme_font_size_override("font_size", shop_button.get_theme_font_size("font_size"))
	map_button.custom_minimum_size.y = shop_button.custom_minimum_size.y
	shop_button.text = "Магазин"
	var garage_button := Button.new()
	garage_button.text = "Гараж"
	garage_button.add_theme_font_size_override("font_size", shop_button.get_theme_font_size("font_size"))
	garage_button.custom_minimum_size.y = shop_button.custom_minimum_size.y
	# «Сбросить рекорд» переезжает в настройки, чтобы меню не вытягивалось
	var settings_vbox := done_button.get_parent() as VBoxContainer
	reset_button.get_parent().remove_child(reset_button)
	settings_vbox.add_child(reset_button)
	settings_vbox.move_child(reset_button, done_button.get_index())
	var ach_button := Button.new()
	ach_button.text = "Достижения"
	ach_button.add_theme_font_size_override("font_size", shop_button.get_theme_font_size("font_size"))
	ach_button.custom_minimum_size.y = shop_button.custom_minimum_size.y
	var rows := [[shop_button, garage_button, ach_button], [map_button, lb_button], [settings_button, quit_button]]
	var at: int = start_button.get_index() + 1
	for pair in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		vbox.move_child(row, at)
		at += 1
		for b in pair:
			var btn := b as Button
			if btn.get_parent():
				btn.get_parent().remove_child(btn)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size.x = 0
			row.add_child(btn)
	_leaderboard = preload("res://scripts/ui/Leaderboard.gd").new()
	ui_root.add_child(_leaderboard)
	_leaderboard.closed.connect(func():
		$UI/UIRoot/Center.show()
		_side_cards(true)
		lb_button.grab_focus())
	lb_button.pressed.connect(func():
		$UI/UIRoot/Center.hide()
		_side_cards(false)
		_leaderboard.open())
	_garage = preload("res://scripts/ui/Garage.gd").new()
	ui_root.add_child(_garage)
	_garage.closed.connect(func():
		$UI/UIRoot/Center.show()
		_side_cards(true)
		_refresh()
		garage_button.grab_focus())
	garage_button.pressed.connect(func():
		$UI/UIRoot/Center.hide()
		_side_cards(false)
		_garage.open())
	_achievements = preload("res://scripts/ui/AchievementsScreen.gd").new()
	ui_root.add_child(_achievements)
	_achievements.closed.connect(func():
		$UI/UIRoot/Center.show()
		_side_cards(true)
		_refresh()
		ach_button.grab_focus())
	ach_button.pressed.connect(func():
		$UI/UIRoot/Center.hide()
		_side_cards(false)
		_achievements.open())
	_omsk_map = preload("res://scripts/ui/OmskMap.gd").new()
	ui_root.add_child(_omsk_map)
	_omsk_map.closed.connect(func():
		$UI/UIRoot/Center.show()
		_side_cards(true)
		map_button.grab_focus())
	map_button.pressed.connect(func():
		$UI/UIRoot/Center.hide()
		_side_cards(false)
		_omsk_map.open())
	_omsk_map.drive_requested.connect(func():
		_omsk_map.hide()
		SaveManager.select("location", "omsk")
		_on_start_pressed())


## Имя игрока для таблицы рекордов — в настройках
func _build_name_field() -> void:
	var vbox := done_button.get_parent() as VBoxContainer
	var cap := Label.new()
	cap.text = "Имя для таблицы рекордов"
	vbox.add_child(cap)
	vbox.move_child(cap, 1)
	_name_edit = LineEdit.new()
	_name_edit.max_length = SaveManager.NAME_MAX
	_name_edit.placeholder_text = "Игрок"
	_name_edit.custom_minimum_size = Vector2(320, 40)
	_name_edit.text = SaveManager.player_name
	vbox.add_child(_name_edit)
	vbox.move_child(_name_edit, 2)
	# Промокод / чит-код
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var code := LineEdit.new()
	code.placeholder_text = "Промокод"
	code.custom_minimum_size = Vector2(200, 40)
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apply := Button.new()
	apply.text = "Ввести"
	var try_code := func(_t = ""):
		if _apply_cheat(code.text):
			code.text = ""
		else:
			code.text = ""
			code.placeholder_text = "Неверный код"
	code.text_submitted.connect(try_code)
	apply.pressed.connect(try_code)
	row.add_child(code)
	row.add_child(apply)
	vbox.add_child(row)
	vbox.move_child(row, done_button.get_index())



# ---------------------------------------------------------------------------
# Чит-коды: можно набрать прямо в меню на клавиатуре или ввести в настройках
# ---------------------------------------------------------------------------
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.unicode == 0:
		return
	_cheat_buffer = (_cheat_buffer + String.chr(k.unicode)).to_lower().right(16)
	if _cheat_buffer.ends_with("контракт"):
		_cheat_buffer = ""
		_apply_cheat("контракт")


func _apply_cheat(code: String) -> bool:
	var msg := SaveManager.apply_cheat(code)
	if msg == "":
		return false
	Sound.play("buy", 0.0, 1.0, 0.0)
	Sound.play("record", -4.0, 1.0, 0.0)
	_refresh()
	var l := Label.new()
	l.text = msg
	l.add_theme_font_override("font", Art.font_title)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Art.YELLOW)
	l.add_theme_color_override("font_outline_color", Art.INK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 20
	l.offset_bottom = 70
	var tw := l.create_tween()
	tw.tween_property(l, "offset_top", 50.0, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	return true


func _side_cards(on: bool) -> void:
	if _missions_card:
		_missions_card.visible = on
	if _daily_card:
		_daily_card.visible = on
	if _level_card:
		_level_card.visible = on


# ---------------------------------------------------------------------------
# Заезд дня и награда за вход — карточка справа
# ---------------------------------------------------------------------------
func _build_daily_card() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230, 0)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	var ins_r := MobileInput.safe_insets(get_viewport()).z
	panel.offset_left = -244 - ins_r
	panel.offset_right = -14 - ins_r
	panel.offset_top = 14
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	ui_root.add_child(panel)
	ui_root.move_child(panel, $UI/UIRoot/Center.get_index())
	_daily_card = panel
	_fill_daily_card()
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.4).set_delay(0.45)


func _card_label(text: String, size_px: int, color: Color, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", Art.font_title)
	return l


func _fill_daily_card() -> void:
	var vb := _daily_card.get_node("VB")
	for c in vb.get_children():
		c.queue_free()
	# Вкладки «День» / «Неделя»
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vb.add_child(tabs)
	for item in [["day", "День"], ["week", "Неделя"]]:
		var tb := Button.new()
		tb.text = item[1]
		if item[0] == "week" and SaveManager.weekly_unclaimed_reward() > 0:
			tb.text = "Неделя ★"
			tb.add_theme_color_override("font_color", Art.YELLOW)
		tb.toggle_mode = true
		tb.button_pressed = _daily_tab == item[0]
		tb.custom_minimum_size = Vector2(0, 34)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 15)
		var id: String = item[0]
		tb.pressed.connect(func():
			_daily_tab = id
			Sound.play("click", -8.0)
			_fill_daily_card.call_deferred())
		tabs.add_child(tb)
	if _daily_tab == "week":
		_fill_weekly(vb)
	else:
		_fill_daily(vb)
	var sep := HSeparator.new()
	vb.add_child(sep)
	vb.add_child(_card_label("НАГРАДА ЗА ВХОД", 16, Art.ORANGE, true))
	var claim := Button.new()
	claim.custom_minimum_size = Vector2(0, 42)
	claim.add_theme_font_size_override("font_size", 16)
	if SaveManager.login_reward_available():
		var streak := (SaveManager.login_streak + 1) if SaveManager.login_day == SaveManager.today() - 1 else 1
		vb.add_child(_card_label("День %d подряд" % streak, 13, Art.UI_TEXT))
		claim.text = "Забрать +%d" % SaveManager.login_reward_amount()
		claim.pressed.connect(_on_claim_pressed)
	else:
		vb.add_child(_card_label("День %d подряд. Завтра: +%d" % [SaveManager.login_streak,
			SaveManager.login_reward_amount(SaveManager.login_streak + 1)], 13, Art.UI_MUTED))
		claim.text = "Получено ✓"
		claim.disabled = true
	vb.add_child(claim)


func _fill_daily(vb: VBoxContainer) -> void:
	var loc := GameData.get_location(SaveManager.daily_location_id())
	var d := Time.get_date_dict_from_system()
	vb.add_child(_card_label("ЗАЕЗД ДНЯ", 20, Art.ORANGE, true))
	vb.add_child(_card_label("%02d.%02d  •  одна трасса для всех" % [d.day, d.month], 12, Art.UI_MUTED))
	vb.add_child(_card_label(loc.name, 17, Art.UI_TEXT, true))
	var bonus := ("%.2f" % SaveManager.DAILY_BONUS).replace(".", ",").trim_suffix("0")
	vb.add_child(_card_label("Очки ×%s  •  рекорд дня: %d" % [bonus, SaveManager.get_daily_best()], 13, Art.YELLOW))
	if not SaveManager.is_owned("location", loc.id):
		vb.add_child(_card_label("Трасса не куплена — сегодня можно попробовать бесплатно!", 12, Art.TEAL))
	var go := Button.new()
	go.text = "Ехать"
	go.custom_minimum_size = Vector2(0, 42)
	go.add_theme_font_size_override("font_size", 18)
	go.pressed.connect(_on_daily_pressed)
	vb.add_child(go)


## Испытание недели: правило, трасса, рекорд недели и три цели
func _fill_weekly(vb: VBoxContainer) -> void:
	var rule := SaveManager.weekly_rule()
	var loc := GameData.get_location(SaveManager.weekly_location_id())
	vb.add_child(_card_label("ИСПЫТАНИЕ НЕДЕЛИ", 18, Art.ORANGE, true))
	vb.add_child(_card_label("%s  •  %s" % [SaveManager.week_dates_text(), loc.name], 12, Art.UI_MUTED))
	vb.add_child(_card_label("«%s»" % rule.name, 17, Art.UI_TEXT, true))
	vb.add_child(_card_label(rule.desc, 12, Art.TEAL))
	var mult := ("%.2f" % rule.score).replace(".", ",").trim_suffix("0")
	vb.add_child(_card_label("Очки ×%s  •  рекорд недели: %d" % [mult, SaveManager.get_weekly_best()], 13, Art.YELLOW))
	var claimed := SaveManager.get_weekly_claimed()
	var reached := SaveManager.get_weekly_reached()
	vb.add_child(_card_label("Цели за один заезд в испытании:", 12, Art.UI_MUTED))
	var goals := ""
	for i in GameData.WEEKLY_GOALS.size():
		var mark := "✓" if i < claimed else ("★" if i < reached else "○")
		goals += "%s %d очков — +%d\n" % [mark, GameData.WEEKLY_GOALS[i], GameData.WEEKLY_REWARDS[i]]
	var gl := _card_label(goals.strip_edges(), 13, Art.UI_TEXT)
	vb.add_child(gl)
	var unclaimed := SaveManager.weekly_unclaimed_reward()
	if unclaimed > 0:
		var take := Button.new()
		take.text = "Забрать +%d" % unclaimed
		take.custom_minimum_size = Vector2(0, 42)
		take.add_theme_font_size_override("font_size", 17)
		take.add_theme_color_override("font_color", Art.YELLOW)
		take.pressed.connect(_on_weekly_claim)
		vb.add_child(take)
	var go := Button.new()
	go.text = "Принять вызов"
	go.custom_minimum_size = Vector2(0, 42)
	go.add_theme_font_size_override("font_size", 17)
	go.pressed.connect(_on_weekly_pressed)
	vb.add_child(go)


func _on_weekly_claim() -> void:
	var amount := SaveManager.claim_weekly()
	if amount <= 0:
		return
	Sound.play("buy", 0.0, 1.0, 0.0)
	Sound.play("record", -4.0, 1.1, 0.0)
	_refresh()
	_flash_message("Награда недели: +%d монет!" % amount)


func _on_weekly_pressed() -> void:
	start_button.disabled = true
	SaveManager.start_weekly()
	Sound.play(SaveManager.horn_sound(), -6.0, 1.1, 0.0)
	Transition.go(GAME_SCENE)


# ---------------------------------------------------------------------------
# Уровень водителя — плашка слева вверху
# ---------------------------------------------------------------------------
func _build_level_card() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(262, 0)
	panel.position = Vector2(14 + MobileInput.safe_insets(get_viewport()).x, 14)
	# Плашка уровня нажимается — открывает профиль водителя
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_open_profile())
	panel.mouse_entered.connect(func(): panel.modulate = Color(1.12, 1.12, 1.12))
	panel.mouse_exited.connect(func(): panel.modulate = Color.WHITE)
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)
	ui_root.add_child(panel)
	ui_root.move_child(panel, $UI/UIRoot/Center.get_index())
	_level_card = panel
	_fill_level_card()
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.4).set_delay(0.3)


func _fill_level_card() -> void:
	var vb := _level_card.get_node("VB")
	for c in vb.get_children():
		c.queue_free()
	var lvl := SaveManager.get_level()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(40, 40)
	badge.draw.connect(func():
		badge.draw_circle(Vector2(20, 20), 19, Art.YELLOW)
		badge.draw_circle(Vector2(20, 20), 15, Art.ORANGE)
		Art.text_center(badge, Vector2(20, 20), str(lvl), 17, Art.INK, true))
	head.add_child(badge)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	head.add_child(names)
	var t := _card_label("Уровень %d  •  всего опыта %d" % [lvl, SaveManager.xp], 13, Art.UI_MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.custom_minimum_size.x = 0
	names.add_child(t)
	var title := _card_label(GameData.level_title(lvl), 18, Art.UI_TEXT, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.x = 0
	names.add_child(title)
	var pr := GameData.level_progress(SaveManager.xp)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.max_value = pr.y
	bar.value = pr.x if lvl < GameData.MAX_LEVEL else pr.y
	var fill := StyleBoxFlat.new()
	fill.bg_color = Art.TEAL
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(bar)
	var info := ""
	if lvl >= GameData.MAX_LEVEL:
		info = "Максимальный уровень. Легенда!"
	else:
		info = "Опыт: %d / %d" % [pr.x, pr.y]
		var nxt := GameData.next_unlock_level(lvl)
		if nxt > 0:
			info += "  •  на ур. %d: %s" % [nxt, GameData.level_unlocks(nxt)[0]]
	var il := _card_label(info, 11, Art.UI_MUTED)
	il.custom_minimum_size.x = 232
	vb.add_child(il)
	# Стрелка «›» в шапке подсказывает, что плашка открывает профиль
	var more := Label.new()
	more.text = "›"
	more.add_theme_font_override("font", Art.font_title)
	more.add_theme_font_size_override("font_size", 30)
	more.add_theme_color_override("font_color", Art.TEAL)
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(more)
	for c in vb.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_profile() -> void:
	if _profile == null:
		_profile = preload("res://scripts/ui/ProfileScreen.gd").new()
		ui_root.add_child(_profile)
		_profile.closed.connect(func():
			$UI/UIRoot/Center.show()
			_side_cards(true)
			start_button.grab_focus())
		_profile.garage_requested.connect(func():
			_garage.open())
	Sound.play("click", -6.0)
	$UI/UIRoot/Center.hide()
	_side_cards(false)
	_profile.open()


func _on_daily_pressed() -> void:
	start_button.disabled = true
	SaveManager.start_daily()
	Sound.play("horn", -6.0, 1.1, 0.0)
	Transition.go(GAME_SCENE)


func _on_claim_pressed() -> void:
	var amount := SaveManager.claim_login_reward()
	if amount <= 0:
		return
	Sound.play("buy", 0.0, 1.0, 0.0)
	Sound.play("coin", -2.0, 1.2, 0.0)
	_refresh()
	_flash_message("Награда за вход: +%d монет!" % amount)


func _flash_message(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.add_theme_font_override("font", Art.font_title)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Art.YELLOW)
	l.add_theme_color_override("font_outline_color", Art.INK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 20
	l.offset_bottom = 70
	var tw := l.create_tween()
	tw.tween_property(l, "offset_top", 50.0, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
