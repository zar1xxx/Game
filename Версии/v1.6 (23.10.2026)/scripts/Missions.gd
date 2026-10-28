extends Node
## Задания на заезд (Autoload "Missions").
## Одновременно активны три задания. Прогресс считается в пределах ОДНОГО заезда:
## не успели — задание остаётся и ждёт следующей попытки. Выполненное задание
## сразу приносит монеты, а после заезда на его место приходит новое.
## Выполнили все три за один заезд — бонус «Хет-трик».
##
## Игра сообщает о событиях вызовом Missions.event("fuel") и т.п.

signal mission_completed(slot: int, text: String, reward: int)
signal progress_changed()

const SLOTS := 3
const HATTRICK_REWARD := 150

## Шаблоны заданий: target — цели по уровням сложности, reward — награда за каждый уровень.
## short — короткий текст для HUD, text — полный (меню, экран проигрыша).
const POOL := {
	"clean": {"short": "Без удара: %d очков", "text": "Проедь %d очков без единого удара",
		"target": [150, 300, 500, 800], "reward": [40, 70, 110, 170]},
	"fuel": {"short": "Канистры: %d", "text": "Собери %d канистр с бензином",
		"target": [3, 5, 8], "reward": [40, 70, 120]},
	"nitro_gate": {"short": "Ворота на нитро: %d", "text": "Пролети ворота на нитро (%d раз)",
		"target": [1, 2], "reward": [120, 220]},
	"near": {"short": "Обгоны впритирку: %d", "text": "Пройди впритирку к встречной %d раз",
		"target": [3, 6, 10], "reward": [40, 80, 130]},
	"combo": {"short": "Комбо ×%d", "text": "Сделай комбо из %d опасных обгонов подряд",
		"target": [3, 4, 6], "reward": [60, 100, 180]},
	"score": {"short": "Набери %d очков", "text": "Набери %d очков за один заезд",
		"target": [300, 600, 1000, 1500], "reward": [40, 80, 130, 200]},
	"nitro": {"short": "Нитро: %d", "text": "Подбери нитро %d раза",
		"target": [2, 3, 5], "reward": [40, 70, 110]},
	"holes": {"short": "Объехать ям: %d", "text": "Объедь %d ям и сугробов, не попав ни в одну",
		"target": [4, 8, 14], "reward": [40, 70, 110]},
	"escape": {"short": "Уйти от погони: %d", "text": "Оторвись от полиции %d раз",
		"target": [1, 2, 3], "reward": [50, 100, 160]},
	"escape_tck": {"short": "Уйти от коллекторов: %d", "text": "Уйди от фургона коллекторов и их дронов %d раз",
		"target": [1, 2], "reward": [80, 150]},
	"repair": {"short": "Ключи: %d", "text": "Подбери %d гаечных ключа",
		"target": [1, 2, 3], "reward": [30, 60, 100]},
	"bird": {"short": "Птичьи подарки (Омск): %d", "text": "Переживи %d «подарка» омской птицы",
		"target": [1, 2, 3], "reward": [60, 110, 170], "only": "omsk"},
}

var progress: Array = [0, 0, 0]       # прогресс текущего заезда по каждому слоту
var completed_this_run: Array = []    # индексы слотов, выполненных в этом заезде
var run_rewards: int = 0              # сколько монет принесли задания в этом заезде
var run_best_combo: int = 0          # лучшее комбо этого заезда
var last_run_summary: Array = []      # итог заезда для экрана проигрыша
var _clean_base: int = 0              # счёт на момент последнего удара
var _score: int = 0
var _active: bool = false


func _ready() -> void:
	_fill_slots()


# ---------------------------------------------------------------------------
# Слоты
# ---------------------------------------------------------------------------
func get_slot(i: int) -> Dictionary:
	return SaveManager.missions[i] if i < SaveManager.missions.size() else {}


func _fill_slots() -> void:
	var slots: Array = SaveManager.missions
	# Отбрасываем испорченные и устаревшие записи (например, после обновления игры)
	slots = slots.filter(func(m): return m is Dictionary and POOL.has(m.get("id", "")))
	while slots.size() < SLOTS:
		slots.append(_new_mission(slots))
	SaveManager.missions = slots
	SaveManager.save_data()


