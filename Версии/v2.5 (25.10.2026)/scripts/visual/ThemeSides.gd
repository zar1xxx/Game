class_name ThemeSides
extends RefCounted
## Обочины новых трасс версии 2.5: дачи, трасса «Шашлык — Шиномонтаж», тайга,
## метро, промзона, ледяное озеро и Омск-1985.
## CityRow вызывает отсюда make() — придумать, что стоит у дороги, и draw() — нарисовать.
## Всё рисуется кодом на узле квартала (ci — это CityRow).

const THEMES := ["dacha", "highway", "taiga", "metro", "refinery", "ice", "retro"]
## Виды, у которых есть заметная анимация (дым, огонь, вода, люди)
const ANIMATED := ["banya", "cafe", "hut", "flare", "seal", "fishing", "kvass", "station"]

## Названия станций метро — идут по порядку, как на настоящей линии
const STATIONS := ["Библиотека им. Пушкина", "Бензиновая", "Карбюраторная", "Площадь Пробок",
	"Канистровая", "Октановая", "Ямская", "Объездная", "Шиномонтажная", "Девяносто пятая",
	"Заправочная", "Улица Светофоров", "Дизельная", "Сто первый километр", "Депо «Конечная»"]
static var _station_i: int = 0


static func handles(theme: String) -> bool:
	return theme in THEMES


## Новый заезд — линия метро начинается сначала
static func reset() -> void:
	_station_i = 0


static func next_station() -> String:
	var name: String = STATIONS[_station_i % STATIONS.size()]
	_station_i += 1
	return name


# ---------------------------------------------------------------------------
# Что стоит у дороги
# ---------------------------------------------------------------------------
static func make(row, d: Dictionary, side: int, rng: RandomNumberGenerator) -> Dictionary:
	var h: float = row.h
	d.inner = row._inner_rect(d.rect, side)
	d.phase = rng.randf() * TAU
	d.items = []
	var inner: Rect2 = d.inner
	var kinds: Array = []
	match Art.theme:
		"dacha":
			kinds = ["dacha_house", "dacha_house", "greenhouses", "beds", "banya", "orchard"]
			d.roof = [Color("b84a3e"), Color("3f6fa8"), Color("5b8f4a"), Color("8a5a9a"), Color("d08a3a")][rng.randi() % 5]
			d.wall = [Color("e8d9b5"), Color("a9c7d9"), Color("d9a98a"), Color("c9d9a0")][rng.randi() % 4]
			d.fence = [Color("5b8f4a"), Color("3f6fa8"), Color("b84a3e"), Color("8a8f9c"), Color("a8743f")][rng.randi() % 5]
		"highway":
			kinds = ["forest", "forest", "field", "cafe", "tire", "truckstop", "billboard", "field"]
			d.crop = [Color("e2c25a"), Color("7fb04a"), Color("f2c230")][rng.randi() % 3]
			d.sign = ["ШИНЫ НЕДОРОГО", "МЁД ДОМАШНИЙ", "ДО ОМСКА 0 КМ", "КЛУБНИКА 300 М", "БЕНЗИН ДЕШЕВЛЕ НЕ БУДЕТ",
				"КАФЕ «У ДАЛЬНОБОЙЩИКА»", "РАКИ ЖИВЫЕ", "ПРОДАМ ГАРАЖ"][rng.randi() % 8]
		"taiga":
			kinds = ["forest", "forest", "forest", "clearing", "logpile", "hut", "creek"]
		"metro":
			if row.station != "":
				kinds = ["station"]
			else:
				kinds = ["wall", "wall", "wall", "niche", "signal"]
		"refinery":
			kinds = ["tanks", "tanks", "flare", "pipes", "columns", "cisterns", "office"]
		"ice":
			kinds = ["snow", "snow", "hummocks", "hummocks", "fishing", "seal"]
		"retro":
			kinds = ["khrush", "khrush", "khrush", "kvass", "booth", "gastronom", "dvor", "kiosk"]
			d.color = [Color("c9b99a"), Color("b8a88a"), Color("d6c8a8"), Color("a89878")][rng.randi() % 4]
	d.kind = kinds[rng.randi() % kinds.size()]
	# Крупным постройкам нужно место
	if d.kind in ["cafe", "office", "gastronom", "station", "truckstop"] and h < 210 and d.kind != "station":
		d.kind = kinds[0]
	var n := rng.randi_range(4, 9) if d.kind in ["forest", "orchard", "snow", "hummocks"] else rng.randi_range(2, 5)
	if d.kind == "forest" and Art.theme == "taiga":
		n = rng.randi_range(9, 14)
	for i in n:
		d.items.append({"pos": Vector2(rng.randf_range(inner.position.x + 12, inner.end.x - 12),
			rng.randf_range(inner.position.y + 12, inner.end.y - 12)),
			"size": rng.randf_range(0.75, 1.3), "phase": rng.randf() * TAU, "k": rng.randf(),
			"color": Art.enemy_colors()[rng.randi() % Art.enemy_colors().size()]})
	if d.kind == "station":
		d.name = row.station
	d.ts = true
	return d


static func is_animated(d: Dictionary) -> bool:
	return d.kind in ANIMATED


## Огни для ночного освещения: [позиция, радиус, яркость]
static func lights(row, d: Dictionary, out: Array) -> void:
	var c: Vector2 = row.position + (d.inner as Rect2).get_center()
	match d.kind:
		"cafe", "gastronom", "office", "kiosk":
			out.append([c, 170.0, 0.85])
		"dacha_house", "banya", "hut", "tire":
			out.append([c, 110.0, 0.55])
		"station":
			out.append([c, 260.0, 1.0])
			out.append([row.position + Vector2(c.x - row.position.x, 30), 200.0, 0.8])
		"flare":
			out.append([c, 300.0, 1.0])
		"wall", "niche", "signal":
			out.append([c, 90.0, 0.5])
		"tanks", "columns", "pipes", "cisterns":
			out.append([c, 120.0, 0.6])
		"khrush", "dvor", "booth", "kvass":
			out.append([c, 120.0, 0.5])
		"fishing":
			out.append([c, 80.0, 0.45])


