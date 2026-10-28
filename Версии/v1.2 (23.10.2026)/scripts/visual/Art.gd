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

## Текущее время суток: 0 — день, 1 — глубокая ночь (выставляет DayNight.gd).
## Влияет на яркость фар и фонарей.
static var night: float = 0.5
## Текущая тема трассы: city, winter, desert, rain, neon (выставляет Game/Меню)
static var theme: String = "city"

## Цвета, зависящие от темы трассы
const THEME_COLORS := {
	"city": {},
	"winter": {"asphalt": Color("4a5163"), "patch": Color("566074"), "crack": Color("3c4252"),
		"sidewalk": Color("d9e2ec"), "seam": Color("c3cedb"), "curb": Color("eef3f8"),
		"grass": Color("e8eef5"), "lot": Color("cfd9e4"), "line_white": Color("c9d0d9"),
		"line_yellow": Color("d9b764")},
	"desert": {"asphalt": Color("3d3a3f"), "patch": Color("47434a"), "crack": Color("2e2b30"),
		"sidewalk": Color("c9a36b"), "seam": Color("b8925c"), "curb": Color("d8c09a"),
		"grass": Color("d9b77e"), "lot": Color("d4ad72")},
	"rain": {"asphalt": Color("22252f"), "patch": Color("2a2e3a"), "crack": Color("1a1c24"),
		"sidewalk": Color("4a4f60"), "seam": Color("40455a"), "lot": Color("1d2030")},
	"neon": {"asphalt": Color("1f1f2e"), "patch": Color("26263a"), "crack": Color("17171f"),
		"sidewalk": Color("34344a"), "seam": Color("2c2c40"), "curb": Color("ff4fd8"),
		"lot": Color("16162a"), "line_white": Color("6ff2ff"), "line_yellow": Color("ff4fd8")},
	# Омск: асфальт в заплатках, серо-бурые тротуары, пыльная трава
	"omsk": {"asphalt": Color("34353d"), "patch": Color("43444d"), "crack": Color("24252b"),
		"sidewalk": Color("74706a"), "seam": Color("65615b"), "curb": Color("b3ada3"),
		"grass": Color("4f6140"), "lot": Color("2b2c33"), "line_white": Color("cfc8b4"),
		"line_yellow": Color("d9a83f")},
}
const BASE_COLORS := {
	"asphalt": Color("2f3242"), "patch": Color("363a4c"), "crack": Color("252836"),
	"sidewalk": Color("666b7e"), "seam": Color("595d6f"), "curb": Color("a9adbb"),
	"grass": Color("2f5e45"), "lot": Color("23263a"), "line_white": Color("e9e4d4"),
	"line_yellow": Color("f4b942"),
}


static func pal(key: String) -> Color:
	var t: Dictionary = THEME_COLORS.get(theme, {})
	return t.get(key, BASE_COLORS[key])


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

static func glow_texture() -> GradientTexture2D:
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
	return _glow_tex


