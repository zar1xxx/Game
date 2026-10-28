extends Control
## Стрелочный спидометр в стиле игры: шкала, красная зона, стрелка и цифры.
## При нитро шкала светится бирюзовым, при торможении стрелка краснеет.

const KMH := 0.16
const MAX_KMH := 220.0
const A0 := deg_to_rad(150.0)     # начало шкалы (слева внизу)
const A1 := deg_to_rad(390.0)     # конец шкалы (справа внизу)

var player = null
var _shown_kmh: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(172, 104)


func _process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player:
		var kmh: float = player.current_speed * KMH
		# Стрелка «догоняет» значение с небольшой инерцией
		_shown_kmh = lerpf(_shown_kmh, kmh, clampf(delta * 8.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	Art.rrect(self, rect, Color(Art.UI_PANEL, 0.88), 14)
	var nitro: bool = player != null and player.nitro_time_left > 0.0
	var braking: bool = player != null and player.is_braking
	var c := Vector2(size.x * 0.5, size.y * 0.62)
	var r := minf(size.x * 0.42, size.y * 0.56)
	# Шкала
	draw_arc(c, r, A0, A1, 48, Color(Art.UI_PANEL_LIGHT), 9.0, true)
	var red_from := lerpf(A0, A1, 0.78)
	draw_arc(c, r, red_from, A1, 16, Color(Art.RED, 0.75), 9.0, true)
	var k := clampf(_shown_kmh / MAX_KMH, 0.0, 1.0)
	var fill_col := Art.TEAL if nitro else Art.ORANGE
	if k > 0.01:
		draw_arc(c, r, A0, lerpf(A0, A1, k), 48, fill_col, 9.0, true)
	if nitro:
		Art.glow(self, c, r * 1.3, Color(Art.TEAL, 0.18 + 0.08 * sin(_t * 12.0)))
	# Деления
	for i in 12:
		var a := lerpf(A0, A1, float(i) / 11.0)
		var dir := Vector2.from_angle(a)
		var long := i % 2 == 0
		draw_line(c + dir * (r - 16.0), c + dir * (r - (8.0 if long else 11.0)),
			Color(Art.UI_MUTED, 0.9 if long else 0.5), 2.0 if long else 1.5, true)
	# Стрелка
	var na := lerpf(A0, A1, k)
	var nd := Vector2.from_angle(na)
	var needle_col := Art.RED if braking else Art.UI_TEXT
	draw_line(c - nd * 6.0, c + nd * (r - 6.0), Color(Art.INK, 0.6), 5.0, true)
	draw_line(c - nd * 6.0, c + nd * (r - 6.0), needle_col, 3.0, true)
	draw_circle(c, 6.0, Art.INK)
	draw_circle(c, 4.0, needle_col)
	# Цифры
	Art.text_center(self, Vector2(c.x, size.y - 22.0), str(int(_shown_kmh)), 24,
		Art.TEAL if nitro else Art.UI_TEXT, true)
	Art.text_center(self, Vector2(c.x, size.y - 7.0), "км/ч", 11, Art.UI_MUTED)
