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
var _tasks: Control = null             # экран «Задания» (задания на заезд, заезд дня, неделя, награда за вход)
var _tasks_button: Button = null
var _settings_scroll: ScrollContainer = null
var _profile: Control = null
var _settings_cols: Control = null
var _graphics_buttons: Dictionary = {}
var _graphics_hint: Label = null
var _level_card: Control = null
var _level_compact: bool = false       # на узком экране плашка уровня сжимается до значка
var _achievements: Control = null
var _leaderboard: Control = null
var _omsk_map: Control = null
var _garage: Control = null
var _cheat_buffer: String = ""
var _name_edit: LineEdit = null
var _diff_button: Button = null
var _friends: Control = null
var _transfer: Control = null
var _mode_swipe: Button = null
var _mode_drag: Button = null
var _mirror_check: CheckBox = null
var _fps_check: CheckBox = null

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
	"Сантехник Степаныч смотрит из люка на улице Ленина с 1998 года — это первая городская скульптура Омска",
	"Совет: нажмите «Сложность» рядом с «Начать гонку» — на «Спокойно» трафик реже, на «Жёстко» очки ×1,3",
	"Совет: разбились? Один раз за заезд можно продолжить за монеты — «Второй шанс»",
	"Совет: щит спасает от одного удара, мигалка расчищает полосу, «×2» удваивает очки",
	"Колян на девятке гоняется на километр. Не бейтесь — и он останется в зеркале",
	"Совет: голосующий пассажир платит монеты, а такси и маршрутке — вдвое больше",
	"Совет: после заезда игра даёт код вызова. Отправьте его другу — пусть попробует побить",
	"Метромост через Иртыш открыли в 2005 году. Нижний ярус до сих пор ждёт поезда метро",
	"Художник Михаил Врубель родился в Омске в 1856 году",
	"Совет: на телефоне можно рулить ведением пальца, кнопками или свайпами — в настройках",
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
		controls_label.text = "Управление: ведите пальцем влево-вправо, педаль — тормоз. Кнопки, свайпы" + \
			(" и наклон" if MobileInput.has_tilt() else "") + " — в настройках"
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
	_build_level_card()
	_build_button_rows()
	# Плашка уровня стоит по якорям и подстраивается под ширину экрана и вырезы камеры
	get_viewport().size_changed.connect(_layout_level_card)
	_layout_level_card.call_deferred()
	_layout_settings()
	# Контейнер по центру растянут на весь экран — он не должен перехватывать нажатия
	# у карточек по краям (из-за этого не нажимались «Ехать» и «Забрать» справа)
	$UI/UIRoot/Center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI/UIRoot/SettingsOverlay/Center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()        # подписи кнопок (скидка дня, сложность) — после того как ряды собраны


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
	var cap := get_node_or_null("UI/UIRoot/Center/Panel/VBox/RecordPanel/RecordBox/BestCaption") as Label
	if cap:
		var d := SaveManager.difficulty()
		cap.text = "РЕКОРД" if d.id == "normal" else "РЕКОРД • " + str(d.name).to_upper()
	if _diff_button:
		_update_diff_button()
	var deal := SaveManager.daily_deal()
	shop_button.text = "Магазин" if deal.is_empty() else "Магазин  −%d%%" % deal.pct
	var loc := GameData.get_location(SaveManager.selected_location)
	var car := GameData.get_car(SaveManager.selected_car)
	selection_label.text = "%s   •   %s   •   %d монет" % [car.name, loc.name, SaveManager.coins]
	if _tasks_button:
		_update_tasks_button()
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
	# Третий вариант управления — свайпы
	_mode_swipe = Button.new()
	_mode_swipe.text = "Свайпы"
	_mode_swipe.toggle_mode = true
	_mode_swipe.button_group = group
	_mode_swipe.custom_minimum_size = mode_buttons.custom_minimum_size
	_mode_swipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_swipe.pressed.connect(func(): _set_mode("swipe"))
	mode_buttons.get_parent().add_child(_mode_swipe)
	# v2.6: ведение пальцем — первое в ряду и по умолчанию (кнопки тестировщикам не понравились)
	_mode_drag = Button.new()
	_mode_drag.text = "Ведение"
	_mode_drag.toggle_mode = true
	_mode_drag.button_group = group
	_mode_drag.custom_minimum_size = mode_buttons.custom_minimum_size
	_mode_drag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_drag.tooltip_text = "Ведите пальцем влево-вправо в любом месте внизу экрана — машина едет следом"
	_mode_drag.pressed.connect(func(): _set_mode("drag"))
	mode_buttons.get_parent().add_child(_mode_drag)
	mode_buttons.get_parent().move_child(_mode_drag, 0)
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
	var touch := MobileInput.is_touch_device()
	mode_buttons.get_parent().visible = has_tilt or touch
	mode_tilt.visible = has_tilt
	var caption := mode_buttons.get_parent().get_parent().get_node_or_null("ControlCaption")
	if caption:
		caption.visible = has_tilt or touch
	vibration_check.visible = MobileInput.has_vibration()
	# Призрак рекорда — полупрозрачная машина лучшего заезда
	var ghost_check := CheckBox.new()
	ghost_check.text = "Призрак рекорда"
	ghost_check.button_pressed = SaveManager.settings.get("ghost", true)
	ghost_check.toggled.connect(func(on: bool): SaveManager.set_setting("ghost", on))
	vibration_check.get_parent().add_child(ghost_check)
	vibration_check.get_parent().move_child(ghost_check, vibration_check.get_index() + 1)
	# Зеркальная раскладка для левшей
	_mirror_check = CheckBox.new()
	_mirror_check.text = "Зеркальные кнопки (для левшей)"
	_mirror_check.button_pressed = SaveManager.settings.get("mirror", false)
	_mirror_check.toggled.connect(func(on: bool): SaveManager.set_setting("mirror", on))
	_mirror_check.visible = MobileInput.is_touch_device()
	vibration_check.get_parent().add_child(_mirror_check)
	vibration_check.get_parent().move_child(_mirror_check, ghost_check.get_index() + 1)
	# Счётчик кадров в углу экрана во время заезда
	_fps_check = CheckBox.new()
	_fps_check.text = "Счётчик FPS в заезде"
	_fps_check.button_pressed = SaveManager.settings.get("show_fps", false)
	_fps_check.toggled.connect(func(on: bool): SaveManager.set_setting("show_fps", on))
	vibration_check.get_parent().add_child(_fps_check)
	vibration_check.get_parent().move_child(_fps_check, _mirror_check.get_index() + 1)
	_build_volume_sliders()
	_build_name_field()
	# Повторить обучение
	var tut := Button.new()
	tut.text = "Пройти обучение ещё раз"
	tut.pressed.connect(_on_tutorial_pressed)
	var svb := done_button.get_parent() as VBoxContainer
	svb.add_child(tut)
	svb.move_child(tut, done_button.get_index())
	# Перенос прогресса на другой телефон
	var transfer := Button.new()
	transfer.text = "Перенести прогресс (код)"
	transfer.pressed.connect(func():
		if _transfer == null:
			_transfer = preload("res://scripts/ui/TransferDialog.gd").new()
			ui_root.add_child(_transfer)
			_transfer.closed.connect(func():
				settings_overlay.show()
				_refresh()
				transfer.grab_focus())
		settings_overlay.hide()
		_transfer.open())
	svb.add_child(transfer)
	svb.move_child(transfer, done_button.get_index())
	# Отчёт разработчику: копирует версию, телефон, графику и FPS последнего заезда
	var report := Button.new()
	report.text = "Отчёт разработчику"
	report.pressed.connect(func():
		DisplayServer.clipboard_set(SaveManager.dev_report())
		report.text = "Скопировано — вставьте в Telegram ✓"
		MobileInput.vibrate(20)
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(report):
				report.text = "Отчёт разработчику"))
	svb.add_child(report)
	svb.move_child(report, done_button.get_index())
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
	var cm := MobileInput.get_mode()
	mode_buttons.button_pressed = cm == "buttons"
	mode_tilt.button_pressed = cm == "tilt"
	if _mode_swipe:
		_mode_swipe.button_pressed = cm == "swipe"
	if _mode_drag:
		_mode_drag.button_pressed = cm == "drag"
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
		elif _tasks and _tasks.visible:
			_tasks.close()
		elif _friends and _friends.visible:
			_friends.close()
		elif _transfer and _transfer.visible:
			_transfer.close()
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
	var friends_button := Button.new()
	friends_button.text = "С друзьями"
	friends_button.add_theme_font_size_override("font_size", settings_button.get_theme_font_size("font_size"))
	friends_button.custom_minimum_size.y = settings_button.custom_minimum_size.y
	# Задания, заезд дня и неделя — отдельный экран, а не карточки по краям меню
	_tasks_button = Button.new()
	_tasks_button.text = "Задания"
	_tasks_button.add_theme_font_size_override("font_size", shop_button.get_theme_font_size("font_size"))
	_tasks_button.custom_minimum_size.y = shop_button.custom_minimum_size.y
	var rows := [[shop_button, garage_button, ach_button], [_tasks_button, map_button, lb_button], [settings_button, friends_button, quit_button]]
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
	_tasks = preload("res://scripts/ui/TasksScreen.gd").new()
	ui_root.add_child(_tasks)
	_tasks.closed.connect(func():
		$UI/UIRoot/Center.show()
		_side_cards(true)
		_refresh()
		_tasks_button.grab_focus())
	_tasks_button.pressed.connect(func():
		$UI/UIRoot/Center.hide()
		_side_cards(false)
		_tasks.open())
	_tasks.daily_requested.connect(func():
		_tasks.hide()
		_on_daily_pressed())
	_tasks.weekly_requested.connect(func():
		_tasks.hide()
		_on_weekly_pressed())
	_tasks.message.connect(func(msg: String):
		_refresh()
		_flash_message(msg))
	_update_tasks_button()
	_friends = preload("res://scripts/ui/FriendsScreen.gd").new()
	ui_root.add_child(_friends)
	_friends.closed.connect(func():
		$UI/UIRoot/Center.show()
		_side_cards(true)
		friends_button.grab_focus())
	friends_button.pressed.connect(func():
		$UI/UIRoot/Center.hide()
		_side_cards(false)
		_friends.open())
	_friends.start_requested.connect(func():
		start_button.disabled = true
		Sound.play(SaveManager.horn_sound(), -6.0, 1.0, 0.0)
		Transition.go(GAME_SCENE))
	_build_difficulty_button()


