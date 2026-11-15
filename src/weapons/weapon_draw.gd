class_name WeaponDraw
extends RefCounted
## Disegno provvisorio delle armi (forme semplici), usato sia in mano al
## personaggio sia a terra. Sarà sostituito da un'immagine per ogni arma:
## il punto di impugnatura (grip) è sempre l'inizio dell'arma, la punta
## (da cui esce il colpo) è a "length" pixel più avanti.

const OUTLINE := Color("1b1b2b")
const WOOD := Color("b98a55")


## grip = punto di impugnatura; dir = direzione in cui punta l'arma.
## side = da che parte guarda (per specchiarla); loaded = pronta a colpire.
static func draw_weapon(ci: CanvasItem, grip: Vector2, dir: Vector2, data: WeaponData, side := NAN, loaded := true) -> void:
	# Se si mira a sinistra l'arma si specchia, così non è mai a testa in giù.
	var ref := dir.x if is_nan(side) else side
	var flip := -1.0 if ref < 0.0 else 1.0
	ci.draw_set_transform(grip, dir.angle(), Vector2(1.0, flip))
	match data.look:
		WeaponData.Look.SWORD:
			_sword(ci, data)
		WeaponData.Look.KNIFE:
			_knife(ci, data)
		WeaponData.Look.AXE:
			_axe(ci, data)
		WeaponData.Look.SLING:
			_sling(ci, data)
		WeaponData.Look.CROSSBOW:
			_crossbow(ci, data, loaded)
		_:
			_gun(ci, data)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rettangolo con il bordo scuro.
static func _box(ci: CanvasItem, r: Rect2, fill: Color) -> void:
	ci.draw_rect(r, OUTLINE)
	ci.draw_rect(r.grow(-2.0), fill)


## Forma qualsiasi con il bordo scuro.
static func _shape(ci: CanvasItem, points: PackedVector2Array, fill: Color) -> void:
	ci.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, OUTLINE, 2.0, true)


static func _gun(ci: CanvasItem, data: WeaponData) -> void:
	var L := data.length
	var T := data.thickness
	# Canna / corpo
	ci.draw_rect(Rect2(0.0, -T / 2.0, L, T), OUTLINE)
	ci.draw_rect(Rect2(2.0, -T / 2.0 + 2.0, L - 4.0, T - 4.0), data.color)
	# Dettaglio colorato
	ci.draw_rect(Rect2(L * 0.35, -T / 2.0 + 2.0, L * 0.3, 3.0), data.accent)
	# Impugnatura (verso il basso)
	ci.draw_rect(Rect2(2.0, T / 2.0 - 2.0, 10.0, T * 0.9), OUTLINE)
	ci.draw_rect(Rect2(4.0, T / 2.0 - 2.0, 6.0, T * 0.9 - 2.0), data.color)
	# Le armi a due mani hanno un calcio dietro
	if data.family == WeaponData.Family.TWO_HAND:
		ci.draw_rect(Rect2(-14.0, -T / 2.0, 16.0, T), OUTLINE)
		ci.draw_rect(Rect2(-12.0, -T / 2.0 + 2.0, 12.0, T - 4.0), data.accent.darkened(0.3))


static func _sword(ci: CanvasItem, data: WeaponData) -> void:
	var L := data.length
	var T := data.thickness
	_box(ci, Rect2(-10.0, -5.0, 26.0, 10.0), data.accent) # manico
	_shape(ci, PackedVector2Array([Vector2(18, -T / 2.0), Vector2(L - 12.0, -T / 2.0), Vector2(L, 0),
		Vector2(L - 12.0, T / 2.0), Vector2(18, T / 2.0)]), data.color) # lama
	_box(ci, Rect2(12.0, -T, 8.0, T * 2.0), data.accent) # guardia


static func _knife(ci: CanvasItem, data: WeaponData) -> void:
	var L := data.length
	var T := data.thickness
	_box(ci, Rect2(-8.0, -5.0, 24.0, 10.0), data.accent)
	_shape(ci, PackedVector2Array([Vector2(14, -T / 2.0), Vector2(L - 8.0, -T / 2.0), Vector2(L, T / 2.0),
		Vector2(14, T / 2.0)]), data.color)


static func _axe(ci: CanvasItem, data: WeaponData) -> void:
	var L := data.length
	var T := data.thickness
	_box(ci, Rect2(-12.0, -5.0, L + 12.0, 10.0), data.accent) # manico lungo
	# Testa dell'ascia, in cima al manico, dal lato "alto".
	_shape(ci, PackedVector2Array([Vector2(L - 36.0, -4.0), Vector2(L - 46.0, -T * 2.0), Vector2(L - 20.0, -T * 2.6),
		Vector2(L + 4.0, -T * 2.0), Vector2(L, -4.0)]), data.color)


static func _sling(ci: CanvasItem, data: WeaponData) -> void:
	var L := data.length
	var fork := Vector2(L * 0.55, 0.0)
	_box(ci, Rect2(-8.0, -5.0, L * 0.55 + 10.0, 10.0), data.color) # manico
	for s in [-1.0, 1.0]:
		var tip := Vector2(L, s * 14.0)
		ci.draw_line(fork, tip, OUTLINE, 10.0, true)
		ci.draw_line(fork, tip, data.color, 6.0, true)
	ci.draw_line(Vector2(L, -14.0), Vector2(L, 14.0), data.accent, 3.0, true) # elastico


static func _crossbow(ci: CanvasItem, data: WeaponData, loaded: bool) -> void:
	var L := data.length
	var T := data.thickness
	_box(ci, Rect2(-16.0, -T / 2.0, L + 16.0, T), data.color) # calcio
	var bow_x := L - 12.0
	var half := 36.0
	ci.draw_line(Vector2(bow_x, -half), Vector2(bow_x, half), OUTLINE, 11.0, true)
	ci.draw_line(Vector2(bow_x, -half), Vector2(bow_x, half), data.accent, 7.0, true) # arco
	# Corda: tirata indietro se è carica, dritta se si sta ricaricando.
	var string_x := 10.0 if loaded else bow_x
	ci.draw_line(Vector2(bow_x, -half), Vector2(string_x, 0.0), Color.WHITE, 2.0, true)
	ci.draw_line(Vector2(bow_x, half), Vector2(string_x, 0.0), Color.WHITE, 2.0, true)
	if loaded: # la freccia c'è solo quando è carica
		ci.draw_line(Vector2(10.0, 0.0), Vector2(L + 10.0, 0.0), OUTLINE, 6.0, true)
		ci.draw_line(Vector2(10.0, 0.0), Vector2(L + 10.0, 0.0), Color("ffe9b0"), 3.0, true)
