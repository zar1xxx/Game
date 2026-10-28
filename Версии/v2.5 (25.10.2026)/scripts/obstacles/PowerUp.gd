extends Area2D
## Бонусы на дороге:
##   «Щит» — один удар (машина, отбойник, яма, полиция) проходит бесплатно;
##   «Мигалка» — 5 секунд встречные машины уходят с вашей полосы;
##   «×2» — 8 секунд очки за расстояние и манёвры идут вдвое.

const KINDS := {
	"shield": {"title": "Щит", "toast": "Щит! Один удар бесплатно", "color": Color("4fd1c5"), "time": 0.0},
	"siren": {"title": "Мигалка", "toast": "Мигалка! Все уступают дорогу", "color": Color("4c8dff"), "time": 5.0},
	"double": {"title": "×2", "toast": "Двойные очки!", "color": Color("ffd23f"), "time": 8.0},
}

var kind: String = "shield"
var _t: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var col: Color = KINDS[kind].color
	Pickup.draw_halo(self, col, _t)
	var bob := sin(_t * 3.0) * 3.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	draw_icon(self, kind, Vector2.ZERO, 1.0, _t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Значок бонуса (им же пользуется HUD)
static func draw_icon(ci: CanvasItem, k: String, c: Vector2, s: float, t: float) -> void:
	var col: Color = KINDS[k].color
	match k:
		"shield":
			var pts := PackedVector2Array()
			for p in [Vector2(0, -22), Vector2(17, -15), Vector2(15, 4), Vector2(0, 21), Vector2(-15, 4), Vector2(-17, -15)]:
				pts.append(c + p * s)
			ci.draw_colored_polygon(pts, col.darkened(0.35))
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(c + (p - c) * 0.72)
			ci.draw_colored_polygon(inner, col)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Art.INK, 2.0 * s, true)
			ci.draw_line(c + Vector2(-6, -2) * s, c + Vector2(-1, 4) * s, Art.INK, 3.0 * s)
			ci.draw_line(c + Vector2(-1, 4) * s, c + Vector2(8, -8) * s, Art.INK, 3.0 * s)
		"siren":
			# Мигалка: красный и синий плафоны на основании
			Art.rrect(ci, Rect2(c + Vector2(-20, 4) * s, Vector2(40, 10) * s), Art.SILVER, 4 * s, 2, Art.INK)
			var on := int(t * 6.0) % 2 == 0
			for i in 2:
				var lc := Art.RED if i == 0 else Color("4c8dff")
				var lit := (i == 0) == on
				var r := Rect2(c + Vector2(-18 + i * 19, -14) * s, Vector2(17, 18) * s)
				Art.rrect(ci, r, lc if lit else lc.darkened(0.5), 7 * s, 2, Art.INK)
				if lit:
					Art.glow(ci, r.get_center(), 26 * s, Color(lc, 0.5), 4)
		"double":
			ci.draw_circle(c, 20 * s, Art.INK)
			ci.draw_circle(c, 18 * s, col)
			ci.draw_circle(c, 13 * s, col.lightened(0.25))
			Art.text_center(ci, c + Vector2(0, 1) * s, "×2", int(17 * s), Art.INK, true)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or body.is_dead:
		return
	if body.has_method("apply_powerup"):
		body.apply_powerup(kind)
	Pickup.burst(self, KINDS[kind].color, KINDS[kind].title + "!", "pickup")
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast(KINDS[kind].toast, KINDS[kind].color, 1.8)
	Missions.event("powerup")
	queue_free()


func _physics_process(_delta: float) -> void:
	Pickup.cleanup_if_behind(self)
