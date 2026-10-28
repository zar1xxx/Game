extends Node2D
## Один «ряд» города по обеим сторонам дороги.
## Виды кварталов: дома, небоскрёб с вертолётной площадкой, парк, парковка,
## АЗС, стройка с краном и перекрёсток (переход, светофоры, машины на боковой улице).
## Всё рисуется кодом в общем стиле Art.gd и анимируется.

var h: float = 200.0
var intersection: bool = false
var sides: Array = []      # [левая сторона, правая сторона] — словари с деталями
var t: float = 0.0
var _frame: int = 0
var _rng := RandomNumberGenerator.new()
var _reported: bool = false
var _salt: int = 0               # сдвиг, чтобы соседние кварталы перерисовывались в разные кадры
var _lights_cache = null        # огни квартала для ночного освещения (считаются один раз)
var _animated: bool = true       # есть ли в квартале заметная анимация (машины, вода, краны…)

## Обычные дома, парки и стоянки рисуются один раз: их мелкая анимация (вентиляторы,
## покачивание деревьев) на скорости незаметна, а перерисовка квартала — самая дорогая
## операция в игре. Анимируются перекрёстки, стройки, АЗС, вода и достопримечательности.
const STATIC_KINDS := ["building", "park", "parking", "lot", "field", "haystacks", "sand", "rocks", "dunes"]


func setup(height: float, is_intersection: bool, seed_value: int) -> void:
	h = height
	intersection = is_intersection
	_rng.seed = seed_value
	t = _rng.randf() * 10.0
	_salt = seed_value & 7
	for side in [-1, 1]:
		sides.append(_make_side(side))
	# Омск: иногда дорога идёт по Ленинградскому мосту через Иртыш
	if Art.theme == "omsk" and not intersection and h >= 200 and _rng.randf() < 0.1:
		for d in sides:
			d.kind = "bridge"
			d.omsk_sign = false

	_animated = intersection or Art.theme == "neon"
	for d in sides:
		if not d.kind in STATIC_KINDS:
			_animated = true


func _side_rect(side: int) -> Rect2:
	# Чуть шире экрана, чтобы тряска камеры не открывала пустоту
	if side < 0:
		return Rect2(-80, 0, Art.CITY_LEFT_END + 80, h)
	return Rect2(Art.CITY_RIGHT_START, 0, Art.VIEW_W - Art.CITY_RIGHT_START + 80, h)


## Полоса за пределами 16:9 (до 420 пикселей в каждую сторону)
func _far_rect(side: int) -> Rect2:
	if side < 0:
		return Rect2(-500, 0, 420, h)
	return Rect2(Art.VIEW_W + 80, 0, 420, h)


func _make_side(side: int) -> Dictionary:
	var d := {"side": side, "rect": _side_rect(side), "far": _far_rect(side), "far_blocks": []}
	# Дальние дома за краем экрана 16:9 — видны на широких экранах телефонов
	var far: Rect2 = d.far
	var fy := 8.0
	while fy < h - 40.0:
		var bh := minf(_rng.randf_range(90.0, 200.0), h - 8.0 - fy)
		var bw := _rng.randf_range(150.0, 260.0)
		var bx := far.end.x - bw - 12.0 if side < 0 else far.position.x + 12.0
		d.far_blocks.append({"rect": Rect2(bx, fy, bw, bh),
			"color": Art.ROOF_COLORS[_rng.randi() % Art.ROOF_COLORS.size()]})
		fy += bh + 14.0
	if intersection:
		d.kind = "street"
		d.cars = []
		for i in _rng.randi_range(1, 2):
			d.cars.append({
				"x": _rng.randf() * 340.0 - i * 120.0, "speed": _rng.randf_range(60, 120),
				"color": Art.ENEMY_COLORS[_rng.randi() % Art.ENEMY_COLORS.size()],
			})
		return d
	if Art.theme == "desert":
		return _make_desert_side(d, side)
	if Art.theme == "village":
		return _make_village_side(d, side)
	if Art.theme == "beach":
		return _make_beach_side(d, side)
	if Art.theme == "mountain":
		return _make_mountain_side(d, side)
	# Омск: табличка «Омск 0 км» у дороги и достопримечательности вместо части кварталов
	d.omsk_sign = Art.theme == "omsk" and _rng.randf() < 0.22
	if Art.theme == "omsk" and _rng.randf() < 0.42 and h >= 200:
		return _make_omsk_side(d, side)
	var kinds := ["building", "building", "building", "tower", "park", "parking", "gas", "construction"]
	d.kind = kinds[_rng.randi() % kinds.size()]
	if d.kind == "gas" and h < 230:
		d.kind = "building"
	var r: Rect2 = d.rect
	var inner := Rect2(r.position + Vector2(10, 10), r.size - Vector2(20, 20))
	if side < 0:
		inner = Rect2(Vector2(r.position.x + 70, 10), Vector2(r.size.x - 84, h - 20))
	else:
		inner = Rect2(Vector2(r.position.x + 14, 10), Vector2(r.size.x - 94, h - 20))
	d.inner = inner
	match d.kind:
		"building", "tower":
			d.buildings = []
			var count := 1 if d.kind == "tower" or h < 240 else 2
			var y := inner.position.y
			for i in count:
				var bh := (inner.size.y - 12 * (count - 1)) / count
				var b := Rect2(inner.position.x, y, inner.size.x, bh)
				var bd := {
					"rect": b,
					"color": Art.ROOF_COLORS[_rng.randi() % Art.ROOF_COLORS.size()],
					"ac": [], "tank": null, "antenna": null, "phase": _rng.randf() * TAU,
					"neon": [Color("ff4fd8"), Color("6ff2ff"), Color("ffe66d"), Color("7dff8a")][_rng.randi() % 4],
					"sign": ["БАР", "24/7", "КИНО", "ОТЕЛЬ", "СУШИ", "КАРАОКЕ", "ПИЦЦА", "ШИНОМОНТАЖ"][_rng.randi() % 8],
				}
				for k in _rng.randi_range(1, 3):
					bd.ac.append(Vector2(_rng.randf_range(b.position.x + 22, b.end.x - 22),
						_rng.randf_range(b.position.y + 22, b.end.y - 22)))
				if _rng.randf() < 0.5:
					bd.tank = Vector2(_rng.randf_range(b.position.x + 26, b.end.x - 26),
						_rng.randf_range(b.position.y + 26, b.end.y - 26))
				if _rng.randf() < 0.6:
					bd.antenna = Vector2(b.end.x - 16, b.position.y + 16) if side < 0 else Vector2(b.position.x + 16, b.position.y + 16)
				d.buildings.append(bd)
				y += bh + 12
		"park":
			d.trees = []
			for i in _rng.randi_range(4, 8):
				d.trees.append({
					"pos": Vector2(_rng.randf_range(inner.position.x + 16, inner.end.x - 16),
						_rng.randf_range(inner.position.y + 16, inner.end.y - 16)),
					"r": _rng.randf_range(16, 28),
					"color": Art.TREE_COLORS[_rng.randi() % Art.TREE_COLORS.size()],
					"phase": _rng.randf() * TAU,
				})
			d.fountain = _rng.randf() < 0.5
			d.fountain_pos = inner.get_center()
		"parking":
			d.cars = []
			var rows := int(inner.size.y / 50.0)
			for i in rows:
				if _rng.randf() < 0.7:
					d.cars.append({
						"pos": Vector2(inner.get_center().x + _rng.randf_range(-10, 10), inner.position.y + 25 + i * 50),
						"color": Art.ENEMY_COLORS[_rng.randi() % Art.ENEMY_COLORS.size()],
						"hazard": _rng.randf() < 0.15,
						"flip": _rng.randf() < 0.5,
					})
		"construction":
			d.crane = inner.get_center() + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-30, 30))
			d.crane_speed = _rng.randf_range(0.15, 0.35) * (1 if _rng.randf() < 0.5 else -1)
			d.piles = []
			for i in 4:
				d.piles.append(Rect2(_rng.randf_range(inner.position.x, inner.end.x - 40),
					_rng.randf_range(inner.position.y, inner.end.y - 24), _rng.randf_range(24, 44), _rng.randf_range(14, 24)))
		"gas":
			d.price = "%.1f" % _rng.randf_range(54.0, 69.0)
	return d