static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color, _steps: int = 0) -> void:
	ci.draw_texture_rect(glow_texture(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


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
			Color(1.0, 0.93, 0.7, 0.04 + 0.11 * night))

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
	var deco: String = opts.get("deco", "")
	if deco == "taxi":
		for sx in [-1.0, 1.0]:
			for k in 6:
				var cy := -L * 0.3 + k * L * 0.1
				ci.draw_rect(Rect2(sx * (hl.x - 5) - 2.5, cy, 5, L * 0.05), INK if k % 2 == 0 else Color.WHITE)
	elif deco == "police":
		for sx in [-1.0, 1.0]:
			ci.draw_rect(Rect2(sx * (hl.x - 7) - 4, -L * 0.3, 8, L * 0.62), Color("2c4bb3"))
	elif deco == "ambulance":
		for sx in [-1.0, 1.0]:
			ci.draw_rect(Rect2(sx * (hl.x - 6) - 3.5, -L * 0.35, 7, L * 0.75), RED)
	if deco == "ev":
		# Панорамная стеклянная крыша от лобового до заднего стекла
		rrect(ci, Rect2(-W * 0.36, -L * 0.22, W * 0.72, L * 0.54), GLASS, W * 0.2)
		ci.draw_line(Vector2(-W * 0.2, -L * 0.18), Vector2(W * 0.05, L * 0.05), GLASS_SHINE, 3.0)
		ci.draw_line(Vector2(-W * 0.4, -hl.y + 4), Vector2(W * 0.4, -hl.y + 4), Color("cfe8ff"), 3.0)
	else:
		# Лобовое стекло, крыша, заднее стекло
		trapezoid(ci, -L * 0.2, -L * 0.04, W * 0.6, W * 0.78, GLASS)
		ci.draw_line(Vector2(-W * 0.22, -L * 0.17), Vector2(-W * 0.06, -L * 0.07), GLASS_SHINE, 2.0)
		rrect(ci, Rect2(-W * 0.37, -L * 0.04, W * 0.74, L * 0.25), body.lightened(0.08), 4)
		trapezoid(ci, L * 0.21, L * 0.31, W * 0.72, W * 0.58, GLASS)
	match deco:
		"taxi":
			# Шашечки на крыше
			rrect(ci, Rect2(-W * 0.28, L * 0.02, W * 0.56, L * 0.1), INK, 3)
			for k in 4:
				ci.draw_rect(Rect2(-W * 0.26 + k * W * 0.13, L * 0.03 + (k % 2) * L * 0.04, W * 0.13, L * 0.04), YELLOW)
		"police", "ambulance":
			var on := fmod(t, 0.5) < 0.25
			var c1 := Color("ff3b4a") if deco == "police" else Color("4d9bff")
			var c2 := Color("4d9bff")
			rrect(ci, Rect2(-W * 0.34, L * 0.03, W * 0.68, L * 0.07), INK, 3)
			ci.draw_rect(Rect2(-W * 0.32, L * 0.04, W * 0.3, L * 0.05), c1 if on else c1.darkened(0.6))
			ci.draw_rect(Rect2(W * 0.02, L * 0.04, W * 0.3, L * 0.05), c2.darkened(0.6) if on else c2)
			glow(ci, Vector2(-W * 0.18 if on else W * 0.18, L * 0.065), W * 1.1,
				Color(c1 if on else c2, 0.35 + 0.25 * night))
			if deco == "ambulance":
				ci.draw_rect(Rect2(-W * 0.06, L * 0.15, W * 0.12, L * 0.17), RED)
				ci.draw_rect(Rect2(-W * 0.2, L * 0.2, W * 0.4, L * 0.07), RED)
			else:
				text_center(ci, Vector2(0, -L * 0.33), "ДПС", int(W * 0.26), Color("2c4bb3"), true)
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


## Любая машина игрока по описанию из GameData.CARS
static func draw_vehicle(ci: CanvasItem, car: Dictionary, opts: Dictionary = {}) -> void:
	var L: float = car.length
	var W: float = car.width
	var col: Color = car.color
	match car.kind:
		"car":
			opts.stripes = true
			opts.spoiler = true
			draw_car(ci, L, W, col, opts)
		"taxi", "police", "ambulance", "ev":
			opts.deco = car.kind
			draw_car(ci, L, W, col, opts)
		"suv":
			draw_suv(ci, L, W, col, opts)
		"truck":
			opts.style = "parcel"
			draw_truck(ci, L, W, Color("5e1f86"), col, opts)
		"bus":
			draw_bus(ci, L, W, col, opts)
		"scooter":
			draw_scooter(ci, L, W, col, opts)
		"racecar":
			draw_racecar(ci, L, W, col, opts)
		"marshrutka":
			draw_marshrutka(ci, L, W, col, opts)
		_:
			draw_car(ci, L, W, col, opts)


## Внедорожник: квадратный кузов, большие колёса, багажник на крыше и запаска сзади
static func draw_suv(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var hl := Vector2(W, L) / 2.0
	ci.draw_set_transform_matrix(base)
	rrect(ci, Rect2(-hl + SHADOW_OFFSET, Vector2(W, L)), SHADOW, W * 0.18)
	_headlight_cone(ci, W, L, opts)
	var steer: float = opts.get("steer", 0.0)
	var wheel := Vector2(W * 0.24, L * 0.21)
	for side in [-1.0, 1.0]:
		for front in [true, false]:
			var c := Vector2(side * (hl.x - W * 0.02), -L * 0.3 if front else L * 0.3)
			ci.draw_set_transform_matrix(base * Transform2D(steer * 0.5 if front else 0.0, c))
			rrect(ci, Rect2(-wheel / 2.0, wheel), INK, 4)
	ci.draw_set_transform_matrix(base)
	rrect(ci, Rect2(-hl, Vector2(W, L)), body, W * 0.16, 2, body.darkened(0.45))
	rrect(ci, Rect2(-W * 0.4, -L * 0.47, W * 0.8, L * 0.22), body.darkened(0.12), 6)     # капот
	trapezoid(ci, -L * 0.24, -L * 0.1, W * 0.7, W * 0.82, GLASS)
	rrect(ci, Rect2(-W * 0.4, -L * 0.1, W * 0.8, L * 0.42), body.lightened(0.06), 5)      # крыша
	for k in 5:  # рейлинги и багажник
		var y := -L * 0.06 + k * L * 0.08
		ci.draw_line(Vector2(-W * 0.34, y), Vector2(W * 0.34, y), INK.lightened(0.15), 2.5)
	ci.draw_line(Vector2(-W * 0.34, -L * 0.06), Vector2(-W * 0.34, L * 0.26), INK.lightened(0.15), 3.0)
	ci.draw_line(Vector2(W * 0.34, -L * 0.06), Vector2(W * 0.34, L * 0.26), INK.lightened(0.15), 3.0)
	ci.draw_circle(Vector2(0, hl.y - L * 0.03), W * 0.2, INK)                              # запаска
	ci.draw_circle(Vector2(0, hl.y - L * 0.03), W * 0.1, Color("5d6274"))
	ci.draw_circle(Vector2(-W * 0.32, -hl.y + 5), W * 0.09, HEADLIGHT)
	ci.draw_circle(Vector2(W * 0.32, -hl.y + 5), W * 0.09, HEADLIGHT)
	_taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Городской автобус
static func draw_bus(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var hl := Vector2(W, L) / 2.0
	ci.draw_set_transform_matrix(base)
	rrect(ci, Rect2(-hl + SHADOW_OFFSET * 1.4, Vector2(W, L)), SHADOW, 10)
	_headlight_cone(ci, W, L, opts)
	for side in [-1.0, 1.0]:
		for y in [-L * 0.32, L * 0.28]:
			rrect(ci, Rect2(side * (hl.x - 2) - 6, y - 12, 12, 24), INK, 3)
	rrect(ci, Rect2(-hl, Vector2(W, L)), body, 10, 2, body.darkened(0.45))
	rrect(ci, Rect2(-W * 0.36, -hl.y + 22, W * 0.72, L - 34), SILVER, 6)                 # белая крыша
	# Боковые окна
	var y := -hl.y + 26
	while y < hl.y - 20:
		for sx in [-1.0, 1.0]:
			ci.draw_rect(Rect2(sx * (hl.x - 6) - 3, y, 6, 15), GLASS)
		y += 20
	rrect(ci, Rect2(-W * 0.42, -hl.y + 2, W * 0.84, 16), GLASS, 4)                       # лобовое
	ci.draw_line(Vector2(-W * 0.3, -hl.y + 6), Vector2(-W * 0.1, -hl.y + 14), GLASS_SHINE, 2.0)
	rrect(ci, Rect2(-W * 0.16, -hl.y + 30, W * 0.32, 16), INK, 3)                        # табло маршрута
	text_center(ci, Vector2(0, -hl.y + 38), "7", 13, YELLOW, true)
	for hy in [-L * 0.12, L * 0.12]:                                                      # люки
		rrect(ci, Rect2(-W * 0.2, hy - 10, W * 0.4, 20), Color("aeb3c0"), 3, 2, Color("8a8f9c"))
	rrect(ci, Rect2(-W * 0.26, hl.y - 34, W * 0.52, 22), Color("8a8f9c"), 3)              # кондиционер
	for k in 4:
		ci.draw_line(Vector2(-W * 0.2, hl.y - 30 + k * 5), Vector2(W * 0.2, hl.y - 30 + k * 5), INK, 1.5)
	rrect(ci, Rect2(-W * 0.44, -hl.y + 1, W * 0.18, 4), HEADLIGHT, 2)
	rrect(ci, Rect2(W * 0.26, -hl.y + 1, W * 0.18, 4), HEADLIGHT, 2)
	_taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Маршрутка «Омск — Омск»: жёлтая «Газель» с табличкой маршрута за лобовым стеклом
static func draw_marshrutka(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var hl := Vector2(W, L) / 2.0
	ci.draw_set_transform_matrix(base)
	rrect(ci, Rect2(-hl + SHADOW_OFFSET * 1.2, Vector2(W, L)), SHADOW, 10)
	_headlight_cone(ci, W, L, opts)
	for side in [-1.0, 1.0]:
		for y in [-L * 0.3, L * 0.3]:
			rrect(ci, Rect2(side * (hl.x - 2) - 6, y - 11, 12, 22), INK, 3)
	# Короткий «нос» с капотом и высокий салон
	rrect(ci, Rect2(-hl.x + 3, -hl.y, W - 6, L * 0.24), body, 10, 2, body.darkened(0.45))
	rrect(ci, Rect2(-hl.x, -hl.y + L * 0.16, W, L * 0.84), body, 8, 2, body.darkened(0.45))
	ci.draw_line(Vector2(-W * 0.25, -hl.y + 6), Vector2(-W * 0.25, -hl.y + L * 0.13), body.darkened(0.2), 2.0)
	ci.draw_line(Vector2(W * 0.25, -hl.y + 6), Vector2(W * 0.25, -hl.y + L * 0.13), body.darkened(0.2), 2.0)
	rrect(ci, Rect2(-W * 0.42, -hl.y + L * 0.15, W * 0.84, L * 0.1), GLASS, 4)          # лобовое
	ci.draw_line(Vector2(-W * 0.3, -hl.y + L * 0.17), Vector2(-W * 0.12, -hl.y + L * 0.23), GLASS_SHINE, 2.0)
	# Табличка маршрута
	rrect(ci, Rect2(-W * 0.4, -hl.y + L * 0.255, W * 0.8, 15), Color("f2f3f7"), 2, 1, INK)
	text_center(ci, Vector2(0, -hl.y + L * 0.255 + 7.5), "ОМСК–ОМСК", 9, INK, true)
	# Крыша с люком и боковые окна
	rrect(ci, Rect2(-W * 0.36, -hl.y + L * 0.37, W * 0.72, L * 0.58), body.lightened(0.18), 5)
	rrect(ci, Rect2(-W * 0.18, -hl.y + L * 0.5, W * 0.36, L * 0.14), Color("aeb3c0"), 3, 2, Color("8a8f9c"))
	var y := -hl.y + L * 0.36
	while y < hl.y - 14:
		ci.draw_rect(Rect2(-hl.x + 2, y, 5, 13), GLASS)
		ci.draw_rect(Rect2(hl.x - 7, y, 5, 13), GLASS)
		y += 17
	# Сдвижная дверь справа и номер маршрута на крыше
	ci.draw_line(Vector2(hl.x - 1, -hl.y + L * 0.38), Vector2(hl.x - 1, -hl.y + L * 0.62), INK, 2.0)
	text_center(ci, Vector2(0, hl.y - L * 0.14), "№0", 12, INK, true)
	rrect(ci, Rect2(-W * 0.44, -hl.y + 1, W * 0.18, 4), HEADLIGHT, 2)
	rrect(ci, Rect2(W * 0.26, -hl.y + 1, W * 0.18, 4), HEADLIGHT, 2)
	_taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Мотороллер доставщика пиццы
static func draw_scooter(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var t: float = opts.get("time", 0.0)
	ci.draw_set_transform_matrix(base * Transform2D(0, SHADOW_OFFSET * 0.7))
	rrect(ci, Rect2(-W * 0.5, -L * 0.5, W, L), SHADOW, W * 0.5)
	ci.draw_set_transform_matrix(base)
	_headlight_cone(ci, W * 0.6, L, opts)
	var steer: float = opts.get("steer", 0.0)
	ci.draw_set_transform_matrix(base * Transform2D(steer * 0.4, Vector2(0, -L * 0.36)))
	rrect(ci, Rect2(-3.5, -9, 7, 18), INK, 3)                                            # переднее колесо
	ci.draw_line(Vector2(-W * 0.55, 4), Vector2(W * 0.55, 4), Color("3d4152"), 3.0)      # руль
	ci.draw_circle(Vector2(0, -8), 3.5, HEADLIGHT)
	ci.draw_set_transform_matrix(base)
	rrect(ci, Rect2(-3.5, L * 0.28, 7, 18), INK, 3)                                       # заднее колесо
	rrect(ci, Rect2(-W * 0.32, -L * 0.3, W * 0.64, L * 0.55), body, W * 0.3, 2, body.darkened(0.4))
	# Курьер: плечи и шлем
	ci.draw_set_transform_matrix(base * Transform2D(0, Vector2(0, -L * 0.04)).scaled_local(Vector2(1.0, 0.6)))
	ci.draw_circle(Vector2.ZERO, W * 0.42, Color("2f3242"))
	ci.draw_set_transform_matrix(base)
	ci.draw_circle(Vector2(0, -L * 0.06), W * 0.27, body.lightened(0.25))
	ci.draw_arc(Vector2(0, -L * 0.06), W * 0.2, PI * 1.1, PI * 1.9, 10, GLASS, 3.0)
	# Термокороб с пиццей
	var bob := sin(t * 10.0) * 0.6
	rrect(ci, Rect2(-W * 0.55, L * 0.12 + bob, W * 1.1, W * 1.0), Color("f2f3f7"), 4, 2, Color("b9bdc8"))
	ci.draw_circle(Vector2(0, L * 0.12 + W * 0.5 + bob), W * 0.3, ORANGE)
	ci.draw_circle(Vector2(-W * 0.1, L * 0.12 + W * 0.42 + bob), W * 0.06, RED)
	ci.draw_circle(Vector2(W * 0.12, L * 0.12 + W * 0.58 + bob), W * 0.06, RED)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Гоночный болид: узкий корпус, открытые колёса, антикрылья
static func draw_racecar(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var hl := Vector2(W, L) / 2.0
	ci.draw_set_transform_matrix(base * Transform2D(0, SHADOW_OFFSET))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-W * 0.2, -hl.y), Vector2(W * 0.2, -hl.y),
		Vector2(W * 0.45, hl.y), Vector2(-W * 0.45, hl.y)]), SHADOW)
	ci.draw_set_transform_matrix(base)
	_headlight_cone(ci, W * 0.5, L, opts)
	var steer: float = opts.get("steer", 0.0)
	var wheel := Vector2(W * 0.24, L * 0.17)
	for side in [-1.0, 1.0]:
		for front in [true, false]:
			var c := Vector2(side * W * 0.42, -L * 0.28 if front else L * 0.3)
			ci.draw_set_transform_matrix(base * Transform2D(steer * 0.5 if front else 0.0, c))
			rrect(ci, Rect2(-wheel / 2.0, wheel), INK, 4)
	ci.draw_set_transform_matrix(base)
	rrect(ci, Rect2(-W * 0.55, -hl.y, W * 1.1, L * 0.07), body.darkened(0.3), 3)          # переднее крыло
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-W * 0.1, -hl.y + 2), Vector2(W * 0.1, -hl.y + 2),
		Vector2(W * 0.24, -L * 0.1), Vector2(W * 0.3, L * 0.38), Vector2(-W * 0.3, L * 0.38),
		Vector2(-W * 0.24, -L * 0.1)]), body)
	rrect(ci, Rect2(-W * 0.38, -L * 0.02, W * 0.76, L * 0.28), body.darkened(0.15), 8)   # понтоны
	ci.draw_rect(Rect2(-W * 0.03, -hl.y + 4, W * 0.06, L * 0.75), Color.WHITE)
	ci.draw_circle(Vector2(0, -L * 0.04), W * 0.15, INK)                                    # кокпит
	ci.draw_circle(Vector2(0, -L * 0.04), W * 0.1, YELLOW)                                  # шлем
	ci.draw_circle(Vector2(0, L * 0.12), W * 0.13, Color.WHITE)
	text_center(ci, Vector2(0, L * 0.12), "1", int(W * 0.22), INK, true)
	rrect(ci, Rect2(-W * 0.5, hl.y - L * 0.09, W, L * 0.08), INK, 3)                     # заднее крыло
	ci.draw_rect(Rect2(-W * 0.45, hl.y - L * 0.08, W * 0.9, L * 0.025), body)
	_taillights(ci, W * 0.6, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _headlight_cone(ci: CanvasItem, W: float, L: float, opts: Dictionary) -> void:
	if opts.get("lights", false):
		var hy := -L / 2.0
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-W * 0.35, hy), Vector2(W * 0.35, hy),
			Vector2(W * 0.9, hy - L * 1.1), Vector2(-W * 0.9, hy - L * 1.1)]),
			Color(1.0, 0.93, 0.7, 0.04 + 0.11 * night))


