extends Node2D
## Бесконечная дорога. Рисуется только та часть, что видна камере,
## поэтому её длина не ограничена и она ничего не стоит по памяти.
## Заплатки, трещины и люки зависят от координаты Y — при каждом проезде одинаковые.

const ROW := 160.0            # шаг «случайных» деталей асфальта
const DASH := 60.0            # длина штриха разметки
const DASH_GAP := 60.0


func _ready() -> void:
	z_index = -20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var top := cam.global_position.y - Art.VIEW_H / 2.0 - 220.0
	var bottom := cam.global_position.y + Art.VIEW_H / 2.0 + 220.0
	var h := bottom - top

	# Тротуары
	draw_rect(Rect2(Art.CITY_LEFT_END - 60, top, Art.SIDEWALK_W + 60, h), Art.pal("sidewalk"))
	draw_rect(Rect2(Art.ROAD_RIGHT, top, Art.SIDEWALK_W + 60, h), Art.pal("sidewalk"))
	var y := floorf(top / 46.0) * 46.0
	while y < bottom:
		draw_line(Vector2(Art.CITY_LEFT_END, y), Vector2(Art.ROAD_LEFT, y), Art.pal("seam"), 2.0)
		draw_line(Vector2(Art.ROAD_RIGHT, y), Vector2(Art.CITY_RIGHT_START, y), Art.pal("seam"), 2.0)
		y += 46.0
	# Бордюры
	draw_rect(Rect2(Art.ROAD_LEFT - 6, top, 6, h), Art.pal("curb"))
	draw_rect(Rect2(Art.ROAD_RIGHT, top, 6, h), Art.pal("curb"))

	# Асфальт
	draw_rect(Rect2(Art.ROAD_LEFT, top, Art.ROAD_W, h), Art.pal("asphalt"))

	# Заплатки, трещины, люки
	var row_start := int(floorf(top / ROW))
	var row_end := int(ceilf(bottom / ROW))
	for row in range(row_start, row_end + 1):
		var ry := row * ROW
		var r1 := Art.hash01(row)
		var r2 := Art.hash01(row * 7 + 3)
		var r3 := Art.hash01(row * 13 + 11)
		if r1 < 0.35:
			var pw := 60.0 + r2 * 120.0
			var px := Art.ROAD_LEFT + 20 + r3 * (Art.ROAD_W - pw - 40)
			draw_rect(Rect2(px, ry + r2 * 60, pw, 30 + r3 * 50), Art.pal("patch"))
		if r2 < 0.3:
			var cx := Art.ROAD_LEFT + 30 + r1 * (Art.ROAD_W - 60)
			var pts := PackedVector2Array()
			for i in 5:
				pts.append(Vector2(cx + (Art.hash01(row * 31 + i) - 0.5) * 30, ry + 20 + i * 16))
			draw_polyline(pts, Art.pal("crack"), 2.0)
		if r3 < 0.12:
			var mx := Art.ROAD_LEFT + Art.LANE_W * (0.5 + floorf(r1 * Art.LANES))
			draw_circle(Vector2(mx, ry + 80), 15, Art.pal("crack"))
			draw_arc(Vector2(mx, ry + 80), 15, 0, TAU, 20, Art.pal("patch"), 2.0)

	# Сплошные линии по краям
	draw_rect(Rect2(Art.ROAD_LEFT + 10, top, 5, h), Art.pal("line_white"))
	draw_rect(Rect2(Art.ROAD_RIGHT - 15, top, 5, h), Art.pal("line_white"))

	# Прерывистая разметка между полосами (по центру — жёлтая)
	var period := DASH + DASH_GAP
	for lane in range(1, Art.LANES):
		var x := Art.ROAD_LEFT + lane * Art.LANE_W
		var color := Art.pal("line_yellow") if lane == (Art.LANES >> 1) else Art.pal("line_white")
		var dy := floorf(top / period) * period
		while dy < bottom:
			if lane == (Art.LANES >> 1):
				draw_rect(Rect2(x - 7, dy, 4, DASH), color)
				draw_rect(Rect2(x + 3, dy, 4, DASH), color)
			else:
				draw_rect(Rect2(x - 3, dy, 6, DASH), color)
			dy += period

	_draw_theme_details(top, bottom)


## Детали, зависящие от трассы: снежные валы, песок, мокрые блики, неоновая подсветка
func _draw_theme_details(top: float, bottom: float) -> void:
	match Art.theme:
		"winter":
			var y := floorf(top / 40.0) * 40.0
			while y < bottom:
				var k := Art.hash01(int(y / 40.0))
				draw_circle(Vector2(Art.ROAD_LEFT + 6 + k * 10, y), 16 + k * 10, Color("e8eef5"))
				draw_circle(Vector2(Art.ROAD_RIGHT - 6 - k * 10, y + 20), 16 + (1.0 - k) * 10, Color("e8eef5"))
				# Накатанные колеи на полосах
				y += 40.0
			for lane in Art.LANES:
				var cx := Art.ROAD_LEFT + Art.LANE_W * (lane + 0.5)
				for off in [-26.0, 26.0]:
					draw_rect(Rect2(cx + off - 9, top, 18, bottom - top), Color(0.2, 0.22, 0.28, 0.22))
		"desert":
			var y := floorf(top / 50.0) * 50.0
			while y < bottom:
				var k := Art.hash01(int(y / 50.0) + 7)
				draw_circle(Vector2(Art.ROAD_LEFT + k * 18, y), 14 + k * 12, Color(0.85, 0.7, 0.45, 0.8))
				draw_circle(Vector2(Art.ROAD_RIGHT - k * 18, y + 25), 12 + k * 14, Color(0.85, 0.7, 0.45, 0.8))
				y += 50.0
		"rain":
			# Мокрый асфальт: длинные блики
			var y := floorf(top / 120.0) * 120.0
			while y < bottom:
				var k := Art.hash01(int(y / 120.0) + 3)
				var x := Art.ROAD_LEFT + 30 + k * (Art.ROAD_W - 60)
				draw_rect(Rect2(x, y, 6 + k * 6, 70 + k * 60), Color(0.6, 0.7, 0.9, 0.07))
				y += 120.0
		"neon":
			draw_rect(Rect2(Art.ROAD_LEFT - 8, top, 4, bottom - top), Color("ff4fd8"))
			draw_rect(Rect2(Art.ROAD_RIGHT + 4, top, 4, bottom - top), Color("6ff2ff"))
