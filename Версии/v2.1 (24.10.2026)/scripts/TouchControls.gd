extends Control
## Сенсорное управление для телефонов и планшетов.
## Режим «Кнопки»: ◀ ▶ слева (под левый большой палец), педаль тормоза справа.
## Режим «Наклон»: рулим наклоном телефона, касание правой половины экрана — тормоз.
## Поддерживается мультитач: можно одновременно рулить и тормозить.
## Зоны нажатия намного больше нарисованных кнопок, чтобы не промахиваться.

@export var force_visible: bool = false   # показать на ПК (для отладки)

const BTN_R := 62.0          # радиус кнопок-стрелок
const MARGIN := 26.0
const PEDAL := Vector2(128, 150)
const HORN_R := 36.0         # кнопка гудка над педалью

var _touches: Dictionary = {}    # индекс пальца -> позиция
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = force_visible or MobileInput.is_touch_device()
	MobileInput.mode_changed.connect(func(_m): queue_redraw())


func _process(delta: float) -> void:
	_t += delta
	var paused := get_tree().paused
	if paused and not _touches.is_empty():
		_touches.clear()
		MobileInput.release_all()
	modulate.a = move_toward(modulate.a, 0.0 if paused else 1.0, delta * 6.0)
	queue_redraw()


# ---------------------------------------------------------------------------
# Раскладка
# ---------------------------------------------------------------------------
func _left_center() -> Vector2:
	return Vector2(MARGIN + BTN_R, size.y - MARGIN - BTN_R)


func _right_center() -> Vector2:
	return _left_center() + Vector2(BTN_R * 2.0 + 24.0, 0)


func _pedal_rect() -> Rect2:
	return Rect2(Vector2(size.x - MARGIN - PEDAL.x, size.y - MARGIN - PEDAL.y), PEDAL)


func _horn_center() -> Vector2:
	var r := _pedal_rect()
	return Vector2(r.position.x + r.size.x / 2.0, r.position.y - HORN_R - 22.0)


## В какую зону попало касание: "left", "right", "brake", "horn" или ""
func _zone(pos: Vector2) -> String:
	# Касания в верхней части экрана не трогаем — там кнопка паузы и счёт
	if pos.y < size.y * 0.35:
		return ""
	if pos.distance_to(_horn_center()) < HORN_R + 14.0:
		return "horn"
	if MobileInput.get_mode() == "tilt":
		return "brake" if pos.x > size.x * 0.5 else ""
	if pos.x > size.x * 0.62:
		return "brake"
	if pos.x < size.x * 0.38:
		var mid := (_left_center().x + _right_center().x) / 2.0
		return "left" if pos.x < mid else "right"
	return ""


# ---------------------------------------------------------------------------
# Ввод
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_recompute()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		_recompute()


func _recompute() -> void:
	var steer := 0.0
	var brk := false
	var horn := false
	for pos in _touches.values():
		match _zone(pos):
			"horn":
				horn = true
			"left":
				steer -= 1.0
			"right":
				steer += 1.0
			"brake":
				brk = true
	var was_brake := MobileInput.touch_brake
	MobileInput.touch_steer = clampf(steer, -1.0, 1.0)
	MobileInput.touch_brake = brk
	MobileInput.horn = horn
	if brk and not was_brake:
		MobileInput.vibrate(12)


# ---------------------------------------------------------------------------
# Отрисовка (в общем стиле Art.gd)
# ---------------------------------------------------------------------------
func _draw() -> void:
	var tilt := MobileInput.get_mode() == "tilt"
	if not tilt:
		_draw_arrow_button(_left_center(), -1, MobileInput.touch_steer < -0.1)
		_draw_arrow_button(_right_center(), 1, MobileInput.touch_steer > 0.1)
	else:
		_draw_wheel(_left_center() + Vector2(BTN_R * 0.6, 0), MobileInput.steer_axis)
	_draw_pedal(_pedal_rect(), MobileInput.touch_brake)
	_draw_horn(_horn_center(), MobileInput.horn)