## Пустыня: дюны, кактусы, скалы, нефтяные качалки и мотель
func _make_desert_side(d: Dictionary, side: int) -> Dictionary:
	var r: Rect2 = d.rect
	var inner := Rect2(Vector2(r.position.x + 70, 10), Vector2(r.size.x - 84, h - 20)) if side < 0 \
		else Rect2(Vector2(r.position.x + 14, 10), Vector2(r.size.x - 94, h - 20))
	d.inner = inner
	var kinds := ["dunes", "cactus", "cactus", "rocks", "pumpjack", "motel", "dunes"]
	d.kind = kinds[_rng.randi() % kinds.size()]
	if d.kind == "motel" and h < 220:
		d.kind = "cactus"
	d.items = []
	for i in _rng.randi_range(3, 6):
		d.items.append({
			"pos": Vector2(_rng.randf_range(inner.position.x, inner.end.x), _rng.randf_range(inner.position.y, inner.end.y)),
			"size": _rng.randf_range(0.7, 1.3), "phase": _rng.randf() * TAU,
		})
	d.pump = inner.get_center()
	return d


## Омские достопримечательности (по мотивам; всё нарисовано кодом)
func _make_omsk_side(d: Dictionary, side: int) -> Dictionary:
	var r: Rect2 = d.rect
	var inner := Rect2(Vector2(r.position.x + 70, 10), Vector2(r.size.x - 84, h - 20)) if side < 0 \
		else Rect2(Vector2(r.position.x + 14, 10), Vector2(r.size.x - 94, h - 20))
	d.inner = inner
	var kinds := ["npz", "tara", "metro", "lyubochka", "stepanych", "irtysh", "sobor", "drama", "dostoevsky"]
	d.kind = kinds[_rng.randi() % kinds.size()]
	d.phase = _rng.randf() * TAU
	d.boat_speed = _rng.randf_range(10.0, 22.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	d.tanks = []
	for i in 3:
		d.tanks.append(Vector2(inner.position.x + inner.size.x * (0.3 + 0.4 * (i % 2)),
			inner.position.y + inner.size.y * (0.22 + 0.3 * i)))
	return d


func _roof_color(col: Color) -> Color:
	match Art.theme:
		"winter":
			return col.lerp(Color("eef3f8"), 0.8)
		"rain":
			return col.darkened(0.3)
		"neon":
			return Color("23233a").lerp(col, 0.15)
	return col


func _tree_color(col: Color) -> Color:
	return col.lerp(Color("f2f6fa"), 0.7) if Art.theme == "winter" else col


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("city")


## Источники света квартала для ночного освещения (WorldFX): [позиция, радиус, яркость]
func get_lights() -> Array:
	# Квартал не двигается — список огней считается один раз
	if _lights_cache != null:
		return _lights_cache
	var out: Array = []
	_lights_cache = out
	for d in sides:
		match d.kind:
			"building", "tower":
				for b in d.buildings:
					var r: Rect2 = b.rect
					if Art.theme == "neon":
						out.append([position + r.get_center(), 170.0, 0.8])
					elif b.antenna != null:
						out.append([position + b.antenna, 40.0, 0.5])
					if d.kind == "tower":
						out.append([position + r.get_center(), 110.0, 0.6])
			"gas":
				var inner: Rect2 = d.inner
				out.append([position + inner.get_center(), 190.0, 0.9])
			"motel":
				var inner: Rect2 = d.inner
				out.append([position + Vector2(inner.get_center().x, inner.position.y + 14), 140.0, 0.8])
			"street":
				for car in d.cars:
					pass
			"parking", "park":
				out.append([position + d.inner.get_center(), 90.0, 0.35])
			"npz":
				var inner: Rect2 = d.inner
				out.append([position + inner.position + Vector2(18, 18), 150.0, 0.9])
				out.append([position + Vector2(inner.end.x - 18, inner.end.y - 18), 150.0, 0.9])
			"metro", "tara", "lyubochka", "stepanych":
				out.append([position + d.inner.get_center(), 120.0, 0.6])
			"izba":
				out.append([position + d.house.get_center(), 110.0, 0.55])
			"resort", "cafe":
				out.append([position + d.inner.get_center(), 150.0, 0.75])
			"pier":
				out.append([position + d.inner.get_center(), 80.0, 0.5])
	return out


func _process(delta: float) -> void:
	t += delta
	if not _reported and Art.theme == "omsk":
		_report_landmarks()
	for d in sides:
		if d.kind == "street":
			for car in d.cars:
				car.x = fmod(car.x + car.speed * delta, 340.0)
	# Анимации квартала перерисовываются только пока он на экране и не каждый кадр:
	# полная перерисовка квартала — самая тяжёлая операция в игре.
	# На слабых телефонах (качество «экономия») кварталы рисуются один раз и не анимируются.
	var stride := Art.city_anim_stride()
	if stride <= 0 or not _animated:
		return
	_frame += 1
	if (_frame + _salt) % stride != 0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam:
		var cy := cam.global_position.y
		var half := Art.VIEW_H / 2.0 + 40.0
		if global_position.y > cy + half or global_position.y + h < cy - half:
			return
	queue_redraw()


# ---------------------------------------------------------------------------
# Рисование
# ---------------------------------------------------------------------------
func _draw() -> void:
	for d in sides:
		_draw_far(d)
		match d.kind:
			"street":
				_draw_street(d)
			"building":
				_draw_lot(d)
				_draw_buildings(d, 1.0)
			"tower":
				_draw_lot(d)
				_draw_buildings(d, 2.2)
			"park":
				_draw_park(d)
			"parking":
				_draw_parking(d)
			"gas":
				_draw_gas(d)
			"construction":
				_draw_construction(d)
			"dunes", "cactus", "rocks", "pumpjack", "motel":
				_draw_desert(d)
			"npz", "tara", "metro", "lyubochka", "stepanych", "irtysh", "sobor", "drama", "dostoevsky":
				_draw_omsk(d)
			"bridge":
				_draw_bridge_side(d)
			"izba", "field", "pasture", "pond", "haystacks":
				_draw_village(d)
			"resort", "cafe", "sand", "pier":
				_draw_beach(d)
			"cliff", "valley":
				_draw_mountain(d)
		if d.get("omsk_sign", false):
			_draw_omsk_sign(d)
	if intersection:
		_draw_crosswalk()


func _draw_lot(d: Dictionary) -> void:
	draw_rect(d.rect, Art.pal("lot"))
	# Узкий газон вдоль тротуара
	var r: Rect2 = d.rect
	if d.side < 0:
		draw_rect(Rect2(r.end.x - 12, 0, 12, h), Art.pal("grass"))
	else:
		draw_rect(Rect2(r.position.x, 0, 12, h), Art.pal("grass"))


func _draw_buildings(d: Dictionary, height_factor: float) -> void:
	for b in d.buildings:
		var r: Rect2 = b.rect
		var col: Color = _roof_color(b.color)
		# Тень тем длиннее, чем выше здание
		draw_rect(Rect2(r.position + Vector2(10, 12) * height_factor, r.size), Color(0, 0, 0, 0.35))
		Art.rrect(self, r, col, 4, 5, col.darkened(0.3))
		# Полосы на крыше
		var yy := r.position.y + 14
		while yy < r.end.y - 10:
			draw_line(Vector2(r.position.x + 8, yy), Vector2(r.end.x - 8, yy), col.darkened(0.08), 2.0)
			yy += 18
		if height_factor > 1.5:
			# Вертолётная площадка с бегущими огнями
			var c := r.get_center()
			var rad := minf(r.size.x, r.size.y) * 0.3
			draw_circle(c, rad, Color("2a2e3d"))
			draw_arc(c, rad - 4, 0, TAU, 32, Art.YELLOW, 3.0)
			Art.text_center(self, c, "H", int(rad * 0.9), Art.LINE_WHITE, true)
			for i in 8:
				var a := TAU * i / 8.0
				var on := int(t * 8.0) % 8 == i
				var p := c + Vector2(cos(a), sin(a)) * (rad + 8)
				draw_circle(p, 3.5, Art.YELLOW if on else Color("5a5030"))
				if on:
					Art.glow(self, p, 14, Color(1, 0.8, 0.3, 0.5), 4)
		else:
			# Кондиционеры с крутящимися вентиляторами
			for p in b.ac:
				Art.rrect(self, Rect2(p - Vector2(13, 13), Vector2(26, 26)), Color("b7bcc8"), 3, 2, Color("8a8f9c"))
				draw_circle(p, 9, Color("70757f"))
				var ang: float = t * 9.0 + b.phase
				for k in 3:
					var a := ang + TAU * k / 3.0
					draw_line(p, p + Vector2(cos(a), sin(a)) * 8, Color("d8dbe2"), 3.0)
			if b.tank != null:
				var tp: Vector2 = b.tank
				draw_circle(tp + Vector2(4, 5), 15, Color(0, 0, 0, 0.3))
				draw_circle(tp, 15, Color("8b6f5a"))
				draw_arc(tp, 11, 0, TAU, 20, Color("6e5646"), 2.0)
		if Art.theme == "neon":
			var nc: Color = b.neon
			var flick := 0.75 + 0.25 * sin(t * 7.0 + b.phase) if fmod(t + b.phase, 5.0) > 0.15 else 0.2
			draw_rect(r.grow(-4), Color(nc, 0.9 * flick), false, 3.0)
			Art.glow(self, r.get_center(), maxf(r.size.x, r.size.y) * 0.7, Color(nc, 0.14 * flick))
			var sp := Vector2(r.get_center().x, r.position.y + 26)
			Art.rrect(self, Rect2(sp - Vector2(62, 14), Vector2(124, 28)), Color(0.05, 0.05, 0.1, 0.9), 6, 2, Color(nc, flick))
			Art.text_center(self, sp, b.sign, 14, Color(nc, flick), true)
		if b.antenna != null:
			var ap: Vector2 = b.antenna
			draw_circle(ap, 4, Art.INK)
			if sin(t * 3.0 + b.phase) > 0.55:
				Art.glow(self, ap, 18, Color(1, 0.2, 0.2, 0.6), 5)
				draw_circle(ap, 3, Art.BRAKELIGHT)


func _draw_park(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	draw_rect(r, Art.pal("grass") if Art.theme != "city" else Art.GRASS)
	var inner: Rect2 = d.inner
	# Дорожка
	draw_rect(Rect2(inner.get_center().x - 9, 0, 18, h), Color("8f866f"))
	if d.fountain and Art.theme == "winter":
		# Зимой вместо фонтана — каток с катающимися человечками
		var c: Vector2 = d.fountain_pos
		draw_circle(c, 34, Color("9fc7e8"))
		draw_arc(c, 34, 0, TAU, 32, Color("eef3f8"), 3.0)
		for k in 3:
			var a := t * (0.8 + k * 0.3) + k * 2.0
			var sp := c + Vector2(cos(a), sin(a)) * (12.0 + k * 7.0)
			draw_circle(sp, 4.5, [Art.RED, Art.BLUE, Art.ORANGE][k])
	elif d.fountain:
		var c: Vector2 = d.fountain_pos
		draw_circle(c, 30, Color("8a8fa0"))
		draw_circle(c, 25, Color("3b6f9e"))
		for k in 3:
			var rr := fmod(t * 12.0 + k * 8.0, 24.0)
			draw_arc(c, rr, 0, TAU, 24, Color(0.8, 0.9, 1.0, 0.6 * (1.0 - rr / 24.0)), 2.0)
		draw_circle(c, 4, Color("d6e6f5"))
	for tr in d.trees:
		var sway := Vector2(sin(t * 1.4 + tr.phase), cos(t * 1.1 + tr.phase)) * 2.0
		var p: Vector2 = tr.pos
		var rad: float = tr.r
		var col: Color = _tree_color(tr.color)
		draw_circle(p + Vector2(7, 9), rad, Color(0, 0, 0, 0.3))
		draw_circle(p + sway, rad, col)
		draw_circle(p + sway + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.5, col.lightened(0.15))


func _draw_parking(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	draw_rect(r, Art.pal("lot").lightened(0.07))
	var inner: Rect2 = d.inner
	var y := inner.position.y
	while y <= inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(1, 1, 1, 0.35), 2.0)
		y += 50
	for c in d.cars:
		var ang := PI / 2.0 if c.flip else -PI / 2.0
		Art.draw_car(self, 64, 32, c.color, {
			"base": Transform2D(ang, c.pos), "hazard": c.hazard, "time": t})


func _draw_gas(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	draw_rect(r, Color("4a4e60") if Art.theme != "winter" else Color("c9d3de"))
	var inner: Rect2 = d.inner
	# Колонки и машина на заправке
	var pump_x := inner.get_center().x
	for i in 2:
		var py := inner.position.y + inner.size.y * (0.35 + 0.3 * i)
		Art.rrect(self, Rect2(pump_x - 8, py - 14, 16, 28), Art.SILVER, 3, 2, Color("8a8f9c"))
		draw_rect(Rect2(pump_x - 5, py - 9, 10, 6), Art.ORANGE)
	Art.draw_car(self, 66, 34, Art.ENEMY_COLORS[int(abs(r.position.x)) % Art.ENEMY_COLORS.size()],
		{"base": Transform2D(0, Vector2(pump_x + 42 * d.side * -1, inner.get_center().y))})
	# Навес
	var canopy := Rect2(inner.position.x + 4, inner.position.y + 24, inner.size.x - 8, inner.size.y - 70)
	draw_rect(Rect2(canopy.position + Vector2(10, 12), canopy.size), Color(0, 0, 0, 0.3))
	Art.rrect(self, canopy, Color(0.85, 0.87, 0.92, 0.92), 6, 6, Art.ORANGE)
	# Вывеска с ценой бензина (мигает)
	var sign_pos := Vector2(inner.get_center().x, inner.end.y - 18)
	Art.rrect(self, Rect2(sign_pos - Vector2(46, 18), Vector2(92, 36)), Art.INK, 6, 2, Art.ORANGE)
	if fmod(t, 2.0) < 1.6:
		Art.text_center(self, sign_pos + Vector2(0, -6), "АЗС", 13, Art.ORANGE, true)
		Art.text_center(self, sign_pos + Vector2(0, 8), d.price, 12, Art.YELLOW)
		Art.glow(self, sign_pos, 60, Color(1, 0.55, 0.2, 0.18), 4)


func _draw_construction(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	draw_rect(r, Color("6b5a45") if Art.theme != "winter" else Color("d6dee8"))
	var inner: Rect2 = d.inner
	# Следы шин
	for i in 3:
		var x := inner.position.x + 20 + i * 30
		draw_line(Vector2(x, 0), Vector2(x + 14, h), Color("5c4c3a"), 4.0)
	for p in d.piles:
		Art.rrect(self, Rect2(p.position + Vector2(4, 5), p.size), Color(0, 0, 0, 0.3), 2)
		Art.rrect(self, p, Color("a7774f"), 2, 2, Color("7d5638"))
	# Забор
	draw_rect(Rect2(r.position.x, 0, r.size.x, 4), Art.YELLOW)
	draw_rect(Rect2(r.position.x, h - 4, r.size.x, 4), Art.YELLOW)
	# Башенный кран: поворачивающаяся стрела
	var c: Vector2 = d.crane
	var ang: float = t * d.crane_speed
	var dir := Vector2(cos(ang), sin(ang))
	draw_line(c + Vector2(14, 18), c + Vector2(14, 18) + dir * 150, Color(0, 0, 0, 0.3), 9.0)
	draw_line(c - dir * 40, c + dir * 150, Art.YELLOW, 8.0)
	var k := -30.0
	while k < 150.0:
		draw_line(c + dir * k + dir.orthogonal() * 4, c + dir * (k + 10) - dir.orthogonal() * 4, Color("c99a2e"), 2.0)
		k += 10.0
	Art.rrect(self, Rect2(c - dir * 46 - Vector2(10, 10), Vector2(20, 20)), Color("5d6274"), 3)
	Art.rrect(self, Rect2(c - Vector2(12, 12), Vector2(24, 24)), Art.ORANGE, 3, 2, Color("b35d22"))
	# Груз на тросе
	var hook := c + dir * (110 + sin(t * 0.7) * 25)
	draw_rect(Rect2(hook - Vector2(9, 9), Vector2(18, 18)), Color("7f8597"))


func _draw_far(d: Dictionary) -> void:
	var far: Rect2 = d.far
	if d.kind == "street":
		draw_rect(far, Art.pal("asphalt"))
		return
	match Art.theme:
		"village":
			draw_rect(far, Color("7aa04f"))
			for k in int(h / 22.0):
				draw_line(Vector2(far.position.x, k * 22.0 + 6), Vector2(far.end.x, k * 22.0 + 6), Color("6b8f43"), 6.0)
			return
		"beach":
			if d.side > 0:
				_draw_sea(far)
				return
		"mountain":
			if d.side < 0:
				_draw_rock(far, 0.85)
			else:
				_draw_valley(far)
			return
	draw_rect(far, Art.pal("lot"))
	if Art.theme == "desert":
		for b in d.far_blocks:
			var r: Rect2 = b.rect
			_dune(r.get_center(), r.size * 0.5)
		return
	for b in d.far_blocks:
		var r: Rect2 = b.rect
		var col: Color = _roof_color(b.color)
		draw_rect(Rect2(r.position + Vector2(10, 12), r.size), Color(0, 0, 0, 0.35))
		Art.rrect(self, r, col.darkened(0.1), 4, 5, col.darkened(0.35))


func _draw_street(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	# Боковая улица и угол тротуара
	draw_rect(r, Art.pal("asphalt"))
	var mid := h / 2.0
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, mid - 2, 26, 4), Art.LINE_WHITE)
		x += 52
	# Пешеходный переход через тротуар-продолжение
	var sx := Art.CITY_LEFT_END if d.side < 0 else Art.ROAD_RIGHT
	draw_rect(Rect2(sx, 0, Art.SIDEWALK_W, h), Art.pal("asphalt"))
	# Светофор на углу
	var pole := Vector2(Art.CITY_LEFT_END - 14, h - 14) if d.side < 0 else Vector2(Art.CITY_RIGHT_START + 14, h - 14)
	Art.rrect(self, Rect2(pole - Vector2(9, 22), Vector2(18, 44)), Art.INK, 4)
	var phase := int(fmod(t, 6.0) / 2.0)   # 0 — зелёный, 1 — жёлтый, 2 — красный
	var cols := [Color("3ddc84"), Art.YELLOW, Art.RED]
	for i in 3:
		var p := pole + Vector2(0, -13 + i * 13)
		var on := (2 - i) == phase
		draw_circle(p, 5, cols[2 - i] if on else Color("2c3040"))
		if on:
			Art.glow(self, p, 16, Color(cols[2 - i], 0.45), 4)
	# Машины на боковой улице подъезжают к главной дороге и ждут у стоп-линии
	var slot := 0
	for car in d.cars:
		var cx: float
		var stop_offset := 40.0 + slot * 72.0
		if d.side < 0:
			cx = minf(r.position.x - 60 + car.x, Art.CITY_LEFT_END - stop_offset)
		else:
			cx = maxf(r.end.x + 60 - car.x, Art.CITY_RIGHT_START + stop_offset)
		var cy := mid + (16.0 if d.side < 0 else -16.0)
		var ang := PI / 2.0 if d.side < 0 else -PI / 2.0
		Art.draw_car(self, 60, 30, car.color, {"base": Transform2D(ang, Vector2(cx, cy)), "lights": true})
		slot += 1


func _draw_crosswalk() -> void:
	# «Зебра» через всю дорогу
	var y0 := h / 2.0 - 26
	var x := Art.ROAD_LEFT + 22
	while x < Art.ROAD_RIGHT - 30:
		draw_rect(Rect2(x, y0, 22, 52), Color(Art.LINE_WHITE, 0.85))
		x += 40
	# Стоп-линии
	draw_rect(Rect2(Art.ROAD_LEFT, y0 - 18, Art.ROAD_W, 5), Color(Art.LINE_WHITE, 0.7))
	draw_rect(Rect2(Art.ROAD_LEFT, y0 + 52 + 13, Art.ROAD_W, 5), Color(Art.LINE_WHITE, 0.7))


# ---------------------------------------------------------------------------
# Пустыня
# ---------------------------------------------------------------------------
func _dune(c: Vector2, r: Vector2) -> void:
	draw_set_transform(c + Vector2(8, 10), 0, Vector2(1.0, r.y / r.x))
	draw_circle(Vector2.ZERO, r.x, Color(0.55, 0.38, 0.2, 0.35))
	draw_set_transform(c, 0, Vector2(1.0, r.y / r.x))
	draw_circle(Vector2.ZERO, r.x, Color("e2c28c"))
	draw_set_transform(c + Vector2(-r.x * 0.25, -r.y * 0.25), 0, Vector2(1.0, r.y / r.x))
	draw_circle(Vector2.ZERO, r.x * 0.55, Color("ecd3a3"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _cactus(p: Vector2, s: float, sway: float) -> void:
	var g := Color("4f8f4a")
	draw_circle(p + Vector2(6, 8) * s, 13 * s, Color(0.4, 0.25, 0.1, 0.35))
	draw_circle(p, 13 * s, g)
	for a in [0.3, 2.4, 4.2]:
		var arm := p + Vector2(cos(a + sway * 0.05), sin(a + sway * 0.05)) * 16 * s
		draw_line(p, arm, g, 9 * s)
		draw_circle(arm, 5.5 * s, g.lightened(0.1))
	draw_circle(p, 6 * s, g.lightened(0.15))
	draw_circle(p + Vector2(0, -2) * s, 2.5 * s, Color("ff7aa8"))   # цветок


func _draw_desert(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	draw_rect(r, Art.pal("lot"))
	match d.kind:
		"dunes":
			for it in d.items:
				_dune(it.pos, Vector2(60, 34) * it.size)
		"cactus":
			for it in d.items:
				_cactus(it.pos, it.size, sin(t + it.phase))
		"rocks":
			for it in d.items:
				var p: Vector2 = it.pos
				var s: float = it.size
				draw_circle(p + Vector2(7, 9) * s, 18 * s, Color(0.4, 0.25, 0.1, 0.35))
				draw_circle(p, 18 * s, Color("a8735a"))
				draw_circle(p + Vector2(-6, -6) * s, 9 * s, Color("c08b6e"))
				draw_circle(p + Vector2(14, 6) * s, 10 * s, Color("94634d"))
		"pumpjack":
			# Нефтяная качалка: коромысло качается
			var c: Vector2 = d.pump
			Art.rrect(self, Rect2(c - Vector2(40, 22), Vector2(80, 44)), Color("8f7b5f"), 4)
			var ang := sin(t * 1.6) * 0.35
			var dir := Vector2(cos(ang), sin(ang) * 0.4)
			draw_line(c + Vector2(6, 8) - dir * 46, c + Vector2(6, 8) + dir * 46, Color(0, 0, 0, 0.3), 9.0)
			draw_line(c - dir * 46, c + dir * 46, Art.INK, 9.0)
			draw_circle(c + dir * 46, 11, Art.INK)                 # «голова»
			draw_circle(c, 7, Art.ORANGE)
			draw_circle(c - dir * 40, 9, Color("5d6274"))          # противовес
			for it in d.items:
				_cactus(it.pos, it.size * 0.6, 0.0)
		"motel":
			var inner: Rect2 = d.inner
			var b := Rect2(inner.position + Vector2(0, 30), Vector2(inner.size.x, inner.size.y - 60))
			draw_rect(Rect2(b.position + Vector2(10, 12), b.size), Color(0.4, 0.25, 0.1, 0.35))
			Art.rrect(self, b, Color("c46a4f"), 4, 4, Color("8f4a37"))
			var sp := Vector2(inner.get_center().x, inner.position.y + 14)
			var on := fmod(t, 1.6) < 1.2
			Art.rrect(self, Rect2(sp - Vector2(56, 14), Vector2(112, 28)), Art.INK, 6, 2, Art.RED if on else Color("5a2a30"))
			Art.text_center(self, sp, "МОТЕЛЬ", 14, Art.RED if on else Color("5a2a30"), true)
			if on:
				Art.glow(self, sp, 70, Color(1, 0.3, 0.3, 0.2))


# ---------------------------------------------------------------------------
# Омск
# ---------------------------------------------------------------------------
func _plate(center: Vector2, text: String, size: int, bg: Color, fg: Color) -> void:
	var w := Art.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 14.0
	Art.rrect(self, Rect2(center - Vector2(w / 2.0, size * 0.75), Vector2(w, size * 1.5)), bg, 4, 2, Art.INK)
	Art.text_center(self, center, text, size, fg)


## Синяя табличка «ОМСК 0 км» на газоне у бордюра
func _draw_omsk_sign(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	var x := r.end.x - 46.0 if d.side < 0 else r.position.x + 46.0
	var c := Vector2(x, h * 0.5)
	draw_line(c + Vector2(0, 16), c + Vector2(0, 30), Color("3d4152"), 4.0)
	Art.rrect(self, Rect2(c - Vector2(38, 16), Vector2(76, 32)), Color("2a5bd7"), 4, 2, Color("eef0f6"))
	Art.text_center(self, c + Vector2(0, -5), "ОМСК", 13, Color("eef0f6"), true)
	Art.text_center(self, c + Vector2(0, 8), "0 км", 11, Color("eef0f6"))


func _draw_omsk(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	var c := inner.get_center()
	match d.kind:
		"npz":
			# Омский НПЗ: резервуары, трубы и факелы, которые горят днём и ночью
			draw_rect(r, Color("3a3b42"))
			for k in 4:
				var yy := inner.position.y + inner.size.y * (0.15 + 0.23 * k)
				draw_line(Vector2(inner.position.x, yy), Vector2(inner.end.x, yy), Color("8a8f9c"), 3.0)
			for tp in d.tanks:
				draw_circle(tp + Vector2(6, 8), 28, Color(0, 0, 0, 0.35))
				draw_circle(tp, 28, Color("c9cdd6"))
				draw_arc(tp, 28, 0, TAU, 32, Color("8a8f9c"), 2.0)
				draw_arc(tp, 18, 0, TAU, 24, Color("a9adbb"), 2.0)
			var fl1 := inner.position + Vector2(18, 18)
			var fl2 := inner.end - Vector2(18, 18)
			for fp in [fl1, fl2]:
				var f := 0.75 + 0.25 * sin(t * 13.0 + fp.x) + 0.1 * sin(t * 31.0)
				draw_circle(fp + Vector2(5, 6), 10, Color(0, 0, 0, 0.35))
				draw_circle(fp, 9, Color("5e6272"))
				Art.glow(self, fp, 46 * f, Color(1.0, 0.55, 0.15, 0.55))
				draw_circle(fp, 7 * f, Art.ORANGE)
				draw_circle(fp, 3.5 * f, Art.YELLOW)
			_plate(Vector2(c.x, inner.end.y - 6), "НПЗ", 12, Art.UI_PANEL, Art.ORANGE)
		"tara":
			# Тарские ворота — белая кирпичная арка на зелёном сквере
			draw_rect(r, Art.pal("grass"))
			draw_rect(Rect2(c.x - 10, 0, 20, h), Color("8f866f"))
			var gw := minf(inner.size.x * 0.8, 130.0)
			var gate := Rect2(c.x - gw / 2.0, c.y - 26, gw, 52)
			draw_rect(Rect2(gate.position + Vector2(8, 10), gate.size), Color(0, 0, 0, 0.35))
			Art.rrect(self, gate, Color("eeeae0"), 3, 2, Color("a8a194"))
			Art.rrect(self, Rect2(gate.position + Vector2(6, 6), gate.size - Vector2(12, 12)), Color("b84c3a"), 2)
			draw_rect(Rect2(c.x - 13, gate.position.y - 2, 26, gate.size.y + 4), Color("6e665a"))   # проезд
			for k in 6:
				var bx := gate.position.x + 8 + k * (gw - 16) / 5.0
				draw_line(Vector2(bx, gate.position.y + 8), Vector2(bx, gate.end.y - 8), Color("9c3d2e"), 1.5)
			_plate(Vector2(c.x, gate.end.y + 22), "ТАРСКИЕ ВОРОТА", 11, Color("eeeae0"), Art.INK)
		"metro":
			# Вход в единственную станцию омского метро
			draw_rect(r, Color("8d8a85"))
			for k in int(h / 26.0):
				draw_line(Vector2(r.position.x, k * 26.0), Vector2(r.end.x, k * 26.0), Color("7d7a75"), 1.0)
			var pav := Rect2(c.x - 50, c.y - 34, 100, 68)
			Art.rrect(self, Rect2(pav.position + Vector2(8, 10), pav.size), Color(0, 0, 0, 0.35), 14)
			Art.rrect(self, pav, Color("3b6f9e"), 14, 3, Color("27496a"))
			Art.rrect(self, Rect2(pav.position + Vector2(10, 10), pav.size - Vector2(20, 20)), Art.GLASS, 8)
			var m_pulse := 0.85 + 0.15 * sin(t * 2.0 + d.phase)
			Art.glow(self, c, 40, Color(Art.RED, 0.35 * m_pulse))
			draw_circle(c, 17, Art.RED)
			Art.text_center(self, c, "М", 20, Color.WHITE, true)
			_plate(Vector2(c.x, pav.end.y + 22), "Библиотека им. Пушкина", 11, Color.WHITE, Art.INK)
			_plate(Vector2(c.x, pav.position.y - 20), "ЕДИНСТВЕННАЯ СТАНЦИЯ", 9, Art.YELLOW, Art.INK)
		"lyubochka":
			# Скверик: скамейка, а на ней бронзовая Любочка с зонтиком
			draw_rect(r, Art.pal("grass"))
			draw_rect(Rect2(inner.position.x, c.y - 30, inner.size.x, 60), Color("9a9183"))
			var bench := Rect2(c.x - 40, c.y - 8, 80, 18)
			Art.rrect(self, Rect2(bench.position + Vector2(5, 6), bench.size), Color(0, 0, 0, 0.3), 3)
			Art.rrect(self, bench, Color("6b4a32"), 3, 2, Color("4a3322"))
			var bronze := Color("a8743c")
			var lp := Vector2(c.x + 10, c.y)
			draw_circle(lp + Vector2(4, 6), 13, Color(0, 0, 0, 0.3))
			draw_circle(lp, 12, bronze.darkened(0.15))            # платье
			draw_circle(lp + Vector2(0, -3), 7, bronze)             # голова
			draw_arc(lp + Vector2(0, -3), 11, PI, TAU, 12, bronze.lightened(0.15), 3.0)   # шляпка
			draw_line(lp + Vector2(-14, -16), lp + Vector2(10, 10), bronze.darkened(0.3), 2.5)   # зонтик
			_plate(Vector2(c.x, c.y + 44), "ЛЮБОЧКА", 11, Color("eeeae0"), Art.INK)
			for k in 3:
				var tp := Vector2(inner.position.x + 20 + k * (inner.size.x - 40) / 2.0, inner.position.y + 24)
				draw_circle(tp + Vector2(6, 8), 18, Color(0, 0, 0, 0.3))
				draw_circle(tp + Vector2(sin(t + k), 0), 18, Art.TREE_COLORS[k])
		"stepanych":
			# Сантехник Степаныч выглядывает из люка
			draw_rect(r, Color("8d8a85"))
			Art.rrect(self, Rect2(inner.position + Vector2(0, 8), Vector2(inner.size.x, inner.size.y * 0.4)),
				_roof_color(Art.ROOF_COLORS[1]), 4, 4, Art.ROOF_COLORS[1].darkened(0.3))
			var mp := Vector2(c.x, c.y + inner.size.y * 0.18)
			draw_circle(mp, 22, Color("3d4152"))
			draw_arc(mp, 22, 0, TAU, 24, Color("5e6272"), 3.0)
			var bob := sin(t * 1.5 + d.phase) * 1.5
			var bronze := Color("9a6a36")
			draw_circle(mp + Vector2(0, -4 + bob), 11, bronze)          # голова в каске
			draw_arc(mp + Vector2(0, -4 + bob), 11, PI * 1.05, PI * 1.95, 12, bronze.lightened(0.2), 4.0)
			draw_line(mp + Vector2(-12, 4), mp + Vector2(-22, -2), bronze.darkened(0.15), 5.0)   # руки на краю люка
			draw_line(mp + Vector2(12, 4), mp + Vector2(22, -2), bronze.darkened(0.15), 5.0)
			_plate(Vector2(mp.x, mp.y + 38), "СТЕПАНЫЧ", 11, Color("eeeae0"), Art.INK)
		"sobor":
			# Успенский собор: белый храм крестом, золотой центральный купол и синие малые
			draw_rect(r, Color("8d8a85"))
			for k in int(h / 26.0):
				draw_line(Vector2(r.position.x, k * 26.0), Vector2(r.end.x, k * 26.0), Color("7d7a75"), 1.0)
			var arm := minf(inner.size.x, 150.0) * 0.5
			var cw := arm * 0.55
			draw_rect(Rect2(c - Vector2(arm, cw) + Vector2(8, 10), Vector2(arm * 2, cw * 2)), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(c - Vector2(cw, arm) + Vector2(8, 10), Vector2(cw * 2, arm * 2)), Color(0, 0, 0, 0.35))
			Art.rrect(self, Rect2(c - Vector2(arm, cw), Vector2(arm * 2, cw * 2)), Color("f2efe6"), 3, 2, Color("c9c2b0"))
			Art.rrect(self, Rect2(c - Vector2(cw, arm), Vector2(cw * 2, arm * 2)), Color("f2efe6"), 3, 2, Color("c9c2b0"))
			for off in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var dp: Vector2 = c + off * cw * 0.95
				draw_circle(dp, cw * 0.38, Color("2f5fa8"))
				draw_circle(dp + Vector2(-2, -2), cw * 0.14, Color("ffd166"))
			var shine := 0.8 + 0.2 * sin(t * 2.0 + d.phase)
			Art.glow(self, c, cw * 1.6, Color(1.0, 0.85, 0.3, 0.3 * shine))
			draw_circle(c, cw * 0.62, Color("e8b931"))
			draw_circle(c + Vector2(-4, -4), cw * 0.22, Color("fff1b8"))
			draw_line(c - Vector2(0, 7), c + Vector2(0, 7), Art.INK, 2.0)
			draw_line(c - Vector2(5, 3), c + Vector2(5, -3), Art.INK, 2.0)
			_plate(Vector2(c.x, c.y + arm + 18), "УСПЕНСКИЙ СОБОР", 11, Color("eeeae0"), Art.INK)
		"drama":
			# Драмтеатр: светлое здание с колоннадой и фонтаном перед входом
			draw_rect(r, Art.pal("grass"))
			var bw := minf(inner.size.x * 0.9, 160.0)
			var b := Rect2(c.x - bw / 2.0, inner.position.y + 14, bw, inner.size.y * 0.5)
			draw_rect(Rect2(b.position + Vector2(9, 11), b.size), Color(0, 0, 0, 0.35))
			Art.rrect(self, b, Color("e9dcc0"), 4, 3, Color("b9a782"))
			Art.rrect(self, Rect2(b.position + Vector2(8, 8), b.size - Vector2(16, 16)), Color("8fb3a5"), 3)
			for k in 6:
				draw_circle(Vector2(b.position.x + 14 + k * (bw - 28) / 5.0, b.end.y - 4), 4, Color("fbf6ea"))
			var fp := Vector2(c.x, b.end.y + (inner.end.y - b.end.y) * 0.5)
			draw_circle(fp, 20, Color("8a8fa0"))
			draw_circle(fp, 16, Color("3b6f9e"))
			var rr := fmod(t * 10.0, 16.0)
			draw_arc(fp, rr, 0, TAU, 20, Color(0.8, 0.9, 1.0, 0.6 * (1.0 - rr / 16.0)), 2.0)
			_plate(Vector2(c.x, b.position.y + b.size.y * 0.5), "ДРАМТЕАТР", 11, Color("eeeae0"), Art.INK)
		"dostoevsky":
			# Сквер с памятником Достоевскому
			draw_rect(r, Art.pal("grass"))
			draw_circle(c, 46, Color("9a9183"))
			draw_circle(c, 40, Color("a8a194"))
			draw_rect(Rect2(c.x - 9, 0, 18, h), Color("8f866f"))
			draw_circle(c, 40, Color("a8a194"))
			Art.rrect(self, Rect2(c - Vector2(16, 16) + Vector2(5, 6), Vector2(32, 32)), Color(0, 0, 0, 0.3), 3)
			Art.rrect(self, Rect2(c - Vector2(16, 16), Vector2(32, 32)), Color("6e6a64"), 3)
			var bronze := Color("5c4a36")
			draw_circle(c + Vector2(0, 2), 10, bronze)
			draw_circle(c + Vector2(0, -4), 6, bronze.lightened(0.15))
			for k in 4:
				var tp := Vector2(inner.position.x + 22 + (k % 2) * (inner.size.x - 44), inner.position.y + 26 + (k / 2) * (inner.size.y - 52))
				draw_circle(tp + Vector2(6, 8), 17, Color(0, 0, 0, 0.3))
				draw_circle(tp + Vector2(sin(t + k) * 1.5, 0), 17, Art.TREE_COLORS[k])
			_plate(Vector2(c.x, c.y + 60), "ДОСТОЕВСКИЙ", 11, Color("eeeae0"), Art.INK)
		"irtysh":
			# Набережная Иртыша: вода, волны и речной трамвайчик
			draw_rect(r, Color("2f5d86"))
			var shore_x := r.end.x - 30.0 if d.side < 0 else r.position.x + 30.0
			draw_rect(Rect2(minf(shore_x, r.end.x) - (0 if d.side < 0 else 30), 0, 30, h), Color("9a9183"))
			for k in int(h / 22.0):
				var wy := fmod(k * 22.0 + t * 8.0, h)
				var wx := r.position.x + 40 + fmod(k * 53.0, maxf(r.size.x - 120, 1.0))
				draw_arc(Vector2(wx, wy), 8, PI * 1.2, PI * 1.8, 6, Color(1, 1, 1, 0.25), 2.0)
			var by := fmod(c.y + t * d.boat_speed + 1000.0, h)
			var boat := Rect2(c.x - 14, by - 32, 28, 64)
			Art.rrect(self, Rect2(boat.position + Vector2(5, 7), boat.size), Color(0, 0, 0, 0.3), 12)
			Art.rrect(self, boat, Color("eef0f6"), 12, 2, Color("8a8f9c"))
			Art.rrect(self, Rect2(boat.position + Vector2(5, 14), Vector2(18, 30)), Art.RED, 4)
			_plate(Vector2(c.x, h - 18), "ИРТЫШ", 11, Color("2a5bd7"), Color.WHITE)



# ---------------------------------------------------------------------------
# Карта Омска: квартал с достопримечательностью появился на экране — отмечаем
# ---------------------------------------------------------------------------
func _report_landmarks() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.name != "World":
		_reported = true       # в главном меню на фоне ничего не открываем
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var top := cam.global_position.y - Art.VIEW_H / 2.0
	if global_position.y + h < top or global_position.y > top + Art.VIEW_H:
		return
	_reported = true
	for d in sides:
		var id: String = d.kind
		if GameData.get_landmark(id).is_empty():
			continue
		var lm := GameData.get_landmark(id)
		var where := "Слева" if d.side < 0 else "Справа"
		var hud = get_tree().get_first_node_in_group("hud")
		if SaveManager.discover_landmark(id):
			Sound.play("record", -6.0, 1.3, 0.0)
			if hud:
				hud.toast("%s — %s! Новая точка на карте Омска (+%d)" % [where, lm.name, GameData.LANDMARK_REWARD], Art.YELLOW, 3.0)
		elif hud and randf() < 0.35:
			hud.toast("%s — %s" % [where, lm.name], Art.UI_TEXT, 2.0)
		if id == "bridge":
			break


func _draw_bridge_side(d: Dictionary) -> void:
	# Вода под мостом, перила и фонари вдоль тротуара
	var r: Rect2 = d.rect
	draw_rect(r, Color("2f5d86"))
	draw_rect(d.far, Color("2f5d86"))
	for k in int(h / 26.0):
		var wy := fmod(k * 26.0 + t * 10.0, h)
		var wx := r.position.x + 20 + fmod(k * 61.0, maxf(r.size.x - 60, 1.0))
		draw_arc(Vector2(wx, wy), 9, PI * 1.2, PI * 1.8, 6, Color(1, 1, 1, 0.25), 2.0)
	var rail_x := Art.CITY_LEFT_END if d.side < 0 else Art.CITY_RIGHT_START
	draw_rect(Rect2(rail_x - 5, 0, 10, h), Color("9aa0ad"))
	var y := 10.0
	while y < h:
		draw_circle(Vector2(rail_x, y), 6, Color("c9cdd6"))
		y += 40.0
	if d.side < 0:
		_plate(Vector2(r.end.x - 110, h * 0.5), "ЛЕНИНГРАДСКИЙ МОСТ", 11, Color("2a5bd7"), Color.WHITE)
	else:
		_plate(Vector2(r.position.x + 110, h * 0.5), "ИРТЫШ", 11, Color("2a5bd7"), Color.WHITE)



# ---------------------------------------------------------------------------
# Село Кукуево: избы с огородами, поля, пастбища, пруды, стога
# ---------------------------------------------------------------------------
func _inner_rect(r: Rect2, side: int) -> Rect2:
	return Rect2(Vector2(r.position.x + 70, 10), Vector2(r.size.x - 84, h - 20)) if side < 0 \
		else Rect2(Vector2(r.position.x + 14, 10), Vector2(r.size.x - 94, h - 20))


func _make_village_side(d: Dictionary, side: int) -> Dictionary:
	var inner := _inner_rect(d.rect, side)
	d.inner = inner
	var kinds := ["izba", "izba", "field", "pasture", "pond", "haystacks", "izba"]
	d.kind = kinds[_rng.randi() % kinds.size()]
	d.phase = _rng.randf() * TAU
	d.items = []
	for i in _rng.randi_range(3, 6):
		d.items.append({"pos": Vector2(_rng.randf_range(inner.position.x + 14, inner.end.x - 14),
			_rng.randf_range(inner.position.y + 14, inner.end.y - 14)), "size": _rng.randf_range(0.8, 1.2),
			"phase": _rng.randf() * TAU})
	var hw := minf(inner.size.x * 0.62, 120.0)
	var hh := minf(inner.size.y * 0.45, 96.0)
	d.house = Rect2(inner.position.x + (inner.size.x - hw) * _rng.randf_range(0.2, 0.8), inner.position.y + 8, hw, hh)
	d.roof = [Color("8a4b32"), Color("4f6a8a"), Color("6b7d4f"), Color("9a3b3b")][_rng.randi() % 4]
	d.crop = [Color("e2c25a"), Color("7fb04a"), Color("c98a4a")][_rng.randi() % 3]
	return d


func _draw_village(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	draw_rect(r, Art.pal("lot"))
	match d.kind:
		"izba":
			# Изба с двускатной крышей, палисадником и грядками
			var hs: Rect2 = d.house
			var garden := Rect2(inner.position.x, hs.end.y + 14, inner.size.x, inner.end.y - hs.end.y - 14)
			if garden.size.y > 20:
				draw_rect(garden, Color("6e5236"))
				var k := 0
				var gy := garden.position.y + 8
				while gy < garden.end.y - 6:
					draw_rect(Rect2(garden.position.x + 6, gy, garden.size.x - 12, 7), Color("5f9a3e") if k % 2 == 0 else Color("7a5a3c"))
					gy += 13
					k += 1
			draw_rect(Rect2(hs.position + Vector2(10, 12), hs.size), Color(0, 0, 0, 0.3))
			draw_rect(hs, Color("a8743f"))
			for ly in range(int(hs.position.y) + 6, int(hs.end.y), 9):
				draw_line(Vector2(hs.position.x, ly), Vector2(hs.end.x, ly), Color("8a5a2e"), 2.0)
			var col: Color = d.roof
			draw_colored_polygon(PackedVector2Array([hs.position, hs.position + Vector2(hs.size.x, 0),
				hs.position + Vector2(hs.size.x, hs.size.y * 0.5), hs.position + Vector2(0, hs.size.y * 0.5)]), col)
			draw_colored_polygon(PackedVector2Array([hs.position + Vector2(0, hs.size.y * 0.5),
				hs.position + Vector2(hs.size.x, hs.size.y * 0.5), hs.end, hs.position + Vector2(0, hs.size.y)]), col.darkened(0.2))
			draw_line(hs.position + Vector2(0, hs.size.y * 0.5), hs.position + Vector2(hs.size.x, hs.size.y * 0.5), col.darkened(0.45), 3.0)
			# Печная труба с дымком
			var ch := hs.position + Vector2(hs.size.x * 0.75, hs.size.y * 0.3)
			draw_rect(Rect2(ch - Vector2(6, 6), Vector2(12, 12)), Color("8f4a37"))
			for k2 in 3:
				var f := fmod(t * 0.6 + k2 / 3.0, 1.0)
				draw_circle(ch + Vector2(f * 30, -f * 20), 5 + f * 8, Color(0.85, 0.85, 0.88, 0.45 * (1.0 - f)))
			# Забор вдоль дороги
			var fx := r.end.x - 16 if d.side < 0 else r.position.x + 16
			var fy := 6.0
			while fy < h - 6:
				draw_rect(Rect2(fx - 3, fy, 6, 14), Color("b98a54"))
				fy += 18.0
			draw_line(Vector2(fx, 0), Vector2(fx, h), Color("8a5a2e"), 2.0)
		"field":
			draw_rect(inner, d.crop.darkened(0.15))
			var y := inner.position.y + 4
			while y < inner.end.y:
				draw_rect(Rect2(inner.position.x, y, inner.size.x, 6), d.crop)
				y += 14
			# Пугало
			var c := inner.get_center()
			draw_line(c + Vector2(-16, -4), c + Vector2(16, -4), Color("6e5236"), 4.0)
			draw_circle(c, 9, Color("c94a3a"))
			draw_circle(c + Vector2(0, -2), 6, Color("e8c48a"))
			draw_circle(c, 11 + sin(t * 2.0) * 1.0, Color("2f3242"), false, 2.0)
		"pasture":
			for it in d.items:
				var p: Vector2 = it.pos
				var s: float = it.size * 0.6
				Art.rrect(self, Rect2(p - Vector2(22, 11) * s + Vector2(4, 5), Vector2(44, 22) * s), Color(0, 0, 0, 0.2), 9)
				Art.rrect(self, Rect2(p - Vector2(22, 11) * s, Vector2(44, 22) * s), Color("f4f1ea"), 9)
				draw_circle(p + Vector2(-6, -2) * s, 5 * s, Art.INK)
				draw_circle(p + Vector2(8, 4) * s, 4 * s, Art.INK)
				draw_circle(p + Vector2(26, sin(t + it.phase) * 2) * s, 8 * s, Color("f4f1ea"))
		"pond":
			var c := inner.get_center()
			var rr := Vector2(inner.size.x * 0.42, inner.size.y * 0.36)
			draw_set_transform(c, 0, Vector2(1.0, rr.y / rr.x))
			draw_circle(Vector2.ZERO, rr.x + 8, Color("7a6a4a"))
			draw_circle(Vector2.ZERO, rr.x, Color("3f7fa6"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			for k in 3:
				var dp := c + Vector2(cos(t * 0.4 + k * 2.1) * rr.x * 0.5, sin(t * 0.4 + k * 2.1) * rr.y * 0.5)
				draw_circle(dp, 6, Color.WHITE)
				draw_circle(dp + Vector2(5, -2), 2.5, Art.ORANGE)
		"haystacks":
			for it in d.items:
				var p: Vector2 = it.pos
				var s: float = it.size
				draw_circle(p + Vector2(6, 8) * s, 20 * s, Color(0, 0, 0, 0.25))
				draw_circle(p, 20 * s, Color("d9b35a"))
				draw_circle(p + Vector2(-5, -5) * s, 11 * s, Color("e8c870"))
				draw_arc(p, 14 * s, 0, TAU, 16, Color("b8923e"), 2.0)


# ---------------------------------------------------------------------------
# Морское побережье: слева отели и кафе, справа пляж и море
# ---------------------------------------------------------------------------
func _make_beach_side(d: Dictionary, side: int) -> Dictionary:
	var inner := _inner_rect(d.rect, side)
	d.inner = inner
	d.phase = _rng.randf() * TAU
	if side < 0:
		d.kind = ["resort", "cafe", "resort"][_rng.randi() % 3]
		d.color = [Color("f4e3c1"), Color("fdf6e9"), Color("ffd6c0"), Color("d8f0f0")][_rng.randi() % 4]
		d.sign = ["КАФЕ «ПРИБОЙ»", "ШАШЛЫК", "ОТЕЛЬ «ЧАЙКА»", "МОРОЖЕНОЕ", "КВАС", "СУВЕНИРЫ"][_rng.randi() % 6]
	else:
		d.kind = "pier" if _rng.randf() < 0.15 and h >= 220 else "sand"
	d.items = []
	for i in _rng.randi_range(3, 5):
		d.items.append({"pos": Vector2(_rng.randf_range(inner.position.x + 12, inner.end.x - 12),
			_rng.randf_range(inner.position.y + 12, inner.end.y - 12)),
			"color": [Color("e8505b"), Color("ffc857"), Color("2ec4b6"), Color("4d7cfe"), Color("ff6fb5")][_rng.randi() % 5],
			"phase": _rng.randf() * TAU})
	return d


func _palm(p: Vector2, s: float, sway: float) -> void:
	draw_circle(p + Vector2(10, 12) * s, 22 * s, Color(0, 0, 0, 0.22))
	for k in 6:
		var a := k * TAU / 6.0 + sway * 0.08
		var tip := p + Vector2(cos(a), sin(a)) * 28 * s
		draw_line(p, tip, Color("3f8f5a"), 7 * s)
		draw_circle(tip, 4 * s, Color("4fa36a"))
	draw_circle(p, 7 * s, Color("8a6a3e"))


func _draw_sea(r: Rect2) -> void:
	draw_rect(r, Color("2a8fbf"))
	for k in int(h / 30.0) + 1:
		var wy := fmod(k * 30.0 + t * 8.0, h + 30.0) - 15.0
		var wx := r.position.x + 20 + fmod(k * 73.0, maxf(r.size.x - 60, 1.0))
		draw_arc(Vector2(wx, wy), 12, PI * 1.15, PI * 1.85, 8, Color(1, 1, 1, 0.35), 2.0)


func _draw_beach(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	match d.kind:
		"resort", "cafe":
			draw_rect(r, Color("e2c992"))
			var b := Rect2(inner.position + Vector2(0, 10), Vector2(inner.size.x, inner.size.y * 0.55))
			draw_rect(Rect2(b.position + Vector2(10, 12), b.size), Color(0, 0, 0, 0.25))
			Art.rrect(self, b, d.color, 6, 3, d.color.darkened(0.25))
			if d.kind == "resort":
				# Бассейн у отеля
				var pool := Rect2(inner.position.x + 10, b.end.y + 12, inner.size.x - 20, inner.end.y - b.end.y - 22)
				if pool.size.y > 16:
					Art.rrect(self, pool, Color("eef6f7"), 6)
					Art.rrect(self, pool.grow(-5), Color("4cc3e0"), 4)
					for k in 3:
						var wx := pool.position.x + 12 + fmod(t * 20.0 + k * 40.0, maxf(pool.size.x - 24, 1.0))
						draw_line(Vector2(wx, pool.position.y + 9 + k * 6), Vector2(wx + 10, pool.position.y + 9 + k * 6), Color(1, 1, 1, 0.6), 2.0)
			else:
				# Столики под зонтиками
				for it in d.items:
					var p: Vector2 = it.pos
					if p.y < b.end.y + 14:
						continue
					draw_circle(p + Vector2(4, 5), 15, Color(0, 0, 0, 0.2))
					draw_circle(p, 15, it.color)
					draw_circle(p, 4, Color.WHITE)
			var sp := Vector2(b.get_center().x, b.position.y + 16)
			var on := fmod(t + d.phase, 2.0) < 1.6
			Art.rrect(self, Rect2(sp - Vector2(minf(b.size.x * 0.45, 80), 11), Vector2(minf(b.size.x * 0.9, 160), 22)), Art.INK, 5, 2, Art.ORANGE if on else Color("6a4a2a"))
			Art.text_center(self, sp, d.sign, 10, Art.ORANGE if on else Color("8a6a4a"), true)
			_palm(Vector2(r.end.x - 30, h * 0.25), 0.9, sin(t * 1.3 + d.phase))
		"sand", "pier":
			# Песок у дороги, дальше — линия прибоя и море
			var shore_x := r.position.x + r.size.x * 0.55
			draw_rect(Rect2(r.position.x, 0, shore_x - r.position.x, h), Color("ecd6a0"))
			_draw_sea(Rect2(shore_x, 0, r.end.x - shore_x, h))
			var foam := PackedVector2Array()
			for k in 13:
				var yy := k * h / 12.0
				foam.append(Vector2(shore_x + sin(t * 1.5 + yy * 0.05) * 6.0, yy))
			draw_polyline(foam, Color(1, 1, 1, 0.8), 5.0, true)
			if d.kind == "pier":
				var py := h * 0.5
				draw_rect(Rect2(shore_x - 10, py - 12, r.end.x - shore_x + 90, 24), Color("9a7048"))
				for k in int((r.end.x - shore_x) / 16.0) + 6:
					draw_line(Vector2(shore_x - 10 + k * 16, py - 12), Vector2(shore_x - 10 + k * 16, py + 12), Color("7a5232"), 2.0)
			# Зонтики и полотенца на песке
			for it in d.items:
				var p: Vector2 = it.pos
				if p.x > shore_x - 20:
					continue
				Art.rrect(self, Rect2(p + Vector2(-8, 6), Vector2(16, 26)), it.color.lightened(0.3), 3)
				draw_circle(p + Vector2(5, 6), 17, Color(0, 0, 0, 0.18))
				draw_circle(p, 17, it.color)
				for k in 4:
					var a := k * PI / 2.0 + t * 0.2
					draw_line(p, p + Vector2(cos(a), sin(a)) * 17, Color(1, 1, 1, 0.7), 2.0)
			# Чайка над пляжем
			var gx := r.position.x + fmod(t * 40.0 + d.phase * 50.0, maxf(r.size.x, 1.0))
			var gy := h * 0.3 + sin(t * 2.0 + d.phase) * 20.0
			var wing := sin(t * 10.0) * 4.0
			draw_line(Vector2(gx - 9, gy + wing), Vector2(gx, gy), Color.WHITE, 2.5)
			draw_line(Vector2(gx, gy), Vector2(gx + 9, gy + wing), Color.WHITE, 2.5)


# ---------------------------------------------------------------------------
# Горный серпантин: слева скалы, справа отбойник и обрыв над долиной
# ---------------------------------------------------------------------------
func _make_mountain_side(d: Dictionary, side: int) -> Dictionary:
	d.inner = _inner_rect(d.rect, side)
	d.kind = "cliff" if side < 0 else "valley"
	d.phase = _rng.randf() * TAU
	d.items = []
	for i in _rng.randi_range(2, 5):
		d.items.append({"pos": Vector2(_rng.randf_range(d.rect.position.x + 10, d.rect.end.x - 10),
			_rng.randf_range(10, h - 10)), "size": _rng.randf_range(0.7, 1.3), "phase": _rng.randf() * TAU})
	d.waterfall = side < 0 and _rng.randf() < 0.12
	return d


func _pine(p: Vector2, s: float) -> void:
	draw_circle(p + Vector2(7, 9) * s, 16 * s, Color(0, 0, 0, 0.3))
	draw_circle(p, 16 * s, Color("2f5e45"))
	draw_circle(p, 10 * s, Color("3f7a52"))
	draw_circle(p, 4 * s, Color("4f8f5a"))


func _draw_rock(r: Rect2, shade: float) -> void:
	draw_rect(r, Color("6f6a66").darkened(1.0 - shade))
	# Слои горной породы
	var k := 0
	var y := fmod(position.y * 0.0, 1.0)
	while y < h:
		var hh := 18.0 + Art.hash01(int(position.y / 7.0) + k) * 26.0
		draw_rect(Rect2(r.position.x, y, r.size.x, hh - 4), Color("7d7772").darkened(1.0 - shade).lerp(Color("8a847e"), Art.hash01(k + int(position.y))))
		y += hh
		k += 1


func _draw_valley(r: Rect2) -> void:
	# Далеко внизу — лес и река
	draw_rect(r, Color("2f5a3f"))
	for k in 6:
		var p := Vector2(r.position.x + Art.hash01(k + int(position.y)) * r.size.x, Art.hash01(k * 3 + int(position.y)) * h)
		draw_circle(p, 26, Color("3a6b4a"))


func _draw_mountain(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	if d.kind == "cliff":
		_draw_rock(r, 1.0)
		# Тень от скалы на обочину
		draw_rect(Rect2(r.end.x - 14, 0, 14, h), Color(0, 0, 0, 0.25))
		for it in d.items:
			var p: Vector2 = it.pos
			var s: float = it.size
			if Art.hash01(int(p.x + p.y)) < 0.5:
				_pine(p, s)
			else:
				draw_circle(p + Vector2(5, 6) * s, 16 * s, Color(0, 0, 0, 0.3))
				draw_circle(p, 16 * s, Color("948e88"))
				draw_circle(p + Vector2(-5, -5) * s, 7 * s, Color("aaa49e"))
		if d.waterfall:
			var wx := r.end.x - 70.0
			draw_rect(Rect2(wx, 0, 26, h), Color("9fd4ee"))
			for k in 6:
				var fy := fmod(t * 160.0 + k * 40.0, h)
				draw_line(Vector2(wx + 4 + k * 3, fy), Vector2(wx + 4 + k * 3, fy + 18), Color(1, 1, 1, 0.7), 2.0)
	else:
		# Обрыв: зелёный склон уходит вниз, ниже — облака
		draw_rect(r, Color("2f5a3f"))
		var edge := r.position.x + 22.0
		draw_rect(Rect2(r.position.x, 0, 22, h), Color("6f6a66"))
		for it in d.items:
			var p: Vector2 = it.pos
			if p.x > edge + 20:
				_pine(p, it.size * 0.7)
		# Облака плывут под дорогой
		for k in 2:
			var cx := r.position.x + fmod(t * 14.0 + k * 140.0 + d.phase * 30.0, r.size.x + 120.0) - 60.0
			var cy := h * (0.3 + 0.4 * k)
			for j in 4:
				draw_circle(Vector2(cx + j * 22, cy + sin(j) * 6), 22 - j * 2, Color(1, 1, 1, 0.55))
		# Отбойник вдоль обрыва
		var gx := Art.CITY_RIGHT_START + 6.0
		draw_rect(Rect2(gx - 4, 0, 8, h), Color("c9ccd4"))
		var yy := 8.0
		while yy < h:
			draw_rect(Rect2(gx - 6, yy, 12, 6), Color("8a8f9c"))
			draw_rect(Rect2(gx - 3, yy - 8, 6, 4), Art.RED if int(yy / 60.0) % 2 == 0 else Color.WHITE)
			yy += 60.0
