extends Control
## Анимированный фон главного меню: бесконечная дорога с разметкой
## и проезжающими машинками. Рисуется кодом, без дополнительных картинок.

@export var scroll_speed: float = 420.0
@export var lanes: int = 4

const GRASS := Color(0.16, 0.36, 0.18)
const ASPHALT := Color(0.18, 0.18, 0.2)
const EDGE := Color(0.92, 0.92, 0.92)
const DASH := Color(0.98, 0.82, 0.2)

var _offset: float = 0.0
var _cars: Array = []  # [{lane, y, speed, color}]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		_cars.append(_make_car(randf_range(-200.0, size.y)))


func _make_car(start_y: float) -> Dictionary:
	var palette := [Color(0.85, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.75, 0.15),
		Color(0.9, 0.9, 0.9), Color(0.4, 0.8, 0.4)]
	return {
		"lane": randi() % lanes,
		"y": start_y,
		"speed": randf_range(80.0, 260.0),
		"color": palette[randi() % palette.size()],
	}


func _process(delta: float) -> void:
	_offset = fmod(_offset + scroll_speed * delta, 80.0)
	for car in _cars:
		car.y += (scroll_speed - car.speed) * delta
		if car.y > size.y + 120.0:
			var fresh := _make_car(-150.0)
			car.lane = fresh.lane
			car.y = fresh.y
			car.speed = fresh.speed
			car.color = fresh.color
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var road_w := minf(w * 0.55, 640.0)
	var road_x := (w - road_w) / 2.0
	var lane_w := road_w / lanes

	draw_rect(Rect2(0, 0, w, h), GRASS)
	draw_rect(Rect2(road_x, 0, road_w, h), ASPHALT)
	draw_rect(Rect2(road_x - 8, 0, 8, h), EDGE)
	draw_rect(Rect2(road_x + road_w, 0, 8, h), EDGE)

	# Прерывистая разметка между полосами
	for lane in range(1, lanes):
		var x := road_x + lane * lane_w - 3.0
		var y := -80.0 + _offset
		while y < h:
			draw_rect(Rect2(x, y, 6, 40), DASH)
			y += 80.0

	# Машинки
	for car in _cars:
		var cx: float = road_x + (car.lane + 0.5) * lane_w
		var body := Rect2(cx - 22, car.y, 44, 80)
		draw_rect(body, car.color)
		draw_rect(Rect2(cx - 17, car.y + 14, 34, 16), Color(0.1, 0.12, 0.18))  # лобовое
		draw_rect(Rect2(cx - 17, car.y + 56, 34, 12), Color(0.1, 0.12, 0.18))  # заднее
		draw_rect(Rect2(cx - 20, car.y + 74, 10, 5), Color(1, 0.2, 0.2))       # стоп-сигналы
		draw_rect(Rect2(cx + 10, car.y + 74, 10, 5), Color(1, 0.2, 0.2))

	# Затемнение, чтобы текст меню хорошо читался
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
