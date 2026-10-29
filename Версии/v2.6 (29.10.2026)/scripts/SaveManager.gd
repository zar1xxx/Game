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

# --- Гараж ---
## car_mods[car_id] = {"tank": 0, "brakes": 0, "magnet": 0, "armor": 0, "paint": "", "decal": "", "plate": ""}
var car_mods: Dictionary = {}
var owned_decals: Array = [""]

# --- Достижения ---
var achievements: Array = []                    # id открытых достижений
var coins_spent: int = 0                        # сколько монет потрачено за всё время

# --- Ежедневный заезд и награда за вход ---
const DAILY_BONUS := 1.25                       # множитель очков в заезде дня
var daily_mode: bool = false                    # идёт заезд дня (не сохраняется)
var daily_prev_location: String = ""            # какая трасса была выбрана до заезда дня
var daily_day: int = -1                         # номер дня, к которому относится рекорд дня
var daily_best: int = 0                         # рекорд дня
var daily_runs: int = 0                         # сколько заездов дня проехано за всё время
var daily_last_new_record: bool = false         # последний заезд дня побил рекорд дня
var login_day: int = -1                         # день, когда последний раз забрали награду за вход
var login_streak: int = 0                       # сколько дней подряд
# --- Испытание недели ---
var weekly_mode: bool = false                   # идёт испытание недели (не сохраняется)
var weekly_week: int = -1                       # номер недели, к которой относятся рекорд и цели
var weekly_best: int = 0
var weekly_claimed: int = 0                     # сколько целей недели уже выполнено (0..3)
var weekly_runs: int = 0
var weekly_last_new_record: bool = false
var weekly_last_goals: Array = []               # цели, выполненные в последнем заезде (индексы)

# --- Уровень водителя ---
var xp: int = 0                                 # опыт за всё время
var last_xp_earned: int = 0
var last_level_before: int = 1                  # уровень до последнего заезда
var last_level_coins: int = 0                   # монеты за новые уровни в последнем заезде
var cosmetics: Dictionary = {"horn": "", "smoke": ""}
var deal_used_day: int = -1                     # день, когда уже купили по скидке дня

# --- Обучение ---
var tutorial_done: bool = false
var tutorial_mode: bool = false                 # идёт обучающий заезд (не сохраняется)
var tutorial_running: bool = false              # подсказки ещё идут — погони и события ждут
const TUTORIAL_REWARD := 100
var _tutorial_xp_pending: bool = false
const COINS_PER_SCORE := 0.2                    # 5 очков = 1 монета (до множителей)

# Счёт текущего заезда (нужен, чтобы не потерять рекорд,
# если игрок закроет окно прямо во время гонки)
var _run_score: int = 0
var _run_active: bool = false
var _best_before_run: int = 0   # рекорд на момент старта заезда (для «Новый рекорд!»)

# --- Настройки (управление, вибрация) ---
var settings := {
	"control_mode": "drag",        # "drag" — ведение пальцем, "buttons" — кнопки, "tilt" — наклон, "swipe" — свайпы
	"tilt_sensitivity": 1.0,       # 0.5 … 2.0
	"tilt_invert": false,
	"vibration": true,
	"music_volume": 0.7,           # 0 … 1
	"sfx_volume": 0.9,             # 0 … 1
	"ghost": true,                 # показывать призрака рекорда
	"graphics": "auto",            # "auto" — сама упрощается на слабом телефоне, "high", "eco"
	"auto_quality": 2,             # до какого уровня «Авто» уже упростила графику (2 — полная)
	"difficulty": "normal",        # "easy" — «Спокойно», "normal", "hard" — «Жёстко»
	"mirror": false,               # зеркальная раскладка кнопок (для левшей)
	"show_fps": false,             # счётчик кадров в углу во время заезда
	"drag_v26": true,              # ведение пальцем уже предложено (см. _apply_loaded)
}

# --- Особые заезды (не сохраняются) ---
var run_seed: int = 0                           # «зерно» трафика текущего заезда (16 бит — входит в код вызова)
var challenge_mode: bool = false                # заезд по коду вызова от друга
var challenge: Dictionary = {}                  # {"loc", "car", "diff", "seed", "score"}
var challenge_prev_car: String = ""
var party_mode: bool = false                    # «Кто дальше» на одном телефоне
var party: Dictionary = {}                      # см. start_party()
var last_run_stats: Dictionary = {}             # средний FPS и т.п. последнего заезда (для отчёта)
var second_chance_used: bool = false


