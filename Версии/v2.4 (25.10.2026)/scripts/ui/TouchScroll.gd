extends Node
## Прокрутка списка пальцем для ScrollContainer.
## Встроенная прокрутка Godot срабатывает, только если палец лёг на пустое место, —
## а в настройках и гараже почти всё место занято кнопками. Этот узел ловит касание
## в любом месте списка: если палец ушёл по вертикали дальше порога, это прокрутка,
## и нажатие на кнопку под пальцем отменяется. После отпускания список докатывается по инерции.
## Использование: TouchScroll.attach(scroll_container)

const THRESHOLD := 12.0          # с какого сдвига (в пикселях экрана игры) начинается прокрутка
const FRICTION := 5.0            # как быстро гаснет инерция

var _sc: ScrollContainer
var _touch: int = -1
var _start := Vector2.ZERO
var _start_scroll: float = 0.0
var _dragging: bool = false
var _blocked: bool = false       # палец лёг на ползунок — его не трогаем
var _vel: float = 0.0            # скорость прокрутки, пикс/с
var _last_y: float = 0.0
var _last_t: int = 0
var _pos: float = 0.0            # дробная позиция прокрутки (scroll_vertical — целое)


static func attach(sc: ScrollContainer) -> Node:
	var ts = load("res://scripts/ui/TouchScroll.gd").new()
	ts.name = "TouchScroll"
	sc.add_child(ts)
	return ts


func _ready() -> void:
	_sc = get_parent() as ScrollContainer
	# Встроенную прокрутку перетаскиванием отключаем, чтобы две прокрутки не спорили.
	# Колесо мыши и полоса прокрутки продолжают работать как обычно.
	_sc.scroll_deadzone = 1000000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _input(event: InputEvent) -> void:
	if _sc == null or not _sc.is_visible_in_tree():
		_touch = -1
		_dragging = false
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch == -1 and _sc.get_global_rect().has_point(st.position):
				_touch = st.index
				_start = st.position
				_start_scroll = _sc.scroll_vertical
				_pos = _start_scroll
				_dragging = false
				_blocked = _on_slider(st.position)
				_vel = 0.0
				_last_y = st.position.y
				_last_t = Time.get_ticks_msec()
				set_process(false)
		elif st.index == _touch:
			_touch = -1
			if _dragging:
				_dragging = false
				# Палец давно стоит на месте — без инерции
				if Time.get_ticks_msec() - _last_t > 90:
					_vel = 0.0
				set_process(absf(_vel) > 30.0)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index != _touch or _blocked:
			return
		var dy := sd.position.y - _start.y
		if not _dragging and absf(dy) > THRESHOLD and absf(dy) > absf(sd.position.x - _start.x):
			_dragging = true
			_cancel_presses()
			# Начинаем от текущей точки, чтобы список не прыгнул на величину порога
			_start = sd.position
			_start_scroll = _sc.scroll_vertical
			_pos = _start_scroll
		if _dragging:
			var now := Time.get_ticks_msec()
			var dt := maxf((now - _last_t) / 1000.0, 0.001)
			var v := -(sd.position.y - _last_y) / dt
			_vel = lerpf(_vel, v, 0.5)
			_last_y = sd.position.y
			_last_t = now
			_pos = _start_scroll - (sd.position.y - _start.y)
			_sc.scroll_vertical = int(roundf(_pos))
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Докат по инерции
	_pos += _vel * delta
	_vel = move_toward(_vel, 0.0, absf(_vel) * FRICTION * delta + 40.0 * delta)
	var before := _sc.scroll_vertical
	_sc.scroll_vertical = int(roundf(_pos))
	if absf(_vel) < 20.0 or (_sc.scroll_vertical == before and absf(_vel) > 0.0 and _hit_edge()):
		_vel = 0.0
		set_process(false)


func _hit_edge() -> bool:
	var bar := _sc.get_v_scroll_bar()
	return _sc.scroll_vertical <= 0 or _sc.scroll_vertical >= int(bar.max_value - bar.page)


## Палец лёг на ползунок громкости — двигать нужно его, а не список
func _on_slider(p: Vector2) -> bool:
	for s in _sc.find_children("*", "Slider", true, false):
		var c := s as Control
		if c.is_visible_in_tree() and c.get_global_rect().grow(6.0).has_point(p):
			return true
	return false


## Прокрутка началась — кнопка под пальцем не должна сработать при отпускании
func _cancel_presses() -> void:
	for b in _sc.find_children("*", "BaseButton", true, false):
		var btn := b as BaseButton
		if btn.disabled or not btn.is_visible_in_tree():
			continue
		# Выключение кнопки сбрасывает начатое нажатие; сразу включаем обратно
		btn.disabled = true
		btn.disabled = false
	var le := _sc.get_viewport().gui_get_focus_owner() as LineEdit
	if le and _sc.is_ancestor_of(le):
		le.release_focus()
