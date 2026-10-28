extends Control
## Предупреждения о том, что едет навстречу, но ещё не видно на экране.
## Стрелка у верхнего края экрана стоит точно над будущим местом появления машины:
##   красная пульсирующая с «!» — машина на ВАШЕЙ полосе (чем ближе, тем крупнее),
##   бледная — машины на соседних полосах (чтобы заранее выбрать, куда уходить).
## Ограждения: знак «!» в треугольнике над КАЖДОЙ перекрытой полосой (по всей ширине
## отбойника), а над проездом — зелёная стрелка. Так сразу видно, где дыра: слева, справа
## или посередине. Знак над вашей полосой мигает.

@export var look_ahead: float = 1400.0     # как далеко за краем экрана замечаем машины

var _t: float = 0.0
var _warned: Dictionary = {}               # для короткой вибрации при новой угрозе


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var cam := get_viewport().get_camera_2d()
	if player == null or cam == null or player.is_dead:
		return
	var xf := get_viewport().get_canvas_transform()
	var top_world := cam.global_position.y - Art.half_view_h()
	var p_half: float = player.CAR_WIDTH / 2.0
	var still_warned := {}
	# --- Машины ---
	for e in get_tree().get_nodes_in_group("enemies"):
		var bottom: float = e.global_position.y + e._length / 2.0
		if bottom >= top_world:
			continue          # уже на экране — предупреждение не нужно
		var dist := top_world - bottom
		if dist > look_ahead:
			continue
		var k := 1.0 - dist / look_ahead          # 0 — далеко, 1 — вот-вот появится
		var in_lane: bool = absf(e.global_position.x - player.global_position.x) < e._width / 2.0 + p_half + 14.0
		var sx: float = (xf * Vector2(e.global_position.x, 0)).x
		if in_lane:
			var pulse := 0.75 + 0.25 * sin(_t * (8.0 + 10.0 * k))
			_arrow(sx, 18.0 + 16.0 * k, Color(Art.RED, pulse), true)
			_remember(e, still_warned, -9.0)
		else:
			_arrow(sx, 10.0 + 6.0 * k, Color(Art.UI_TEXT, 0.22 + 0.25 * k), false)
	# --- Ограждения: собираем в «ряды» (ворота из двух кусков — один ряд) ---
	var rows := {}
	for o in get_tree().get_nodes_in_group("obstacles"):
		var bottom: float = o.global_position.y + o.height / 2.0
		if bottom >= top_world:
			continue
		var dist := top_world - bottom
		if dist > look_ahead:
			continue
		var key := int(round(o.global_position.y / 120.0))
		if not rows.has(key):
			rows[key] = {"lanes": {}, "dist": dist, "nodes": []}
		var row: Dictionary = rows[key]
		row.dist = minf(row.dist, dist)
		row.nodes.append(o)
		var half: float = o.width / 2.0
		for l in range(_lane_of(o.global_position.x - half + 12.0), _lane_of(o.global_position.x + half - 12.0) + 1):
			row.lanes[l] = true
	var p_lane := _lane_of(player.global_position.x)
	for row in rows.values():
		var k: float = 1.0 - row.dist / look_ahead
		var mine: bool = row.lanes.has(p_lane)
		for l in Art.LANES:
			var sx: float = (xf * Vector2(Art.ROAD_LEFT + Art.LANE_W * (l + 0.5), 0)).x
			if row.lanes.has(l):
				_sign(sx, 13.0 + 9.0 * k, l == p_lane, k)
			elif row.lanes.size() >= 2 or mine:
				_go(sx, 11.0 + 6.0 * k, k)
		if mine:
			for o in row.nodes:
				_remember(o, still_warned, -12.0)
	_warned = still_warned


func _remember(node: Node, still: Dictionary, volume: float) -> void:
	var id := node.get_instance_id()
	still[id] = true
	if not _warned.has(id):
		MobileInput.vibrate(15)
		Sound.play("warn", volume, 1.0, 0.0)


static func _lane_of(x: float) -> int:
	return clampi(int((x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)


func _arrow(x: float, s: float, col: Color, danger: bool) -> void:
	var y := 10.0
	var pts := PackedVector2Array([Vector2(x - s, y), Vector2(x + s, y), Vector2(x, y + s * 1.15)])
	if danger:
		Art.glow(self, Vector2(x, y + s * 0.5), s * 2.4, Color(col, 0.35))
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Art.INK, 0.8), 2.0, true)
	if danger and s > 22.0:
		Art.text_center(self, Vector2(x, y + s * 0.42), "!", int(s * 0.8), Art.INK, true)


## Дорожный знак «Опасность»: белый треугольник с красной каймой и «!»
func _sign(x: float, s: float, mine: bool, k: float) -> void:
	var y := 8.0
	var a := 0.55 + 0.45 * k
	if mine:
		a = 0.7 + 0.3 * sin(_t * (9.0 + 8.0 * k))
		Art.glow(self, Vector2(x, y + s * 0.9), s * 2.6, Color(Art.ORANGE, 0.4 * a))
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + s * 1.05, y + s * 1.8), Vector2(x - s * 1.05, y + s * 1.8)])
	draw_colored_polygon(pts, Color(Art.RED, a))
	var c := Vector2(x, y + s * 1.2)
	var inner := PackedVector2Array()
	for pt in pts:
		inner.append(c + (pt - c) * 0.62)
	draw_colored_polygon(inner, Color(1, 1, 1, a))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Art.INK, 0.7 * a), 1.5, true)
	Art.text_center(self, Vector2(x, y + s * 1.22), "!", int(s * 0.95), Color(Art.INK, a), true)


## Зелёная стрелка «здесь проезд»
func _go(x: float, s: float, k: float) -> void:
	var y := 10.0 + 3.0 * sin(_t * 6.0)
	var col := Color(Art.GREEN, 0.45 + 0.45 * k)
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + s, y + s), Vector2(x + s * 0.4, y + s),
		Vector2(x + s * 0.4, y + s * 1.8), Vector2(x - s * 0.4, y + s * 1.8), Vector2(x - s * 0.4, y + s), Vector2(x - s, y + s)])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Art.INK, 0.6), 1.5, true)
