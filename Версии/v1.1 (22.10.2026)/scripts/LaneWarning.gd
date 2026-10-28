extends Control
## Предупреждения о том, что едет навстречу, но ещё не видно на экране.
## Стрелка у верхнего края экрана стоит точно над будущим местом появления машины:
##   красная пульсирующая с «!» — машина на ВАШЕЙ полосе (чем ближе, тем крупнее),
##   оранжевая — ограждение на вашем пути,
##   бледная — машины на соседних полосах (чтобы заранее выбрать, куда уходить).

@export var look_ahead: float = 1400.0     # как далеко за краем экрана замечаем машины

var _t: float = 0.0
var _warned: Dictionary = {}               # для короткой вибрации при новой угрозе


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var cam := get_viewport().get_camera_2d()
	if player == null or cam == null or player.is_dead:
		return
	var xf := get_viewport().get_canvas_transform()
	var top_world := cam.global_position.y - size.y / 2.0
	var p_half: float = player.CAR_WIDTH / 2.0
	var still_warned := {}
	var threats: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		threats.append([e, e._width / 2.0, e._length / 2.0, "car"])
	for o in get_tree().get_nodes_in_group("obstacles"):
		threats.append([o, o.width / 2.0, o.height / 2.0, "barrier"])
	for th in threats:
		var node: Node2D = th[0]
		var bottom: float = node.global_position.y + th[2]
		if bottom >= top_world:
			continue          # уже на экране — предупреждение не нужно
		var dist := top_world - bottom
		if dist > look_ahead:
			continue
		var k := 1.0 - dist / look_ahead          # 0 — далеко, 1 — вот-вот появится
		var in_lane: bool = absf(node.global_position.x - player.global_position.x) < th[1] + p_half + 14.0
		var sx: float = (xf * Vector2(node.global_position.x, 0)).x
		if in_lane:
			var col := Art.RED if th[3] == "car" else Art.ORANGE
			var pulse := 0.75 + 0.25 * sin(_t * (8.0 + 10.0 * k))
			_arrow(sx, 18.0 + 16.0 * k, Color(col, pulse), true)
			still_warned[node.get_instance_id()] = true
			if not _warned.has(node.get_instance_id()):
				MobileInput.vibrate(15)
		elif th[3] == "car":
			_arrow(sx, 10.0 + 6.0 * k, Color(Art.UI_TEXT, 0.22 + 0.25 * k), false)
	_warned = still_warned


func _arrow(x: float, s: float, col: Color, danger: bool) -> void:
	var y := 10.0
	var pts := PackedVector2Array([Vector2(x - s, y), Vector2(x + s, y), Vector2(x, y + s * 1.15)])
	if danger:
		Art.glow(self, Vector2(x, y + s * 0.5), s * 2.4, Color(col, 0.35))
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Art.INK, 0.8), 2.0, true)
	if danger and s > 22.0:
		Art.text_center(self, Vector2(x, y + s * 0.42), "!", int(s * 0.8), Art.INK, true)
