class_name GunData
extends WeaponData
## Scheda delle armi che lanciano proiettili: pistola, mitra, fucile a pompa,
## balestra. (La fionda usa ChargeData, che parte da questa.)

@export_group("Sparo")
@export var pellets := 1 ## proiettili per colpo (il fucile a pompa ne spara tanti)
@export var spread_deg := 0.0 ## quanto si allargano i colpi (gradi)
@export var automatic := false ## true = tieni premuto e spara a raffica
@export var bullet_speed := 2500.0 ## pixel al secondo
@export var bullet_range := 2500.0 ## distanza massima percorsa da un proiettile
@export var speed_jitter := 0.05 ## piccola differenza a caso di velocità tra i proiettili (0 = nessuna)
@export var bullet_gravity := 0.0 ## quanto il proiettile cade (0 = va dritto; la pietra della fionda cade)
@export var bullet_radius := 0.0 ## 0 = si disegna come una scia; più di 0 = una palla (pietra)
@export var bullet_color := Color("ffe08a")
@export var muzzle_flash := true ## lampo alla bocca dell'arma quando spara

@export_group("Rinculo")
@export var recoil := 100.0 ## spinta all'indietro su chi spara, a ogni colpo
@export var recoil_air_mult := 1.0 ## in aria il rinculo pesa di più (es. 1.5)


func tick(p: Player, _delta: float, can_act: bool) -> void:
	# Le automatiche sparano tenendo premuto, le altre a ogni pressione.
	var wants := p.attack_held() if automatic else p.fire_queued > 0.0
	if wants and can_act and p.fire_cd <= 0.0:
		fire(p, bullet_speed)


## Spara un colpo: proiettili, rinculo su chi spara, munizioni.
func fire(p: Player, speed: float) -> void:
	p.fire_cd = fire_interval
	p.fire_queued = 0.0
	if muzzle_flash:
		p.muzzle_flash = 0.06
	var muzzle := p.shot_origin()
	p.night_flash(340.0, Color(1.0, 0.9, 0.65), 0.45) # al buio lo sparo fa vedere chi ha sparato
	for i in pellets:
		var spread := deg_to_rad(randf_range(-spread_deg, spread_deg) / 2.0)
		var b := Bullet.new()
		b.velocity = p.aim.rotated(spread) * speed * randf_range(1.0 - speed_jitter, 1.0 + speed_jitter)
		b.damage = damage
		b.shooter = p
		b.max_distance = bullet_range
		b.gravity = bullet_gravity
		b.radius = bullet_radius
		b.color = bullet_color
		b.global_position = muzzle
		p.get_parent().add_child(b)
	# Rinculo: spinge chi spara nella direzione opposta alla mira.
	var push := recoil * (1.0 if p.is_on_floor() else recoil_air_mult)
	if push > 0.0:
		# Sparando verso il basso mentre cadi, prima si ferma la caduta: così il
		# "salto col rinculo" è sempre uguale, qualunque sia la velocità di caduta.
		if p.aim.y > 0.5 and p.velocity.y > 0.0:
			p.velocity.y = 0.0
		p.velocity -= p.aim * push
	p.use_ammo()


func bot_range() -> float:
	return bullet_range * 0.9


func bot_keep_distance() -> float:
	return 250.0 if bullet_range < 1000.0 else 650.0


func bot_style() -> StringName:
	return &"hold" if automatic else &"tap"
