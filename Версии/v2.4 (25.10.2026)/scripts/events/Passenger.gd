extends "res://scripts/events/RoadEvent.gd"
## Пассажир: на тротуаре справа голосует человек. Перестройтесь в правую полосу и
## сбросьте скорость в жёлтой зоне — он сядет. Довезите до остановки впереди и снова
## притормозите в зоне — получите монеты. Такси и маршрутке платят вдвое.
## Проскочили — пассажир обидится (или выйдет, ругаясь, без оплаты).

const LANE := Art.LANES - 1
const PICK_START := 560.0
const ZONE_LEN := 380.0
const MAX_KMH := 60.0
const RIDERS := [
	{"who": "Бабушка с рассадой", "hi": "«Внучок, до остановки «%s», только аккуратно — помидоры!»",
		"bye": "«Дай бог здоровья! Возьми огурчик»", "body": "8a5a9e", "head": "e8b48a", "cap": "d8d0c0"},
	{"who": "Студент с ноутбуком", "hi": "«До «%s», пожалуйста, у меня пара через пять минут!»",
		"bye": "«Успел! Ставлю пять звёзд»", "body": "3d6fc9", "head": "e8b48a", "cap": ""},
	{"who": "Мужик с удочкой", "hi": "«Шеф, до «%s». Клёв уходит!»",
		"bye": "«Держи, на бензин. Рыбу не дам»", "body": "4f7a4f", "head": "d9a07a", "cap": "6b6b4a"},
	{"who": "Девушка с собачкой", "hi": "«До «%s», и можно потише? Пуся боится скорости»",
		"bye": "«Пуся говорит спасибо»", "body": "e07a9a", "head": "f0c8a0", "cap": ""},
	{"who": "Курьер с коробкой", "hi": "«До «%s», и побыстрее — заказ горит!»",
		"bye": "«Курьер курьера выручил!»", "body": "f2c230", "head": "d9a07a", "cap": "2f3242"},
	{"who": "Дедушка в ушанке", "hi": "«Сынок, до «%s». Я в восемьдесят пятом так же гонял»",
		"bye": "«Хорошо водишь. Почти как я»", "body": "6b5a4a", "head": "e8b48a", "cap": "5a4a3a"},
]
const STOPS := ["Рынок", "Поликлиника", "ДК Строителей", "Гаражи", "Школа №5", "Конечная", "Баня",
	"Стадион", "Почта", "Улица Мира", "Автовокзал", "Хлебозавод"]
const STOPS_OMSK := ["Любинский проспект", "Телецентр", "Политех", "Рабочий городок", "Космический проспект"]

var drop_start: float = 3200.0
var rider: Dictionary = {}
var stop_name: String = ""
var state: String = "wait"       # wait → riding → paid / missed / left
var _wave: float = 0.0
var _board_t: float = 0.0         # анимация посадки
var _board_from: Vector2 = Vector2.ZERO


func _init() -> void:
	kind = "passenger"
	lanes_blocked = [LANE]
	max_age = 70.0


func setup(rng: RandomNumberGenerator, omsk: bool) -> void:
	drop_start = PICK_START + ZONE_LEN + rng.randf_range(2600.0, 3600.0)
	length = drop_start + ZONE_LEN + 220.0
	rider = RIDERS[rng.randi() % RIDERS.size()]
	var pool: Array = STOPS + (STOPS_OMSK if omsk else [])
	stop_name = pool[rng.randi() % pool.size()]


func start() -> void:
	toast("%s голосует у дороги! Правая полоса, тормози в жёлтой зоне" % rider.who, Art.YELLOW, 3.0)


func _zone(d0: float) -> Vector2:
	return Vector2(wy(d0), wy(d0 + ZONE_LEN))      # (низ, верх) в мировых y


func _in_zone(p, d0: float) -> bool:
	var z := _zone(d0)
	return p.global_position.x > lane_left(LANE) + 14.0 and p.global_position.y < z.x and p.global_position.y > z.y


