class_name ArtCars
extends RefCounted
## Машины версии 2.5 (вид сверху, капот смотрит вверх по оси -Y) и встречные
## машины для новых трасс: бензовоз, лесовоз, «шестёрка» с прицепом рассады.
## Рисуется в общем стиле Art.gd: плоские цвета, мягкие тени, без сторонних картинок.

const INK := Art.INK
const GLASS := Art.GLASS
const SHINE := Art.GLASS_SHINE
const HEAD := Art.HEADLIGHT


static func draw(kind: String, ci: CanvasItem, L: float, W: float, col: Color, opts: Dictionary) -> void:
	match kind:
		"nine":
			draw_nine(ci, L, W, col, opts)
		"volga":
			draw_volga(ci, L, W, col, opts)
		"rally":
			draw_rally(ci, L, W, col, opts)
		"tow":
			draw_tow(ci, L, W, col, opts)
		"trolley":
			draw_trolley(ci, L, W, col, opts)
		"armored":
			draw_armored(ci, L, W, col, opts)
		"hyper":
			draw_hyper(ci, L, W, col, opts)
		"snowmobile":
			draw_snowmobile(ci, L, W, col, opts)


static func _begin(ci: CanvasItem, opts: Dictionary, L: float, W: float, radius: float, shadow_k: float = 1.0) -> Transform2D:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	# Тень не поворачивается вместе с машиной — свет всегда падает с одной стороны
	if opts.get("shadow", true):
		ci.draw_set_transform_matrix(Transform2D(base.get_rotation() if absf(absf(base.get_rotation()) - PI) > 0.1 else 0.0, base.origin))
		Art.rrect(ci, Rect2(-Vector2(W, L) / 2.0 + Art.SHADOW_OFFSET * shadow_k, Vector2(W, L)), Art.SHADOW, radius)
	ci.draw_set_transform_matrix(base)
	Art._headlight_cone(ci, W, L, opts)
	return base


static func _four_wheels(ci: CanvasItem, base: Transform2D, L: float, W: float, opts: Dictionary,
		front_y: float = -0.3, rear_y: float = 0.3, size := Vector2(0.2, 0.18), inset := 0.04) -> void:
	var steer: float = opts.get("steer", 0.0)
	var hx := W / 2.0
	for side in [-1.0, 1.0]:
		Art._wheel(ci, base, Vector2(side * (hx - W * inset), L * front_y), Vector2(W * size.x, L * size.y), steer * 0.5)
		Art._wheel(ci, base, Vector2(side * (hx - W * inset), L * rear_y), Vector2(W * size.x, L * size.y))


# ---------------------------------------------------------------------------
# Девятка «Бумбокс»: клиновидный хэтчбек, тонировка в ноль, сабвуфер в багажнике
# ---------------------------------------------------------------------------
static func draw_nine(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var t: float = opts.get("time", 0.0)
	var base := _begin(ci, opts, L, W, W * 0.22)
	var hl := Vector2(W, L) / 2.0
	# Басовые волны от сабвуфера (кольца расходятся от багажника)
	if opts.get("bass", true):
		for k in 2:
			var ph := fmod(t * 1.6 + k * 0.5, 1.0)
			ci.draw_arc(Vector2(0, L * 0.32), W * (0.45 + ph * 0.9), PI * 0.12, PI * 0.88, 18,
				Color(0.85, 0.55, 1.0, 0.32 * (1.0 - ph)), 3.0, true)
	_four_wheels(ci, base, L, W, opts)
	# Кузов: клин — узкий нос, широкая корма
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-W * 0.4, -hl.y), Vector2(W * 0.4, -hl.y),
		Vector2(hl.x, -L * 0.3), Vector2(hl.x, hl.y - 4), Vector2(hl.x - 4, hl.y), Vector2(-hl.x + 4, hl.y),
		Vector2(-hl.x, hl.y - 4), Vector2(-hl.x, -L * 0.3)]), body)
	ci.draw_polyline(PackedVector2Array([Vector2(-W * 0.4, -hl.y), Vector2(W * 0.4, -hl.y),
		Vector2(hl.x, -L * 0.3), Vector2(hl.x, hl.y - 4), Vector2(hl.x - 4, hl.y), Vector2(-hl.x + 4, hl.y),
		Vector2(-hl.x, hl.y - 4), Vector2(-hl.x, -L * 0.3), Vector2(-W * 0.4, -hl.y)]), body.darkened(0.45), 2.0, true)
	ci.draw_rect(Rect2(-W * 0.32, -L * 0.46, W * 0.64, L * 0.16), body.lightened(0.12))       # капот
	# Тонировка «в ноль»: лобовое, крыша, длинное заднее стекло
	Art.trapezoid(ci, -L * 0.28, -L * 0.12, W * 0.66, W * 0.82, Color("0b0c10"))
	ci.draw_line(Vector2(-W * 0.24, -L * 0.25), Vector2(-W * 0.08, -L * 0.15), Color(1, 1, 1, 0.18), 2.0)
	Art.rrect(ci, Rect2(-W * 0.4, -L * 0.12, W * 0.8, L * 0.26), body.lightened(0.05), 4)
	Art.trapezoid(ci, L * 0.14, L * 0.38, W * 0.78, W * 0.7, Color("0b0c10"))
	# Сабвуфер просвечивает через заднее стекло
	ci.draw_circle(Vector2(0, L * 0.27), W * 0.13, Color("26262e"))
	var pump := 1.0 + 0.12 * absf(sin(t * 9.0))
	ci.draw_circle(Vector2(0, L * 0.27), W * 0.08 * pump, Color("54545e"))
	# Ёлочка-вонючка за лобовым стеклом
	ci.draw_colored_polygon(PackedVector2Array([Vector2(W * 0.14, -L * 0.21), Vector2(W * 0.1, -L * 0.15),
		Vector2(W * 0.18, -L * 0.15)]), Color("5bbf72"))
	# Фары-«щёлочки» и стоп-сигналы во всю ширину
	Art.rrect(ci, Rect2(-W * 0.4, -hl.y + 2, W * 0.24, 5), HEAD, 2)
	Art.rrect(ci, Rect2(W * 0.16, -hl.y + 2, W * 0.24, 5), HEAD, 2)
	var brake: bool = opts.get("brake", false)
	ci.draw_rect(Rect2(-hl.x + 3, hl.y - 6, W - 6, 4), Art.BRAKELIGHT if brake else Art.TAILLIGHT)
	if brake:
		Art.glow(ci, Vector2(0, hl.y), W * 0.6, Color(1, 0.2, 0.25, 0.35))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Чёрная «Волга»: длинный седан, хромированная решётка, антенна и шторки
