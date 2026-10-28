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
	{"id": "loop_5", "name": "Омск не отпускает", "desc": "Доехать до пятого круга в одноимённом режиме", "reward": 300, "icon": "∞"},
	{"id": "omsk_map", "name": "Краевед", "desc": "Найти все достопримечательности на карте Омска", "reward": 200, "icon": "★"},
	{"id": "ghost", "name": "Быстрее себя", "desc": "Обогнать призрака своего рекорда", "reward": 150, "icon": "◆"},
	{"id": "daily", "name": "Заезд дня", "desc": "Проехать ежедневный заезд", "reward": 50, "icon": "Д"},
	{"id": "streak_7", "name": "Неделя за рулём", "desc": "Забирать награду за вход 7 дней подряд", "reward": 300, "icon": "7"},
	{"id": "tuned", "name": "Тюнингованный", "desc": "Прокачать любую деталь в гараже до максимума", "reward": 150, "icon": "5/5"},
	{"id": "cars_5", "name": "Автопарк", "desc": "Собрать в гараже пять машин", "reward": 200, "icon": "×5"},
	{"id": "tutorial", "name": "Курс молодого водителя", "desc": "Пройти обучение", "reward": 30, "icon": "У"},
	{"id": "weekly", "name": "Испытатель", "desc": "Выполнить первую цель испытания недели", "reward": 100, "icon": "Н"},
	{"id": "weekly_gold", "name": "Неделя на золото", "desc": "Выполнить все три цели испытания недели", "reward": 400, "icon": "3/3"},
	{"id": "level_10", "name": "Опытный водитель", "desc": "Дорасти до 10-го уровня водителя", "reward": 200, "icon": "10"},
	{"id": "level_30", "name": "Легенда дорог", "desc": "Дорасти до 30-го уровня водителя", "reward": 1000, "icon": "30"},
	{"id": "millionaire", "name": "Миллионер", "desc": "Потратить миллион монет. Говорят, есть один код…", "reward": 1, "icon": "₽₽"},
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
	run = {"potholes": 0, "tck": 0, "police": 0, "cameras": 0}


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