func _ready() -> void:
	load_data()
	apply_graphics()


## Качество графики: 2 — полное, 1 — облегчённое, 0 — экономия
func graphics_quality() -> int:
	match str(settings.get("graphics", "auto")):
		"high":
			return 2
		"eco":
			return 0
	return clampi(int(settings.get("auto_quality", 2)), 0, 2)


## Применяет качество: на «экономии» игра рисуется в базовом разрешении (≈1440×648)
## и растягивается на экран — телефону нужно закрашивать в 2–3 раза меньше пикселей
func apply_graphics() -> void:
	Art.quality = graphics_quality()
	var root := get_tree().root
	if root:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if Art.quality == 0 \
			else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


func load_data() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		# Файла ещё нет (первый запуск) — оставляем значения по умолчанию
		return
	_apply_loaded(cfg)


func _apply_loaded(cfg: ConfigFile) -> void:
	best_score = int(cfg.get_value("records", "best_score", 0))
	last_score = int(cfg.get_value("records", "last_score", 0))
	games_played = int(cfg.get_value("stats", "games_played", 0))
	total_score = int(cfg.get_value("stats", "total_score", 0))
	for key in settings.keys():
		settings[key] = cfg.get_value("settings", key, settings[key])
	# v2.6: по отзывам тестировщиков кнопки ◀ ▶ неудобны — тем, кто их не менял,
	# один раз включаем ведение пальцем (вернуть кнопки можно в настройках)
	if not cfg.has_section_key("settings", "drag_v26"):
		if settings.control_mode == "buttons":
			settings.control_mode = "drag"
	settings["drag_v26"] = true
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
	car_mods = cfg.get_value("garage", "car_mods", {})
	owned_decals = cfg.get_value("garage", "owned_decals", [""])
	achievements = cfg.get_value("achievements", "unlocked", [])
	coins_spent = int(cfg.get_value("achievements", "coins_spent", 0))
	daily_day = int(cfg.get_value("daily", "day", -1))
	daily_best = int(cfg.get_value("daily", "best", 0))
	daily_runs = int(cfg.get_value("daily", "runs", 0))
	login_day = int(cfg.get_value("daily", "login_day", -1))
	login_streak = int(cfg.get_value("daily", "login_streak", 0))
	weekly_week = int(cfg.get_value("weekly", "week", -1))
	weekly_best = int(cfg.get_value("weekly", "best", 0))
	weekly_claimed = int(cfg.get_value("weekly", "claimed", 0))
	weekly_runs = int(cfg.get_value("weekly", "runs", 0))
	xp = int(cfg.get_value("driver", "xp", 0))
	deal_used_day = int(cfg.get_value("shop", "deal_used_day", -1))
	last_run_stats = cfg.get_value("stats", "last_perf", {})
	var cos: Dictionary = cfg.get_value("driver", "cosmetics", {})
	for k in cos.keys():
		cosmetics[k] = cos[k]
	_migrate_omsk_loop()
	# Тем, кто уже играл в прошлые версии, обучение не навязываем
	tutorial_done = bool(cfg.get_value("driver", "tutorial_done", games_played > 0))
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


