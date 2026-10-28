extends "res://scripts/events/RoadEvent.gd"
## АЗС «Канистра» на обочине.
## Перед заправкой правая полоса размечена «карманом». Перестройтесь в неё и
## сбросьте скорость в зоне — заправщик успеет залить полный бак прямо на ходу.

const LANE := Art.LANES - 1
const BAY_START := 560.0          # от начала события до начала зоны заправки
const BAY_LEN := 520.0
const MAX_KMH := 60.0             # медленнее этого — успеваем заправиться
const LOT_X := Art.ROAD_RIGHT + 6.0

var done: bool = false
var _tried: bool = false
var _missed: bool = false
var _hose_t: float = 0.0
var _refuel_pos: float = 0.0


func _init() -> void:
	kind = "station"
	length = BAY_START + BAY_LEN + 260.0
	lanes_blocked = [LANE]


func start() -> void:
	toast("Впереди АЗС «Канистра»: правая полоса, тормози в зоне", Art.ORANGE, 2.8)


func _bay_bottom() -> float:
	return wy(BAY_START)


func _bay_top() -> float:
	return wy(BAY_START + BAY_LEN)


func _in_lane(p) -> bool:
	return p.global_position.x > lane_left(LANE) + 14.0


func _update(p, delta: float) -> void:
	_hose_t = maxf(0.0, _hose_t - delta)
	var y: float = p.global_position.y
	var in_bay: bool = _in_lane(p) and y < _bay_bottom() and y > _bay_top()
	if in_bay:
		_tried = true
	if not done and in_bay and p.current_speed * KMH <= MAX_KMH:
		_refuel(p)
	if not done and not _missed and _tried and y < _bay_top():
		_missed = true
		toast("Проскочили! На АЗС нужно сбросить скорость до %d км/ч" % int(MAX_KMH), Art.RED, 2.4)


func _refuel(p) -> void:
	done = true
	_hose_t = 1.2
	_refuel_pos = global_position.y - p.global_position.y
	p.add_fuel(p.max_fuel)
	Sound.play("fuel", 0.0, 1.0, 0.0)
	Sound.play("coin", -6.0, 1.2, 0.0)
	Pickup.burst(p, Art.ORANGE, "Полный бак!", "")
	MobileInput.vibrate(40)
	add_score(30)
	Missions.event("refuel")
	var old: float = manager.fuel_price if manager else 62.4
	var price := old + randf_range(3.0, 9.0)
	if manager:
		manager.fuel_price = price
	toast("Заправились! А АИ-95 тем временем подорожал до %s ₽" % _rub(price), Art.ORANGE, 2.6)