# ---------------------------------------------------------------------------
# Дальняя полоса (видна на широких экранах)
# ---------------------------------------------------------------------------
static func draw_far(ci: Node2D, d: Dictionary, h: float) -> void:
	var far: Rect2 = d.far
	match Art.theme:
		"dacha":
			ci.draw_rect(far, Color("6aa04a"))
			for k in int(h / 26.0):
				ci.draw_line(Vector2(far.position.x, k * 26.0 + 8), Vector2(far.end.x, k * 26.0 + 8), Color("7a5a3c"), 7.0)
		"highway", "taiga":
			ci.draw_rect(far, Color("2f5a35") if Art.theme == "taiga" else Color("4f7a3f"))
			for k in 8:
				var p := Vector2(far.position.x + Art.hash01(k + int(ci.position.y)) * far.size.x, Art.hash01(k * 3 + int(ci.position.y)) * h)
				ci.draw_circle(p, 30, Color("244a2c") if Art.theme == "taiga" else Color("3f6a35"))
		"metro":
			ci.draw_rect(far, Color("1a1b20"))
		"refinery":
			ci.draw_rect(far, Color("5d5b55"))
			for b in d.far_blocks:
				var r: Rect2 = b.rect
				ci.draw_circle(r.get_center(), minf(r.size.x, r.size.y) * 0.4, Color("c9cdd6"))
				ci.draw_arc(r.get_center(), minf(r.size.x, r.size.y) * 0.4, 0, TAU, 24, Color("8a8f9c"), 3.0)
		"ice":
			ci.draw_rect(far, Color("cfe3ee"))
			for k in 4:
				var y := Art.hash01(k + int(ci.position.y)) * h
				ci.draw_line(Vector2(far.position.x, y), Vector2(far.end.x, y + 30), Color(1, 1, 1, 0.6), 2.0)
		"retro":
			ci.draw_rect(far, Art.pal("lot"))
			for b in d.far_blocks:
				var r: Rect2 = b.rect
				ci.draw_rect(Rect2(r.position + Vector2(10, 12), r.size), Color(0, 0, 0, 0.3))
				ci.draw_rect(r, Color("8f877a"))
				ci.draw_rect(r.grow(-6), Color("6f685c"))