## v2.1: трасса «Омск не отпускает» слилась с «Омском» — переносим покупку, рекорды и выбор
func _migrate_omsk_loop() -> void:
	const OLD := "omsk_loop"
	if OLD in owned_locations:
		owned_locations.erase(OLD)
		if not "omsk" in owned_locations:
			owned_locations.append("omsk")
	if selected_location == OLD:
		selected_location = "omsk"
	if daily_prev_location == OLD:
		daily_prev_location = "omsk"
	if best_by_location.has(OLD):
		best_by_location["omsk"] = maxi(int(best_by_location.get("omsk", 0)), int(best_by_location[OLD]))
		best_by_location.erase(OLD)
	for e in leaderboard:
		if e.get("location", "") == OLD:
			e.location = "omsk"
	# Неизвестные трассы и машины (например, из будущих версий) не ломают игру
	if GameData.get_location(selected_location).id != selected_location:
		selected_location = "city"


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
	cfg.set_value("shop", "selected_car", challenge_prev_car if (challenge_mode or party_mode) else selected_car)
	cfg.set_value("shop", "selected_location", daily_prev_location if in_challenge() else selected_location)
	cfg.set_value("records", "best_by_location", best_by_location)
	cfg.set_value("missions", "slots", missions)
	cfg.set_value("missions", "done", missions_done)
	cfg.set_value("records", "best_combo", best_combo)
	cfg.set_value("omsk", "seen", omsk_seen)
	cfg.set_value("garage", "car_mods", car_mods)
	cfg.set_value("garage", "owned_decals", owned_decals)
	cfg.set_value("achievements", "unlocked", achievements)
	cfg.set_value("achievements", "coins_spent", coins_spent)
	cfg.set_value("daily", "day", daily_day)
	cfg.set_value("daily", "best", daily_best)
	cfg.set_value("daily", "runs", daily_runs)
	cfg.set_value("daily", "login_day", login_day)
	cfg.set_value("daily", "login_streak", login_streak)
	cfg.set_value("weekly", "week", weekly_week)
	cfg.set_value("weekly", "best", weekly_best)
	cfg.set_value("weekly", "claimed", weekly_claimed)
	cfg.set_value("weekly", "runs", weekly_runs)
	cfg.set_value("driver", "xp", xp)
	cfg.set_value("shop", "deal_used_day", deal_used_day)
	cfg.set_value("stats", "last_perf", last_run_stats)
	cfg.set_value("driver", "cosmetics", cosmetics)
	cfg.set_value("driver", "tutorial_done", tutorial_done)
	cfg.set_value("leaderboard", "entries", leaderboard)
	cfg.set_value("leaderboard", "player_name", player_name)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Не удалось сохранить рекорд: ошибка " + str(err))


## Вызывается в начале каждого заезда
func start_run() -> void:
	_run_score = 0
	_run_active = true
	second_chance_used = false
	run_seed = _make_run_seed()
	_best_before_run = get_location_best()
	Missions.start_run()
	Achievements.start_run()


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
	var records := records_enabled()
	var is_new_record := records and score > _best_before_run
	if records and score > get_location_best():
		best_by_location[record_key()] = score
	if records and score > best_score:
		best_score = score
	best_score_changed.emit(best_score)
	# Монеты: зависят от очков, трассы и машины
	var mult: float = GameData.get_location(selected_location).coins * GameData.get_car(selected_car).coins
	last_coins_earned = int(score * COINS_PER_SCORE * mult)
	coins += last_coins_earned
	coins_changed.emit(coins)
	if records:
		_add_leaderboard_entry(score)
	else:
		last_entry_id = -1
	if party_mode:
		_party_record(score)
	if daily_mode:
		_finish_daily(score)
	if weekly_mode:
		_finish_weekly(score)
	Missions.end_run()
	_add_run_xp(score)
	save_data()
	Achievements.event("run_finished")
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
	# Призраки старых рекордов тоже стираем
	if FileAccess.file_exists("user://ghosts.cfg"):
		DirAccess.remove_absolute("user://ghosts.cfg")
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
		"car": selected_car, "date": "%02d.%02d.%d" % [d.day, d.month, d.year], "diff": difficulty_id()}
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
	if backgrounded and _run_active and records_enabled() and _run_score > get_location_best():
		best_by_location[record_key()] = _run_score
		best_score = maxi(best_score, _run_score)
		save_data()


# ---------------------------------------------------------------------------
# Магазин
# ---------------------------------------------------------------------------
func get_location_best(location_id: String = "") -> int:
	return int(best_by_location.get(record_key(location_id), 0))


# ---------------------------------------------------------------------------
# Сложность и рекорды
# ---------------------------------------------------------------------------
## Сложность текущего заезда. В заезде дня, испытании недели и обучении — всегда «Нормально»,
## чтобы все соревновались на равных; в вызове — та, на которой ехал друг.
func difficulty_id() -> String:
	if challenge_mode:
		return str(challenge.get("diff", "normal"))
	if daily_mode or weekly_mode or tutorial_mode:
		return "normal"
	return str(settings.get("difficulty", "normal"))


func difficulty() -> Dictionary:
	return GameData.get_difficulty(difficulty_id())


## Ключ рекорда: у «Нормально» — просто трасса (как в прошлых версиях), у остальных — «трасса@сложность»
func record_key(location_id: String = "") -> String:
	if location_id == "":
		location_id = selected_location
	var d := difficulty_id()
	return location_id if d == "normal" else location_id + "@" + d


## Рекорды и таблица пишутся только в обычных заездах (не в «Кто дальше» и не в вызове)
func records_enabled() -> bool:
	return not party_mode and not challenge_mode


