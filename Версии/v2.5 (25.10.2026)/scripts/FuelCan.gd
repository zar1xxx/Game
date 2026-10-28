extends Area2D
## Канистра с бензином — главный бонус игры.

@export var fuel_restore_amount: float = 28.0

var _t: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	_t = randf() * TAU


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if "car" in body and body.car.get("electric", false):
			var sc = body.get_node_or_null("scoreComponent")
			if sc and sc.has_method("add_bonus"):
				sc.add_bonus(15)
			Pickup.burst(self, Art.TEAL, "+15", "fuel")
			Missions.event("fuel")
			queue_free()
			return
		# «Копейка» выжимает из канистры больше
		var amount := fuel_restore_amount
		if "car" in body:
			amount *= float(body.car.get("fuel_bonus", 1.0))
		if body.has_method("add_fuel"):
			body.add_fuel(amount)
		Pickup.burst(self, Art.ORANGE, "+%d л" % int(amount), "fuel")
		Missions.event("fuel")
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _physics_process(_delta: float) -> void:
	Pickup.cleanup_if_behind(self)


func _draw() -> void:
	var bob := sin(_t * 3.0) * 3.0
	Pickup.draw_halo(self, Art.ORANGE, _t)
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	Art.rrect(self, Rect2(Vector2(-14, -16) + Art.SHADOW_OFFSET * 0.7, Vector2(28, 36)), Art.SHADOW, 6)
	Art.rrect(self, Rect2(-14, -16, 28, 36), Art.RED, 6, 2, Art.RED.darkened(0.45))
	# Ручка и горловина
	Art.rrect(self, Rect2(-10, -22, 13, 8), Art.RED.darkened(0.2), 3)
	draw_rect(Rect2(5, -22, 6, 7), Art.YELLOW)
	# Крест-выдавка
	draw_line(Vector2(-8, -8), Vector2(8, 14), Art.RED.lightened(0.25), 3.0)
	draw_line(Vector2(8, -8), Vector2(-8, 14), Art.RED.lightened(0.25), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