func _slow(p) -> bool:
	return p.current_speed * KMH <= MAX_KMH


func pay() -> int:
	var base := 20 + int((drop_start - PICK_START) / 140.0)
	var k: String = GameData.get_car(SaveManager.selected_car).kind
	if k == "taxi" or k == "marshrutka":
		base *= 2
	return base


func _update(p, delta: float) -> void:
	_wave += delta
	_board_t = maxf(0.0, _board_t - delta)
	match state:
		"wait":
			if _in_zone(p, PICK_START) and _slow(p):
				state = "riding"
				_board_t = 0.6
				_board_from = Vector2(Art.ROAD_RIGHT + 22, wy(PICK_START + ZONE_LEN * 0.5)) - global_position
				Sound.play("pickup", -4.0, 0.9, 0.0)
				MobileInput.vibrate(30)
				toast("%s сел. %s" % [rider.who, rider.hi % stop_name], Art.TEAL, 3.4)
			elif p.global_position.y < _zone(PICK_START).y - 40.0:
				state = "left"
				toast("Проехали мимо! %s машет вслед и идёт пешком" % rider.who, Art.UI_MUTED, 2.4)
		"riding":
			if _in_zone(p, drop_start) and _slow(p):
				state = "paid"
				var coins := pay()
				SaveManager.add_coins(coins)
				Sound.play("coin", -2.0, 1.1, 0.0)
				Sound.play("coin", -6.0, 1.3, 0.0)
				Pickup.burst(p, Art.YELLOW, "+%d монет" % coins, "")
				add_score(25)
				Missions.event("passenger")
				var bonus := "  (двойной тариф!)" if coins > 20 + int((drop_start - PICK_START) / 140.0) else ""
				toast("Приехали! +%d монет%s %s" % [coins, bonus, rider.bye], Art.YELLOW, 3.2)
			elif p.global_position.y < _zone(drop_start).y - 40.0:
				state = "missed"
				toast("Проскочили остановку! Пассажир выходит, ругаясь, и не платит", Art.RED, 2.6)


func _is_done(p) -> bool:
	if state == "left" or state == "paid" or state == "missed":
		return true
	return super._is_done(p)


func hud_info(p) -> Dictionary:
	var y: float = p.global_position.y
	var kmh: float = p.current_speed * KMH
	match state:
		"wait":
			var dist: float = y - _zone(PICK_START).x
			if dist > 1300.0:
				return {}
			if dist > 0.0:
				return {"title": "Пассажир голосует", "text": "Правая полоса • жёлтая зона", "color": Art.YELLOW, "dist": dist * 0.1}
			var text := "Тормози до %d км/ч!" % int(MAX_KMH) if _in_zone(p, PICK_START) else "Правая полоса • жёлтая зона"
			return {"title": "Пассажир голосует", "text": text, "color": Art.YELLOW, "kmh": kmh, "limit": MAX_KMH, "show_speed": true}
		"riding":
			var dist2: float = y - _zone(drop_start).x
			if dist2 > 0.0:
				return {"title": "До остановки «%s»" % stop_name, "text": "Правая полоса • оплата %d монет" % pay(),
					"color": Art.TEAL, "dist": dist2 * 0.1}
			return {"title": "Остановка «%s»" % stop_name, "text": "Тормози в зоне до %d км/ч!" % int(MAX_KMH),
				"color": Art.TEAL, "kmh": kmh, "limit": MAX_KMH, "show_speed": true}
	return {}


func get_lights() -> Array:
	return [[Vector2(Art.ROAD_RIGHT + 30, wy(drop_start + ZONE_LEN * 0.5)), 150.0, 0.8]]


