class_name Fx
extends RefCounted
## Piccoli effetti visivi riutilizzabili (scintille, sbuffi di fumo).


## Scintille: quando un proiettile colpisce un muro o viene parato.
static func sparks(parent: Node, pos: Vector2, color: Color, amount := 10) -> void:
	_burst(parent, pos, color, amount, 0.25, 250.0, 650.0, 4.0, 8.0, Vector2(0, 900))


## Sbuffo di fumo: quando un personaggio muore.
static func puff(parent: Node, pos: Vector2, color: Color) -> void:
	_burst(parent, pos, color, 32, 0.8, 120.0, 340.0, 8.0, 16.0, Vector2(0, -80), 150.0)


static var _light_tex: Texture2D


## Macchia di luce tonda che sfuma verso il bordo (una sola, usata da tutte le luci).
static func light_texture() -> Texture2D:
	if _light_tex == null:
		var ramp := Gradient.new()
		ramp.set_color(0, Color.WHITE)
		ramp.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = ramp
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 256
		tex.height = 256
		_light_tex = tex
	return _light_tex


## Crea una luce tonda di raggio "radius" (pixel).
static func make_light(radius: float, color: Color, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius * 2.0 / 256.0
	l.color = color
	l.energy = energy
	return l


## Lampo di luce che si spegne da solo: nelle arene buie fa vedere per un attimo
## chi ha appena sparato o colpito, e cosa c'è lì intorno.
static func flash(parent: Node, pos: Vector2, color: Color, radius: float, time := 0.2) -> void:
	var l := make_light(radius, color, 1.8)
	l.position = pos
	l.add_to_group("round_temp")
	l.add_to_group("flashes")
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(time * 0.4) # resta pieno per un attimo, poi sfuma
	tw.tween_property(l, "energy", 0.0, time * 0.6)
	tw.finished.connect(l.queue_free)


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