# ---------------------------------------------------------------------------
static func draw_volga(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base := _begin(ci, opts, L, W, 8)
	var hl := Vector2(W, L) / 2.0
	var chrome := Color("d9dde6")
	_four_wheels(ci, base, L, W, opts, -0.31, 0.31, Vector2(0.2, 0.16))
	Art.rrect(ci, Rect2(-hl, Vector2(W, L)), body, 8, 2, body.darkened(0.5))
	# Блики «лакированного» кузова
	ci.draw_line(Vector2(-W * 0.36, -L * 0.42), Vector2(-W * 0.36, L * 0.42), body.lightened(0.28), 2.0)
	ci.draw_line(Vector2(W * 0.36, -L * 0.42), Vector2(W * 0.36, L * 0.42), body.lightened(0.18), 1.5)
	ci.draw_rect(Rect2(-hl.x + 3, -hl.y - 2, W - 6, 6), chrome)                                  # бампер
	ci.draw_rect(Rect2(-W * 0.3, -hl.y + 5, W * 0.6, 5), chrome.darkened(0.15))                 # решётка
	for k in 7:
		ci.draw_line(Vector2(-W * 0.28 + k * W * 0.093, -hl.y + 5), Vector2(-W * 0.28 + k * W * 0.093, -hl.y + 10), INK, 1.0)
	ci.draw_rect(Rect2(-hl.x + 3, hl.y - 4, W - 6, 6), chrome)
	Art.rrect(ci, Rect2(-W * 0.4, -L * 0.42, W * 0.8, L * 0.2), body.lightened(0.07), 4)         # капот
	ci.draw_circle(Vector2(0, -L * 0.43), W * 0.05, chrome)                                       # значок на капоте
	ci.draw_rect(Rect2(-W * 0.36, -L * 0.2, W * 0.72, L * 0.12), GLASS)
	ci.draw_line(Vector2(-W * 0.24, -L * 0.18), Vector2(-W * 0.08, -L * 0.1), SHINE, 2.0)
	Art.rrect(ci, Rect2(-W * 0.39, -L * 0.08, W * 0.78, L * 0.3), body.lightened(0.04), 4)
	ci.draw_rect(Rect2(-W * 0.36, L * 0.22, W * 0.72, L * 0.1), GLASS)
	# Шторки на заднем стекле
	for k in 5:
		ci.draw_rect(Rect2(-W * 0.34 + k * W * 0.14, L * 0.225, W * 0.08, L * 0.09), Color(0.95, 0.93, 0.86, 0.85))
	# Антенна на крыше
	ci.draw_line(Vector2(W * 0.25, L * 0.18), Vector2(W * 0.32, L * 0.02), Color("8a8f9c"), 1.5)
	ci.draw_circle(Vector2(W * 0.25, L * 0.18), 2.5, INK)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(Vector2(sx * W * 0.33, -hl.y + 7), W * 0.075, HEAD)
		ci.draw_circle(Vector2(sx * W * 0.2, -hl.y + 7), W * 0.06, HEAD.darkened(0.08))
	Art._taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Раллийная «Лада»: ливрея, номер, прожекторы на крыше и грязь
# ---------------------------------------------------------------------------
static func draw_rally(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base := _begin(ci, opts, L, W, 7)
	var hl := Vector2(W, L) / 2.0
	_four_wheels(ci, base, L, W, opts, -0.3, 0.3, Vector2(0.22, 0.19), 0.0)
	Art.rrect(ci, Rect2(-hl, Vector2(W, L)), body, 7, 2, body.darkened(0.45))
	# Ливрея: оранжевая и синяя диагонали
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-hl.x, -L * 0.1), Vector2(hl.x, -L * 0.3),
		Vector2(hl.x, -L * 0.18), Vector2(-hl.x, L * 0.02)]), Art.ORANGE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-hl.x, L * 0.06), Vector2(hl.x, -L * 0.14),
		Vector2(hl.x, -L * 0.06), Vector2(-hl.x, L * 0.14)]), Art.BLUE)
	ci.draw_rect(Rect2(-W * 0.36, -L * 0.24, W * 0.72, L * 0.12), GLASS)
	Art.rrect(ci, Rect2(-W * 0.38, -L * 0.12, W * 0.76, L * 0.3), body.lightened(0.04), 4)
	ci.draw_rect(Rect2(-W * 0.34, L * 0.2, W * 0.68, L * 0.1), GLASS)
	# Номер на крыше
	ci.draw_circle(Vector2(0, L * 0.04), W * 0.17, Color.WHITE)
	ci.draw_arc(Vector2(0, L * 0.04), W * 0.17, 0, TAU, 20, INK, 2.0, true)
	Art.text_center(ci, Vector2(0, L * 0.04), "55", int(W * 0.2), INK, true)
	# Люстра из четырёх прожекторов
	ci.draw_rect(Rect2(-W * 0.42, -L * 0.14, W * 0.84, 5), INK)
	for k in 4:
		var p := Vector2(-W * 0.32 + k * W * 0.213, -L * 0.115)
		ci.draw_circle(p, W * 0.065, Color("f4f1ea"))
		ci.draw_circle(p, W * 0.04, HEAD)
	# Брызги грязи на корме
	for k in 6:
		var mx := -hl.x + 4 + Art.hash01(k * 17 + 3) * (W - 8)
		ci.draw_circle(Vector2(mx, hl.y - 6 - Art.hash01(k * 5) * L * 0.12), 2 + Art.hash01(k) * 4, Color(0.42, 0.3, 0.18, 0.75))
	ci.draw_rect(Rect2(-W * 0.5, hl.y - L * 0.07, W, 4), INK)                                    # брызговик
	Art.rrect(ci, Rect2(-W * 0.4, -hl.y + 2, W * 0.22, 5), HEAD, 2)
	Art.rrect(ci, Rect2(W * 0.18, -hl.y + 2, W * 0.22, 5), HEAD, 2)
	Art._taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Эвакуатор: кабина, платформа с лебёдкой и мигалками. opts.cargo — цвет увозимой машины
