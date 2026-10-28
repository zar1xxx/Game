extends Node2D
## Бесконечная дорога из отрезков по CHUNK пикселей. Каждый отрезок рисуется один раз,
## когда появляется над экраном, и удаляется, когда остаётся позади, — каждый кадр
## дорога больше не перерисовывается (это заметно экономит силы телефона).
## Заплатки, трещины и люки зависят от координаты Y — при каждом проезде одинаковые.
## Здесь же стоят фонари вдоль дороги (их мягкий свет ярче ночью).

const ROW := 160.0            # шаг «случайных» деталей асфальта
const DASH := 60.0            # длина штриха разметки
const DASH_GAP := 60.0
const CHUNK := 480.0          # высота одного отрезка дороги
const LAMP_STEP := 290.0      # шаг фонарей (WorldFX берёт те же позиции для ночного света)

var _chunks: Dictionary = {}  # номер отрезка → [узел дороги, узел фонарей]
var _theme: String = ""
var _lamp_alpha: float = -1.0


func _ready() -> void:
	z_index = -20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if _theme != Art.theme:
		# Сменилась трасса (выбор в меню) — перерисовываем всё заново
		_theme = Art.theme
		for k in _chunks:
			for n in _chunks[k]:
				n.queue_free()
		_chunks.clear()
	var top := cam.global_position.y - Art.VIEW_H / 2.0 - 260.0
	var bottom := cam.global_position.y + Art.VIEW_H / 2.0 + 260.0
	var first := int(floorf(top / CHUNK))
	var last := int(floorf(bottom / CHUNK))
	for i in range(first, last + 1):
		if not _chunks.has(i):
			_chunks[i] = _make_chunk(i)
	for k in _chunks.keys():
		if k < first - 1 or k > last + 1:
			for n in _chunks[k]:
				n.queue_free()
			_chunks.erase(k)
	# Фонари: днём свет почти не виден, ночью ярче
	var a := 0.2 + 0.8 * Art.night
	if absf(a - _lamp_alpha) > 0.01:
		_lamp_alpha = a
		for k in _chunks:
			_chunks[k][1].modulate.a = a


func _make_chunk(i: int) -> Array:
	var y0 := i * CHUNK
	var road := Node2D.new()
	road.draw.connect(func(): _draw_segment(road, y0, y0 + CHUNK))
	add_child(road)
	var lamps := Node2D.new()
	# Фонари рисуются поверх кварталов (как раньше): абсолютный слой над городом
	lamps.z_as_relative = false
	lamps.z_index = -8
	lamps.modulate.a = 0.2 + 0.8 * Art.night
	lamps.draw.connect(func(): _draw_lamps(lamps, y0, y0 + CHUNK))
	add_child(lamps)
	return [road, lamps]


## Первая координата сетки с шагом step, попадающая в [top, ...) — так каждая деталь
## рисуется ровно в одном отрезке
static func _first(top: float, step: float) -> float:
	return ceilf(top / step) * step


func _draw_lamps(ci: CanvasItem, top: float, bottom: float) -> void:
	if Art.theme == "desert":
		return
	# В горах фонари стоят только справа, у отбойника
	var lamp_sides: Array = [1] if Art.theme == "mountain" else [-1, 1]
	var y := _first(top, LAMP_STEP)
	while y < bottom:
		for side in lamp_sides:
			var base := Vector2(Art.ROAD_LEFT - 14, y) if side < 0 else Vector2(Art.ROAD_RIGHT + 14, y)
			var head := base + Vector2(34 * -side, 0)
			Art.glow(ci, head + Vector2(20 * -side, 0), 95, Color(1.0, 0.84, 0.55, 0.22))
			ci.draw_line(base, head, Color("3d4152"), 4.0)
			ci.draw_circle(base, 6, Color("3d4152"))
			Art.rrect(ci, Rect2(head - Vector2(9, 5), Vector2(18, 10)), Color("fff2c4"), 4)
		y += LAMP_STEP


