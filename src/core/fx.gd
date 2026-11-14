class_name Fx
extends RefCounted
## Piccoli effetti visivi riutilizzabili (scintille, sbuffi di fumo).


## Scintille: quando un proiettile colpisce un muro o viene parato.
static func sparks(parent: Node, pos: Vector2, color: Color, amount := 10) -> void:
	_burst(parent, pos, color, amount, 0.25, 250.0, 650.0, 4.0, 8.0, Vector2(0, 900))


## Sbuffo di fumo: quando un personaggio muore.
static func puff(parent: Node, pos: Vector2, color: Color) -> void:
	_burst(parent, pos, color, 32, 0.8, 120.0, 340.0, 8.0, 16.0, Vector2(0, -80), 150.0)


static func _burst(parent: Node, pos: Vector2, color: Color, amount: int, life: float,
		vmin: float, vmax: float, smin: float, smax: float, gravity: Vector2, damping := 0.0) -> void:
	var cp := CPUParticles2D.new()
	cp.one_shot = true
	cp.amount = amount
	cp.lifetime = life
	cp.explosiveness = 0.95
	cp.spread = 180.0
	cp.initial_velocity_min = vmin
	cp.initial_velocity_max = vmax
	cp.gravity = gravity
	cp.damping_min = damping
	cp.damping_max = damping * 1.4
	cp.scale_amount_min = smin
	cp.scale_amount_max = smax
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	cp.color_ramp = ramp
	cp.position = pos
	cp.add_to_group("round_temp")
	parent.add_child(cp)
	cp.emitting = true
	cp.finished.connect(cp.queue_free)
