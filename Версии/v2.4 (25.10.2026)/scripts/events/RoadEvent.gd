extends Node2D
## Базовый класс дорожного события (АЗС, камера, ремонт, мост…).
## Узел стоит в мировых координатах: x — как у дороги, y — ближний (нижний) край события.
## Всё, что событие рисует, задаётся в локальных координатах: «вперёд по дороге» — это −y.

const KMH := 0.16                  # перевод игровой скорости в км/ч (как у спидометра)

var kind: String = ""
var length: float = 1200.0         # длина события вдоль дороги
var lanes_blocked: Array = []      # полосы, где спавнер ничего не ставит
## "all" — спавн как обычно, "enemies" — только встречные и бонусы, "none" — ничего
var spawn_policy: String = "all"
var clear_all_lanes: bool = false  # при появлении убрать препятствия со всей ширины дороги
var finished: bool = false
var max_age: float = 40.0          # страховка: событие не может длиться дольше
var manager = null
var _t: float = 0.0
var _redraw_tick: int = 0


func _ready() -> void:
	z_index = -5                   # над городом и асфальтом, но под машинами
	add_to_group("lit")
	add_to_group("road_event_nodes")


## Верхний (дальний) край события в мировых координатах
func top_y() -> float:
	return global_position.y - length


## Мировая y-координата точки на расстоянии d от начала события
func wy(d: float) -> float:
	return global_position.y - d


func _physics_process(delta: float) -> void:
	_t += delta
	var p = get_tree().get_first_node_in_group("player")
	if p and not p.is_dead and not finished:
		_update(p, delta)
		if _is_done(p) or _t > max_age:
			finished = true
			_on_finished(p)
	var cam := get_viewport().get_camera_2d()
	if cam and _gone_behind(cam.global_position.y + Art.half_view_h() + 300.0):
		queue_free()
	# Анимации события (мигалки, вода, шлагбаум) перерисовываются через кадр
	# и только пока событие видно на экране
	_redraw_tick += 1
	if _redraw_tick % 2 != 0:
		return
	if cam:
		var cy := cam.global_position.y
		var half := Art.half_view_h() + 120.0
		if top_y() > cy + half or global_position.y + 200.0 < cy - half:
			return
	queue_redraw()


## Событие полностью позади камеры — можно удалять
func _gone_behind(cam_bottom: float) -> bool:
	return top_y() > cam_bottom


func _is_done(p) -> bool:
	return p.global_position.y < top_y() - 250.0


# --- Переопределяется в наследниках ---
func start() -> void:
	pass


func _update(_p, _delta: float) -> void:
	pass


func _on_finished(_p) -> void:
	pass


## Подсказка для HUD (пустой словарь — ничего не показывать)
func hud_info(_p) -> Dictionary:
	return {}


## Источники света для ночи: [мировая позиция, радиус, сила]
func get_lights() -> Array:
	return []


# --- Помощники ---
static func lane_left(lane: int) -> float:
	return Art.ROAD_LEFT + lane * Art.LANE_W


static func lane_right(lane: int) -> float:
	return Art.ROAD_LEFT + (lane + 1) * Art.LANE_W


static func lane_center(lane: int) -> float:
	return Art.ROAD_LEFT + (lane + 0.5) * Art.LANE_W


func toast(text: String, color: Color, duration: float = 2.4) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast(text, color, duration)


func add_score(points: int) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p:
		var sc = p.get_node_or_null("scoreComponent")
		if sc and sc.has_method("add_bonus"):
			sc.add_bonus(points)


## Всплывающая надпись над машиной игрока
func popup_at_player(text: String, color: Color) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p:
		Pickup.burst(p, color, text, "")


# --- Мелкие рисовалки, общие для событий ---
## Дорожный знак на стойке (вид сверху): тень, стойка и круглая/квадратная табличка
func draw_round_sign(pos: Vector2, r: float, fill: Color, ring: Color, text: String, text_color: Color, text_size: int = 16) -> void:
	draw_circle(pos + Vector2(5, 7), r, Art.SHADOW)
	draw_circle(pos, r, fill)
	draw_arc(pos, r - 2.5, 0, TAU, 32, ring, 5.0, true)
	draw_arc(pos, r, 0, TAU, 32, Art.INK, 1.5, true)
	if text != "":
		Art.text_center(self, pos, text, text_size, text_color, true)


func draw_plate(rect: Rect2, fill: Color, text: String, text_color: Color, text_size: int = 10, border: Color = Art.INK) -> void:
	Art.rrect(self, Rect2(rect.position + Vector2(4, 6), rect.size), Art.SHADOW, 4)
	Art.rrect(self, rect, fill, 4, 2, border)
	if text != "":
		var lines := text.split("\n")
		var lh := text_size + 3.0
		var y0 := rect.get_center().y - (lines.size() - 1) * lh / 2.0
		for i in lines.size():
			Art.text_center(self, Vector2(rect.get_center().x, y0 + i * lh), lines[i], text_size, text_color, true)


## Конус (вид сверху)
func draw_cone(pos: Vector2, s: float = 1.0) -> void:
	draw_rect(Rect2(pos - Vector2(11, 11) * s + Vector2(3, 4), Vector2(22, 22) * s), Art.SHADOW)
	draw_rect(Rect2(pos - Vector2(11, 11) * s, Vector2(22, 22) * s), Color("2a2c36"))
	draw_circle(pos, 9.0 * s, Art.ORANGE)
	draw_arc(pos, 5.5 * s, 0, TAU, 16, Art.LINE_WHITE, 2.5 * s, true)
	draw_circle(pos, 2.5 * s, Art.ORANGE.lightened(0.2))


## Человечек сверху: плечи, голова, руки. Возвращает ничего — просто рисует.
func draw_person(pos: Vector2, body: Color, head: Color = Color("e8b48a"), angle: float = 0.0, cap: Color = Color(0, 0, 0, 0)) -> void:
	draw_set_transform(pos, angle, Vector2.ONE)
	draw_circle(Vector2(3, 4), 11, Art.SHADOW)
	Art.rrect(self, Rect2(-11, -6, 22, 12), body, 6, 1, body.darkened(0.4))
	draw_circle(Vector2(-11, 0), 4, body.darkened(0.15))
	draw_circle(Vector2(11, 0), 4, body.darkened(0.15))
	draw_circle(Vector2(0, -1), 6, head)
	if cap.a > 0.0:
		draw_circle(Vector2(0, -1), 6, cap)
		draw_rect(Rect2(-5, -9, 10, 4), cap.darkened(0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