## Второй шанс можно купить в обычном заезде, заезде дня и испытании недели
func second_chance_allowed() -> bool:
	return not party_mode and not challenge_mode and not tutorial_mode and not second_chance_used


func second_chance_price(score: int) -> int:
	return clampi(int(score * 0.15 / 10.0) * 10, 100, 1500)


func _make_run_seed() -> int:
	if challenge_mode:
		return int(challenge.get("seed", 1))
	if party_mode:
		return (int(party.get("seed", 1)) + int(party.get("round", 0)) * 7919) & 0xFFFF
	if daily_mode:
		return (daily_seed() * 2654435761 >> 7) & 0xFFFF
	if weekly_mode:
		return (weekly_seed() * 2246822519 >> 7) & 0xFFFF
	return randi() & 0xFFFF


func is_owned(kind: String, id: String) -> bool:
	return id in (owned_cars if kind == "car" else owned_locations)


## Покупка машины ("car") или трассы ("location"). Возвращает true при успехе.
func buy(kind: String, id: String) -> bool:
	if is_owned(kind, id):
		return true
	var price := price_for(kind, id)
	if coins < price:
		return false
	_spend(price)
	_use_deal(kind, id)
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
	Achievements.check_static()
	return true


# ---------------------------------------------------------------------------
# Гараж
# ---------------------------------------------------------------------------
func get_mod(car_id: String, key: String, default = 0):
	return car_mods.get(car_id, {}).get(key, default)


func _set_mod(car_id: String, key: String, value) -> void:
	if not car_mods.has(car_id):
		car_mods[car_id] = {}
	car_mods[car_id][key] = value


func get_plate(car_id: String) -> String:
	var p: String = get_mod(car_id, "plate", "")
	return p if p != "" else GameData.default_plate(car_id)


## Улучшение тюнинга на один уровень. true — если хватило монет
func buy_upgrade(car_id: String, key: String) -> bool:
	var lvl: int = get_mod(car_id, key, 0)
	if lvl >= GameData.UPGRADE_MAX:
		return false
	var price := GameData.upgrade_price(lvl)
	if coins < price:
		return false
	_spend(price)
	_set_mod(car_id, key, lvl + 1)
	coins_changed.emit(coins)
	save_data()
	return true


## Покраска ("" — заводской цвет, бесплатно)
func buy_paint(car_id: String, color_html: String) -> bool:
	if color_html != "":
		if coins < GameData.paint_price(color_html):
			return false
		_spend(GameData.paint_price(color_html))
		coins_changed.emit(coins)
	_set_mod(car_id, "paint", color_html)
	save_data()
	selection_changed.emit()
	return true


## Наклейка: покупается один раз и потом клеится на любую машину бесплатно
func apply_decal(car_id: String, decal_id: String) -> bool:
	if not is_cosmetic_unlocked("decal", decal_id):
		return false
	if not decal_id in owned_decals:
		var price: int = price_for("decal", decal_id)
		if coins < price:
			return false
		_spend(price)
		_use_deal("decal", decal_id)
		owned_decals.append(decal_id)
		coins_changed.emit(coins)
	_set_mod(car_id, "decal", decal_id)
	save_data()
	selection_changed.emit()
	return true


func buy_plate(car_id: String, plate: String) -> bool:
	if not GameData.is_valid_plate(plate) or coins < GameData.PLATE_PRICE:
		return false
	_spend(GameData.PLATE_PRICE)
	_set_mod(car_id, "plate", plate)
	coins_changed.emit(coins)
	save_data()
	return true


## Машина из каталога с учётом покраски (для рисования)
func custom_car(car_id: String) -> Dictionary:
	var car := GameData.get_car(car_id).duplicate()
	var paint: String = get_mod(car_id, "paint", "")
	if paint != "":
		car.color = Color(paint)
	car["decal"] = get_mod(car_id, "decal", "")
	car["plate"] = get_plate(car_id)
	return car


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


