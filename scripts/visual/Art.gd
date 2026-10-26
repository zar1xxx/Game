class_name Art
extends RefCounted
## Единый визуальный стиль игры «В погоне за бензином».
## Здесь собраны палитра, размеры дороги и функции рисования машин,
## которыми пользуются игрок, встречные машины, город и главное меню.
## Хотите поменять цвета всей игры — меняйте их здесь.

# ---------------------------------------------------------------------------
# Разметка мира (в мировых координатах, ширина экрана 1152)
# ---------------------------------------------------------------------------
const VIEW_W := 1152.0
const VIEW_H := 648.0
const ROAD_LEFT := 236.0
const ROAD_RIGHT := 916.0
const ROAD_W := ROAD_RIGHT - ROAD_LEFT
const LANES := 4
const LANE_W := ROAD_W / LANES
const SIDEWALK_W := 46.0
const CITY_LEFT_END := ROAD_LEFT - SIDEWALK_W          # граница левого квартала
const CITY_RIGHT_START := ROAD_RIGHT + SIDEWALK_W      # граница правого квартала

# ---------------------------------------------------------------------------
# Палитра: вечерний город, плоские цвета, мягкие тени
# ---------------------------------------------------------------------------
const INK := Color("171a24")            # самый тёмный (фон, контуры)
const ASPHALT := Color("2f3242")
const ASPHALT_PATCH := Color("363a4c")
const ASPHALT_CRACK := Color("252836")
const LINE_WHITE := Color("e9e4d4")
const LINE_YELLOW := Color("f4b942")
const SIDEWALK := Color("666b7e")
const SIDEWALK_SEAM := Color("595d6f")
const CURB := Color("a9adbb")
const GLASS := Color("1c2333")
const GLASS_SHINE := Color("4a5d80")
const HEADLIGHT := Color("fff2c4")
const TAILLIGHT := Color("8c1c2b")
const BRAKELIGHT := Color("ff3b4a")

const ORANGE := Color("ff8a3d")         # фирменный цвет игрока и бензина
const YELLOW := Color("ffc857")
const RED := Color("e8505b")
const TEAL := Color("2ec4b6")
const BLUE := Color("4d7cfe")
const PURPLE := Color("8e6cef")
const GREEN := Color("5bbf72")
const SILVER := Color("c9cdd6")

const GRASS := Color("2f5e45")
const GRASS_LIGHT := Color("3b7354")
const TREE_COLORS := [Color("3f8f5a"), Color("4fa36a"), Color("2f7a4b"), Color("5a9e4b")]
const ROOF_COLORS := [Color("5b6c8f"), Color("7a5c7e"), Color("b07b62"), Color("4f7a74"),
	Color("8d8a6e"), Color("6e7487"), Color("9a6a6a")]
const ENEMY_COLORS := [BLUE, TEAL, PURPLE, SILVER, GREEN, Color("5d6b8a")]

const SHADOW := Color(0, 0, 0, 0.32)
const SHADOW_OFFSET := Vector2(6, 8)

# UI
const UI_PANEL := Color("1b1e2b")
const UI_PANEL_LIGHT := Color("272b3d")
const UI_TEXT := Color("eef0f6")
const UI_MUTED := Color("9aa0b4")

static var font_bold: Font = preload("res://fonts/Inter-Bold.otf")
static var font_title: Font = preload("res://fonts/InterDisplay-Black.otf")

static var _box_cache: Dictionary = {}


# ---------------------------------------------------------------------------
# Базовые примитивы
# ---------------------------------------------------------------------------

## Прямоугольник со скруглёнными углами (с необязательной обводкой)
static func rrect(ci: CanvasItem, rect: Rect2, color: Color, radius: float,
		border: float = 0.0, border_color: Color = Color.TRANSPARENT) -> void:
	var key := "%s|%d|%d|%s" % [color.to_html(), int(radius), int(border), border_color.to_html()]
	var sb: StyleBoxFlat = _box_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(radius))
		sb.anti_aliasing = true
		sb.corner_detail = 6
		if border > 0.0:
			sb.set_border_width_all(int(border))
			sb.border_color = border_color
		_box_cache[key] = sb
	sb.draw(ci.get_canvas_item(), rect)


## Мягкое свечение (радиальный градиент, без «колец»)
static var _glow_tex: GradientTexture2D = null

