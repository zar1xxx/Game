extends Node
## Мобильный ввод (Autoload "MobileInput").
## Собирает управление с сенсорных кнопок (TouchControls) и акселерометра
## в два значения, которые читает машина игрока:
##   steer_axis — руль от -1 (влево) до 1 (вправо)
##   brake      — нажат ли тормоз
## Здесь же — вибрация с учётом настроек.

signal mode_changed(mode: String)

const TILT_DEADZONE := 0.6      # м/с² — небольшой наклон игнорируется
const TILT_FULL := 4.2          # м/с² — при таком наклоне руль «до упора»

var steer_axis: float = 0.0
var brake: bool = false

# Значения с сенсорных кнопок (выставляет TouchControls)
var touch_steer: float = 0.0
var touch_brake: bool = false
var horn: bool = false              # кнопка гудка (TouchControls)
## Режим «Свайпы»: на сколько полос перестроиться (копится, пока машина не перестроится)
var swipe_lanes: int = 0

var _tilt_neutral: float = 0.0
var _tilt_value: float = 0.0


## Только для автотестов на ПК: вести себя как телефон (экранные кнопки и т.п.)
var force_touch: bool = false
var test_insets: Vector4 = Vector4.ZERO


## Вырезы экрана (камера, «чёлка», скруглённые углы) в координатах игры:
## x — слева, y — сверху, z — справа, w — снизу. На ПК — нули.
## Интерфейс сдвигается на эти отступы, чтобы ничего не пряталось под камерой.
func safe_insets(vp: Viewport = null) -> Vector4:
	if test_insets != Vector4.ZERO:
		return test_insets
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	if vp == null:
		vp = get_viewport()
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var vs := vp.get_visible_rect().size
	var kx := vs.x / float(win.x)
	var ky := vs.y / float(win.y)
	var ins := Vector4(maxf(0.0, safe.position.x) * kx, maxf(0.0, safe.position.y) * ky,
		maxf(0.0, win.x - safe.end.x) * kx, maxf(0.0, win.y - safe.end.y) * ky)
	# Защита от странных значений на некоторых прошивках
	return ins.clamp(Vector4.ZERO, Vector4(140, 90, 140, 90))


## Это устройство с сенсорным экраном (телефон/планшет)?
func is_touch_device() -> bool:
	return force_touch or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


## Запущено на ОС «Аврора» (порт Godot от сообщества добавляет признак "AuroraOS")
func is_aurora() -> bool:
	return OS.has_feature("AuroraOS") or OS.get_name() == "AuroraOS"


## Есть ли акселерометр. В порте Godot для Авроры датчики пока не подключены,
## поэтому там управление только кнопками.
func has_tilt() -> bool:
	return OS.has_feature("mobile") and not is_aurora()


## Вибрация работает на Android и iOS; на Авроре порт её пока не поддерживает
func has_vibration() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


func get_mode() -> String:
	var m: String = SaveManager.settings.get("control_mode", "buttons")
	if m == "tilt" and not has_tilt() and OS.has_feature("mobile"):
		return "buttons"
	return m


## Зеркальная раскладка для левшей: руль справа, тормоз и гудок слева
func mirrored() -> bool:
	return bool(SaveManager.settings.get("mirror", false))


func set_mode(mode: String) -> void:
	SaveManager.set_setting("control_mode", mode)
	calibrate_tilt()
	mode_changed.emit(mode)


## Запоминает текущий наклон как «прямо» (вызывается при старте заезда)
func calibrate_tilt() -> void:
	_tilt_neutral = _read_tilt_raw()
	_tilt_value = 0.0


func _read_tilt_raw() -> float:
	# В альбомной ориентации Godot поворачивает оси датчика вместе с экраном,
	# поэтому наклон влево/вправо — это ось X
	return Input.get_accelerometer().x


func _process(delta: float) -> void:
	var steer := touch_steer
	if get_mode() == "tilt":
		var raw := _read_tilt_raw() - _tilt_neutral
		if SaveManager.settings.get("tilt_invert", false):
			raw = -raw
		var sens: float = SaveManager.settings.get("tilt_sensitivity", 1.0)
		var v := 0.0
		if absf(raw) > TILT_DEADZONE:
			v = clampf((absf(raw) - TILT_DEADZONE) / (TILT_FULL / sens - TILT_DEADZONE), 0.0, 1.0) * signf(raw)
		# Сглаживание, чтобы машину не дёргало от дрожания рук
		_tilt_value = lerpf(_tilt_value, v, clampf(delta * 12.0, 0.0, 1.0))
		steer = _tilt_value if absf(touch_steer) < 0.01 else touch_steer
	steer_axis = steer
	brake = touch_brake


## Короткая вибрация (если включена в настройках и поддерживается устройством)
func vibrate(ms: int) -> void:
	if SaveManager.settings.get("vibration", true) and has_vibration():
		Input.vibrate_handheld(ms)


## Сбросить состояние (например, при паузе), чтобы руль не «залипал»
func release_all() -> void:
	touch_steer = 0.0
	touch_brake = false
	horn = false
	swipe_lanes = 0
	steer_axis = 0.0
	brake = false
