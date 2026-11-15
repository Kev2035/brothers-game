class_name MeleeData
extends WeaponData
## Scheda delle armi corpo a corpo (spada di legno, coltello, ascia).
## Funzionano come il pugno: il colpo è istantaneo quando premi, nella direzione
## di mira; l'animazione del fendente è solo grafica. Lo scudo le para.
## Cambiano tre cose: danno, portata e tempo tra un colpo e l'altro.

@export_group("Fendente")
@export var reach := 170.0 ## portata (pixel dal centro del corpo; il pugno arriva a 115)
@export var cone_deg := 50.0 ## quanto può essere "storta" la mira e colpire lo stesso
@export var swing_time := 0.14 ## durata dell'animazione del fendente (solo grafica)
@export var swing_arc_deg := 110.0 ## ampiezza del movimento dell'arma (solo grafica)


func tick(p: Player, _delta: float, can_act: bool) -> void:
	if can_act and p.fire_queued > 0.0 and p.fire_cd <= 0.0:
		p.fire_cd = fire_interval
		p.fire_queued = 0.0
		p.swing_t = 0.0
		p.swing_dir = p.aim
		if p.melee_hit(reach, cone_deg, damage):
			p.use_ammo() # conta solo se "ammo" è più di 0 (armi che si consumano)


func _swinging(p: Player) -> bool:
	return p.swing_t >= 0.0 and p.swing_t <= swing_time


## Durante il fendente l'arma ruota dall'alto verso il basso.
func held_direction(p: Player) -> Vector2:
	if not _swinging(p):
		return p.aim
	var k := p.swing_t / swing_time
	var side := 1.0 if p.swing_dir.x >= 0.0 else -1.0
	return p.swing_dir.rotated(deg_to_rad(swing_arc_deg) * (k - 0.5) * side)


func held_side(p: Player) -> float:
	return p.swing_dir.x if _swinging(p) else p.aim.x


func bot_range() -> float:
	return reach + 20.0