# ---------------------------------------------------------------------------
static func draw_tow(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var t: float = opts.get("time", 0.0)
	var base := _begin(ci, opts, L, W, 6, 1.2)
	var hl := Vector2(W, L) / 2.0
	var steer: float = opts.get("steer", 0.0)
	var cab := L * 0.27
	for side in [-1.0, 1.0]:
		Art._wheel(ci, base, Vector2(side * (hl.x - 3), -hl.y + cab * 0.55), Vector2(W * 0.18, L * 0.11), steer * 0.5)
		for k in 2:
			Art._wheel(ci, base, Vector2(side * (hl.x - 3), L * (0.22 + 0.14 * k)), Vector2(W * 0.18, L * 0.11))
	# Платформа
	var deck := Rect2(-hl.x, -hl.y + cab + 4, W, L - cab - 4)
	Art.rrect(ci, deck, Color("8a8f9c"), 4, 2, Color("5d6274"))
	var y := deck.position.y + 10
	while y < deck.end.y - 6:
		ci.draw_line(Vector2(-hl.x + 6, y), Vector2(hl.x - 6, y), Color("6d7182"), 2.0)
		y += 12
	ci.draw_rect(Rect2(-hl.x, deck.position.y, 5, deck.size.y), Color("f2c230"))
	ci.draw_rect(Rect2(hl.x - 5, deck.position.y, 5, deck.size.y), Color("f2c230"))
	# Лебёдка и трос
	Art.rrect(ci, Rect2(-W * 0.22, deck.position.y + 2, W * 0.44, 12), INK, 3)
	var cargo = opts.get("cargo", null)
	if cargo is Color:
		Art.draw_car(ci, L * 0.48, W * 0.8, cargo, {"base": opts.get("base", Transform2D.IDENTITY) * Transform2D(0, Vector2(0, deck.get_center().y + 6)), "shadow": false})
		ci.draw_set_transform_matrix(base)
		ci.draw_line(Vector2(0, deck.position.y + 12), Vector2(0, deck.get_center().y - L * 0.2), Color("c9cdd6"), 2.0)
	else:
		ci.draw_line(Vector2(0, deck.position.y + 12), Vector2(0, deck.end.y - 10), Color("c9cdd6"), 1.5)
		ci.draw_arc(Vector2(0, deck.end.y - 8), 5, 0, PI, 8, Color("c9cdd6"), 2.0)
	# Кабина
	Art.rrect(ci, Rect2(-hl.x + 2, -hl.y, W - 4, cab), body, 7, 2, body.darkened(0.45))
	Art.trapezoid(ci, -hl.y + cab * 0.2, -hl.y + cab * 0.52, W * 0.66, W * 0.8, GLASS)
	ci.draw_line(Vector2(-W * 0.22, -hl.y + cab * 0.25), Vector2(-W * 0.06, -hl.y + cab * 0.45), SHINE, 2.0)
	# Оранжевые мигалки на крыше кабины
	var on := fmod(t, 0.6) < 0.3
	Art.rrect(ci, Rect2(-W * 0.36, -hl.y + cab * 0.62, W * 0.72, 9), INK, 3)
	ci.draw_rect(Rect2(-W * 0.34, -hl.y + cab * 0.62 + 2, W * 0.3, 5), Color("ffb020") if on else Color("6a4a10"))
	ci.draw_rect(Rect2(W * 0.04, -hl.y + cab * 0.62 + 2, W * 0.3, 5), Color("6a4a10") if on else Color("ffb020"))
	Art.glow(ci, Vector2(-W * 0.19 if on else W * 0.19, -hl.y + cab * 0.66), W * 0.9, Color(1, 0.65, 0.1, 0.3 + 0.2 * Art.night))
	Art.rrect(ci, Rect2(-W * 0.4, -hl.y + 2, W * 0.2, 6), HEAD, 2)
	Art.rrect(ci, Rect2(W * 0.2, -hl.y + 2, W * 0.2, 6), HEAD, 2)
	Art._taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Троллейбус: как автобус, но со штангами-«рогами» к проводам.
# opts.dewired — рога слетели и болтаются; opts.pole_t — фаза покачивания
# ---------------------------------------------------------------------------
static func draw_trolley(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var t: float = opts.get("time", 0.0)
	var base := _begin(ci, opts, L, W, 10, 1.4)
	var hl := Vector2(W, L) / 2.0
	for side in [-1.0, 1.0]:
		for y in [-L * 0.3, L * 0.28]:
			Art.rrect(ci, Rect2(side * (hl.x - 2) - 6, y - 12, 12, 24), INK, 3)
	Art.rrect(ci, Rect2(-hl, Vector2(W, L)), body, 12, 2, body.darkened(0.45))
	Art.rrect(ci, Rect2(-W * 0.38, -hl.y + 22, W * 0.76, L - 36), Color("eef0f6"), 8)            # белая крыша
	ci.draw_rect(Rect2(-hl.x, -L * 0.05, W, 6), body.darkened(0.2))
	var y := -hl.y + 26
	while y < hl.y - 20:
		for sx in [-1.0, 1.0]:
			ci.draw_rect(Rect2(sx * (hl.x - 6) - 3, y, 6, 16), GLASS)
		y += 21
	Art.rrect(ci, Rect2(-W * 0.42, -hl.y + 2, W * 0.84, 17), GLASS, 5)
	ci.draw_line(Vector2(-W * 0.3, -hl.y + 6), Vector2(-W * 0.1, -hl.y + 15), SHINE, 2.0)
	Art.rrect(ci, Rect2(-W * 0.2, -hl.y + 30, W * 0.4, 16), INK, 3)
	Art.text_center(ci, Vector2(0, -hl.y + 38), "7", 13, Art.YELLOW, true)
	# Блок электрооборудования на крыше
	Art.rrect(ci, Rect2(-W * 0.3, -L * 0.2, W * 0.6, L * 0.2), Color("8a8f9c"), 4, 2, Color("5d6274"))
	for k in 4:
		ci.draw_line(Vector2(-W * 0.24, -L * 0.17 + k * L * 0.045), Vector2(W * 0.24, -L * 0.17 + k * L * 0.045), INK, 1.5)
	# Рога: от основания на крыше назад-вверх, к проводам над дорогой
	var dewired: bool = opts.get("dewired", false)
	var root_y := L * 0.08
	for sx in [-1.0, 1.0]:
		var root := Vector2(sx * W * 0.14, root_y)
		var tip: Vector2
		if dewired:
			# Слетевшие рога разошлись в стороны и болтаются
			var sway := sin(t * 7.0 + sx) * 0.12
			tip = root + Vector2.from_angle(PI / 2.0 - sx * (0.9 + sway)) * L * 0.62
		else:
			tip = Vector2(sx * W * 0.2, hl.y + L * 0.22)
		ci.draw_line(root, tip, INK, 4.0, true)
		ci.draw_line(root, tip, Color("6d7182"), 2.0, true)
		ci.draw_circle(root, 5, INK)
		Art.rrect(ci, Rect2(tip - Vector2(4, 6), Vector2(8, 12)), Color("3a3f52"), 2)
		if not dewired and fmod(t * 3.0 + sx, 2.3) < 0.08:
			Art.glow(ci, tip, 16, Color(0.6, 0.85, 1.0, 0.8))                                    # искра на проводе
	Art.rrect(ci, Rect2(-W * 0.44, -hl.y + 1, W * 0.18, 4), HEAD, 2)
	Art.rrect(ci, Rect2(W * 0.26, -hl.y + 1, W * 0.18, 4), HEAD, 2)
	Art._taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Инкассаторский броневик: угловатый короб, бронелисты, узкие окна, люк
# ---------------------------------------------------------------------------
static func draw_armored(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base := _begin(ci, opts, L, W, 6, 1.3)
	var hl := Vector2(W, L) / 2.0
	_four_wheels(ci, base, L, W, opts, -0.32, 0.32, Vector2(0.22, 0.15), 0.0)
	Art.rrect(ci, Rect2(-hl, Vector2(W, L)), body, 6, 3, body.darkened(0.5))
	# Скошенный нос
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-hl.x + 3, -hl.y + 3), Vector2(hl.x - 3, -hl.y + 3),
		Vector2(W * 0.36, -L * 0.3), Vector2(-W * 0.36, -L * 0.3)]), body.lightened(0.1))
	# Узкие бронированные окна
	ci.draw_rect(Rect2(-W * 0.34, -L * 0.29, W * 0.68, L * 0.06), GLASS)
	ci.draw_line(Vector2(-W * 0.2, -L * 0.28), Vector2(-W * 0.06, -L * 0.24), SHINE, 1.5)
	# Крыша с бронелистами и заклёпками
	var roof := Rect2(-W * 0.4, -L * 0.2, W * 0.8, L * 0.62)
	Art.rrect(ci, roof, body.darkened(0.08), 4)
	for k in 3:
		var yy := roof.position.y + roof.size.y * (k + 1) / 4.0
		ci.draw_line(Vector2(roof.position.x, yy), Vector2(roof.end.x, yy), body.darkened(0.35), 2.0)
	for k in 8:
		ci.draw_circle(Vector2(roof.position.x + 5, roof.position.y + 6 + k * roof.size.y / 8.0), 1.6, body.lightened(0.3))
		ci.draw_circle(Vector2(roof.end.x - 5, roof.position.y + 6 + k * roof.size.y / 8.0), 1.6, body.lightened(0.3))
	# Люк и надпись
	ci.draw_circle(Vector2(0, -L * 0.1), W * 0.13, body.darkened(0.25))
	ci.draw_arc(Vector2(0, -L * 0.1), W * 0.13, 0, TAU, 18, INK, 2.0, true)
	ci.draw_set_transform_matrix(base * Transform2D(-PI / 2.0, Vector2(0, L * 0.17)))
	Art.text_center(ci, Vector2.ZERO, "ИНКАССАЦИЯ", int(clampf(L * 0.075, 7.0, 11.0)), Color("f2f3f7"), true)
	ci.draw_set_transform_matrix(base)
	ci.draw_rect(Rect2(-hl.x, L * 0.43, W, 4), Color("f2f3f7"))
	for sx in [-1.0, 1.0]:
		Art.rrect(ci, Rect2(sx * W * 0.3 - W * 0.1, -hl.y + 2, W * 0.2, 5), HEAD, 2)
		ci.draw_rect(Rect2(sx * (hl.x - 2) - 2, -L * 0.18, 4, 7), body.darkened(0.4))         # зеркала
	Art._taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Гиперкар: низкий широкий клин, каплевидная кабина, диффузор и антикрыло.
