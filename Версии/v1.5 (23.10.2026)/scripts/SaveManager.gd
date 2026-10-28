extends Node
## Глобальный менеджер сохранений (Autoload "SaveManager").
## Хранит рекорд и статистику в файле user://savegame.cfg,
## поэтому данные не теряются после выхода из игры.
## На Windows файл лежит в %APPDATA%\Godot\app_userdata\Game\savegame.cfg

signal best_score_changed(new_best: int)
signal coins_changed(coins: int)
signal selection_changed()

const SAVE_PATH := "user://savegame.cfg"

var best_score: int = 0        # Лучший результат за всё время
var last_score: int = 0        # Результат последнего заезда
var games_played: int = 0      # Сколько заездов сыграно
var total_score: int = 0       # Сумма очков за все заезды

# --- Магазин ---
var coins: int = 0                              # Монеты (зарабатываются в заездах)
var owned_cars: Array = ["orange"]
var owned_locations: Array = ["city"]
var selected_car: String = "orange"
var selected_location: String = "city"
var best_by_location: Dictionary = {}           # рекорд на каждой трассе
var last_coins_earned: int = 0

# --- Задания и комбо ---
var missions: Array = []                        # три активных задания (см. Missions.gd)
var missions_done: int = 0                      # сколько заданий выполнено за всё время
var best_combo: int = 0                         # лучшее комбо за всё время

# --- Таблица рекордов ---
## Записи {id, name, score, location, car, date}. Хранятся лучшие 10 на каждой трассе —
## этого достаточно и для общей десятки.
const LEADERBOARD_SIZE := 10
const NAME_MAX := 16
var leaderboard: Array = []
var player_name: String = "Игрок"
var last_entry_id: int = -1                     # запись последнего заезда (подсветка, переименование)

# --- Карта Омска: найденные достопримечательности ---
var omsk_seen: Array = []
const COINS_PER_SCORE := 0.2                    # 5 очков = 1 монета (до множителей)

# Счёт текущего заезда (нужен, чтобы не потерять рекорд,
# если игрок закроет окно прямо во время гонки)
var _run_score: int = 0
var _run_active: bool = false
var _best_before_run: int = 0   # рекорд на момент старта заезда (для «Новый рекорд!»)

# --- Настройки (управление, вибрация) ---
var settings := {
	"control_mode": "buttons",     # "buttons" — кнопки на экране, "tilt" — наклон телефона
	"tilt_sensitivity": 1.0,       # 0.5 … 2.0
	"tilt_invert": false,
	"vibration": true,
	"music_volume": 0.7,           # 0 … 1
	"sfx_volume": 0.9,             # 0 … 1
}


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
	for key in settings.keys():
		settings[key] = cfg.get_value("settings", key, settings[key])
	coins = int(cfg.get_value("shop", "coins", 0))
	owned_cars = cfg.get_value("shop", "owned_cars", ["orange"])
	owned_locations = cfg.get_value("shop", "owned_locations", ["city"])
	selected_car = cfg.get_value("shop", "selected_car", "orange")
	selected_location = cfg.get_value("shop", "selected_location", "city")
	best_by_location = cfg.get_value("records", "best_by_location", {})
	missions = cfg.get_value("missions", "slots", [])
	missions_done = int(cfg.get_value("missions", "done", 0))
	best_combo = int(cfg.get_value("records", "best_combo", 0))
	omsk_seen = cfg.get_value("omsk", "seen", [])
	leaderboard = cfg.get_value("leaderboard", "entries", [])
	player_name = cfg.get_value("leaderboard", "player_name", "Игрок")
	# Старый рекорд из прошлых версий попадает в таблицу, чтобы она не была пустой
	if leaderboard.is_empty():
		for loc_id in best_by_location.keys():
			if int(best_by_location[loc_id]) > 0:
				leaderboard.append({"id": _new_id(), "name": player_name, "score": int(best_by_location[loc_id]),
					"location": loc_id, "car": selected_car, "date": ""})
	# Рекорд из старых версий игры засчитываем «Вечернему городу»
	if best_score > 0 and not best_by_location.has("city"):
		best_by_location["city"] = best_score


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_score", best_score)
	cfg.set_value("records", "last_score", last_score)
	cfg.set_value("stats", "games_played", games_played)
	cfg.set_value("stats", "total_score", total_score)
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.set_value("shop", "coins", coins)
	cfg.set_value("shop", "owned_cars", owned_cars)
	cfg.set_value("shop", "owned_locations", owned_locations)
	cfg.set_value("shop", "selected_car", selected_car)
	cfg.set_value("shop", "selected_location", selected_location)
	cfg.set_value("records", "best_by_location", best_by_location)
	cfg.set_value("missions", "slots", missions)
	cfg.set_value("missions", "done", missions_done)
	cfg.set_value("records", "best_combo", best_combo)
	cfg.set_value("omsk", "seen", omsk_seen)
	cfg.set_value("leaderboard", "entries", leaderboard)
	cfg.set_value("leaderboard", "player_name", player_name)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Не удалось сохранить рекорд: ошибка " + str(err))


## Вызывается в начале каждого заезда
func start_run() -> void:
	_run_score = 0
	_run_active = true
	_best_before_run = get_location_best()
	Missions.start_run()


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
	var is_new_record := score > _best_before_run
	if score > get_location_best():
		best_by_location[selected_location] = score
	if score > best_score:
		best_score = score
	best_score_changed.emit(best_score)
	# Монеты: зависят от очков, трассы и машины
	var mult: float = GameData.get_location(selected_location).coins * GameData.get_car(selected_car).coins
	last_coins_earned = int(score * COINS_PER_SCORE * mult)
	coins += last_coins_earned
	coins_changed.emit(coins)
	_add_leaderboard_entry(score)
	Missions.end_run()
	save_data()
	return is_new_record


