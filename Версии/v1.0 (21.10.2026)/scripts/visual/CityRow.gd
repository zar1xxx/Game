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


func setup(height: float, is_intersection: bool, seed_value: int) -> void:
	h = height
	intersection = is_intersection
	_rng.seed = seed_value
	t = _rng.randf() * 10.0
	for side in [-1, 1]:
		sides.append(_make_side(side))


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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	t += delta
	for d in sides:
		if d.kind == "street":
			for car in d.cars:
				car.x = fmod(car.x + car.speed * delta, 340.0)
	# Анимации города перерисовываются через кадр (~30 к/с) — экономит батарею на телефоне
	_frame += 1
	if _frame % 2 == 0:
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
	if intersection:
		_draw_crosswalk()


func _draw_lot(d: Dictionary) -> void:
	draw_rect(d.rect, Color("23263a"))
	# Узкий газон вдоль тротуара
	var r: Rect2 = d.rect
	if d.side < 0:
		draw_rect(Rect2(r.end.x - 12, 0, 12, h), Art.GRASS)
	else:
		draw_rect(Rect2(r.position.x, 0, 12, h), Art.GRASS)


func _draw_buildings(d: Dictionary, height_factor: float) -> void:
	for b in d.buildings:
		var r: Rect2 = b.rect
		var col: Color = b.color
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
		if b.antenna != null:
			var ap: Vector2 = b.antenna
			draw_circle(ap, 4, Art.INK)
			if sin(t * 3.0 + b.phase) > 0.55:
				Art.glow(self, ap, 18, Color(1, 0.2, 0.2, 0.6), 5)
				draw_circle(ap, 3, Art.BRAKELIGHT)


func _draw_park(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	draw_rect(r, Art.GRASS)
	var inner: Rect2 = d.inner
	# Дорожка
	draw_rect(Rect2(inner.get_center().x - 9, 0, 18, h), Color("8f866f"))
	if d.fountain:
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
		var col: Color = tr.color
		draw_circle(p + Vector2(7, 9), rad, Color(0, 0, 0, 0.3))
		draw_circle(p + sway, rad, col)
		draw_circle(p + sway + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.5, col.lightened(0.15))


func _draw_parking(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	draw_rect(r, Color("34374a"))
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
	draw_rect(r, Color("4a4e60"))
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
	draw_rect(r, Color("6b5a45"))
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
		draw_rect(far, Art.ASPHALT)
		return
	draw_rect(far, Color("23263a"))
	for b in d.far_blocks:
		var r: Rect2 = b.rect
		var col: Color = b.color
		draw_rect(Rect2(r.position + Vector2(10, 12), r.size), Color(0, 0, 0, 0.35))
		Art.rrect(self, r, col.darkened(0.1), 4, 5, col.darkened(0.35))


func _draw_street(d: Dictionary) -> void:
	var r: Rect2 = d.rect
	# Боковая улица и угол тротуара
	draw_rect(r, Art.ASPHALT)
	var mid := h / 2.0
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, mid - 2, 26, 4), Art.LINE_WHITE)
		x += 52
	# Пешеходный переход через тротуар-продолжение
	var sx := Art.CITY_LEFT_END if d.side < 0 else Art.ROAD_RIGHT
	draw_rect(Rect2(sx, 0, Art.SIDEWALK_W, h), Art.ASPHALT)
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