static func _taillights(ci: CanvasItem, W: float, L: float, opts: Dictionary) -> void:
	var brake: bool = opts.get("brake", false)
	var tail := BRAKELIGHT if brake else TAILLIGHT
	var hy := L / 2.0
	rrect(ci, Rect2(-W * 0.44, hy - 6, W * 0.2, 5), tail, 2)
	rrect(ci, Rect2(W * 0.24, hy - 6, W * 0.2, 5), tail, 2)
	if brake:
		glow(ci, Vector2(-W * 0.34, hy), W * 0.4, Color(1, 0.2, 0.25, 0.35))
		glow(ci, Vector2(W * 0.34, hy), W * 0.4, Color(1, 0.2, 0.25, 0.35))


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
	if opts.get("style", "") == "parcel":
		# Фиолетовый фургон доставки с коробками-посылками на крыше
		ci.draw_rect(Rect2(-hl.x + 4, box_rect.position.y + 8, 7, box_rect.size.y - 16), Color("d16fe0"))
		ci.draw_rect(Rect2(hl.x - 11, box_rect.position.y + 8, 7, box_rect.size.y - 16), Color("d16fe0"))
		var py := box_rect.position.y + 14
		var k := 0
		while py < box_rect.end.y - 30:
			var px := -W * 0.22 + (k % 2) * W * 0.1
			rrect(ci, Rect2(px, py, W * 0.34, 24), Color("d9b98a"), 2, 2, Color("a88758"))
			ci.draw_line(Vector2(px + W * 0.17, py), Vector2(px + W * 0.17, py + 24), Color("c79a5a"), 3.0)
			py += 34
			k += 1
	else:
		ci.draw_rect(Rect2(-hl.x + 4, box_rect.position.y + 8, 6, box_rect.size.y - 16), ORANGE)
		ci.draw_rect(Rect2(hl.x - 10, box_rect.position.y + 8, 6, box_rect.size.y - 16), ORANGE)
	# Кабина
	rrect(ci, Rect2(-hl.x + 2, -hl.y, W - 4, cab_len), cab, 8, 2, cab.darkened(0.45))
	trapezoid(ci, -hl.y + cab_len * 0.18, -hl.y + cab_len * 0.48, W * 0.66, W * 0.8, GLASS)
	rrect(ci, Rect2(-W * 0.4, -hl.y + 2, W * 0.2, 6), HEADLIGHT, 2)
	rrect(ci, Rect2(W * 0.2, -hl.y + 2, W * 0.2, 6), HEADLIGHT, 2)
	var brake: bool = opts.get("brake", false)
	rrect(ci, Rect2(-W * 0.45, hl.y - 6, W * 0.2, 5), BRAKELIGHT if brake else TAILLIGHT, 2)
	rrect(ci, Rect2(W * 0.25, hl.y - 6, W * 0.2, 5), BRAKELIGHT if brake else TAILLIGHT, 2)
	if opts.get("lights", false):
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-W * 0.35, -hl.y), Vector2(W * 0.35, -hl.y),
			Vector2(W * 0.9, -hl.y - L * 0.6), Vector2(-W * 0.9, -hl.y - L * 0.6)]),
			Color(1.0, 0.93, 0.7, 0.04 + 0.11 * night))
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