## Награда (за задания и т.п.) — сразу на счёт и в сохранение
func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	save_data()


func get_average_score() -> int:
	if games_played == 0:
		return 0
	return int(round(float(total_score) / games_played))


func reset_records() -> void:
	best_score = 0
	best_by_location.clear()
	last_score = 0
	games_played = 0
	total_score = 0
	leaderboard.clear()
	last_entry_id = -1
	best_combo = 0
	best_score_changed.emit(best_score)
	save_data()


# ---------------------------------------------------------------------------
# Таблица рекордов
# ---------------------------------------------------------------------------
func _new_id() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) % 1000000000 * 10 + randi() % 10


func _add_leaderboard_entry(score: int) -> void:
	last_entry_id = -1
	if score <= 0:
		return
	var d := Time.get_date_dict_from_system()
	var entry := {"id": _new_id(), "name": player_name, "score": score, "location": selected_location,
		"car": selected_car, "date": "%02d.%02d.%d" % [d.day, d.month, d.year]}
	leaderboard.append(entry)
	_prune_leaderboard()
	for e in leaderboard:
		if e.id == entry.id:
			last_entry_id = entry.id


## Оставляет лучшие 10 записей на каждой трассе
func _prune_leaderboard() -> void:
	leaderboard.sort_custom(func(a, b): return a.score > b.score)
	var per_loc := {}
	var kept: Array = []
	for e in leaderboard:
		var n: int = per_loc.get(e.location, 0)
		if n < LEADERBOARD_SIZE:
			kept.append(e)
			per_loc[e.location] = n + 1
	leaderboard = kept


## Десятка лучших: по всем трассам ("") или по одной
func get_leaderboard(location_id: String = "") -> Array:
	var out: Array = []
	for e in leaderboard:
		if location_id == "" or e.location == location_id:
			out.append(e)
		if out.size() >= LEADERBOARD_SIZE:
			break
	return out


## Место записи в таблице (1..10) или 0, если не попала
func get_rank(entry_id: int, location_id: String = "") -> int:
	var table := get_leaderboard(location_id)
	for i in table.size():
		if table[i].id == entry_id:
			return i + 1
	return 0


## Игрок ввёл имя после заезда: переименовываем запись и запоминаем имя на будущее
func rename_entry(entry_id: int, new_name: String) -> void:
	new_name = new_name.strip_edges().left(NAME_MAX)
	if new_name == "":
		new_name = "Игрок"
	player_name = new_name
	for e in leaderboard:
		if e.id == entry_id:
			e.name = new_name
	save_data()


func set_setting(key: String, value) -> void:
	settings[key] = value
	save_data()


func _notification(what: int) -> void:
	# Игрок закрыл окно во время заезда — всё равно засчитываем результат
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _run_active:
		finish_run(_run_score)
	# Android может выгрузить свёрнутое приложение без предупреждения,
	# поэтому при сворачивании сразу сохраняем рекорд (заезд при этом продолжается)
	# На Авроре и ПК сворачивание приходит как потеря фокуса
	var backgrounded := what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	if backgrounded and _run_active and _run_score > get_location_best():
		best_by_location[selected_location] = _run_score
		best_score = maxi(best_score, _run_score)
		save_data()


# ---------------------------------------------------------------------------
# Магазин
# ---------------------------------------------------------------------------
func get_location_best(location_id: String = "") -> int:
	if location_id == "":
		location_id = selected_location
	return int(best_by_location.get(location_id, 0))


func is_owned(kind: String, id: String) -> bool:
	return id in (owned_cars if kind == "car" else owned_locations)


## Покупка машины ("car") или трассы ("location"). Возвращает true при успехе.
func buy(kind: String, id: String) -> bool:
	if is_owned(kind, id):
		return true
	var item := GameData.get_car(id) if kind == "car" else GameData.get_location(id)
	if coins < item.price:
		return false
	coins -= item.price
	if kind == "car":
		owned_cars.append(id)
	else:
		owned_locations.append(id)
	coins_changed.emit(coins)
	select(kind, id)
	return true


func select(kind: String, id: String) -> void:
	if not is_owned(kind, id):
		return
	if kind == "car":
		selected_car = id
	else:
		selected_location = id
	save_data()
	selection_changed.emit()



# ---------------------------------------------------------------------------
# Карта Омска
# ---------------------------------------------------------------------------
## Отмечает достопримечательность как найденную. true — если найдена впервые (с наградой)
func discover_landmark(id: String) -> bool:
	if id in omsk_seen:
		return false
	omsk_seen.append(id)
	coins += GameData.LANDMARK_REWARD
	if omsk_seen.size() == GameData.LANDMARKS.size():
		coins += GameData.LANDMARKS_ALL_REWARD
	coins_changed.emit(coins)
	save_data()
	return true


## Чит-код из мода: «контракт» — много денег
const CHEAT_COINS := 1000000

func apply_cheat(code: String) -> String:
	match code.strip_edges().to_lower().replace("ё", "е"):
		"контракт":
			coins += CHEAT_COINS
			coins_changed.emit(coins)
			save_data()
			return "Контракт подписан! +%d монет" % CHEAT_COINS
	return ""
