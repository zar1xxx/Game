extends Node
## Следит за плавностью во время заезда.
## Если в режиме графики «Авто» телефон стабильно не успевает (меньше ~45 кадров в секунду
## два замера подряд), графика упрощается на одну ступень: сначала облегчённая,
## потом экономная (ниже разрешение, меньше эффектов). Выбор запоминается.

const WINDOW := 2.0          # длина одного замера, с
const LOW_FPS := 45.0
const WARMUP := 2            # первые замеры пропускаем: идёт загрузка и обратный отсчёт

var _t0: int = 0
var _frames: int = 0
var _bad: int = 0
var _skip: int = WARMUP


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_t0 = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if SaveManager.settings.get("graphics", "auto") != "auto":
		return
	_frames += 1
	var now := Time.get_ticks_usec()
	var el := (now - _t0) / 1000000.0
	if el < WINDOW:
		return
	var fps := _frames / el
	_frames = 0
	_t0 = now
	if _skip > 0:
		_skip -= 1
		return
	if fps < LOW_FPS:
		_bad += 1
	else:
		_bad = 0
	if _bad < 2:
		return
	_bad = 0
	var q := int(SaveManager.settings.get("auto_quality", 2))
	if q <= 0:
		return
	SaveManager.settings["auto_quality"] = q - 1
	SaveManager.save_data()
	SaveManager.apply_graphics()
	# После смены качества даём игре пару секунд, прежде чем мерить снова
	_skip = 1
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast("Графика упрощена, чтобы игра шла плавнее" if q == 2 else
			"Включён экономный режим графики — так плавнее", Art.TEAL, 2.5)


## Пауза и сворачивание сбивают замер — начинаем заново
func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_frames = 0
		_t0 = Time.get_ticks_usec()