func _draw() -> void:
	# Зона посадки и зона высадки — жёлтые «карманы» на правой полосе
	if state == "wait":
		_draw_zone(PICK_START, "ТАКСИ?")
	if state == "wait" or state == "riding":
		_draw_zone(drop_start, "ОСТ.")
	# Остановка с навесом и табличкой
	var sy := -(drop_start + ZONE_LEN * 0.5)
	var shelter := Rect2(Art.ROAD_RIGHT + 14, sy - 70, 44, 140)
	Art.rrect(self, Rect2(shelter.position + Vector2(6, 8), shelter.size), Art.SHADOW, 6)
	Art.rrect(self, shelter, Color(0.75, 0.85, 0.95, 0.85), 6, 2, Color("6d7182"))
	draw_rect(Rect2(shelter.position.x, shelter.position.y, 8, shelter.size.y), Color("3d6fc9"))
	draw_plate(Rect2(Art.ROAD_RIGHT + 64, sy - 32, 62, 46), Color("f2f3f7"), "А\n" + stop_name.left(9), Color("3d6fc9"), 9, Color("3d6fc9"))
	# Пассажир: ждёт и машет рукой, потом «садится» в машину
	if state == "wait":
		var pos := Vector2(Art.ROAD_RIGHT + 22, -(PICK_START + ZONE_LEN * 0.5))
		var cap := Color(rider.cap) if rider.cap != "" else Color(0, 0, 0, 0)
		draw_person(pos, Color(rider.body), Color(rider.head), -PI / 2.0, cap)
		# Поднятая рука качается
		var a := -PI / 2.0 - 0.6 + sin(_wave * 9.0) * 0.5
		var hand := pos + Vector2(cos(a), sin(a)) * 24.0 + Vector2(-6, 0)
		draw_line(pos + Vector2(-6, -4), hand, Color(rider.body).darkened(0.1), 5.0, true)
		draw_circle(hand, 4.5, Color(rider.head))
		if int(_wave * 2.0) % 2 == 0:
			Art.text_center(self, pos + Vector2(-34, -36), "Эй!", 13, Art.YELLOW, true)
	elif _board_t > 0.0:
		var p = get_tree().get_first_node_in_group("player")
		if p:
			var k := 1.0 - _board_t / 0.6
			var to: Vector2 = p.global_position - global_position
			draw_person(_board_from.lerp(to, k), Color(rider.body), Color(rider.head), -PI / 2.0)
	# Те, кто ждёт на остановке (для красоты)
	draw_person(Vector2(Art.ROAD_RIGHT + 36, sy + 34), Color("7a7f92"), Color("e8b48a"), -PI / 2.0)


func _draw_zone(d0: float, label: String) -> void:
	var lx0 := lane_left(LANE) + 8.0
	var w := Art.LANE_W - 22.0
	var b := -d0
	var t := -(d0 + ZONE_LEN)
	draw_rect(Rect2(lx0, t, w, ZONE_LEN), Color(1.0, 0.82, 0.25, 0.16))
	var dy := t
	while dy < b:
		draw_rect(Rect2(lx0, dy, 5, minf(24.0, b - dy)), Art.YELLOW)
		draw_rect(Rect2(lx0 + w - 5, dy, 5, minf(24.0, b - dy)), Art.YELLOW)
		dy += 48.0
	draw_rect(Rect2(lx0, t, w, 5), Art.YELLOW)
	draw_rect(Rect2(lx0, b - 5, w, 5), Art.YELLOW)
	Art.text_center(self, Vector2(lx0 + w / 2.0, (t + b) / 2.0), label, 30, Color(1, 0.9, 0.4, 0.45), true)
	for k in 3:
		var cy := b + 70 + k * 46
		var cx := lerpf(lane_center(LANE - 1), lane_center(LANE), 0.55 + 0.15 * k)
		draw_polyline(PackedVector2Array([Vector2(cx - 22, cy + 12), Vector2(cx, cy - 6), Vector2(cx + 22, cy + 12)]),
			Color(Art.YELLOW, 0.7), 6.0, true)
