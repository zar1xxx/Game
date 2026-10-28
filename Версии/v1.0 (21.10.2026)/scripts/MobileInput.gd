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

var _tilt_neutral: float = 0.0
var _tilt_value: float = 0.0


## Это устройство с сенсорным экраном (телефон/планшет)?
func is_touch_device() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func get_mode() -> String:
	return SaveManager.settings.get("control_mode", "buttons")


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
	if SaveManager.settings.get("vibration", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Сбросить состояние (например, при паузе), чтобы руль не «залипал»
func release_all() -> void:
	touch_steer = 0.0
	touch_brake = false
	steer_axis = 0.0
	brake = false
