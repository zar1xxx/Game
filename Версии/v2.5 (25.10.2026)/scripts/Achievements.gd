extends Node
## Достижения (Autoload "Achievements").
## Игра сообщает о событиях через Achievements.event("…") — большую часть событий
## пересылает сюда Missions.event, остальные (ямы, круги Омска, призрак, покупки) — напрямую.
## Открытое достижение сразу приносит монеты и показывает плашку поверх любого экрана.

signal unlocked(def: Dictionary)

const LIST := [
	{"id": "first_run", "name": "Первый блин", "desc": "Завершить первый заезд", "reward": 30, "icon": "▶"},
	{"id": "score_1000", "name": "Тысячник", "desc": "Набрать 1000 очков за один заезд", "reward": 100, "icon": "1K"},
	{"id": "score_5000", "name": "Дальнобойщик", "desc": "Набрать 5000 очков за один заезд", "reward": 300, "icon": "5K"},
	{"id": "combo_8", "name": "Впритирку", "desc": "Сделать комбо ×8 из опасных обгонов", "reward": 150, "icon": "×8"},
	{"id": "omsk_clean", "name": "Без единой ямы", "desc": "Набрать 500 очков в Омске, ни разу не попав в яму", "reward": 250, "icon": "◯"},
	{"id": "tck_3", "name": "Неуловимый должник", "desc": "Уйти от коллекторов три раза за один заезд", "reward": 250, "icon": "₽"},
	{"id": "police_3", "name": "Шумахер", "desc": "Оторваться от полиции три раза за один заезд", "reward": 200, "icon": "ДПС"},
	{"id": "refuel", "name": "Пит-стоп", "desc": "Заправиться на ходу на АЗС «Канистра»", "reward": 60, "icon": "АЗС"},
	{"id": "cameras_3", "name": "Законопослушный", "desc": "Проехать три камеры без штрафа за один заезд", "reward": 120, "icon": "60"},
	{"id": "bridge", "name": "Через Иртыш", "desc": "Перепрыгнуть разведённый мост на нитро", "reward": 150, "icon": "↑"},
	{"id": "flood_dry", "name": "Сухим из воды", "desc": "Пройти половодье, не заехав ни в одну лужу", "reward": 150, "icon": "≈"},
	{"id": "loop_5", "name": "Омск не отпускает", "desc": "Доехать до пятого круга в Омске — он не отпускает", "reward": 300, "icon": "∞"},
	{"id": "omsk_map", "name": "Краевед", "desc": "Найти все достопримечательности на карте Омска", "reward": 200, "icon": "★"},
	{"id": "ghost", "name": "Быстрее себя", "desc": "Обогнать призрака своего рекорда", "reward": 150, "icon": "◆"},
	{"id": "daily", "name": "Заезд дня", "desc": "Проехать ежедневный заезд", "reward": 50, "icon": "Д"},
	{"id": "streak_7", "name": "Неделя за рулём", "desc": "Забирать награду за вход 7 дней подряд", "reward": 300, "icon": "7"},
	{"id": "tuned", "name": "Тюнингованный", "desc": "Прокачать любую деталь в гараже до максимума", "reward": 150, "icon": "5/5"},
	{"id": "cars_5", "name": "Автопарк", "desc": "Собрать в гараже пять машин", "reward": 200, "icon": "×5"},
	{"id": "cars_10", "name": "Автосалон", "desc": "Собрать в гараже десять машин", "reward": 500, "icon": "×10"},
	{"id": "all_tracks", "name": "Турист", "desc": "Открыть все трассы", "reward": 500, "icon": "◎"},
	{"id": "cow", "name": "Му-у-у!", "desc": "Встретиться с коровой в селе Кукуево. Близко", "reward": 40, "icon": "М"},
	{"id": "crush_10", "name": "Каток", "desc": "Раздавить 10 конусов и ям монстр-траком за один заезд", "reward": 200, "icon": "▼"},
	{"id": "tutorial", "name": "Курс молодого водителя", "desc": "Пройти обучение", "reward": 30, "icon": "У"},
	{"id": "weekly", "name": "Испытатель", "desc": "Выполнить первую цель испытания недели", "reward": 100, "icon": "Н"},
	{"id": "weekly_gold", "name": "Неделя на золото", "desc": "Выполнить все три цели испытания недели", "reward": 400, "icon": "3/3"},
	{"id": "level_10", "name": "Опытный водитель", "desc": "Дорасти до 10-го уровня водителя", "reward": 200, "icon": "10"},
	{"id": "level_30", "name": "Легенда дорог", "desc": "Дорасти до 30-го уровня водителя", "reward": 1000, "icon": "30"},
	{"id": "millionaire", "name": "Миллионер", "desc": "Потратить миллион монет. Говорят, есть один код…", "reward": 1, "icon": "₽₽"},
	{"id": "rival_win", "name": "Король района", "desc": "Обогнать Коляна на девятке в гонке на километр", "reward": 150, "icon": "9"},
	{"id": "passenger_3", "name": "Бомбила", "desc": "Довезти трёх пассажиров за один заезд", "reward": 200, "icon": "А"},
	{"id": "shield_save", "name": "Броня крепка", "desc": "Щит принял удар на себя", "reward": 40, "icon": "◈"},
	{"id": "hard_1000", "name": "Жёсткий режим", "desc": "Набрать 1000 очков на сложности «Жёстко»", "reward": 250, "icon": "!!"},
	{"id": "party", "name": "Кто дальше?", "desc": "Сыграть партию «Кто дальше» до конца", "reward": 80, "icon": "×4"},
	{"id": "challenge_win", "name": "Вызов принят", "desc": "Побить результат друга в заезде по коду", "reward": 120, "icon": "VS"},
	# v2.5
	{"id": "rail", "name": "Успел!", "desc": "Проскочить ж/д переезд перед самым поездом", "reward": 120, "icon": "Ж/Д"},
	{"id": "tow_10", "name": "Штрафстоянка", "desc": "Увезти эвакуатором 10 машин за один заезд", "reward": 200, "icon": "⚓"},
	{"id": "drift_10", "name": "Король заноса", "desc": "Сделать 10 управляемых заносов на раллийной «Ладе» за заезд", "reward": 200, "icon": "≋"},
	{"id": "metro_10", "name": "Вся ветка", "desc": "Проехать 10 станций метро за один заезд", "reward": 200, "icon": "М"},
	{"id": "bear", "name": "Хозяин тайги", "desc": "Встретиться с медведем. Лицом к лицу", "reward": 50, "icon": "Р-р"},
	{"id": "cars_20", "name": "Автомагнат", "desc": "Собрать в гараже двадцать машин", "reward": 1500, "icon": "×20"},
]