static func _rub(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


func hud_info(p) -> Dictionary:
	if done or p.global_position.y < _bay_top():
		return {}
	var dist: float = p.global_position.y - _bay_bottom()
	if dist > 1100.0:
		return {}
	var in_bay: bool = dist < 0.0
	var kmh: float = p.current_speed * KMH
	var text := "Тормози до %d км/ч!" % int(MAX_KMH) if in_bay and _in_lane(p) else "Правая полоса • тормози в зоне до %d км/ч" % int(MAX_KMH)
	return {"title": "АЗС «Канистра»", "text": text, "color": Art.ORANGE, "icon": "fuel",
		"kmh": kmh, "limit": MAX_KMH, "show_speed": in_bay}


func get_lights() -> Array:
	var mid := wy(BAY_START + BAY_LEN * 0.5)
	return [[Vector2(lane_center(LANE), mid), 190.0, 0.8], [Vector2(1040, mid), 240.0, 1.0],
		[Vector2(Art.ROAD_RIGHT + 70, wy(BAY_START - 120)), 120.0, 0.9]]


func _draw() -> void:
	var lot_top := -(BAY_START + BAY_LEN + 170.0)
	var lot_bottom := -(BAY_START - 170.0)
	var bay_b := -BAY_START
	var bay_t := -(BAY_START + BAY_LEN)
	var lx0 := lane_left(LANE)
	var lx1 := lane_right(LANE)

	# --- Территория АЗС (перекрывает квартал справа) ---
	var lot := Rect2(LOT_X, lot_top, 1800.0, lot_bottom - lot_top)
	draw_rect(lot, Color("8a8fa0"))
	draw_rect(Rect2(LOT_X, lot_top, 1800.0, 6), Art.CURB)
	draw_rect(Rect2(LOT_X, lot_bottom - 6, 1800.0, 6), Art.CURB)
	# Разметка стоянки
	var y := lot_top + 40.0
	while y < lot_bottom - 40.0:
		draw_line(Vector2(LOT_X + 50, y), Vector2(LOT_X + 90, y), Color(1, 1, 1, 0.35), 3.0)
		y += 60.0
	# Островки с колонками у самой дороги, вдоль «кармана»
	for i in 3:
		var py := bay_b - BAY_LEN * (0.2 + 0.3 * i)
		var isl := Rect2(LOT_X + 8, py - 34, 30, 68)
		Art.rrect(self, Rect2(isl.position + Vector2(4, 6), isl.size), Art.SHADOW, 6)
		Art.rrect(self, isl, Art.CURB, 6, 2, Color("6d7182"))
		Art.rrect(self, Rect2(LOT_X + 13, py - 20, 20, 40), Art.ORANGE, 4, 2, Art.ORANGE.darkened(0.4))
		draw_rect(Rect2(LOT_X + 16, py - 14, 14, 9), Color("1b2a3a"))
		draw_rect(Rect2(LOT_X + 18, py - 12, 10, 5), Art.TEAL if done else Art.GREEN)
		draw_circle(Vector2(LOT_X + 23, py + 10), 3.5, Art.INK)
	# Навес над колонками и магазин
	var canopy := Rect2(LOT_X + 52, bay_t + 30, 172, BAY_LEN - 60)
	Art.rrect(self, Rect2(canopy.position + Vector2(10, 14), canopy.size), Art.SHADOW, 10)
	Art.rrect(self, canopy, Color("f2f3f7"), 10, 3, Color("c9cdd6"))
	draw_rect(Rect2(canopy.position.x, canopy.position.y, canopy.size.x, 16), Art.ORANGE)
	draw_rect(Rect2(canopy.position.x, canopy.end.y - 16, canopy.size.x, 16), Art.ORANGE)
	Art.text_center(self, canopy.get_center() + Vector2(0, -14), "КАНИСТРА", 22, Art.ORANGE.darkened(0.15), true)
	Art.text_center(self, canopy.get_center() + Vector2(0, 16), "АЗС 24/7", 14, Color("6d7182"), true)
	var shop := Rect2(LOT_X + 52, lot_top + 20, 172, 110)
	Art.rrect(self, Rect2(shop.position + Vector2(8, 10), shop.size), Art.SHADOW, 6)
	Art.rrect(self, shop, Color("5b6c8f"), 6, 2, Color("3e4a63"))
	draw_rect(Rect2(shop.position.x + 20, shop.position.y + 30, shop.size.x - 40, 30), Color("3e4a63"))
	Art.text_center(self, shop.get_center() + Vector2(0, -10), "ШАУРМА • КОФЕ", 12, Art.YELLOW, true)

	# --- Стела с ценами ---
	var stela := Rect2(Art.ROAD_RIGHT + 50, bay_b + 70, 74, 92)
	Art.rrect(self, Rect2(stela.position + Vector2(6, 8), stela.size), Art.SHADOW, 6)
	Art.rrect(self, stela, Color("20232f"), 6, 2, Art.ORANGE)
	Art.text_center(self, stela.position + Vector2(37, 12), "КАНИСТРА", 9, Art.ORANGE, true)
	var price: float = manager.fuel_price if manager else 62.4
	var rows := [["95", price], ["92", price - 4.3], ["ДТ", price + 6.1]]
	for i in rows.size():
		var ry: float = stela.position.y + 32 + i * 20
		Art.text_center(self, Vector2(stela.position.x + 16, ry), rows[i][0], 10, Art.UI_MUTED, true)
		Art.text_center(self, Vector2(stela.position.x + 48, ry), _rub(rows[i][1]), 11, Art.YELLOW, true)

	# --- Знак «АЗС» заранее ---
	var sign_pos := Vector2(Art.ROAD_RIGHT + 24, -20)
	draw_plate(Rect2(sign_pos - Vector2(20, 26), Vector2(40, 52)), Art.BLUE, "АЗС\n500м", Art.LINE_WHITE, 9)

	# --- «Карман» на правой полосе ---
	var bay := Rect2(lx0 + 8, bay_t, lx1 - lx0 - 22, BAY_LEN)
	draw_rect(bay, Color(1.0, 0.54, 0.24, 0.16 if not done else 0.08))
	var dash := 26.0
	var dy := bay_t
	while dy < bay_b:
		draw_rect(Rect2(bay.position.x, dy, 5, minf(dash, bay_b - dy)), Art.LINE_WHITE)
		dy += dash * 2.0
	draw_rect(Rect2(bay.position.x, bay_t, bay.size.x, 5), Art.LINE_WHITE)
	draw_rect(Rect2(bay.position.x, bay_b - 5, bay.size.x, 5), Art.LINE_WHITE)
	# Шевроны перед карманом — «сюда!»
	for k in 3:
		var cy := bay_b + 70 + k * 46
		var cx := lerpf(lane_center(LANE - 1), lane_center(LANE), 0.55 + 0.15 * k)
		var pts := PackedVector2Array([Vector2(cx - 22, cy + 12), Vector2(cx, cy - 6), Vector2(cx + 22, cy + 12)])
		draw_polyline(pts, Color(Art.YELLOW, 0.75), 6.0, true)
	var paint := Color(1, 1, 1, 0.55)
	Art.text_center(self, Vector2(bay.get_center().x, bay_b - 50), "ТОРМОЗИ", 20, paint, true)
	Art.text_center(self, Vector2(bay.get_center().x, bay.get_center().y), "АЗС", 46, Color(1, 1, 1, 0.35), true)
	# Заправщик с пистолетом у края кармана
	var man_y := bay_b - BAY_LEN * 0.5
	draw_person(Vector2(Art.ROAD_RIGHT + 20, man_y), Art.ORANGE, Color("e8b48a"), -PI / 2.0, Color("2f3242"))
	if _hose_t > 0.0:
		var target := Vector2(lane_center(LANE) + 20, -_refuel_pos)
		draw_line(Vector2(Art.ROAD_RIGHT + 14, man_y), target, Color("20232f"), 5.0, true)
		Art.glow(self, target, 40, Color(Art.ORANGE, 0.5 * _hose_t))