## Списание монет за покупку (учитывается для достижения «Миллионер»)
# ---------------------------------------------------------------------------
# Скидка дня: каждый день одна машина, трасса или наклейка дешевле (одна покупка в день)
# ---------------------------------------------------------------------------
func daily_deal() -> Dictionary:
	if deal_used_day == today():
		return {}
	var all: Array = []
	for c in GameData.CARS:
		if c.price > 0:
			all.append({"kind": "car", "id": c.id, "name": c.name, "price": c.price})
	for l in GameData.LOCATIONS:
		if l.price > 0:
			all.append({"kind": "location", "id": l.id, "name": l.name, "price": l.price})
	for d in GameData.DECALS:
		if d.price > 0:
			all.append({"kind": "decal", "id": d.id, "name": "наклейка «%s»" % d.name, "price": d.price})
	if all.is_empty():
		return {}
	var x := (today() * 2654435761 + 977) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	var start := x % all.size()
	# Если выпала уже купленная вещь — берём следующую некупленную
	for i in all.size():
		var it: Dictionary = all[(start + i) % all.size()]
		var owned: bool = (it.id in owned_decals) if it.kind == "decal" else is_owned(it.kind, it.id)
		if not owned:
			it["pct"] = [15, 20, 25, 20, 30][(x >> 5) % 5]
			it["new_price"] = int(round(it.price * (100 - it.pct) / 1000.0)) * 10
			return it
	return {}


func price_for(kind: String, id: String) -> int:
	var base: int = 0
	match kind:
		"car":
			base = GameData.get_car(id).price
		"location":
			base = GameData.get_location(id).price
		"decal":
			base = GameData.get_decal(id).price
	var deal := daily_deal()
	if not deal.is_empty() and deal.kind == kind and deal.id == id:
		return deal.new_price
	return base


func _use_deal(kind: String, id: String) -> void:
	var deal := daily_deal()
	if not deal.is_empty() and deal.kind == kind and deal.id == id:
		deal_used_day = today()


func _spend(amount: int) -> void:
	coins -= amount
	coins_spent += amount
	Achievements.call_deferred("check_static")


# ---------------------------------------------------------------------------
# Ежедневный заезд и награда за вход
# ---------------------------------------------------------------------------
## Номер сегодняшнего дня (по местному времени)
static func today() -> int:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return int(floor((Time.get_unix_time_from_system() + bias * 60.0) / 86400.0))


## Трасса дня — одна и та же у всех игроков в этот день (не обязательно купленная)
static func daily_location_id(day: int = -1) -> String:
	if day < 0:
		day = today()
	var x := (day * 2654435761) & 0x7fffffff
	x = ((x ^ (x >> 15)) * 2246822519) & 0x7fffffff
	return GameData.LOCATIONS[x % GameData.LOCATIONS.size()].id


static func daily_seed(day: int = -1) -> int:
	if day < 0:
		day = today()
	return day * 7919 + 17


func get_daily_best() -> int:
	return daily_best if daily_day == today() else 0


func start_daily() -> void:
	if in_challenge():
		return
	daily_prev_location = selected_location
	daily_mode = true
	selected_location = daily_location_id()


## Особый заезд (день, неделя, обучение): трасса подменяется, выбор игрока хранится отдельно
func in_challenge() -> bool:
	return daily_mode or weekly_mode or tutorial_mode or challenge_mode or party_mode


## Вызывается при возврате в меню: возвращаем трассу, выбранную игроком
func end_daily() -> void:
	if not in_challenge():
		return
	daily_mode = false
	weekly_mode = false
	tutorial_mode = false
	tutorial_running = false
	if challenge_mode or party_mode:
		selected_car = challenge_prev_car
	challenge_mode = false
	party_mode = false
	selected_location = daily_prev_location
	daily_prev_location = ""


func _finish_daily(score: int) -> void:
	var d := today()
	if daily_day != d:
		daily_day = d
		daily_best = 0
	daily_last_new_record = score > daily_best
	if daily_last_new_record:
		daily_best = score
	daily_runs += 1
	Achievements.call_deferred("event", "daily_done")


## Награду за вход сегодня ещё не забирали
func login_reward_available() -> bool:
	return login_day != today()


## Сколько монет дадут за вход: 50 в первый день, +25 за каждый день подряд (до 200)
func login_reward_amount(streak: int = -1) -> int:
	if streak < 0:
		streak = (login_streak + 1) if login_day == today() - 1 else 1
	return 50 + 25 * mini(streak - 1, 6)


## Забрать награду за вход. Возвращает выданную сумму (0 — уже забрана)
func claim_login_reward() -> int:
	if not login_reward_available():
		return 0
	var d := today()
	login_streak = (login_streak + 1) if login_day == d - 1 else 1
	login_day = d
	var amount := login_reward_amount(login_streak)
	coins += amount
	coins_changed.emit(coins)
	save_data()
	Achievements.check_static()
	return amount


# ---------------------------------------------------------------------------
# Испытание недели
# ---------------------------------------------------------------------------
## Номер недели (недели начинаются в понедельник)
static func week_index(day: int = -1) -> int:
	if day < 0:
		day = today()
	return int(floor((day + 3) / 7.0))