# ---------------------------------------------------------------------------
# Рисование
# ---------------------------------------------------------------------------
static func draw(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	match Art.theme:
		"dacha":
			_draw_dacha(ci, d, h, t)
		"highway":
			_draw_highway(ci, d, h, t)
		"taiga":
			_draw_taiga(ci, d, h, t)
		"metro":
			_draw_metro(ci, d, h, t)
		"refinery":
			_draw_refinery(ci, d, h, t)
		"ice":
			_draw_ice(ci, d, h, t)
		"retro":
			_draw_retro(ci, d, h, t)


# --- общие мелочи ---
static func _shadow_circle(ci: Node2D, p: Vector2, r: float) -> void:
	ci.draw_circle(p + Vector2(r * 0.35, r * 0.45), r, Color(0, 0, 0, 0.25))


static func _pine(ci: Node2D, p: Vector2, s: float, dark: bool = false) -> void:
	_shadow_circle(ci, p, 17 * s)
	ci.draw_circle(p, 17 * s, Color("1f4a2c") if dark else Color("2f5e45"))
	ci.draw_circle(p, 11 * s, Color("2b5a37") if dark else Color("3f7a52"))
	ci.draw_circle(p, 5 * s, Color("3a6b45") if dark else Color("4f8f5a"))


static func _birch(ci: Node2D, p: Vector2, s: float) -> void:
	_shadow_circle(ci, p, 16 * s)
	ci.draw_circle(p, 16 * s, Color("7fb04a"))
	ci.draw_circle(p + Vector2(-4, -4) * s, 8 * s, Color("9ac25a"))
	ci.draw_circle(p, 2.5 * s, Color("f2f3f7"))


static func _person(ci: Node2D, p: Vector2, col: Color, head: Color = Color("e8c49a")) -> void:
	ci.draw_circle(p + Vector2(2, 3), 8, Color(0, 0, 0, 0.2))
	ci.draw_circle(p, 8, col)
	ci.draw_circle(p, 4.5, head)


static func _plate(ci: Node2D, center: Vector2, text: String, size: int, bg: Color, fg: Color, w: float = 0.0) -> void:
	var tw: float = Art.font_title.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var width := maxf(w, tw + 14.0)
	Art.rrect(ci, Rect2(center - Vector2(width / 2.0, size * 0.8), Vector2(width, size * 1.6)), bg, 4, 2, bg.darkened(0.4))
	Art.text_center(ci, center, text, size, fg, true)


static func _gable(ci: Node2D, hs: Rect2, roof: Color) -> void:
	ci.draw_rect(Rect2(hs.position + Vector2(9, 11), hs.size), Color(0, 0, 0, 0.3))
	ci.draw_colored_polygon(PackedVector2Array([hs.position, hs.position + Vector2(hs.size.x, 0),
		hs.position + Vector2(hs.size.x, hs.size.y * 0.5), hs.position + Vector2(0, hs.size.y * 0.5)]), roof)
	ci.draw_colored_polygon(PackedVector2Array([hs.position + Vector2(0, hs.size.y * 0.5),
		hs.position + Vector2(hs.size.x, hs.size.y * 0.5), hs.end, hs.position + Vector2(0, hs.size.y)]), roof.darkened(0.22))
	ci.draw_line(hs.position + Vector2(0, hs.size.y * 0.5), hs.position + Vector2(hs.size.x, hs.size.y * 0.5), roof.darkened(0.45), 3.0)


static func _smoke(ci: Node2D, p: Vector2, t: float, col := Color(0.85, 0.85, 0.88)) -> void:
	for k in 3:
		var f := fmod(t * 0.6 + k / 3.0, 1.0)
		ci.draw_circle(p + Vector2(f * 30, -f * 22), 5 + f * 9, Color(col, 0.45 * (1.0 - f)))


static func _fence_x(d: Dictionary) -> float:
	var r: Rect2 = d.rect
	return r.end.x - 14.0 if d.side < 0 else r.position.x + 6.0


# ---------------------------------------------------------------------------
# Дачи
# ---------------------------------------------------------------------------
static func _draw_dacha(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	ci.draw_rect(r, Art.pal("lot"))
	match d.kind:
		"dacha_house":
			var hw := minf(inner.size.x * 0.5, 96.0)
			var hs := Rect2(inner.position.x + 8, inner.position.y + 10, hw, minf(inner.size.y * 0.42, 84.0))
			ci.draw_rect(Rect2(hs.position - Vector2(4, 4), hs.size + Vector2(8, 8)), d.wall)
			_gable(ci, hs, d.roof)
			# Теплица рядом с домиком
			var gh := Rect2(hs.end.x + 12, inner.position.y + 14, inner.end.x - hs.end.x - 20, hs.size.y * 0.9)
			if gh.size.x > 30:
				_greenhouse(ci, gh)
			# Грядки
			var by := hs.end.y + 18
			var k := 0
			while by < inner.end.y - 8:
				ci.draw_rect(Rect2(inner.position.x + 6, by, inner.size.x - 12, 9), Color("7a5a3c"))
				for j in 6:
					ci.draw_circle(Vector2(inner.position.x + 14 + j * (inner.size.x - 28) / 5.0, by + 4.5), 4, Color("5fb04a") if k % 2 == 0 else Color("8fc24a"))
				by += 17
				k += 1
		"greenhouses":
			var gw := inner.size.x * 0.44
			for i in 2:
				_greenhouse(ci, Rect2(inner.position.x + 6 + i * (gw + 12), inner.position.y + 10, gw, inner.size.y - 20))
		"beds":
			var by := inner.position.y + 6
			while by < inner.end.y - 6:
				ci.draw_rect(Rect2(inner.position.x + 4, by, inner.size.x - 8, 11), Color("6e5236"))
				for j in 7:
					ci.draw_circle(Vector2(inner.position.x + 12 + j * (inner.size.x - 24) / 6.0, by + 5.5), 4.5, Color("4f8f3a"))
				by += 19
			# Дачники склонились над грядками
			for it in d.items:
				var p: Vector2 = it.pos
				ci.draw_circle(p + Vector2(3, 4), 11, Color(0, 0, 0, 0.2))
				ci.draw_set_transform(p, 0, Vector2(1.0, 0.75))
				ci.draw_circle(Vector2.ZERO, 11, it.color)
				ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				ci.draw_circle(p + Vector2(0, -9), 5, Color("e8505b") if it.k < 0.5 else Color("f2f3f7"))   # косынка / панама
		"banya":
			var bs := Rect2(inner.position.x + 10, inner.position.y + 12, minf(inner.size.x * 0.55, 100.0), minf(inner.size.y * 0.5, 80.0))
			ci.draw_rect(Rect2(bs.position + Vector2(8, 10), bs.size), Color(0, 0, 0, 0.3))
			ci.draw_rect(bs, Color("a8743f"))
			for ly in range(int(bs.position.y) + 6, int(bs.end.y), 9):
				ci.draw_line(Vector2(bs.position.x, ly), Vector2(bs.end.x, ly), Color("8a5a2e"), 2.0)
			var ch := bs.position + Vector2(bs.size.x * 0.7, bs.size.y * 0.3)
			ci.draw_rect(Rect2(ch - Vector2(6, 6), Vector2(12, 12)), Color("5d6274"))
			_smoke(ci, ch, t)
			# Поленница
			for j in 6:
				ci.draw_circle(Vector2(bs.end.x + 16 + (j % 3) * 14, bs.position.y + 18 + (j / 3) * 14), 7, Color("c9a06a"))
				ci.draw_circle(Vector2(bs.end.x + 16 + (j % 3) * 14, bs.position.y + 18 + (j / 3) * 14), 3, Color("8a6a3e"))
			Art.rrect(ci, Rect2(inner.position.x + 10, bs.end.y + 16, 40, 28), Color("4a90c2"), 6)   # бочка-купель
		"orchard":
			for it in d.items:
				var p: Vector2 = it.pos
				var s: float = it.size
				_shadow_circle(ci, p, 18 * s)
				ci.draw_circle(p, 18 * s, Color("4f8f3a"))
				ci.draw_circle(p + Vector2(-4, -4) * s, 9 * s, Color("6aa64a"))
				for j in 4:
					ci.draw_circle(p + Vector2(cos(j * 1.7 + it.phase), sin(j * 1.7 + it.phase)) * 11 * s, 3 * s, Color("e8505b"))
	# Забор из профлиста вдоль дороги
	var fx := _fence_x(d)
	ci.draw_rect(Rect2(fx, 0, 8, h), d.fence)
	var y := 4.0
	while y < h:
		ci.draw_line(Vector2(fx + 1, y), Vector2(fx + 7, y), d.fence.darkened(0.3), 1.5)
		y += 7.0


static func _greenhouse(ci: Node2D, g: Rect2) -> void:
	ci.draw_rect(Rect2(g.position + Vector2(6, 8), g.size), Color(0, 0, 0, 0.18))
	Art.rrect(ci, g, Color(0.85, 0.95, 0.9, 0.75), int(minf(g.size.x, 30.0) * 0.45), 2, Color("b9c9c0"))
	var k := 0
	var y := g.position.y + 10
	while y < g.end.y - 6:
		ci.draw_line(Vector2(g.position.x + 3, y), Vector2(g.end.x - 3, y), Color(1, 1, 1, 0.6), 1.5)
		ci.draw_circle(Vector2(g.get_center().x - g.size.x * 0.2, y + 6), 3, Color("e8505b") if k % 2 == 0 else Color("4f8f3a"))
		ci.draw_circle(Vector2(g.get_center().x + g.size.x * 0.2, y + 6), 3, Color("4f8f3a") if k % 2 == 0 else Color("e8505b"))
		y += 16
		k += 1


# ---------------------------------------------------------------------------
# Трасса «Шашлык — Шиномонтаж»
# ---------------------------------------------------------------------------
static func _draw_highway(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	ci.draw_rect(r, Art.pal("lot"))
	match d.kind:
		"forest":
			for it in d.items:
				if it.k < 0.5:
					_pine(ci, it.pos, it.size)
				else:
					_birch(ci, it.pos, it.size)
		"field":
			ci.draw_rect(inner, d.crop.darkened(0.15))
			var y := inner.position.y + 4
			while y < inner.end.y:
				ci.draw_rect(Rect2(inner.position.x, y, inner.size.x, 6), d.crop)
				y += 13
		"cafe":
			var b := Rect2(inner.position.x + 6, inner.position.y + 8, inner.size.x - 12, inner.size.y * 0.42)
			ci.draw_rect(Rect2(b.position + Vector2(10, 12), b.size), Color(0, 0, 0, 0.3))
			Art.rrect(ci, b, Color("d9c9a8"), 4, 3, Color("8a6a4a"))
			_plate(ci, Vector2(b.get_center().x, b.position.y + 16), "ШАШЛЫК 24 ЧАСА", 11, Color("b8312f"), Color("ffe08a"))
			# Мангал с дымком и столики
			var m := Vector2(b.position.x + 22, b.end.y + 22)
			Art.rrect(ci, Rect2(m - Vector2(14, 6), Vector2(28, 12)), Color("3d4152"), 2)
			ci.draw_circle(m, 4, Color(1.0, 0.5, 0.15, 0.6 + 0.4 * sin(t * 9.0)))
			_smoke(ci, m + Vector2(0, -6), t)
			for k in 2:
				var tp := Vector2(b.position.x + 70 + k * 46, b.end.y + 26)
				if tp.x < b.end.x:
					ci.draw_circle(tp, 11, Color("f2f3f7"))
					ci.draw_circle(tp + Vector2(0, -16), 5, Color("e8505b"))
			# Фура на стоянке
			var ty := b.end.y + 50
			if ty + 30 < h:
				Art.draw_truck(ci, minf(inner.size.x - 20, 150.0), 44, Color("3f6fa8"), Color("e9e4d4"),
					{"base": Transform2D(PI / 2.0 if d.side < 0 else -PI / 2.0, Vector2(inner.get_center().x, ty + 22))})
		"tire":
			var b := Rect2(inner.position.x + 8, inner.position.y + 10, inner.size.x * 0.62, inner.size.y * 0.45)
			ci.draw_rect(Rect2(b.position + Vector2(8, 10), b.size), Color(0, 0, 0, 0.3))
			ci.draw_rect(b, Color("8a8f9c"))
			for k in int(b.size.x / 10.0):
				ci.draw_line(Vector2(b.position.x + k * 10, b.position.y), Vector2(b.position.x + k * 10, b.end.y), Color("6d7182"), 1.5)
			_plate(ci, Vector2(b.get_center().x, b.position.y + 14), "ШИНОМОНТАЖ", 10, Color("f2c230"), Art.INK)
			# Пирамида старых покрышек
			for k in 7:
				var p := Vector2(b.end.x + 18 + (k % 2) * 16, b.position.y + 12 + k * 15)
				if p.y < inner.end.y:
					ci.draw_circle(p, 9, Art.INK)
					ci.draw_circle(p, 4, Color("4a4e60"))
		"truckstop":
			ci.draw_rect(inner, Color("3a3d48"))
			var n := int(inner.size.y / 60.0)
			for k in n:
				var y := inner.position.y + 30 + k * 60
				Art.draw_truck(ci, minf(inner.size.x - 16, 150.0), 44, [Color("3f6fa8"), Color("b8312f"), Color("5bbf72")][k % 3],
					[Color("e9e4d4"), Color("8a8f9c"), Color("f2c230")][k % 3],
					{"base": Transform2D(PI / 2.0 if d.side < 0 else -PI / 2.0, Vector2(inner.get_center().x, y)), "hazard": false})
		"billboard":
			for it in d.items:
				_birch(ci, it.pos, it.size * 0.8)
			var c := inner.get_center()
			var bw := minf(inner.size.x - 10, 170.0)
			ci.draw_rect(Rect2(c.x - bw * 0.3, c.y - 4, 6, 30), Color("5d6274"))
			ci.draw_rect(Rect2(c.x + bw * 0.3, c.y - 4, 6, 30), Color("5d6274"))
			Art.rrect(ci, Rect2(c - Vector2(bw / 2.0, 30), Vector2(bw, 44)), Color("f4f1ea"), 3, 3, Color("3d4152"))
			Art.text_center(ci, c - Vector2(0, 8), d.sign, int(clampf(bw / maxf(d.sign.length(), 1.0) * 1.5, 8.0, 14.0)), Color("b8312f"), true)
	# Столбики и отбойник у обочины
	var fx := _fence_x(d) + (6.0 if d.side < 0 else -2.0)
	var y := 10.0
	while y < h:
		ci.draw_rect(Rect2(fx - 3, y, 6, 12), Color("f2f3f7"))
		ci.draw_rect(Rect2(fx - 3, y + 7, 6, 3), Art.INK)
		y += 64.0


# ---------------------------------------------------------------------------
# Тайга
# ---------------------------------------------------------------------------
static func _draw_taiga(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	ci.draw_rect(r, Art.pal("lot"))
	# Подлесок: мох и папоротник
	for k in 6:
		var p := Vector2(r.position.x + Art.hash01(k * 11 + int(ci.position.y)) * r.size.x, Art.hash01(k * 7 + int(ci.position.y) + 3) * h)
		ci.draw_circle(p, 14, Color("3a6b3f"))
	match d.kind:
		"forest":
			for it in d.items:
				_pine(ci, it.pos, it.size * 1.1, it.k < 0.6)
		"clearing":
			for it in d.items:
				var p: Vector2 = it.pos
				ci.draw_circle(p + Vector2(3, 4), 10, Color(0, 0, 0, 0.25))
				ci.draw_circle(p, 10, Color("b8925a"))
				ci.draw_arc(p, 6, 0, TAU, 12, Color("8a6a3e"), 1.5)
			var a: Vector2 = inner.position + Vector2(10, inner.size.y * 0.6)
			ci.draw_line(a, a + Vector2(inner.size.x * 0.7, -30), Color("6b4526"), 10.0)       # поваленное дерево
		"logpile":
			var y := inner.position.y + 14
			var row_i := 0
			while y < inner.position.y + inner.size.y * 0.6:
				for k in int(inner.size.x / 18.0) - 1:
					var p := Vector2(inner.position.x + 14 + k * 18 + (row_i % 2) * 9, y)
					ci.draw_circle(p, 8.5, Color("d9b07a"))
					ci.draw_arc(p, 5, 0, TAU, 10, Color("b8925a"), 1.5)
					ci.draw_circle(p, 1.5, Color("8a6a3e"))
				y += 15
				row_i += 1
			# Погрузчик
			var lp := Vector2(inner.get_center().x, inner.end.y - 34)
			Art.rrect(ci, Rect2(lp - Vector2(26, 18), Vector2(52, 36)), Color("e8a33a"), 5, 2, Color("8a5a1a"))
			ci.draw_line(lp + Vector2(0, -18), lp + Vector2(0, -50), Color("5d6274"), 6.0)
		"hut":
			var hs := Rect2(inner.position.x + 14, inner.position.y + 16, minf(inner.size.x * 0.55, 96.0), minf(inner.size.y * 0.45, 76.0))
			ci.draw_rect(Rect2(hs.position - Vector2(4, 4), hs.size + Vector2(8, 8)), Color("6b4526"))
			_gable(ci, hs, Color("5d4a36"))
			var ch := hs.position + Vector2(hs.size.x * 0.75, hs.size.y * 0.28)
			ci.draw_rect(Rect2(ch - Vector2(5, 5), Vector2(10, 10)), Color("5d6274"))
			_smoke(ci, ch, t)
			for it in d.items:
				if (it.pos as Vector2).y > hs.end.y + 20:
					_pine(ci, it.pos, it.size, true)
		"creek":
			var pts := PackedVector2Array()
			for k in 9:
				var yy := k * h / 8.0
				pts.append(Vector2(inner.get_center().x + sin(yy * 0.03 + d.phase) * inner.size.x * 0.25, yy))
			ci.draw_polyline(pts, Color("2f6f8f"), 26.0, true)
			ci.draw_polyline(pts, Color("4a90b0"), 14.0, true)
			for it in d.items:
				ci.draw_circle(it.pos, 6 * it.size, Color("8a8f9c"))
	# Тёмная полоса леса вдоль обочины
	var fx := _fence_x(d)
	for k in int(h / 34.0) + 1:
		_pine(ci, Vector2(fx + (4.0 if d.side < 0 else 2.0), k * 34.0 + 12), 0.7, true)


# ---------------------------------------------------------------------------
# Метро: стены тоннеля и станции
# ---------------------------------------------------------------------------
static func _draw_metro(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	if d.kind == "station":
		_draw_station(ci, d, h, t)
		return
	# Тюбинги: кольца тоннеля
	ci.draw_rect(r, Color("2e3038"))
	var y := 0.0
	var k := 0
	while y < h:
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, 22), Color("34363f") if k % 2 == 0 else Color("2e3038"))
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("1f2026"), 2.0)
		for j in 4:
			ci.draw_circle(Vector2(r.position.x + 30 + j * r.size.x / 4.0, y + 11), 2, Color("4a4e5a"))
		y += 22
		k += 1
	# Кабели вдоль стены
	var cx := _fence_x(d) + (-10.0 if d.side < 0 else 14.0)
	for j in 3:
		ci.draw_line(Vector2(cx + j * 5 * (-1 if d.side < 0 else 1), 0), Vector2(cx + j * 5 * (-1 if d.side < 0 else 1), h),
			[Color("1a1b20"), Color("6b3a2e"), Color("2b3a5a")][j], 3.0)
	match d.kind:
		"niche":
			var nr := Rect2(inner.end.x - 90 if d.side < 0 else inner.position.x + 10, h * 0.3, 80, h * 0.4)
			ci.draw_rect(nr, Color("1f2026"))
			_person(ci, nr.get_center() + Vector2(-12, 0), Color("ff8a3d"), Color("f2c230"))         # рабочий в каске
			ci.draw_rect(Rect2(nr.position + Vector2(44, 10), Vector2(24, 34)), Color("5d6274"))
			_plate(ci, Vector2(nr.get_center().x, nr.position.y - 12), "ПОСТОРОННИМ ВХОД ВОСПРЕЩЁН", 7, Color("f2f3f7"), Color("b8312f"))
		"signal":
			var sp := Vector2(_fence_x(d) + (-24.0 if d.side < 0 else 30.0), h * 0.5)
			Art.rrect(ci, Rect2(sp - Vector2(9, 24), Vector2(18, 48)), Art.INK, 4)
			var green := fmod(t + d.phase, 5.0) < 3.0
			ci.draw_circle(sp + Vector2(0, -11), 6, Color("ff3b4a") if not green else Color("3a1a1a"))
			ci.draw_circle(sp + Vector2(0, 11), 6, Color("3ddc84") if green else Color("1a3a2a"))
			Art.glow(ci, sp + Vector2(0, 11 if green else -11), 24, Color(Color("3ddc84") if green else Color("ff3b4a"), 0.5))
		_:
			if Art.hash01(int(ci.position.y) + d.side) < 0.3:
				_plate(ci, Vector2(inner.get_center().x, h * 0.5), "ВЫХОД", 10, Color("2a8a4a"), Color.WHITE)


static func _draw_station(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	var r: Rect2 = d.rect
	# Платформа: светлый мрамор
	ci.draw_rect(r, Color("c9c2b4"))
	var y := 0.0
	while y < h:
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("b5ad9e"), 1.5)
		y += 30
	var edge := _fence_x(d) + (4.0 if d.side < 0 else 0.0)
	ci.draw_rect(Rect2(edge - 5, 0, 10, h), Color("f2c230"))                                      # жёлтая линия у края
	# Колонны
	var cx: float = (r.position.x + r.end.x) / 2.0 + (40.0 if d.side < 0 else -40.0)
	var cy := 30.0
	while cy < h - 10:
		ci.draw_circle(Vector2(cx + 6, cy + 8), 16, Color(0, 0, 0, 0.25))
		ci.draw_circle(Vector2(cx, cy), 16, Color("8a7f6e"))
		ci.draw_circle(Vector2(cx, cy), 11, Color("a89a84"))
		cy += 80
	# Пассажиры ждут поезд (машину?)
	for it in d.items:
		var p: Vector2 = it.pos
		_person(ci, Vector2(lerpf(edge, cx, 0.45) + (p.x - (d.inner as Rect2).get_center().x) * 0.2, p.y), it.color)
	# Табличка с названием станции
	var label_x: float = lerpf(edge, cx, 0.5)
	_plate(ci, Vector2(label_x, h * 0.5), d.name, 12, Color("1d3a7a"), Color.WHITE)
	_plate(ci, Vector2(label_x, h * 0.5 + 26), "М", 12, Color("b8312f"), Color.WHITE, 28.0)
	# Часы над платформой
	var clock := "%02d:%02d" % [int(t / 60.0) % 24, int(t) % 60]
	_plate(ci, Vector2(label_x, 24), clock, 10, Art.INK, Color("ff6a3a"), 60.0)


# ---------------------------------------------------------------------------
# Промзона «Бензоград»
# ---------------------------------------------------------------------------
static func _draw_refinery(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	ci.draw_rect(r, Art.pal("lot"))
	match d.kind:
		"tanks":
			var n := 1 if inner.size.y < 200 else 2
			for k in n:
				var c := Vector2(inner.get_center().x, inner.position.y + inner.size.y * (k + 0.5) / n)
				var rad := minf(inner.size.x, inner.size.y / n) * 0.42
				_shadow_circle(ci, c, rad)
				ci.draw_circle(c, rad, Color("e4e8ef"))
				ci.draw_arc(c, rad, 0, TAU, 32, Color("8a8f9c"), 3.0, true)
				ci.draw_arc(c, rad * 0.65, 0, TAU, 28, Color("c9cdd6"), 2.0, true)
				ci.draw_line(c + Vector2(rad * 0.7, 0), c + Vector2(rad, rad * 0.1), Color("8a8f9c"), 3.0)   # лестница
				Art.text_center(ci, c, "АИ-95" if k == 0 else "ДТ", int(rad * 0.3), Color("b8312f"), true)
		"flare":
			var c := inner.get_center()
			ci.draw_circle(c + Vector2(4, 6), 14, Color(0, 0, 0, 0.3))
			ci.draw_circle(c, 14, Color("8a8f9c"))
			ci.draw_circle(c, 7, Color("3d4152"))
			var fl := 1.0 + 0.25 * sin(t * 13.0) + 0.15 * sin(t * 31.0 + d.phase)
			Art.glow(ci, c, 70 * fl, Color(1.0, 0.55, 0.12, 0.55))
			Art.glow(ci, c, 34 * fl, Color(1.0, 0.85, 0.4, 0.8))
			for k in 4:
				var f := fmod(t * 0.5 + k / 4.0, 1.0)
				ci.draw_circle(c + Vector2(f * 40, -f * 34), 8 + f * 14, Color(0.25, 0.25, 0.28, 0.4 * (1.0 - f)))
		"pipes":
			for k in 4:
				var py: float = inner.position.y + 18 + k * 22
				ci.draw_line(Vector2(r.position.x, py + 4), Vector2(r.end.x, py + 4), Color(0, 0, 0, 0.25), 12.0)
				ci.draw_line(Vector2(r.position.x, py), Vector2(r.end.x, py), [Color("c9cdd6"), Color("e8b923"), Color("b8312f"), Color("6d7182")][k], 10.0)
			for k in 3:
				var vp := Vector2(inner.position.x + 30 + k * inner.size.x * 0.33, inner.position.y + 29)
				ci.draw_circle(vp, 7, Color("e8505b"))
				ci.draw_arc(vp, 7, 0, TAU, 12, Art.INK, 1.5)
			for it in d.items:
				if (it.pos as Vector2).y > inner.position.y + 110:
					Art.rrect(ci, Rect2(it.pos - Vector2(14, 10), Vector2(28, 20)), Color("8a8f9c"), 3, 2, Color("5d6274"))
		"columns":
			for k in 3:
				var c := Vector2(inner.position.x + inner.size.x * (0.25 + 0.25 * k), inner.position.y + inner.size.y * (0.3 + 0.2 * (k % 2)))
				var rad := 18.0 + k * 4.0
				_shadow_circle(ci, c, rad)
				ci.draw_circle(c, rad, Color("c9cdd6"))
				ci.draw_arc(c, rad - 5, 0, TAU, 20, Color("e8b923"), 3.0, true)
				ci.draw_circle(c, 5, Color("5d6274"))
				if k == 1:
					Art.glow(ci, c, 18, Color(1, 0.3, 0.3, 0.6 * (0.5 + 0.5 * sin(t * 3.0))))         # огонёк на верхушке
		"cisterns":
			var rail_x: float = inner.get_center().x
			for sx in [-12.0, 12.0]:
				ci.draw_line(Vector2(rail_x + sx, 0), Vector2(rail_x + sx, h), Color("6d7182"), 3.0)
			var y := 10.0
			while y < h - 10:
				ci.draw_line(Vector2(rail_x - 20, y), Vector2(rail_x + 20, y), Color("5d4a36"), 4.0)
				y += 14
			var cy := 20.0
			while cy < h - 60:
				Art.rrect(ci, Rect2(rail_x - 18, cy, 36, 70), Color("2b2e38"), 14, 2, Art.INK)
				ci.draw_line(Vector2(rail_x, cy + 6), Vector2(rail_x, cy + 64), Color(1, 1, 1, 0.12), 3.0)
				cy += 80
		"office":
			var b := Rect2(inner.position.x + 6, inner.position.y + 12, inner.size.x - 12, inner.size.y * 0.5)
			ci.draw_rect(Rect2(b.position + Vector2(10, 12), b.size), Color(0, 0, 0, 0.3))
			Art.rrect(ci, b, Color("b9b0a0"), 3, 3, Color("7a7062"))
			_plate(ci, b.get_center(), "БЕНЗОГРАД", 14, Color("1d3a7a"), Color("ffd23f"))
			var fy := b.end.y + 26
			for k in 3:
				var fp := Vector2(b.position.x + 30 + k * 40, fy)
				ci.draw_circle(fp, 3, Art.INK)
				var wave := sin(t * 4.0 + k) * 3.0
				ci.draw_colored_polygon(PackedVector2Array([fp, fp + Vector2(24, wave), fp + Vector2(24, 12 + wave), fp + Vector2(0, 12)]),
					[Color("f2f3f7"), Color("4d7cfe"), Color("e8505b")][k])
	# Бетонный забор с колючей проволокой
	var fx := _fence_x(d)
	ci.draw_rect(Rect2(fx, 0, 8, h), Color("a8a296"))
	var y := 0.0
	while y < h:
		ci.draw_line(Vector2(fx, y), Vector2(fx + 8, y), Color("7a7468"), 1.5)
		y += 40.0
	var zz := PackedVector2Array()
	y = 0.0
	var k2 := 0
	while y <= h:
		zz.append(Vector2(fx + 4 + (3.0 if k2 % 2 == 0 else -3.0), y))
		y += 6.0
		k2 += 1
	ci.draw_polyline(zz, Color("5d6274"), 1.0)


# ---------------------------------------------------------------------------
# Озеро «Звенящий лёд»
# ---------------------------------------------------------------------------
static func _draw_ice(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	ci.draw_rect(r, Color("e8f1f7"))
	# Заструги: волны снега
	for k in int(h / 26.0):
		var y := k * 26.0 + 10
		var x0 := r.position.x + Art.hash01(k + int(ci.position.y)) * 60
		ci.draw_line(Vector2(x0, y), Vector2(x0 + 90, y + 8), Color("d3e2ec"), 4.0)
	match d.kind:
		"snow":
			for it in d.items:
				var p: Vector2 = it.pos
				ci.draw_set_transform(p, 0.3, Vector2(1.0, 0.55))
				ci.draw_circle(Vector2.ZERO, 24 * it.size, Color(0.55, 0.78, 0.9, 0.45))        # голый лёд
				ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"hummocks":
			for it in d.items:
				_hummock(ci, it.pos, 22.0 * it.size, it.phase)
		"fishing":
			for it in d.items:
				var p: Vector2 = it.pos
				ci.draw_circle(p + Vector2(18, 0), 7, Color("1d3a5a"))                              # лунка
				Art.rrect(ci, Rect2(p - Vector2(9, 7), Vector2(18, 14)), Color("5d6274"), 3)        # ящик
				_person(ci, p + Vector2(0, -2), [Color("3f6fa8"), Color("6b7d4f"), Color("b8312f")][int(it.k * 3.0) % 3], Color("8a6a4a"))
				ci.draw_line(p + Vector2(6, -4), p + Vector2(18, 0), Color("c9cdd6"), 1.5)
				ci.draw_circle(p + Vector2(18, 0) + Vector2(0, sin(t * 3.0 + it.phase) * 1.5), 2, Art.RED)
			var tent := Vector2(inner.end.x - 40, inner.position.y + 30)
			ci.draw_colored_polygon(PackedVector2Array([tent + Vector2(-26, 20), tent + Vector2(26, 20), tent + Vector2(0, -24)]), Color("e8a33a"))
		"seal":
			var c := inner.get_center()
			ci.draw_set_transform(c, 0, Vector2(1.0, 0.7))
			ci.draw_circle(Vector2.ZERO, 40, Color("c6dbe8"))
			ci.draw_circle(Vector2.ZERO, 33, Color("1d4a6a"))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			var up := clampf(sin(t * 0.9 + d.phase) * 1.6, 0.0, 1.0)
			if up > 0.05:
				ci.draw_circle(c + Vector2(0, 6 - up * 6), 13 * up + 2, Color("6d7182"))
				ci.draw_circle(c + Vector2(-5, 2 - up * 8), 2.5 * up, Art.INK)
				ci.draw_circle(c + Vector2(5, 2 - up * 8), 2.5 * up, Art.INK)
			ci.draw_arc(c, 22 + fmod(t * 10.0, 10.0), 0, TAU, 20, Color(1, 1, 1, 0.3), 1.5)
	# Торосы вдоль дороги
	var fx := _fence_x(d)
	for k in int(h / 40.0) + 1:
		_hummock(ci, Vector2(fx + 4, k * 40.0 + 14), 13.0 + Art.hash01(k + int(ci.position.y)) * 6.0, k * 1.3)


static func _hummock(ci: Node2D, p: Vector2, s: float, ph: float) -> void:
	var pts := PackedVector2Array()
	for k in 7:
		var a := k * TAU / 7.0 + ph
		pts.append(p + Vector2(cos(a), sin(a)) * s * (0.7 + 0.3 * sin(ph * 3.0 + k * 2.1)))
	var sh := PackedVector2Array()
	for q in pts:
		sh.append(q + Vector2(5, 7))
	ci.draw_colored_polygon(sh, Color(0.3, 0.45, 0.6, 0.3))
	ci.draw_colored_polygon(pts, Color("bfe0f0"))
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], p]), Color("e8f6fd"))
	ci.draw_line(p, pts[3], Color(1, 1, 1, 0.8), 1.5)


