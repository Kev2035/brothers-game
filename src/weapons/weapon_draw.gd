class_name WeaponDraw
extends RefCounted
## Disegno provvisorio delle armi (forme semplici), usato sia in mano al
## personaggio sia a terra. Sarà sostituito da un'immagine per ogni arma:
## il punto di impugnatura (grip) è sempre l'inizio dell'arma, la bocca
## (da cui esce il colpo) è a "length" pixel più avanti.

const OUTLINE := Color("1b1b2b")


## grip = punto di impugnatura; dir = direzione in cui punta l'arma.
static func draw_weapon(ci: CanvasItem, grip: Vector2, dir: Vector2, data: WeaponData) -> void:
	var angle := dir.angle()
	# Se si mira a sinistra l'arma si specchia, così non è mai a testa in giù.
	var flip := -1.0 if dir.x < 0.0 else 1.0
	ci.draw_set_transform(grip, angle, Vector2(1.0, flip))
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
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
