extends Control
## «Второй шанс»: после аварии (один раз за заезд) можно продолжить за монеты.
## Пока идёт обратный отсчёт, игра на паузе. Не успел — показываются итоги.

const WAIT := 6.0

var _cb: Callable
var _left: float = 0.0
var _active: bool = false
var _ring: Control
var _yes: Button
var _no: Button
var _reason: Label
var _panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "ВТОРОЙ ШАНС?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Art.font_title)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Art.ORANGE)
	vb.add_child(title)
	_reason = Label.new()
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.custom_minimum_size.x = 440
	_reason.add_theme_font_size_override("font_size", 15)
	_reason.add_theme_color_override("font_color", Art.UI_MUTED)
	vb.add_child(_reason)
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(440, 96)
	_ring.draw.connect(_draw_ring)
	vb.add_child(_ring)
	var note := Label.new()
	note.text = "Машина как новая, полный бак, дорога впереди расчищена\nи 3 секунды неуязвимости. Один раз за заезд."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Art.UI_TEXT)
	vb.add_child(note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	_yes = Button.new()
	_yes.custom_minimum_size = Vector2(250, 56)
	_yes.add_theme_font_size_override("font_size", 19)
	_yes.pressed.connect(func(): _finish(true))
	row.add_child(_yes)
	_no = Button.new()
	_no.text = "Нет, итоги"
	_no.custom_minimum_size = Vector2(170, 56)
	_no.pressed.connect(func(): _finish(false))
	row.add_child(_no)
	hide()


func offer(price: int, reason: String, cb: Callable) -> void:
	_cb = cb
	_left = WAIT
	_active = true
	_reason.text = reason
	_yes.text = "Продолжить  •  %d монет" % price
	show()
	get_tree().paused = true
	Sound.play("warn", -4.0, 0.8, 0.0)
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_yes.grab_focus()


func _process(delta: float) -> void:
	if not _active:
		return
	var before := ceili(_left)
	_left -= delta
	if ceili(_left) != before and _left > 0.0:
		Sound.play("beep", -10.0, 0.9, 0.0)
	_ring.queue_redraw()
	if _left <= 0.0:
		_finish(false)


func is_offering() -> bool:
	return _active


func decline() -> void:
	if _active:
		_finish(false)


func _finish(accepted: bool) -> void:
	if not _active:
		return
	_active = false
	hide()
	if _cb.is_valid():
		_cb.call(accepted)


func _draw_ring() -> void:
	var c := Vector2(_ring.size.x / 2.0, _ring.size.y / 2.0)
	var k := clampf(_left / WAIT, 0.0, 1.0)
	_ring.draw_circle(c, 44, Color(Art.UI_PANEL_LIGHT))
	_ring.draw_arc(c, 40, -PI / 2.0, -PI / 2.0 + TAU * k, 48, Art.ORANGE if k > 0.33 else Art.RED, 7.0, true)
	Art.text_center(_ring, c + Vector2(0, 2), str(ceili(_left)), 34, Art.UI_TEXT, true)
