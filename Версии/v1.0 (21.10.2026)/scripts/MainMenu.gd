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

var _reset_armed: bool = false
var _time: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_setup_settings()
	if MobileInput.is_touch_device():
		controls_label.text = "Управление: кнопки ◀ ▶ и ТОРМОЗ или наклон — в настройках"
	SaveManager.best_score_changed.connect(func(_v): _refresh())
	_refresh()
	start_button.grab_focus()

	# Плавное появление меню
	ui_root.modulate.a = 0.0
	create_tween().tween_property(ui_root, "modulate:a", 1.0, 0.5)


func _process(delta: float) -> void:
	# Лёгкая «пульсация» заголовка
	_time += delta
	var s := 1.0 + sin(_time * 2.5) * 0.03
	title_label.pivot_offset = title_label.size / 2.0
	title_label.scale = Vector2(s, s)


func _refresh() -> void:
	best_value.text = str(SaveManager.best_score)
	if SaveManager.games_played == 0:
		stats_label.text = "Сыграйте первый заезд, чтобы установить рекорд!"
	else:
		stats_label.text = "Последний заезд: %d   •   Заездов: %d   •   В среднем: %d" % [
			SaveManager.last_score, SaveManager.games_played, SaveManager.get_average_score()]


func _on_start_pressed() -> void:
	start_button.disabled = true
	var tw := create_tween()
	tw.tween_property(ui_root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))


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


func _open_settings() -> void:
	var st: Dictionary = SaveManager.settings
	mode_buttons.button_pressed = st.control_mode != "tilt"
	mode_tilt.button_pressed = st.control_mode == "tilt"
	sens_slider.set_value_no_signal(st.tilt_sensitivity)
	sens_caption.text = "Чувствительность наклона: %.1f" % st.tilt_sensitivity
	invert_check.set_pressed_no_signal(st.tilt_invert)
	vibration_check.set_pressed_no_signal(st.vibration)
	tilt_box.visible = st.control_mode == "tilt"
	settings_overlay.show()
	done_button.grab_focus()


func _close_settings() -> void:
	settings_overlay.hide()
	settings_button.grab_focus()


func _set_mode(mode: String) -> void:
	MobileInput.set_mode(mode)
	tilt_box.visible = mode == "tilt"


## Кнопка «Назад» на Android: закрывает настройки, а в меню — выходит из игры
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings_overlay.visible:
			_close_settings()
		else:
			get_tree().quit()
