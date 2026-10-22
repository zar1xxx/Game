extends Node
## Глобальный менеджер сохранений (Autoload "SaveManager").
## Хранит рекорд и статистику в файле user://savegame.cfg,
## поэтому данные не теряются после выхода из игры.
## На Windows файл лежит в %APPDATA%\Godot\app_userdata\GameNew\savegame.cfg
## (имя папки берётся из названия проекта, application/config/name в project.godot)

signal best_score_changed(new_best: int)

const SAVE_PATH := "user://savegame.cfg"

var best_score: int = 0        # Лучший результат за всё время
var last_score: int = 0        # Результат последнего заезда
var games_played: int = 0      # Сколько заездов сыграно
var total_score: int = 0       # Сумма очков за все заезды

# Счёт текущего заезда (нужен, чтобы не потерять рекорд,
# если игрок закроет окно прямо во время гонки)
var _run_score: int = 0
var _run_active: bool = false


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		# Файла ещё нет (первый запуск) — оставляем значения по умолчанию
		return
	best_score = int(cfg.get_value("records", "best_score", 0))
	last_score = int(cfg.get_value("records", "last_score", 0))
	games_played = int(cfg.get_value("stats", "games_played", 0))
	total_score = int(cfg.get_value("stats", "total_score", 0))


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_score", best_score)
	cfg.set_value("records", "last_score", last_score)
	cfg.set_value("stats", "games_played", games_played)
	cfg.set_value("stats", "total_score", total_score)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Не удалось сохранить рекорд: ошибка " + str(err))


## Вызывается в начале каждого заезда
func start_run() -> void:
	_run_score = 0
	_run_active = true


## Вызывается счётчиком очков каждый раз, когда счёт растёт
func update_run_score(score: int) -> void:
	_run_score = score


## Завершает заезд и сохраняет результат.
## Возвращает true, если установлен новый рекорд.
func finish_run(score: int) -> bool:
	if not _run_active:
		return false
	_run_active = false
	_run_score = score
	last_score = score
	games_played += 1
	total_score += score
	var is_new_record := score > best_score
	if is_new_record:
		best_score = score
		best_score_changed.emit(best_score)
	save_data()
	return is_new_record


func get_average_score() -> int:
	if games_played == 0:
		return 0
	return int(round(float(total_score) / games_played))


func reset_records() -> void:
	best_score = 0
	last_score = 0
	games_played = 0
	total_score = 0
	best_score_changed.emit(best_score)
	save_data()


func _notification(what: int) -> void:
	# Игрок закрыл окно во время заезда — всё равно засчитываем результат
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _run_active:
		finish_run(_run_score)