static func _week_hash(week: int, salt: int) -> int:
	var x := ((week + salt * 7919) * 2654435761) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 2246822519) & 0x7fffffff
	return x ^ (x >> 16)


## Правило недели — одно для всех игроков; подряд два одинаковых не бывает
static func weekly_rule(week: int = -1) -> Dictionary:
	if week < 0:
		week = week_index()
	var n := GameData.WEEKLY_RULES.size()
	var i := _week_hash(week, 1) % n
	var prev := _week_hash(week - 1, 1) % n
	if i == prev:
		i = (i + 1) % n
	return GameData.WEEKLY_RULES[i]


## Трасса недели — одна для всех
static func weekly_location_id(week: int = -1) -> String:
	if week < 0:
		week = week_index()
	var ids: Array = []
	for l in GameData.LOCATIONS:
		ids.append(l.id)
	return ids[_week_hash(week, 2) % ids.size()]


static func weekly_seed(week: int = -1) -> int:
	if week < 0:
		week = week_index()
	return week * 104729 + 31


## Первый день недели (понедельник) — для подписи «19.10 – 25.10»
static func week_dates_text(week: int = -1) -> String:
	if week < 0:
		week = week_index()
	var monday := week * 7 - 3
	var a := Time.get_date_dict_from_unix_time(monday * 86400)
	var b := Time.get_date_dict_from_unix_time((monday + 6) * 86400)
	return "%02d.%02d – %02d.%02d" % [a.day, a.month, b.day, b.month]


## Правило действует прямо сейчас (идёт испытание недели с этим правилом)
func rule_active(rule_id: String) -> bool:
	return weekly_mode and weekly_rule().id == rule_id


func _sync_week() -> void:
	var w := week_index()
	if weekly_week != w:
		weekly_week = w
		weekly_best = 0
		weekly_claimed = 0


func get_weekly_best() -> int:
	_sync_week()
	return weekly_best


func get_weekly_claimed() -> int:
	_sync_week()
	return weekly_claimed


func start_weekly() -> void:
	if in_challenge():
		return
	daily_prev_location = selected_location
	weekly_mode = true
	selected_location = weekly_location_id()


func _finish_weekly(score: int) -> void:
	_sync_week()
	var reached_before := get_weekly_reached()
	weekly_last_new_record = score > weekly_best
	if weekly_last_new_record:
		weekly_best = score
	weekly_runs += 1
	# Новые выполненные цели — награду за них забирают кнопкой в меню (вкладка «Неделя»)
	weekly_last_goals = []
	for i in GameData.WEEKLY_GOALS.size():
		if i >= reached_before and score >= GameData.WEEKLY_GOALS[i]:
			weekly_last_goals.append(i)
	Achievements.call_deferred("event", "weekly_done", get_weekly_reached())


## Сколько целей недели выполнено (по лучшему заезду недели)
func get_weekly_reached() -> int:
	_sync_week()
	var n := 0
	for g in GameData.WEEKLY_GOALS:
		if weekly_best >= g:
			n += 1
	return n


## Награда за выполненные, но ещё не забранные цели недели
func weekly_unclaimed_reward() -> int:
	var total := 0
	for i in range(get_weekly_claimed(), get_weekly_reached()):
		total += GameData.WEEKLY_REWARDS[i]
	return total


## Забрать награду за цели недели. Возвращает выданную сумму
func claim_weekly() -> int:
	var amount := weekly_unclaimed_reward()
	if amount <= 0:
		return 0
	weekly_claimed = get_weekly_reached()
	coins += amount
	coins_changed.emit(coins)
	save_data()
	return amount


# ---------------------------------------------------------------------------
# Уровень водителя
# ---------------------------------------------------------------------------
func get_level() -> int:
	return GameData.level_from_xp(xp)


## Опыт за заезд: за очки, выполненные задания, особые заезды
func run_xp(score: int) -> int:
	var gained := 15 + int(score / 8.0)
	for m in Missions.last_run_summary:
		if m.done:
			gained += 25
	if daily_mode or weekly_mode:
		gained += 30
	if _tutorial_xp_pending:
		_tutorial_xp_pending = false
		gained += 60
	return gained


func _add_run_xp(score: int) -> void:
	last_level_before = get_level()
	last_xp_earned = run_xp(score) if score > 0 or _tutorial_xp_pending else 0
	add_xp(last_xp_earned)