## Новое задание, не повторяющее уже активные. Сложность растёт с числом выполненных.
func _new_mission(existing: Array) -> Dictionary:
	var used := existing.map(func(m): return m.id)
	var ids: Array = []
	for id in POOL.keys():
		if id in used:
			continue
		var only: String = POOL[id].get("only", "")
		if only != "" and not SaveManager.is_owned("location", only):
			continue        # «омские» задания — только если Омск уже куплен
		ids.append(id)
	var id: String = ids.pick_random()
	var tpl: Dictionary = POOL[id]
	var max_level: int = tpl.target.size() - 1
	# Первые задания лёгкие, дальше чаще выпадают сложные
	var cap := clampi(SaveManager.missions_done / 4, 0, max_level)
	var level := randi_range(maxi(0, cap - 1), cap)
	return {"id": id, "level": level}


func target_of(m: Dictionary) -> int:
	return POOL[m.id].target[m.level]


func reward_of(m: Dictionary) -> int:
	return POOL[m.id].reward[m.level]


func short_text(m: Dictionary) -> String:
	return POOL[m.id].short % target_of(m)


func full_text(m: Dictionary) -> String:
	var t: String = POOL[m.id].text
	if m.id == "nitro_gate" and target_of(m) == 1:
		t = "Пролети ворота на нитро"
	return t % target_of(m) if "%d" in t else t


## Задание этого типа сейчас активно и ещё не выполнено (нужно спавнеру)
func is_active(id: String) -> bool:
	for i in SaveManager.missions.size():
		if SaveManager.missions[i].id == id and not i in completed_this_run:
			return true
	return false


## Задание можно выполнить только на определённой трассе
func is_available_here(m: Dictionary) -> bool:
	var only: String = POOL[m.id].get("only", "")
	return only == "" or only == SaveManager.selected_location


# ---------------------------------------------------------------------------
# Заезд
# ---------------------------------------------------------------------------
func start_run() -> void:
	_fill_slots()
	progress = [0, 0, 0]
	completed_this_run = []
	run_rewards = 0
	run_best_combo = 0
	_clean_base = 0
	_score = 0
	_active = true
	progress_changed.emit()


## Конец заезда: выполненные задания заменяются новыми
func end_run() -> void:
	if not _active:
		return
	_active = false
	progress_changed.emit()
	var slots: Array = SaveManager.missions
	last_run_summary = []
	for i in slots.size():
		var m: Dictionary = slots[i]
		last_run_summary.append({"text": short_text(m), "done": i in completed_this_run,
			"progress": progress[i], "target": target_of(m), "reward": reward_of(m)})
	for i in completed_this_run:
		var others := slots.filter(func(m): return m != slots[i])
		slots[i] = _new_mission(others)
	SaveManager.missions = slots


## Событие из игры. amount — на сколько увеличить счётчик (или новое значение для «score»)
func event(kind: String, amount: int = 1) -> void:
	if not _active:
		return
	match kind:
		"score":
			_score = amount
			_set_progress("score", _score)
			_set_progress("clean", _score - _clean_base)
		"hit":
			# Любой удар обнуляет «чистый» отрезок
			_clean_base = _score
		"combo":
			run_best_combo = maxi(run_best_combo, amount)
			_set_progress("combo", amount)
		_:
			_add_progress(kind, amount)


func _add_progress(id: String, amount: int) -> void:
	for i in SLOTS:
		var m := get_slot(i)
		if m.get("id", "") == id and not i in completed_this_run:
			progress[i] += amount
			_check(i)
	progress_changed.emit()


func _set_progress(id: String, value: int) -> void:
	for i in SLOTS:
		var m := get_slot(i)
		if m.get("id", "") == id and not i in completed_this_run and value > progress[i]:
			progress[i] = value
			_check(i)
			progress_changed.emit()


func _check(i: int) -> void:
	var m := get_slot(i)
	if progress[i] < target_of(m):
		return
	progress[i] = target_of(m)
	completed_this_run.append(i)
	var reward := reward_of(m)
	SaveManager.missions_done += 1
	run_rewards += reward
	SaveManager.add_coins(reward)
	mission_completed.emit(i, short_text(m), reward)
	if completed_this_run.size() == SLOTS:
		run_rewards += HATTRICK_REWARD
		SaveManager.add_coins(HATTRICK_REWARD)
		mission_completed.emit(-1, "Хет-трик: все задания!", HATTRICK_REWARD)