func _draw_segment(ci: CanvasItem, top: float, bottom: float) -> void:
	var h := bottom - top
	# Тротуары
	ci.draw_rect(Rect2(Art.CITY_LEFT_END - 60, top, Art.SIDEWALK_W + 60, h), Art.pal("sidewalk"))
	ci.draw_rect(Rect2(Art.ROAD_RIGHT, top, Art.SIDEWALK_W + 60, h), Art.pal("sidewalk"))
	var y := _first(top, 46.0)
	while y < bottom:
		ci.draw_line(Vector2(Art.CITY_LEFT_END, y), Vector2(Art.ROAD_LEFT, y), Art.pal("seam"), 2.0)
		ci.draw_line(Vector2(Art.ROAD_RIGHT, y), Vector2(Art.CITY_RIGHT_START, y), Art.pal("seam"), 2.0)
		y += 46.0
	# Бордюры
	ci.draw_rect(Rect2(Art.ROAD_LEFT - 6, top, 6, h), Art.pal("curb"))
	ci.draw_rect(Rect2(Art.ROAD_RIGHT, top, 6, h), Art.pal("curb"))

	# Асфальт
	ci.draw_rect(Rect2(Art.ROAD_LEFT, top, Art.ROAD_W, h), Art.pal("asphalt"))

	# Заплатки, трещины, люки
	var row_start := int(ceilf(top / ROW))
	var row_end := int(ceilf(bottom / ROW)) - 1
	for row in range(row_start, row_end + 1):
		var ry := row * ROW
		var r1 := Art.hash01(row)
		var r2 := Art.hash01(row * 7 + 3)
		var r3 := Art.hash01(row * 13 + 11)
		if r1 < 0.35:
			var pw := 60.0 + r2 * 120.0
			var px := Art.ROAD_LEFT + 20 + r3 * (Art.ROAD_W - pw - 40)
			ci.draw_rect(Rect2(px, ry + r2 * 60, pw, 30 + r3 * 50), Art.pal("patch"))
		if r2 < 0.3:
			var cx := Art.ROAD_LEFT + 30 + r1 * (Art.ROAD_W - 60)
			var pts := PackedVector2Array()
			for i in 5:
				pts.append(Vector2(cx + (Art.hash01(row * 31 + i) - 0.5) * 30, ry + 20 + i * 16))
			ci.draw_polyline(pts, Art.pal("crack"), 2.0)
		if r3 < 0.12:
			var mx := Art.ROAD_LEFT + Art.LANE_W * (0.5 + floorf(r1 * Art.LANES))
			ci.draw_circle(Vector2(mx, ry + 80), 15, Art.pal("crack"))
			ci.draw_arc(Vector2(mx, ry + 80), 15, 0, TAU, 20, Art.pal("patch"), 2.0)

	# Сплошные линии по краям
	ci.draw_rect(Rect2(Art.ROAD_LEFT + 10, top, 5, h), Art.pal("line_white"))
	ci.draw_rect(Rect2(Art.ROAD_RIGHT - 15, top, 5, h), Art.pal("line_white"))

	# Прерывистая разметка между полосами (по центру — жёлтая)
	var period := DASH + DASH_GAP
	for lane in range(1, Art.LANES):
		var x := Art.ROAD_LEFT + lane * Art.LANE_W
		var color := Art.pal("line_yellow") if lane == (Art.LANES >> 1) else Art.pal("line_white")
		var dy := _first(top, period)
		while dy < bottom:
			if lane == (Art.LANES >> 1):
				ci.draw_rect(Rect2(x - 7, dy, 4, DASH), color)
				ci.draw_rect(Rect2(x + 3, dy, 4, DASH), color)
			else:
				ci.draw_rect(Rect2(x - 3, dy, 6, DASH), color)
			dy += period

	_draw_theme_details(ci, top, bottom)