## Сложность — рядом с «Начать гонку»: нажатие переключает Спокойно → Нормально → Жёстко
func _build_difficulty_button() -> void:
	var vbox := start_button.get_parent() as VBoxContainer
	var at := start_button.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	vbox.move_child(row, at)
	vbox.remove_child(start_button)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.custom_minimum_size.x = 0          # ширину панели задают ряды кнопок ниже
	row.add_child(start_button)
	_diff_button = Button.new()
	_diff_button.custom_minimum_size = Vector2(150, start_button.custom_minimum_size.y)
	_diff_button.add_theme_font_size_override("font_size", 15)
	_diff_button.tooltip_text = "Сложность: от неё зависят плотность трафика и рост скорости. У каждой свои рекорды."
	_diff_button.pressed.connect(_cycle_difficulty)
	row.add_child(_diff_button)
	_update_diff_button()


func _cycle_difficulty() -> void:
	var ids := ["easy", "normal", "hard"]
	var i := ids.find(str(SaveManager.settings.get("difficulty", "normal")))
	SaveManager.set_setting("difficulty", ids[(i + 1) % ids.size()])
	Sound.play("coin", -8.0, 1.2, 0.0)
	var d := SaveManager.difficulty()
	_flash_message("Сложность: %s" % d.name)
	if _tip_label:
		_tip_label.text = d.desc
	_refresh()


