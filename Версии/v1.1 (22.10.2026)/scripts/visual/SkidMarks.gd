extends Node2D
## Следы шин на асфальте: появляются при заносе, торможении и на масле,
## постепенно бледнеют и исчезают.

const MAX_SEGMENTS := 700
const LIFETIME := 5.0

var _segments: Array = []      # [точка A, точка B, время появления]
var _last: Dictionary = {}     # последняя точка для каждого колеса
var _t: float = 0.0


func _ready() -> void:
	z_index = -9


func add_point(wheel: int, pos: Vector2, active: bool) -> void:
	if active and _last.has(wheel):
		_segments.append([_last[wheel], pos, _t])
		if _segments.size() > MAX_SEGMENTS:
			_segments.pop_front()
	if active:
		_last[wheel] = pos
	else:
		_last.erase(wheel)


func _process(delta: float) -> void:
	_t += delta
	while _segments.size() > 0 and _t - _segments[0][2] > LIFETIME:
		_segments.pop_front()
	queue_redraw()


func _draw() -> void:
	for s in _segments:
		var a: float = 1.0 - (_t - s[2]) / LIFETIME
		draw_line(s[0], s[1], Color(0.07, 0.07, 0.09, 0.55 * a), 7.0)
