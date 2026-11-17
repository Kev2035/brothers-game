class_name ExcaliburData
extends MeleeData
## Scheda della spada di Re Artù (finale del bosco). È un'arma corpo a corpo
## come le altre, con in più:
## - ogni fendente lancia una LAMA VOLANTE nella direzione del colpo;
## - non si può lasciare col tasto, ha colpi infiniti;
## - dà uno scudo tutto intorno (i numeri sono nel gruppo "Regole speciali").
## Il colpo diretto uccide (danno 100); la lama volante fa meno male.

@export_group("Lama volante")
@export var blade_damage := 34.0 ## danno della lama volante (34 = 3 lame per uccidere)
@export var blade_speed := 1500.0 ## pixel al secondo
@export var blade_range := 1500.0 ## fin dove arriva
@export var blade_color := Color(1.0, 0.92, 0.55)


func after_swing(p: Player, _hit: bool) -> void:
	var b := Bullet.new()
	b.velocity = p.swing_dir * blade_speed
	b.damage = blade_damage
	b.shooter = p
	b.max_distance = blade_range
	b.color = blade_color
	b.blade = true
	# Chi ha già preso il fendente non prende anche la lama dello stesso colpo.
	b.ignore = p.last_melee_hits.duplicate()
	b.global_position = p.shot_origin()
	p.get_parent().add_child(b)


func bot_range() -> float:
	return blade_range * 0.6