var run: Dictionary = {}          # счётчики текущего заезда
var _queue: Array = []            # плашки, ждущие показа
var _layer: CanvasLayer
var _popup: Control
var _popup_def: Dictionary = {}
var _popup_t: float = 0.0
const POPUP_TIME := 3.2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_popup = Control.new()
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.draw.connect(_draw_popup)
	_layer.add_child(_popup)
	start_run()


static func get_def(id: String) -> Dictionary:
	for d in LIST:
		if d.id == id:
			return d
	return {}


func is_unlocked(id: String) -> bool:
	return id in SaveManager.achievements


func unlocked_count() -> int:
	var n := 0
	for d in LIST:
		if is_unlocked(d.id):
			n += 1
	return n


func start_run() -> void:
	run = {"potholes": 0, "tck": 0, "police": 0, "cameras": 0, "crush": 0}


func unlock(id: String) -> void:
	if is_unlocked(id):
		return
	var def := get_def(id)
	if def.is_empty():
		return
	SaveManager.achievements.append(id)
	SaveManager.add_coins(int(def.reward))     # заодно сохраняет
	_queue.append(def)
	unlocked.emit(def)


## Событие из игры. amount — значение или прибавка (зависит от события)
func event(kind: String, amount: int = 1) -> void:
	var theme: String = GameData.get_location(SaveManager.selected_location).theme
	match kind:
		"run_finished":
			unlock("first_run")
		"score":
			if amount >= 1000 and SaveManager.difficulty_id() == "hard":
				unlock("hard_1000")
			if amount >= 1000:
				unlock("score_1000")
			if amount >= 5000:
				unlock("score_5000")
			if amount >= 500 and theme == "omsk" and run.potholes == 0:
				unlock("omsk_clean")
		"pothole":
			run.potholes += 1
		"combo":
			if amount >= 8:
				unlock("combo_8")
		"escape_tck":
			run.tck += 1
			if run.tck >= 3:
				unlock("tck_3")
		"escape":
			run.police += 1
			if run.police >= 3:
				unlock("police_3")
		"refuel":
			unlock("refuel")
		"camera_ok":
			run.cameras += 1
			if run.cameras >= 3:
				unlock("cameras_3")
		"bridge":
			unlock("bridge")
		"flood_dry":
			unlock("flood_dry")
		"omsk_loop":
			if amount >= 5:
				unlock("loop_5")
		"ghost":
			unlock("ghost")
		"daily_done":
			unlock("daily")
		"weekly_done":
			if amount >= 1:
				unlock("weekly")
			if amount >= 3:
				unlock("weekly_gold")
		"tutorial":
			unlock("tutorial")
		"cow":
			unlock("cow")
		"crush":
			run.crush += 1
			if run.crush >= 10:
				unlock("crush_10")
		"rival_win":
			unlock("rival_win")
		"passenger":
			run.passengers = int(run.get("passengers", 0)) + 1
			if run.passengers >= 3:
				unlock("passenger_3")
		"shield_save":
			unlock("shield_save")
		"party_done":
			unlock("party")
		"challenge_win":
			unlock("challenge_win")
		"rail":
			unlock("rail")
		"tow":
			run.tow = int(run.get("tow", 0)) + 1
			if run.tow >= 10:
				unlock("tow_10")
		"drift":
			run.drift = int(run.get("drift", 0)) + 1
			if run.drift >= 10:
				unlock("drift_10")
		"station":
			run.stations = int(run.get("stations", 0)) + 1
			if run.stations >= 10:
				unlock("metro_10")
		"bear":
			unlock("bear")
		"level":
			if amount >= 10:
				unlock("level_10")
			if amount >= 30:
				unlock("level_30")
	check_static()


