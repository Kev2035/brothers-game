class_name ChargeData
extends GunData
## Scheda delle armi "a carica" (fionda): tieni premuto per caricare, lasci per
## tirare. Più carichi, più il colpo parte veloce e quindi va lontano.
## La velocità a carica piena è "bullet_speed"; la caduta è "bullet_gravity".
## Mentre carichi si vede la linea tratteggiata della traiettoria.

@export_group("Carica")
@export var charge_time := 0.6 ## secondi per arrivare alla carica piena
@export var min_speed := 700.0 ## velocità del colpo senza carica (tasto appena toccato)
@export var show_trajectory := true ## linea tratteggiata mentre carichi
@export var preview_time := 1.3 ## quanti secondi di volo mostra la linea


## Velocità del colpo per una certa carica (0 = niente, 1 = piena).
func speed_for(charge: float) -> float:
	return lerpf(min_speed, bullet_speed, clampf(charge, 0.0, 1.0))


func tick(p: Player, delta: float, can_act: bool) -> void:
	if not can_act:
		p.cancel_charge() # scudo alzato: la carica si perde
		return
	if p.charge < 0.0:
		# Non sta caricando: una pressione fa partire la carica.
		if p.fire_queued > 0.0 and p.fire_cd <= 0.0:
			p.fire_queued = 0.0
			if p.attack_held():
				p.charge = 0.0
			else:
				# Tasto toccato e già lasciato (si sta "martellando"): parte subito
				# una pietra senza carica, così a raffica non si perde nessun colpo.
				fire(p, speed_for(0.0))
				return
	elif p.attack_held():
		p.charge = minf(p.charge + delta / charge_time, 1.0)
	else:
		# Tasto lasciato: parte il colpo.
		var speed := speed_for(p.charge)
		p.cancel_charge()
		fire(p, speed)
		return
	if p.charge >= 0.0 and show_trajectory:
		p.aim_preview = trajectory(p, speed_for(p.charge))


## I punti della traiettoria (rispetto alla posizione del personaggio):
## si ferma al primo muro, come farà il colpo vero.
func trajectory(p: Player, speed: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var start := p.shot_origin()
	var v := p.aim * speed
	var g := Vector2(0.0, bullet_gravity)
	var space := p.get_world_2d().direct_space_state
	var steps := 40
	var prev := start
	points.append(start - p.global_position)
	for i in range(1, steps + 1):
		var t := preview_time * float(i) / float(steps)
		var pos := start + v * t + 0.5 * g * t * t
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(prev, pos, Bullet.WORLD_MASK))
		if not hit.is_empty():
			points.append(hit.position - p.global_position)
			break
		points.append(pos - p.global_position)
		prev = pos
	return points


func bot_range() -> float:
	return 1500.0


func bot_keep_distance() -> float:
	return 500.0


func bot_aim_lift(dist: float) -> float:
	var speed := speed_for(0.9)
	return bullet_gravity * dist / (2.0 * speed * speed)


func bot_style() -> StringName:
	return &"charge"