func _update_diff_button() -> void:
	var d := GameData.get_difficulty(str(SaveManager.settings.get("difficulty", "normal")))
	_diff_button.text = "Сложность\n%s" % d.name
	_diff_button.add_theme_color_override("font_color", Color(d.color))
	_diff_button.add_theme_color_override("font_hover_color", Color(d.color).lightened(0.2))
	_diff_button.add_theme_color_override("font_focus_color", Color(d.color))


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
	if _level_card:
		_level_card.visible = on


# ---------------------------------------------------------------------------
# Экран «Задания» и заезд дня / испытание недели
# ---------------------------------------------------------------------------
func _update_tasks_button() -> void:
	var star: bool = preload("res://scripts/ui/TasksScreen.gd").has_reward()
	_tasks_button.text = "Задания ★" if star else "Задания"
	if star:
		_tasks_button.add_theme_color_override("font_color", Art.YELLOW)
		_tasks_button.add_theme_color_override("font_focus_color", Art.YELLOW)
	else:
		_tasks_button.remove_theme_color_override("font_color")
		_tasks_button.remove_theme_color_override("font_focus_color")


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
	# Якорь — левый верхний угол; отступы пересчитывает _layout_level_card()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
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


## Ставит плашку уровня в левый верхний угол с учётом выреза камеры. Если слева от меню
## не хватает места (16:9, планшеты), плашка сжимается до значка уровня и не наезжает на меню.
## Вызывается при каждом изменении размера окна — раньше позиция считалась один раз.
func _layout_level_card() -> void:
	if _level_card == null:
		return
	var ins := MobileInput.safe_insets(get_viewport())
	var vw := get_viewport().get_visible_rect().size.x
	var menu_w := ($UI/UIRoot/Center/Panel as Control).get_combined_minimum_size().x
	var room := (vw - menu_w) / 2.0 - ins.x - 14.0 - 10.0
	# Полная ширина плашки: строка опыта (232) + поля панели из темы
	var full_w := maxf(262.0, 232.0 + _level_card.get_theme_stylebox("panel").get_minimum_size().x)
	var compact := room < full_w
	if compact != _level_compact:
		_level_compact = compact
		_fill_level_card()
	_level_card.custom_minimum_size.x = 0.0 if compact else 262.0
	_level_card.position = Vector2(14.0 + ins.x, 14.0)
	_level_card.reset_size()


func _fill_level_card() -> void:
	var vb := _level_card.get_node("VB")
	for c in vb.get_children():
		# Убираем сразу, а не в конце кадра — иначе reset_size() считает по старому содержимому
		vb.remove_child(c)
		c.queue_free()
	var lvl := SaveManager.get_level()
	_level_card.tooltip_text = ""
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
	if _level_compact:
		_level_card.tooltip_text = "Уровень %d — %s. Нажмите, чтобы открыть профиль." % [lvl, GameData.level_title(lvl)]
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", -2)
	head.add_child(names)
	var t := _card_label("Уровень %d  •  всего опыта %d" % [lvl, SaveManager.xp], 13, Art.UI_MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.custom_minimum_size.x = 0
	# Длинные подписи обрезаются многоточием — иначе плашка росла вширь и наезжала на меню
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(t)
	var title := _card_label(GameData.level_title(lvl), 18, Art.UI_TEXT, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.x = 0
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	more.size_flags_horizontal = Control.SIZE_SHRINK_END
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