## Начисляет опыт; за каждый новый уровень — монеты
func add_xp(amount: int) -> void:
	var before := get_level()
	xp += amount
	var after := get_level()
	last_level_coins = 0
	for l in range(before + 1, after + 1):
		last_level_coins += GameData.level_reward(l)
	if last_level_coins > 0:
		coins += last_level_coins
		coins_changed.emit(coins)
		Achievements.call_deferred("event", "level", after)


func is_cosmetic_unlocked(kind: String, id: String) -> bool:
	var need := 1
	match kind:
		"horn":
			need = GameData.get_horn(id).level
		"smoke":
			need = GameData.get_smoke(id).level
		"decal":
			need = GameData.get_decal(id).get("level", 1)
	return get_level() >= need


func set_cosmetic(kind: String, id: String) -> bool:
	if not is_cosmetic_unlocked(kind, id):
		return false
	cosmetics[kind] = id
	save_data()
	return true


## Гудок игрока (звук выбранного гудка)
func horn_sound() -> String:
	return GameData.get_horn(cosmetics.get("horn", "")).sound


# ---------------------------------------------------------------------------
# Обучение
# ---------------------------------------------------------------------------
func start_tutorial() -> void:
	if in_challenge():
		return
	daily_prev_location = selected_location
	tutorial_mode = true
	tutorial_running = true
	selected_location = "city"


func complete_tutorial() -> void:
	tutorial_running = false
	var first := not tutorial_done
	_tutorial_xp_pending = first
	tutorial_done = true
	if first:
		coins += TUTORIAL_REWARD
		coins_changed.emit(coins)
	save_data()


# ---------------------------------------------------------------------------
# Вызов по коду: друг едет ту же трассу на той же машине с тем же трафиком
# ---------------------------------------------------------------------------
const ChallengeCode := preload("res://scripts/ChallengeCode.gd")


## Код вызова для только что закончившегося заезда («» — если делиться нечем)
func last_challenge_code() -> String:
	if last_score <= 0 or tutorial_mode or party_mode:
		return ""
	return ChallengeCode.encode(selected_location, selected_car, difficulty_id(), run_seed, last_score)


## Начать заезд по коду. c — результат ChallengeCode.decode()
func start_challenge(c: Dictionary) -> void:
	if in_challenge():
		end_daily()
	daily_prev_location = selected_location
	challenge_prev_car = selected_car
	challenge = c
	challenge_mode = true
	selected_location = c.loc
	selected_car = c.car


# ---------------------------------------------------------------------------
# «Кто дальше» на одном телефоне: 2–4 игрока по очереди, три круга, в зачёт — лучший заезд
# ---------------------------------------------------------------------------
const PARTY_ROUNDS := 3


func start_party(names: Array) -> void:
	if in_challenge():
		end_daily()
	daily_prev_location = selected_location
	challenge_prev_car = selected_car
	party_mode = true
	party = {"names": names.duplicate(), "scores": [], "round": 0, "turn": 0,
		"seed": randi() & 0xFFFF, "loc": selected_location, "car": selected_car}
	for _n in names:
		party.scores.append([])


func _party_record(score: int) -> void:
	if party.is_empty() or party_finished():
		return
	party.scores[party.turn].append(score)
	party.turn += 1
	if party.turn >= party.names.size():
		party.turn = 0
		party.round += 1


func party_finished() -> bool:
	return party_mode and int(party.get("round", 0)) >= PARTY_ROUNDS


func party_current_name() -> String:
	if party.is_empty():
		return ""
	return party.names[party.turn]


## Таблица: [{name, best, scores}] по убыванию лучшего результата
func party_table() -> Array:
	var out: Array = []
	if party.is_empty():
		return out
	for i in party.names.size():
		var sc: Array = party.scores[i]
		var best := 0
		for v in sc:
			best = maxi(best, int(v))
		out.append({"name": party.names[i], "best": best, "scores": sc, "index": i})
	out.sort_custom(func(a, b): return a.best > b.best)
	return out



# ---------------------------------------------------------------------------
# Перенос прогресса кодом: сохранение → сжатие → текст. Вставляешь на новом телефоне — готово.
# ---------------------------------------------------------------------------
const TRANSFER_PREFIX := "BENZIN1"


func export_code() -> String:
	save_data()
	var raw := FileAccess.get_file_as_bytes(SAVE_PATH)
	if raw.is_empty():
		return ""
	var b64 := Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))
	return "%s-%04X-%s" % [TRANSFER_PREFIX, _transfer_sum(b64), b64]