# ---------------------------------------------------------------------------
# Омск-1985
# ---------------------------------------------------------------------------
static func _draw_retro(ci: Node2D, d: Dictionary, h: float, t: float) -> void:
	var r: Rect2 = d.rect
	var inner: Rect2 = d.inner
	ci.draw_rect(r, Art.pal("lot"))
	# Газон с тополями вдоль тротуара
	var gx := _fence_x(d) - (2.0 if d.side < 0 else 0.0)
	ci.draw_rect(Rect2(gx, 0, 10, h), Color("6b6a4a"))
	match d.kind:
		"khrush":
			var b := Rect2(inner.position.x + 4, inner.position.y + 6, inner.size.x - 8, inner.size.y - 12)
			ci.draw_rect(Rect2(b.position + Vector2(12, 14), b.size), Color(0, 0, 0, 0.32))
			ci.draw_rect(b, d.color)
			ci.draw_rect(b.grow(-6), d.color.darkened(0.12))
			# Швы панелей и вентиляция
			var y := b.position.y + 30
			while y < b.end.y - 10:
				ci.draw_line(Vector2(b.position.x + 6, y), Vector2(b.end.x - 6, y), d.color.darkened(0.25), 1.5)
				y += 36
			for it in d.items:
				var p: Vector2 = it.pos
				if b.has_point(p):
					ci.draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color("7a7062"))
					# Антенна-«ёлочка»
					ci.draw_line(p + Vector2(0, -14), p + Vector2(0, 14), Color("3d3a35"), 1.5)
					for k in 3:
						ci.draw_line(p + Vector2(-10, -8 + k * 8), p + Vector2(10, -8 + k * 8), Color("3d3a35"), 1.2)
			# Балконы со стороны дороги и бельё
			var bx: float = b.end.x if d.side < 0 else b.position.x - 10
			var yy := b.position.y + 14
			while yy < b.end.y - 20:
				ci.draw_rect(Rect2(bx, yy, 10, 22), Color("8f877a"))
				yy += 40
		"kvass":
			var c := inner.get_center() + Vector2(0, -20)
			Art.rrect(ci, Rect2(c - Vector2(34, 20) + Vector2(5, 6), Vector2(68, 40)), Color(0, 0, 0, 0.25), 18)
			Art.rrect(ci, Rect2(c - Vector2(34, 20), Vector2(68, 40)), Color("e8c040"), 18, 2, Color("8a6a20"))
			Art.text_center(ci, c, "КВАС", 14, Color("6b3a1a"), true)
			_person(ci, c + Vector2(44, 0), Color("f2f3f7"), Color("e8c49a"))                         # продавщица
			for k in 5:                                                                              # очередь
				_person(ci, c + Vector2(-48 + sin(k * 1.3) * 6, 26 + k * 20), [Color("8a6e5a"), Color("5a7896"), Color("b8483e")][k % 3])
		"booth":
			for k in 2:
				var p := Vector2(inner.position.x + 24 + k * 44, inner.position.y + 30)
				ci.draw_rect(Rect2(p + Vector2(5, 6), Vector2(34, 34)), Color(0, 0, 0, 0.3))
				Art.rrect(ci, Rect2(p, Vector2(34, 34)), Color("c43a2e"), 3, 2, Color("6a1a10"))
				ci.draw_rect(Rect2(p + Vector2(5, 5), Vector2(24, 24)), Color("e8d9b5"))
			_plate(ci, Vector2(inner.position.x + 66, inner.position.y + 84), "ТАКСОФОН", 9, Color("c43a2e"), Color("f2efe6"))
			# Автомат с газировкой
			var gp := Vector2(inner.position.x + 30, inner.position.y + 120)
			if gp.y + 40 < h:
				Art.rrect(ci, Rect2(gp, Vector2(30, 40)), Color("d9d4c4"), 3, 2, Color("8a8070"))
				ci.draw_rect(Rect2(gp + Vector2(6, 6), Vector2(18, 10)), Color("5a7896"))
				Art.text_center(ci, gp + Vector2(15, 28), "3к", 9, Color("b8483e"), true)
		"gastronom":
			var b := Rect2(inner.position.x + 6, inner.position.y + 10, inner.size.x - 12, inner.size.y * 0.55)
			ci.draw_rect(Rect2(b.position + Vector2(10, 12), b.size), Color(0, 0, 0, 0.3))
			ci.draw_rect(b, Color("b8ad98"))
			_plate(ci, Vector2(b.get_center().x, b.position.y + 18), "ГАСТРОНОМ", 13, Color("2f4a6a"), Color("f2e6c8"))
			# Грузовичок разгружает хлеб
			var ty := b.end.y + 40
			if ty + 30 < h:
				Art.draw_van(ci, minf(inner.size.x - 30, 110.0), 46, Color("8fae8a"), "ХЛЕБ",
					{"base": Transform2D(PI / 2.0 if d.side < 0 else -PI / 2.0, Vector2(inner.get_center().x, ty)), "text_color": Color("6b3a1a")})
		"dvor":
			ci.draw_rect(inner, Color("7a7a58"))
			var c := inner.get_center()
			# Горка-ракета, песочница, качели
			ci.draw_circle(c + Vector2(-30, -30), 18, Color("b8483e"))
			ci.draw_circle(c + Vector2(-30, -30), 8, Color("e3d6b4"))
			Art.rrect(ci, Rect2(c + Vector2(10, -10), Vector2(44, 34)), Color("d6bd72"), 3, 3, Color("8a6e5a"))
			ci.draw_line(c + Vector2(-50, 40), c + Vector2(10, 40), Color("5a7896"), 4.0)
			var sw := sin(t * 2.0 + d.phase) * 6.0
			ci.draw_rect(Rect2(c + Vector2(-26 + sw, 34), Vector2(14, 10)), Color("b8483e"))
			# Бабушки на лавочке
			for k in 3:
				_person(ci, Vector2(inner.position.x + 20 + k * 18, inner.end.y - 18), [Color("6f8f5f"), Color("8a6e5a"), Color("5a7896")][k], Color("d9d4c4"))
			# Ковёр на турнике
			Art.rrect(ci, Rect2(inner.end.x - 60, inner.position.y + 14, 44, 26), Color("8a2a2a"), 2, 2, Color("d6bd72"))
		"kiosk":
			var kp := Vector2(inner.position.x + 20, inner.position.y + 20)
			Art.rrect(ci, Rect2(kp + Vector2(5, 6), Vector2(70, 46)), Color(0, 0, 0, 0.25), 4)
			Art.rrect(ci, Rect2(kp, Vector2(70, 46)), Color("5a7896"), 4, 2, Color("2f4a6a"))
			_plate(ci, kp + Vector2(35, 23), "СОЮЗПЕЧАТЬ", 8, Color("f2e6c8"), Color("2f4a6a"))
			for it in d.items:
				var p: Vector2 = it.pos
				if p.y > kp.y + 70:
					_shadow_circle(ci, p, 16 * it.size)
					ci.draw_circle(p, 16 * it.size, Color("6f7a4a"))
					ci.draw_circle(p + Vector2(-4, -4), 8 * it.size, Color("858f5a"))
	# Тополя вдоль тротуара
	for k in int(h / 70.0) + 1:
		var p := Vector2(gx + 5, k * 70.0 + 30)
		ci.draw_circle(p + Vector2(4, 5), 12, Color(0, 0, 0, 0.22))
		ci.draw_circle(p, 12, Color("6f7a4a"))