static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color, _steps: int = 0) -> void:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	ci.draw_texture_rect(_glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


static func shadow_rect(ci: CanvasItem, rect: Rect2, radius: float, offset: Vector2 = SHADOW_OFFSET) -> void:
	rrect(ci, Rect2(rect.position + offset, rect.size), SHADOW, radius)


static func trapezoid(ci: CanvasItem, y_top: float, y_bottom: float, w_top: float, w_bottom: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-w_top / 2.0, y_top), Vector2(w_top / 2.0, y_top),
		Vector2(w_bottom / 2.0, y_bottom), Vector2(-w_bottom / 2.0, y_bottom)]), color)


# ---------------------------------------------------------------------------
# Машины (вид сверху, капот смотрит вверх по оси -Y)
# ---------------------------------------------------------------------------
## opts:
##   steer: float  — поворот передних колёс (-1..1)
##   brake: bool   — горят стоп-сигналы
##   lights: bool  — включены фары (рисуется световой конус)
##   stripes: bool — гоночные полосы
##   spoiler: bool — антикрыло
##   hazard: bool  — мигает аварийка
##   flip: bool    — машина развёрнута на 180° (встречная)
##   time: float   — время для анимаций
##   shadow: bool  — рисовать тень (по умолчанию да)
##   base: Transform2D — дополнительное преобразование (позиция/поворот внутри узла)
static func draw_car(ci: CanvasItem, length: float, width: float, body: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var flip: bool = opts.get("flip", false)
	var t: float = opts.get("time", 0.0)
	var L := length
	var W := width
	var hl := Vector2(W, L) / 2.0
	var frame := base * Transform2D(PI if flip else 0.0, Vector2.ZERO)

	# Тень не разворачивается вместе с машиной — свет всегда падает с одной стороны
	if opts.get("shadow", true):
		ci.draw_set_transform_matrix(base)
		rrect(ci, Rect2(-hl + SHADOW_OFFSET, Vector2(W, L)), SHADOW, W * 0.32)

	# Световой конус фар
	if opts.get("lights", false):
		ci.draw_set_transform_matrix(frame)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-W * 0.35, -hl.y), Vector2(W * 0.35, -hl.y),
			Vector2(W * 0.9, -hl.y - L * 1.1), Vector2(-W * 0.9, -hl.y - L * 1.1)]),
			Color(1.0, 0.93, 0.7, 0.09))

	# Колёса
	var steer: float = opts.get("steer", 0.0)
	var wheel := Vector2(W * 0.2, L * 0.19)
	for side in [-1.0, 1.0]:
		for front in [true, false]:
			var c := Vector2(side * (hl.x - W * 0.05), -L * 0.3 if front else L * 0.3)
			var ang := steer * 0.5 if front else 0.0
			ci.draw_set_transform_matrix(frame * Transform2D(ang, c))
			rrect(ci, Rect2(-wheel / 2.0, wheel), INK, 3)

	ci.draw_set_transform_matrix(frame)
	# Кузов
	rrect(ci, Rect2(-hl, Vector2(W, L)), body, W * 0.32, 2, body.darkened(0.45))
	# Блик на капоте
	rrect(ci, Rect2(-W * 0.34, -L * 0.46, W * 0.68, L * 0.2), body.lightened(0.18), W * 0.2)
	if opts.get("stripes", false):
		for sx in [-1.0, 1.0]:
			ci.draw_rect(Rect2(sx * W * 0.1 - W * 0.04, -hl.y + 3, W * 0.08, L - 6), Color(1, 1, 1, 0.85))
	# Лобовое стекло, крыша, заднее стекло
	trapezoid(ci, -L * 0.2, -L * 0.04, W * 0.6, W * 0.78, GLASS)
	ci.draw_line(Vector2(-W * 0.22, -L * 0.17), Vector2(-W * 0.06, -L * 0.07), GLASS_SHINE, 2.0)
	rrect(ci, Rect2(-W * 0.37, -L * 0.04, W * 0.74, L * 0.25), body.lightened(0.08), 4)
	trapezoid(ci, L * 0.21, L * 0.31, W * 0.72, W * 0.58, GLASS)
	# Зеркала
	ci.draw_rect(Rect2(-hl.x - 3, -L * 0.14, 4, 6), body.darkened(0.3))
	ci.draw_rect(Rect2(hl.x - 1, -L * 0.14, 4, 6), body.darkened(0.3))
	# Фары
	rrect(ci, Rect2(-W * 0.42, -hl.y + 2, W * 0.24, L * 0.05), HEADLIGHT, 2)
	rrect(ci, Rect2(W * 0.18, -hl.y + 2, W * 0.24, L * 0.05), HEADLIGHT, 2)
	# Стоп-сигналы
	var brake: bool = opts.get("brake", false)
	var tail := BRAKELIGHT if brake else TAILLIGHT
	rrect(ci, Rect2(-W * 0.42, hl.y - 2 - L * 0.045, W * 0.22, L * 0.045), tail, 2)
	rrect(ci, Rect2(W * 0.2, hl.y - 2 - L * 0.045, W * 0.22, L * 0.045), tail, 2)
	if brake:
		glow(ci, Vector2(-W * 0.31, hl.y), W * 0.35, Color(1, 0.2, 0.25, 0.35), 4)
		glow(ci, Vector2(W * 0.31, hl.y), W * 0.35, Color(1, 0.2, 0.25, 0.35), 4)
	if opts.get("spoiler", false):
		rrect(ci, Rect2(-W * 0.55, hl.y - L * 0.09, W * 1.1, L * 0.06), INK, 2)
	if opts.get("hazard", false) and fmod(t, 0.8) < 0.4:
		for p in [Vector2(-hl.x, -hl.y), Vector2(hl.x, -hl.y), Vector2(-hl.x, hl.y), Vector2(hl.x, hl.y)]:
			glow(ci, p * 0.9, 10, Color(1, 0.6, 0.1, 0.8), 4)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Грузовик: кабина + длинный фургон