static func _transfer_sum(b64: String) -> int:
	var h := 5381
	for i in b64.length():
		h = ((h * 33) ^ b64.unicode_at(i)) & 0x7fffffff
	return h & 0xFFFF


## Разобрать код. Возвращает {} при ошибке, иначе {"text", "coins", "level", "cars", "tracks", "games"}
func peek_code(code: String) -> Dictionary:
	var c := ""
	for ch in code:
		if ch != " " and ch != "\n" and ch != "\r" and ch != "\t":
			c += ch
	var parts := c.split("-", false, 2)
	if parts.size() != 3 or parts[0] != TRANSFER_PREFIX or not parts[1].is_valid_hex_number():
		return {}
	if parts[1].hex_to_int() != _transfer_sum(parts[2]):
		return {}
	var comp := Marshalls.base64_to_raw(parts[2])
	if comp.is_empty():
		return {}
	var raw := comp.decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	var text := raw.get_string_from_utf8()
	var cfg := ConfigFile.new()
	if text == "" or cfg.parse(text) != OK or not cfg.has_section("shop"):
		return {}
	return {"text": text, "coins": int(cfg.get_value("shop", "coins", 0)),
		"level": GameData.level_from_xp(int(cfg.get_value("driver", "xp", 0))),
		"cars": (cfg.get_value("shop", "owned_cars", []) as Array).size(),
		"tracks": (cfg.get_value("shop", "owned_locations", []) as Array).size(),
		"games": int(cfg.get_value("stats", "games_played", 0))}


func import_code(code: String) -> bool:
	var info := peek_code(code)
	if info.is_empty():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(info.text)
	f.close()
	load_data()
	apply_graphics()
	Missions._fill_slots()
	coins_changed.emit(coins)
	best_score_changed.emit(best_score)
	selection_changed.emit()
	Achievements.check_static()
	return true


# ---------------------------------------------------------------------------
# Отчёт разработчику: версия, телефон, графика и FPS последнего заезда — одним текстом
# ---------------------------------------------------------------------------
func dev_report() -> String:
	var q_names := ["экономная", "облегчённая", "полная"]
	var lines: Array = []
	lines.append("«В погоне за бензином» %s" % ProjectSettings.get_setting("application/config/version", "?"))
	lines.append("Телефон: %s • %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version()])
	var scr := DisplayServer.screen_get_size()
	var win := DisplayServer.window_get_size()
	var hz := DisplayServer.screen_get_refresh_rate()
	lines.append("Экран: %d×%d • окно %d×%d%s" % [scr.x, scr.y, win.x, win.y, (" • %d Гц" % int(round(hz))) if hz > 0.0 else ""])
	lines.append("Видео: %s" % RenderingServer.get_video_adapter_name())
	var gmode: String = {"auto": "Авто", "high": "Высокая", "eco": "Экономия"}.get(str(settings.get("graphics", "auto")), "?")
	lines.append("Графика: %s, сейчас %s" % [gmode, q_names[clampi(graphics_quality(), 0, 2)]])
	lines.append("Управление: %s%s" % [{"buttons": "кнопки", "tilt": "наклон", "swipe": "свайпы", "drag": "ведение"}.get(MobileInput.get_mode(), "?"),
		", зеркально" if settings.get("mirror", false) else ""])
	var st := last_run_stats
	if st.is_empty():
		lines.append("Последний заезд: данных пока нет — сыграйте заезд и нажмите ещё раз")
	else:
		lines.append("Последний заезд: %s, %s, %s, %d с" % [GameData.get_location(str(st.get("location", ""))).name,
			GameData.get_car(str(st.get("car", ""))).name, GameData.get_difficulty(str(st.get("diff", "normal"))).name,
			int(st.get("secs", 0))])
		lines.append("FPS: средний %s, худший замер %s, ниже 45 — %d%% времени" % [str(st.get("avg", 0)), str(st.get("worst", 0)),
			int(st.get("low_pct", 0))])
		lines.append("Графика в заезде: %s → %s (упрощений: %d)" % [q_names[clampi(int(st.get("quality_start", 2)), 0, 2)],
			q_names[clampi(int(st.get("quality_end", 2)), 0, 2)], int(st.get("downgrades", 0))])
	lines.append("Заездов: %d • уровень %d" % [games_played, get_level()])
	return "\n".join(lines)