# Рисунок обобщённый — без фирменных элементов дизайна и логотипов.
# ---------------------------------------------------------------------------
static func draw_hyper(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var t: float = opts.get("time", 0.0)
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var hl := Vector2(W, L) / 2.0
	ci.draw_set_transform_matrix(base)
	var outline := PackedVector2Array([Vector2(-W * 0.26, -hl.y), Vector2(W * 0.26, -hl.y),
		Vector2(hl.x, -L * 0.3), Vector2(hl.x, L * 0.36), Vector2(W * 0.44, hl.y), Vector2(-W * 0.44, hl.y),
		Vector2(-hl.x, L * 0.36), Vector2(-hl.x, -L * 0.3)])
	if opts.get("shadow", true):
		var sh := PackedVector2Array()
		for p in outline:
			sh.append(p + Art.SHADOW_OFFSET)
		ci.draw_colored_polygon(sh, Art.SHADOW)
	Art._headlight_cone(ci, W, L, opts)
	_four_wheels(ci, base, L, W, opts, -0.29, 0.3, Vector2(0.22, 0.2), 0.0)
	ci.draw_colored_polygon(outline, body)
	ci.draw_polyline(outline + PackedVector2Array([outline[0]]), body.darkened(0.5), 2.0, true)
	# Тёмные воздухозаборники по бокам
	for sx in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx * hl.x, -L * 0.02), Vector2(sx * W * 0.3, L * 0.06),
			Vector2(sx * W * 0.3, L * 0.26), Vector2(sx * hl.x, L * 0.3)]), INK.lightened(0.05))
	# Капот с рёбрами
	ci.draw_line(Vector2(-W * 0.12, -hl.y + 4), Vector2(-W * 0.16, -L * 0.18), body.lightened(0.25), 2.0)
	ci.draw_line(Vector2(W * 0.12, -hl.y + 4), Vector2(W * 0.16, -L * 0.18), body.lightened(0.25), 2.0)
	# Каплевидная кабина
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -L * 0.24), Vector2(W * 0.3, -L * 0.08),
		Vector2(W * 0.26, L * 0.16), Vector2(0, L * 0.22), Vector2(-W * 0.26, L * 0.16), Vector2(-W * 0.3, -L * 0.08)]), GLASS)
	ci.draw_line(Vector2(-W * 0.14, -L * 0.15), Vector2(W * 0.02, -L * 0.07), SHINE, 2.0)
	# Хребет по крыше и моторный отсек с решёткой
	ci.draw_rect(Rect2(-W * 0.03, L * 0.2, W * 0.06, L * 0.18), body.darkened(0.3))
	for k in 4:
		ci.draw_line(Vector2(-W * 0.22, L * 0.25 + k * L * 0.04), Vector2(W * 0.22, L * 0.25 + k * L * 0.04), INK, 2.0)
	# Антикрыло и диффузор с четырьмя выхлопными трубами
	Art.rrect(ci, Rect2(-W * 0.46, hl.y - L * 0.1, W * 0.92, L * 0.05), INK, 2)
	for k in 4:
		ci.draw_circle(Vector2(-W * 0.15 + k * W * 0.1, hl.y - 2), 3, Color("8a8f9c"))
	# Тонкие светодиодные фары
	ci.draw_line(Vector2(-W * 0.36, -L * 0.36), Vector2(-W * 0.18, -L * 0.44), HEAD, 3.0)
	ci.draw_line(Vector2(W * 0.36, -L * 0.36), Vector2(W * 0.18, -L * 0.44), HEAD, 3.0)
	var brake: bool = opts.get("brake", false)
	ci.draw_line(Vector2(-W * 0.4, hl.y - 4), Vector2(W * 0.4, hl.y - 4), Art.BRAKELIGHT if brake else Art.TAILLIGHT, 3.0)
	if brake:
		Art.glow(ci, Vector2(0, hl.y), W * 0.6, Color(1, 0.2, 0.25, 0.35))
	if opts.get("nitro", false):
		Art.glow(ci, Vector2(0, hl.y + 6), W * 0.7, Color(0.35, 0.75, 1.0, 0.35 + 0.15 * sin(t * 30.0)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Снегоход «Буран»: лыжи спереди, капот с ветровым стеклом, водитель в ушанке, гусеница
# ---------------------------------------------------------------------------
static func draw_snowmobile(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var t: float = opts.get("time", 0.0)
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var hl := Vector2(W, L) / 2.0
	var steer: float = opts.get("steer", 0.0)
	ci.draw_set_transform_matrix(base * Transform2D(0, Art.SHADOW_OFFSET * 0.7))
	Art.rrect(ci, Rect2(-W * 0.45, -L * 0.48, W * 0.9, L * 0.96), Art.SHADOW, W * 0.2)
	ci.draw_set_transform_matrix(base)
	Art._headlight_cone(ci, W * 0.6, L, opts)
	# Гусеница сзади (протектор бежит)
	var track := Rect2(-W * 0.3, L * 0.02, W * 0.6, L * 0.47)
	Art.rrect(ci, track, INK, 5)
	var off := fmod(t * 60.0, 10.0)
	var yy := track.position.y + off
	while yy < track.end.y - 2:
		ci.draw_line(Vector2(track.position.x + 3, yy), Vector2(track.end.x - 3, yy), Color("3d4152"), 2.5)
		yy += 10.0
	# Лыжи спереди (поворачиваются)
	for sx in [-1.0, 1.0]:
		ci.draw_set_transform_matrix(base * Transform2D(steer * 0.35, Vector2(sx * W * 0.36, -L * 0.3)))
		Art.rrect(ci, Rect2(-4, -L * 0.2, 8, L * 0.36), Color("3d4152"), 4)
		ci.draw_arc(Vector2(0, -L * 0.18), 4, PI, TAU, 6, Color("8a8f9c"), 2.0)
		ci.draw_set_transform_matrix(base)
		ci.draw_line(Vector2(sx * W * 0.36, -L * 0.3), Vector2(sx * W * 0.14, -L * 0.22), Color("3d4152"), 3.0)
	# Капот и ветровое стекло
	Art.rrect(ci, Rect2(-W * 0.24, -hl.y + 2, W * 0.48, L * 0.42), body, W * 0.16, 2, body.darkened(0.4))
	ci.draw_rect(Rect2(-W * 0.2, -L * 0.16, W * 0.4, 4), INK)
	ci.draw_arc(Vector2(0, -L * 0.12), W * 0.22, PI * 1.1, PI * 1.9, 12, Color(0.75, 0.88, 1.0, 0.85), 4.0, true)
	ci.draw_circle(Vector2(0, -hl.y + 8), W * 0.08, HEAD)
	# Сиденье и водитель в тулупе и ушанке
	Art.rrect(ci, Rect2(-W * 0.18, -L * 0.04, W * 0.36, L * 0.32), Color("2b2e38"), 6)
	ci.draw_set_transform_matrix(base * Transform2D(0, Vector2(0, L * 0.04)).scaled_local(Vector2(1.0, 0.7)))
	ci.draw_circle(Vector2.ZERO, W * 0.3, Color("6b4f36"))                                       # тулуп
	ci.draw_set_transform_matrix(base)
	ci.draw_circle(Vector2(0, L * 0.0), W * 0.17, Color("8a6a4a"))                              # ушанка
	ci.draw_circle(Vector2(-W * 0.17, L * 0.02), W * 0.07, Color("6b4f36"))
	ci.draw_circle(Vector2(W * 0.17, L * 0.02), W * 0.07, Color("6b4f36"))
	ci.draw_circle(Vector2(0, -L * 0.02), W * 0.09, Color("a4875f"))
	# Искры из-под гусеницы на асфальте
	if opts.get("sparks", false):
		for k in 4:
			var ph := fmod(t * 8.0 + k * 0.27, 1.0)
			var sx := (Art.hash01(int(t * 8.0) * 7 + k) - 0.5) * W * 0.6
			ci.draw_circle(Vector2(sx, hl.y + ph * 22.0), 2.0 * (1.0 - ph) + 0.5, Color(1.0, 0.75, 0.3, 1.0 - ph))
	Art._taillights(ci, W * 0.6, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Встречные для новых трасс (рисуются развёрнутыми: base содержит поворот на 180°)
# ---------------------------------------------------------------------------
## Бензовоз: кабина + цистерна
static func draw_tanker(ci: CanvasItem, L: float, W: float, cab: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var hl := Vector2(W, L) / 2.0
	ci.draw_set_transform_matrix(Transform2D(0, base.origin))
	Art.rrect(ci, Rect2(-hl + Art.SHADOW_OFFSET * 1.4, Vector2(W, L)), Art.SHADOW, 10)
	ci.draw_set_transform_matrix(base)
	Art._headlight_cone(ci, W, L, opts)
	var cab_len := L * 0.24
	for side in [-1.0, 1.0]:
		for y in [-hl.y + cab_len * 0.45, hl.y - L * 0.12, hl.y - L * 0.28]:
			Art.rrect(ci, Rect2(side * (hl.x - 4) - 6, y - 10, 12, 20), INK, 3)
	var tank := Rect2(-hl.x + 2, -hl.y + cab_len + 6, W - 4, L - cab_len - 8)
	Art.rrect(ci, tank, Color("d9dde6"), W * 0.45, 2, Color("8a8f9c"))
	ci.draw_rect(Rect2(-hl.x + 2, tank.position.y + tank.size.y * 0.45, W - 4, 10), Art.ORANGE)
	var tc := Vector2(0, tank.position.y + tank.size.y * 0.45 + 5)
	if absf(base.get_rotation()) > PI / 2.0:
		ci.draw_set_transform_matrix(base * Transform2D(PI, tc))
		Art.text_center(ci, Vector2.ZERO, "ОГНЕОПАСНО", 8, INK, true)
		ci.draw_set_transform_matrix(base)
	else:
		Art.text_center(ci, tc, "ОГНЕОПАСНО", 8, INK, true)
	for k in 3:
		ci.draw_circle(Vector2(0, tank.position.y + 18 + k * tank.size.y * 0.32), 6, Color("8a8f9c"))   # люки
	ci.draw_line(Vector2(0, tank.position.y + 4), Vector2(0, tank.end.y - 4), Color(1, 1, 1, 0.35), 3.0)
	Art.rrect(ci, Rect2(-hl.x + 2, -hl.y, W - 4, cab_len), cab, 8, 2, cab.darkened(0.45))
	Art.trapezoid(ci, -hl.y + cab_len * 0.18, -hl.y + cab_len * 0.48, W * 0.66, W * 0.8, GLASS)
	Art.rrect(ci, Rect2(-W * 0.4, -hl.y + 2, W * 0.2, 6), HEAD, 2)
	Art.rrect(ci, Rect2(W * 0.2, -hl.y + 2, W * 0.2, 6), HEAD, 2)
	Art._taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Лесовоз: кабина + брёвна на коннике
static func draw_logger(ci: CanvasItem, L: float, W: float, cab: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var hl := Vector2(W, L) / 2.0
	ci.draw_set_transform_matrix(Transform2D(0, base.origin))
	Art.rrect(ci, Rect2(-hl + Art.SHADOW_OFFSET * 1.4, Vector2(W, L)), Art.SHADOW, 8)
	ci.draw_set_transform_matrix(base)
	Art._headlight_cone(ci, W, L, opts)
	var cab_len := L * 0.24
	for side in [-1.0, 1.0]:
		for y in [-hl.y + cab_len * 0.45, hl.y - L * 0.12, hl.y - L * 0.28]:
			Art.rrect(ci, Rect2(side * (hl.x - 4) - 6, y - 10, 12, 20), INK, 3)
	var bed := Rect2(-hl.x, -hl.y + cab_len + 6, W, L - cab_len - 6)
	ci.draw_rect(bed, Color("4a4e60"))
	for k in 5:                                    # брёвна вдоль кузова
		var x := -hl.x + 4 + k * (W - 8) / 5.0
		Art.rrect(ci, Rect2(x, bed.position.y - 6, (W - 8) / 5.0 - 2, bed.size.y + 10), Color("9a6a3e"), 5, 1, Color("6b4526"))
		ci.draw_circle(Vector2(x + (W - 8) / 10.0 - 1, bed.end.y + 2), (W - 8) / 10.0 - 2, Color("d9b07a"))
	for y in [bed.position.y + 14, bed.end.y - 18]:                                              # стойки-коники
		ci.draw_rect(Rect2(-hl.x - 2, y, W + 4, 5), INK)
	Art.rrect(ci, Rect2(-hl.x + 2, -hl.y, W - 4, cab_len), cab, 8, 2, cab.darkened(0.45))
	Art.trapezoid(ci, -hl.y + cab_len * 0.18, -hl.y + cab_len * 0.48, W * 0.66, W * 0.8, GLASS)
	Art.rrect(ci, Rect2(-W * 0.4, -hl.y + 2, W * 0.2, 6), HEAD, 2)
	Art.rrect(ci, Rect2(W * 0.2, -hl.y + 2, W * 0.2, 6), HEAD, 2)
	Art._taillights(ci, W, L, opts)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## «Шестёрка» с прицепом рассады (дачи). L — длина машины вместе с прицепом
static func draw_trailer_car(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	var base: Transform2D = opts.get("base", Transform2D.IDENTITY)
	var car_l := L * 0.6
	var tr_l := L * 0.34
	var o := opts.duplicate()
	o.base = base * Transform2D(0, Vector2(0, -L / 2.0 + car_l / 2.0))
	Art.draw_classic(ci, car_l, W, body, o)
	ci.draw_set_transform_matrix(base)
	var tr := Rect2(-W * 0.42, L / 2.0 - tr_l, W * 0.84, tr_l)
	ci.draw_line(Vector2(0, -L / 2.0 + car_l), Vector2(0, tr.position.y), INK, 3.0)              # дышло
	Art.rrect(ci, Rect2(tr.position + Art.SHADOW_OFFSET * 0.6, tr.size), Art.SHADOW, 4)
	for sx in [-1.0, 1.0]:
		ci.draw_rect(Rect2(sx * W * 0.46 - 4, tr.get_center().y - 8, 8, 16), INK)
	Art.rrect(ci, tr, Color("8a8f9c"), 4, 2, Color("5d6274"))
	# Ящики с рассадой
	for k in 6:
		var p := tr.position + Vector2(6 + (k % 3) * (tr.size.x - 12) / 3.0, 6 + (k / 3) * (tr.size.y - 12) / 2.0)
		var sz := Vector2((tr.size.x - 12) / 3.0 - 3, (tr.size.y - 12) / 2.0 - 3)
		ci.draw_rect(Rect2(p, sz), Color("7a5a3c"))
		for j in 3:
			ci.draw_circle(p + Vector2(sz.x * (0.2 + 0.3 * j), sz.y * 0.5), 3.5, Color("5fb04a"))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## «Жигули» для встречного потока: копейка со своим цветом
static func draw_classic_enemy(ci: CanvasItem, L: float, W: float, body: Color, opts: Dictionary = {}) -> void:
	Art.draw_classic(ci, L, W, body, opts)
