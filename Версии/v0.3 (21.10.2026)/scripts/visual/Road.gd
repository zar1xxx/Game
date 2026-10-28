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
	draw_rect(Rect2(Art.CITY_LEFT_END - 60, top, Art.SIDEWALK_W + 60, h), Art.SIDEWALK)
	draw_rect(Rect2(Art.ROAD_RIGHT, top, Art.SIDEWALK_W + 60, h), Art.SIDEWALK)
	var y := floorf(top / 46.0) * 46.0
	while y < bottom:
		draw_line(Vector2(Art.CITY_LEFT_END, y), Vector2(Art.ROAD_LEFT, y), Art.SIDEWALK_SEAM, 2.0)
		draw_line(Vector2(Art.ROAD_RIGHT, y), Vector2(Art.CITY_RIGHT_START, y), Art.SIDEWALK_SEAM, 2.0)
		y += 46.0
	# Бордюры
	draw_rect(Rect2(Art.ROAD_LEFT - 6, top, 6, h), Art.CURB)
	draw_rect(Rect2(Art.ROAD_RIGHT, top, 6, h), Art.CURB)

	# Асфальт
	draw_rect(Rect2(Art.ROAD_LEFT, top, Art.ROAD_W, h), Art.ASPHALT)

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
			draw_rect(Rect2(px, ry + r2 * 60, pw, 30 + r3 * 50), Art.ASPHALT_PATCH)
		if r2 < 0.3:
			var cx := Art.ROAD_LEFT + 30 + r1 * (Art.ROAD_W - 60)
			var pts := PackedVector2Array()
			for i in 5:
				pts.append(Vector2(cx + (Art.hash01(row * 31 + i) - 0.5) * 30, ry + 20 + i * 16))
			draw_polyline(pts, Art.ASPHALT_CRACK, 2.0)
		if r3 < 0.12:
			var mx := Art.ROAD_LEFT + Art.LANE_W * (0.5 + floorf(r1 * Art.LANES))
			draw_circle(Vector2(mx, ry + 80), 15, Art.ASPHALT_CRACK)
			draw_arc(Vector2(mx, ry + 80), 15, 0, TAU, 20, Art.ASPHALT_PATCH, 2.0)

	# Сплошные линии по краям
	draw_rect(Rect2(Art.ROAD_LEFT + 10, top, 5, h), Art.LINE_WHITE)
	draw_rect(Rect2(Art.ROAD_RIGHT - 15, top, 5, h), Art.LINE_WHITE)

	# Прерывистая разметка между полосами (по центру — жёлтая)
	var period := DASH + DASH_GAP
	for lane in range(1, Art.LANES):
		var x := Art.ROAD_LEFT + lane * Art.LANE_W
		var color := Art.LINE_YELLOW if lane == (Art.LANES >> 1) else Art.LINE_WHITE
		var dy := floorf(top / period) * period
		while dy < bottom:
			if lane == (Art.LANES >> 1):
				draw_rect(Rect2(x - 7, dy, 4, DASH), color)
				draw_rect(Rect2(x + 3, dy, 4, DASH), color)
			else:
				draw_rect(Rect2(x - 3, dy, 6, DASH), color)
			dy += period