## Достижения, которые зависят от сохранения, а не от заезда
func check_static() -> void:
	if SaveManager.omsk_seen.size() >= GameData.LANDMARKS.size():
		unlock("omsk_map")
	if SaveManager.owned_cars.size() >= 5:
		unlock("cars_5")
	if SaveManager.owned_cars.size() >= 10:
		unlock("cars_10")
	if SaveManager.owned_cars.size() >= 20:
		unlock("cars_20")
	if SaveManager.owned_locations.size() >= GameData.LOCATIONS.size():
		unlock("all_tracks")
	if SaveManager.coins_spent >= 1000000:
		unlock("millionaire")
	if SaveManager.login_streak >= 7:
		unlock("streak_7")
	if SaveManager.get_level() >= 10:
		unlock("level_10")
	if SaveManager.get_level() >= 30:
		unlock("level_30")
	for car_id in SaveManager.car_mods.keys():
		for up in GameData.UPGRADES:
			if int(SaveManager.car_mods[car_id].get(up.id, 0)) >= GameData.UPGRADE_MAX:
				unlock("tuned")
				return


# ---------------------------------------------------------------------------
# Плашка «Достижение открыто!»
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _popup_def.is_empty():
		if _queue.is_empty():
			return
		_popup_def = _queue.pop_front()
		_popup_t = 0.0
		Sound.play("record", -3.0, 1.25, 0.0)
	_popup_t += delta
	if _popup_t > POPUP_TIME:
		_popup_def = {}
	_popup.queue_redraw()


func _draw_popup() -> void:
	if _popup_def.is_empty():
		return
	var vs := _popup.get_viewport_rect().size
	var appear := clampf(_popup_t / 0.3, 0.0, 1.0)
	var vanish := clampf((POPUP_TIME - _popup_t) / 0.4, 0.0, 1.0)
	var a := minf(appear, vanish)
	var w := 420.0
	var h := 74.0
	var y := lerpf(-h, 64.0, ease(appear, -2.0)) if vanish >= 1.0 else 64.0 - (1.0 - vanish) * 40.0
	var r := Rect2(vs.x / 2.0 - w / 2.0, y - 56.0, w, h)
	Art.rrect(_popup, Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.35 * a), 14)
	Art.rrect(_popup, r, Color(Art.UI_PANEL, 0.96 * a), 14, 3, Color(Art.YELLOW, a))
	var c := r.position + Vector2(40, h / 2.0)
	_popup.draw_circle(c, 26, Color(Art.YELLOW, a))
	_popup.draw_circle(c, 21, Color(Art.ORANGE, a))
	Art.text_center(_popup, c, _popup_def.icon, 16 if _popup_def.icon.length() <= 2 else 11, Color(Art.INK, a), true)
	Art.text_center(_popup, Vector2(r.position.x + w / 2.0 + 24, r.position.y + 20), "ДОСТИЖЕНИЕ: " + _popup_def.name.to_upper(), 16, Color(Art.YELLOW, a), true)
	Art.text_center(_popup, Vector2(r.position.x + w / 2.0 + 24, r.position.y + 42), _popup_def.desc, 12, Color(Art.UI_TEXT, a))
	Art.text_center(_popup, Vector2(r.position.x + w / 2.0 + 24, r.position.y + 60), "+%d монет" % _popup_def.reward, 12, Color(Art.GREEN, a), true)