func _draw_horn(c: Vector2, pressed: bool) -> void:
	draw_circle(c + Vector2(0, 4), HORN_R, Color(0, 0, 0, 0.25))
	draw_circle(c, HORN_R, Color(Art.YELLOW, 0.9) if pressed else Color(Art.UI_PANEL, 0.55))
	draw_arc(c, HORN_R - 1.5, 0, TAU, 40, Color(Art.YELLOW, 0.9 if pressed else 0.55), 3.0, true)
	Art.text_center(self, c, "БИП", 15, Art.INK if pressed else Color(Art.UI_TEXT, 0.9), true)


func _draw_arrow_button(c: Vector2, dir: int, pressed: bool) -> void:
	var fill := Color(Art.ORANGE, 0.9) if pressed else Color(Art.UI_PANEL, 0.55)
	draw_circle(c + Vector2(0, 5), BTN_R, Color(0, 0, 0, 0.25))
	draw_circle(c, BTN_R, fill)
	draw_arc(c, BTN_R - 1.5, 0, TAU, 48, Color(Art.ORANGE, 0.9 if pressed else 0.6), 3.0, true)
	var s := BTN_R * 0.42
	var pts := PackedVector2Array([
		c + Vector2(dir * s, 0), c + Vector2(-dir * s * 0.6, -s), c + Vector2(-dir * s * 0.6, s)])
	draw_colored_polygon(pts, Art.INK if pressed else Color(Art.UI_TEXT, 0.9))


func _draw_pedal(r: Rect2, pressed: bool) -> void:
	var press_off := Vector2(0, 4) if pressed else Vector2.ZERO
	Art.rrect(self, Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.25), 18)
	var body := Rect2(r.position + press_off, r.size)
	Art.rrect(self, body, Color(Art.RED, 0.9) if pressed else Color(Art.UI_PANEL, 0.55), 18, 3,
		Color(Art.RED, 0.9 if pressed else 0.6))
	# Рифление педали
	for i in 4:
		var y := body.position.y + 28 + i * 22
		Art.rrect(self, Rect2(body.position.x + 22, y, body.size.x - 44, 8),
			Color(Art.INK, 0.5) if pressed else Color(Art.UI_TEXT, 0.25), 4)
	Art.text_center(self, body.position + Vector2(body.size.x / 2.0, body.size.y - 20), "ТОРМОЗ", 15,
		Art.UI_TEXT if not pressed else Art.INK, true)
	# Испытание «Без тормозов» — педаль перечёркнута
	if SaveManager.rule_active("no_brakes"):
		draw_line(body.position + Vector2(10, 10), body.end - Vector2(10, 10), Color(Art.RED, 0.95), 7.0, true)
		draw_line(Vector2(body.end.x - 10, body.position.y + 10), Vector2(body.position.x + 10, body.end.y - 10), Color(Art.RED, 0.95), 7.0, true)


## Индикатор руля в режиме наклона
func _draw_wheel(c: Vector2, steer: float) -> void:
	draw_circle(c, BTN_R * 0.95, Color(Art.UI_PANEL, 0.55))
	var ang := steer * 1.2
	draw_arc(c, BTN_R * 0.75, 0, TAU, 48, Color(Art.UI_TEXT, 0.85), 8.0, true)
	for k in [-1.0, 1.0]:
		var d := Vector2(cos(ang + (PI if k < 0 else 0.0)), sin(ang + (PI if k < 0 else 0.0)))
		draw_line(c, c + d * BTN_R * 0.75, Color(Art.UI_TEXT, 0.85), 6.0, true)
	draw_line(c, c + Vector2(sin(ang), cos(ang)) * BTN_R * 0.75, Color(Art.UI_TEXT, 0.85), 6.0, true)
	draw_circle(c, 10, Art.ORANGE)
	Art.text_center(self, c + Vector2(0, -BTN_R - 14), "НАКЛОН", 13, Color(Art.UI_TEXT, 0.8))
