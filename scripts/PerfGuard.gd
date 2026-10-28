extends Node
## Следит за плавностью во время заезда.
## Если в режиме графики «Авто» телефон стабильно не успевает (меньше ~45 кадров в секунду
## два замера подряд), графика упрощается на одну ступень: сначала облегчённая,
## потом экономная (ниже разрешение, меньше эффектов). Выбор запоминается.
## Заодно собирает статистику кадров за заезд — для кнопки «Отчёт разработчику».

const WINDOW := 2.0          # длина одного замера, с
const LOW_FPS := 45.0
const WARMUP := 2            # первые замеры пропускаем: идёт загрузка и обратный отсчёт

var _t0: int = 0
var _frames: int = 0
var _bad: int = 0
var _skip: int = WARMUP
# Статистика заезда
var _total_frames: int = 0
var _total_time: float = 0.0
var _windows: int = 0
var _low_windows: int = 0
var _worst: float = 999.0
var _downgrades: int = 0
var _start_quality: int = 2
var fps_now: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_t0 = Time.get_ticks_usec()
	_start_quality = Art.quality


func _process(_delta: float) -> void:
	_frames += 1
	var now := Time.get_ticks_usec()
	var el := (now - _t0) / 1000000.0
	if el < WINDOW:
		return
	var fps := _frames / el
	fps_now = fps
	_frames = 0
	_t0 = now
	if _skip > 0:
		_skip -= 1
		return
	_collect(fps, el)
	if SaveManager.settings.get("graphics", "auto") != "auto":
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
	_downgrades += 1
	# После смены качества даём игре пару секунд, прежде чем мерить снова
	_skip = 1
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast("Графика упрощена, чтобы игра шла плавнее" if q == 2 else
			"Включён экономный режим графики — так плавнее", Art.TEAL, 2.5)


func _collect(fps: float, el: float) -> void:
	_total_frames += int(round(fps * el))
	_total_time += el
	_windows += 1
	_worst = minf(_worst, fps)
	if fps < LOW_FPS:
		_low_windows += 1
	_store()


## Итог заезда для отчёта (обновляется на каждом замере — вдруг игру просто закроют)
func _store() -> void:
	if _total_time <= 0.0:
		return
	SaveManager.last_run_stats = {
		"avg": snappedf(_total_frames / _total_time, 0.1),
		"worst": snappedf(_worst, 0.1),
		"low_pct": int(round(100.0 * _low_windows / maxf(_windows, 1))),
		"secs": int(_total_time),
		"quality_start": _start_quality,
		"quality_end": Art.quality,
		"downgrades": _downgrades,
		"location": SaveManager.selected_location,
		"car": SaveManager.selected_car,
		"diff": SaveManager.difficulty_id(),
	}


func _exit_tree() -> void:
	_store()
	SaveManager.save_data()


## Пауза и сворачивание сбивают замер — начинаем заново
func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_frames = 0
		_t0 = Time.get_ticks_usec()