## Детали, зависящие от трассы: снежные валы, песок, мокрые блики, неоновая подсветка
func _draw_theme_details(ci: CanvasItem, top: float, bottom: float) -> void:
	match Art.theme:
		"winter":
			var y := _first(top, 40.0)
			while y < bottom:
				var k := Art.hash01(int(y / 40.0))
				ci.draw_circle(Vector2(Art.ROAD_LEFT + 6 + k * 10, y), 16 + k * 10, Color("e8eef5"))
				ci.draw_circle(Vector2(Art.ROAD_RIGHT - 6 - k * 10, y + 20), 16 + (1.0 - k) * 10, Color("e8eef5"))
				# Накатанные колеи на полосах
				y += 40.0
			for lane in Art.LANES:
				var cx := Art.ROAD_LEFT + Art.LANE_W * (lane + 0.5)
				for off in [-26.0, 26.0]:
					ci.draw_rect(Rect2(cx + off - 9, top, 18, bottom - top), Color(0.2, 0.22, 0.28, 0.22))
		"desert":
			var y := _first(top, 50.0)
			while y < bottom:
				var k := Art.hash01(int(y / 50.0) + 7)
				ci.draw_circle(Vector2(Art.ROAD_LEFT + k * 18, y), 14 + k * 12, Color(0.85, 0.7, 0.45, 0.8))
				ci.draw_circle(Vector2(Art.ROAD_RIGHT - k * 18, y + 25), 12 + k * 14, Color(0.85, 0.7, 0.45, 0.8))
				y += 50.0
		"rain":
			# Мокрый асфальт: длинные блики
			var y := _first(top, 120.0)
			while y < bottom:
				var k := Art.hash01(int(y / 120.0) + 3)
				var x := Art.ROAD_LEFT + 30 + k * (Art.ROAD_W - 60)
				ci.draw_rect(Rect2(x, y, 6 + k * 6, 70 + k * 60), Color(0.6, 0.7, 0.9, 0.07))
				y += 120.0
		"village":
			# Пыльные обочины и заплатки на старом асфальте
			var y := _first(top, 70.0)
			while y < bottom:
				var k := Art.hash01(int(y / 70.0) + 11)
				ci.draw_circle(Vector2(Art.ROAD_LEFT + k * 14, y), 10 + k * 10, Color(0.6, 0.5, 0.36, 0.6))
				ci.draw_circle(Vector2(Art.ROAD_RIGHT - k * 14, y + 35), 10 + (1.0 - k) * 10, Color(0.6, 0.5, 0.36, 0.6))
				if k > 0.85:
					ci.draw_rect(Rect2(Art.ROAD_LEFT + 40 + k * (Art.ROAD_W - 140), y + 10, 40, 20), Color(0.36, 0.35, 0.37, 0.45))
				y += 70.0
		"beach":
			# Песок, нанесённый ветром на края дороги
			var y := _first(top, 60.0)
			while y < bottom:
				var k := Art.hash01(int(y / 60.0) + 5)
				ci.draw_circle(Vector2(Art.ROAD_RIGHT - k * 12, y), 12 + k * 12, Color(0.93, 0.84, 0.62, 0.7))
				y += 60.0
		"mountain":
			# Отбойник у обрыва и предупреждающие стрелки «поворот»
			var y := _first(top, 400.0)
			while y < bottom:
				if Art.hash01(int(y / 400.0)) > 0.5:
					for k in 3:
						var cy := y + 40 + k * 40
						var cx := Art.ROAD_RIGHT - 18.0
						ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, cy - 10), Vector2(cx + 4, cy), Vector2(cx - 8, cy + 10)]), Color(1, 0.85, 0.2, 0.8))
				y += 400.0
		"neon":
			ci.draw_rect(Rect2(Art.ROAD_LEFT - 8, top, 4, bottom - top), Color("ff4fd8"))
			ci.draw_rect(Rect2(Art.ROAD_RIGHT + 4, top, 4, bottom - top), Color("6ff2ff"))
