extends CanvasLayer
## Плавные переходы между экранами и «живые» кнопки (Autoload "Transition").
##   Transition.go("res://scenes/MainMenu.tscn")   — шторка, смена сцены, шторка уходит
##   Transition.reload()                            — перезапуск текущей сцены со шторкой
## Заодно ко ВСЕМ кнопкам игры автоматически цепляются звук нажатия/наведения
## и лёгкая анимация (пружинка при нажатии, увеличение при наведении/фокусе).

var _curtain: Control
var _busy: bool = false
var _t: float = 0.0
var _progress: float = 0.0     # 0 — шторки нет, 1 — экран закрыт


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_curtain = Control.new()
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.draw.connect(_draw_curtain)
	add_child(_curtain)
	get_tree().node_added.connect(_on_node_added)


func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	Sound.play("whoosh", -8.0)
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().paused = false
	if path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_method(_set_progress, 1.0, 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func reload() -> void:
	go("")


func _set_progress(v: float) -> void:
	_progress = v
	_curtain.queue_redraw()


## Шторка из косых полос в цветах игры (как дорожная разметка)
func _draw_curtain() -> void:
	if _progress <= 0.001:
		return
	var size := _curtain.size
	var cols := [Art.INK, Art.UI_PANEL, Art.INK, Art.UI_PANEL_LIGHT, Art.INK]
	var n := 7
	var slant := size.y * 0.35
	var band_w := (size.x + slant) / n
	for i in n:
		# Полосы выезжают по очереди — получается «волна»
		var k := clampf(_progress * 1.6 - float(i) / n * 0.6, 0.0, 1.0)
		if k <= 0.0:
			continue
		var x0 := i * band_w - slant
		var h := size.y * k
		var pts := PackedVector2Array([
			Vector2(x0, 0), Vector2(x0 + band_w + 2, 0),
			Vector2(x0 + band_w + 2 + slant * k, h), Vector2(x0 + slant * k, h)])
		_curtain.draw_colored_polygon(pts, cols[i % cols.size()])
	if _progress > 0.85:
		var a := (_progress - 0.85) / 0.15
		Art.text_center(_curtain, size / 2.0, "В ПОГОНЕ ЗА БЕНЗИНОМ", 34, Color(Art.ORANGE, a), true)


# ---------------------------------------------------------------------------
# «Живые» кнопки
# ---------------------------------------------------------------------------
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b: BaseButton = node
		if b.has_meta("no_fx") or b.has_meta("_fx_on"):
			return        # кнопку переставили в другой контейнер — сигналы уже подключены
		b.set_meta("_fx_on", true)
		b.pressed.connect(_on_button_pressed.bind(b))
		b.mouse_entered.connect(_on_button_hover.bind(b, true))
		b.mouse_exited.connect(_on_button_hover.bind(b, false))
		b.focus_entered.connect(_on_button_hover.bind(b, true))
		b.focus_exited.connect(_on_button_hover.bind(b, false))
		b.resized.connect(func(): b.pivot_offset = b.size / 2.0)


func _on_button_pressed(b: BaseButton) -> void:
	Sound.play("click", -4.0)
	if not is_instance_valid(b) or b is CheckButton:
		return
	b.pivot_offset = b.size / 2.0
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(0.92, 0.92), 0.06)
	tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_button_hover(b: BaseButton, on: bool) -> void:
	if not is_instance_valid(b) or b.disabled or b is CheckButton or not b.is_visible_in_tree():
		return
	if on and b.has_meta("_hovered"):
		return
	if on:
		b.set_meta("_hovered", true)
		# Звук наведения — только мышью/клавиатурой: на телефоне фокус прыгает при касании
		if not MobileInput.is_touch_device():
			Sound.play("hover", -14.0)
	else:
		if b.has_focus() or b.is_hovered():
			return
		b.remove_meta("_hovered")
	b.pivot_offset = b.size / 2.0
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.04, 1.04) if on else Vector2.ONE, 0.12)