static func draw_truck(ci: CanvasItem, length: float, width: float, cab: Color, box: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var flip: bool = opts.get("flip", false)
	var L := length
	var W := width
	var hl := Vector2(W, L) / 2.0
	var frame := base * Transform2D(PI if flip else 0.0, Vector2.ZERO)
	ci.draw_set_transform_matrix(base)
	rrect(ci, Rect2(-hl + SHADOW_OFFSET * 1.4, Vector2(W, L)), SHADOW, 8)
	ci.draw_set_transform_matrix(frame)
	var cab_len := L * 0.24
	# Колёса
	for side in [-1.0, 1.0]:
		for y in [-hl.y + cab_len * 0.45, hl.y - L * 0.12, hl.y - L * 0.28]:
			rrect(ci, Rect2(side * (hl.x - 4) - 6, y - 10, 12, 20), INK, 3)
	# Фургон
	var box_rect := Rect2(-hl.x, -hl.y + cab_len + 6, W, L - cab_len - 6)
	rrect(ci, box_rect, box, 6, 2, box.darkened(0.4))
	var y := box_rect.position.y + 16
	while y < box_rect.end.y - 8:
		ci.draw_line(Vector2(-hl.x + 6, y), Vector2(hl.x - 6, y), box.darkened(0.12), 2.0)
		y += 22
	ci.draw_rect(Rect2(-hl.x + 4, box_rect.position.y + 8, 6, box_rect.size.y - 16), ORANGE)
	ci.draw_rect(Rect2(hl.x - 10, box_rect.position.y + 8, 6, box_rect.size.y - 16), ORANGE)
	# Кабина
	rrect(ci, Rect2(-hl.x + 2, -hl.y, W - 4, cab_len), cab, 8, 2, cab.darkened(0.45))
	trapezoid(ci, -hl.y + cab_len * 0.18, -hl.y + cab_len * 0.48, W * 0.66, W * 0.8, GLASS)
	rrect(ci, Rect2(-W * 0.4, -hl.y + 2, W * 0.2, 6), HEADLIGHT, 2)
	rrect(ci, Rect2(W * 0.2, -hl.y + 2, W * 0.2, 6), HEADLIGHT, 2)
	rrect(ci, Rect2(-W * 0.45, hl.y - 6, W * 0.2, 5), TAILLIGHT, 2)
	rrect(ci, Rect2(W * 0.25, hl.y - 6, W * 0.2, 5), TAILLIGHT, 2)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Текст по центру точки (используется на вывесках и бонусах)
static func text_center(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color, title: bool = false) -> void:
	var f := font_title if title else font_bold
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, pos + Vector2(-w / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Детерминированный «случайный» хеш для целого числа (одинаковый при каждом кадре)
static func hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x % 100000) / 100000.0
