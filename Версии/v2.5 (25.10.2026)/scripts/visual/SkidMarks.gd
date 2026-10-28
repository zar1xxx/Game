extends Node2D
## Следы шин на асфальте: появляются при заносе, торможении и на масле,
## постепенно бледнеют и исчезают.

const MAX_SEGMENTS := 700
const LIFETIME := 5.0

var _segments: Array = []      # [точка A, точка B, время появления]
var _last: Dictionary = {}     # последняя точка для каждого колеса
var _t: float = 0.0
var _frame: int = 0
var _dirty: bool = false


func _ready() -> void:
	z_index = -9


func add_point(wheel: int, pos: Vector2, active: bool) -> void:
	if active and _last.has(wheel):
		_segments.append([_last[wheel], pos, _t])
		_dirty = true
		if _segments.size() > MAX_SEGMENTS:
			_segments.pop_front()
	if active:
		_last[wheel] = pos
	else:
		_last.erase(wheel)


func _process(delta: float) -> void:
	_t += delta
	var removed := false
	while _segments.size() > 0 and _t - _segments[0][2] > LIFETIME:
		_segments.pop_front()
		removed = true
	# Следы бледнеют медленно: достаточно перерисовывать их несколько раз в секунду,
	# а новые отрезки — сразу
	_frame += 1
	if _dirty or (_frame % 6 == 0 and (removed or not _segments.is_empty())):
		_dirty = false
		queue_redraw()


func _draw() -> void:
	var n := _segments.size()
	if n == 0:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(n * 2)
	cols.resize(n)
	var i := 0
	for s in _segments:
		var a: float = 1.0 - (_t - s[2]) / LIFETIME
		pts[i * 2] = s[0]
		pts[i * 2 + 1] = s[1]
		cols[i] = Color(0.07, 0.07, 0.09, 0.55 * a)
		i += 1
	draw_multiline_colors(pts, cols, 7.0)
