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
@onready var pause_menu: Control = %PauseMenu
@onready var resume_button: Button = %ResumeButton
@onready var pause_restart_button: Button = %PauseRestartButton
@onready var pause_menu_button: Button = %PauseMenuButton

var player = null  # Машина игрока (moveCharacter.gd)
var _counting_down: bool = false
var _blink_time: float = 0.0
var _health_fill: StyleBoxFlat
var _fuel_fill: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_tree().get_first_node_in_group("player")

	best_label.text = "Рекорд: %d" % SaveManager.best_score
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

	var counter = get_tree().get_first_node_in_group("score_counter")
	if counter:
		counter.new_record_reached.connect(_on_new_record)

	if countdown_enabled:
		_start_countdown()


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
	if paused:
		resume_button.grab_focus()


func _on_restart_pressed() -> void:
	# Прерванный заезд тоже засчитывается в статистику и может стать рекордом
	if player and player.has_node("scoreComponent"):
		SaveManager.finish_run(player.get_node("scoreComponent").max_score)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	if player and player.has_node("scoreComponent"):
		SaveManager.finish_run(player.get_node("scoreComponent").max_score)
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Отсчёт 3-2-1 перед стартом ---
func _start_countdown() -> void:
	_counting_down = true
	get_tree().paused = true
	for text in ["3", "2", "1", "ВПЕРЁД!"]:
		_pop_center(text, Art.YELLOW if text != "ВПЕРЁД!" else Art.GREEN)
		if text == "ВПЕРЁД!":
			get_tree().paused = false
			_counting_down = false
			MobileInput.calibrate_tilt()
			var tw := create_tween()
			tw.tween_interval(3.5)
			tw.tween_property(hint_label, "modulate:a", 0.0, 1.0)
		await get_tree().create_timer(0.7).timeout
	center_label.hide()


func _on_new_record(_score: int) -> void:
	_pop_center("НОВЫЙ РЕКОРД!", Art.ORANGE)
	best_label.modulate = Art.YELLOW
	await get_tree().create_timer(1.5).timeout
	center_label.hide()


func _physics_process(_delta: float) -> void:
	# Если текущий счёт выше рекорда — показываем его как рекорд в реальном времени
	var counter = get_tree().get_first_node_in_group("score_counter")
	if counter and counter.max_score > SaveManager.best_score:
		best_label.text = "Рекорд: %d" % counter.max_score


func _pop_center(text: String, color: Color) -> void:
	center_label.text = text
	center_label.modulate = color
	center_label.show()
	center_label.pivot_offset = center_label.size / 2.0
	center_label.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(center_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
