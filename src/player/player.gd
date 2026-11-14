class_name Player
extends CharacterBody2D
## Personaggio del prototipo: movimento arcade veloce, mira a 360° e pugno
## nella direzione di mira, con contraccolpo.
## La grafica per ora è fatta di cerchi disegnati da Godot (corpo, mani, piedi).
## Tutti i numeri con @export si possono cambiare dall'Inspector di Godot
## mentre si prova, senza toccare il codice.

signal died(player: Player, cause: String) ## cause: "fall" (caduto) o "hp" (vita finita)
signal damaged(victim: Player, attacker: Player, amount: float)

@export_group("Vita")
@export var max_health := 100.0
@export var punch_damage := 10.0 ## vita tolta da un pugno (10 = servono 10 pugni)

@export_group("Corsa")
@export var run_speed := 700.0 ## velocità massima (pixel al secondo)
@export var ground_accel := 9000.0 ## quanto in fretta parte
@export var ground_decel := 10000.0 ## quanto in fretta si ferma
@export var air_accel := 6000.0 ## controllo in aria
@export var air_decel := 2500.0

@export_group("Salto")
@export var jump_height := 300.0 ## altezza del salto (pixel; il personaggio è alto ~90)
@export var time_to_apex := 0.36 ## secondi per arrivare in cima: meno = più scattante
@export var fall_gravity_mult := 1.7 ## la discesa è più rapida della salita
@export var double_jump_height := 220.0
@export var max_air_jumps := 1 ## 1 = doppio salto
@export var jump_cut := 0.45 ## lasci il tasto presto -> salto più basso
@export var max_fall_speed := 2000.0
@export var fast_fall_speed := 2800.0 ## tenendo Giù in aria
@export var coyote_time := 0.1 ## puoi ancora saltare appena caduto dal bordo
@export var jump_buffer := 0.12 ## premi un attimo prima di atterrare e salta lo stesso

@export_group("Salto dai muri")
@export var wall_jump_height := 150.0 ## salto dal muro senza SU: ti lanci via dal muro
@export var wall_jump_push := 650.0 ## quanto ti spinge via dal muro
@export var wall_climb_height := 130.0 ## tenendo SU (scalata): quanto sali a ogni salto...
@export var wall_climb_push := 400.0 ## ...e quanto ti stacchi: più è alto, più la scalata è faticosa
@export var wall_jump_lock := 0.18 ## secondi in cui non puoi subito tornare verso il muro
@export var wall_detect := 6.0 ## distanza (pixel) entro cui sei "attaccato" al muro

@export_group("Scudo")
@export var shield_duration := 0.45 ## secondi prima che l'arco sparisca del tutto
@export var shield_max_half_angle := 90.0 ## apertura iniziale: 90 = semicerchio
@export var shield_radius := 64.0
@export var shield_follows_aim := false ## true = lo scudo ruota mentre muovi la mira
@export var block_pushback := 0.0 ## spinta quando pari un colpo (0 = nessuna)

@export_group("Mira")
@export var aim_deadzone := 0.35 ## levetta destra: sotto questo valore non mira

@export_group("Pugno e contraccolpo")
@export var punch_cooldown := 0.11 ## tempo minimo tra due pugni (0.11 = circa 9 pugni al secondo)
@export var punch_out_time := 0.035 ## quanto ci mette la mano ad andare avanti
@export var punch_back_time := 0.07 ## quanto ci mette a tornare indietro
@export var punch_buffer := 0.1 ## un pugno premuto troppo presto parte appena possibile
@export var punch_range := 115.0
@export var punch_cone_deg := 45.0 ## quanto può essere "storta" la mira e colpire lo stesso
@export var knockback_power := 0.0 ## spinta subita da chi è colpito (0 = i colpi non spostano)
@export var knockback_lift := 0.0 ## spinta extra verso l'alto per chi è colpito
@export var hitstun := 0.0 ## secondi senza controllo per chi è colpito (0 = nessuno)
@export var hit_flash_time := 0.15 ## quanto dura il lampo rosso quando vieni colpito
@export var pogo_bounce := 1000.0 ## colpo verso il basso in aria: rimbalzi sopra l'avversario
@export var pogo_refreshes_double_jump := true

const LAYER_SOLID := 1
const LAYER_ONE_WAY := 2
const OUTLINE := Color("1b1b2b")
const BODY := Vector2(0, -52) ## centro del corpo rispetto ai piedi
const BODY_RADIUS := 32.0

## Modi di mirare: "mouse" (tastiera+mouse), "stick" (joystick), "keys" (frecce).
var aim_mode := "keys"
var device := -1
var slot := 0
var color := Color.WHITE
var alive := true
var death_y := 1250.0
var side_limits := Vector2(-300, 2220)
var facing := 1.0
var aim := Vector2.RIGHT ## direzione di mira (lunghezza 1)

var _gravity := 0.0
var _jump_velocity := 0.0
var _double_jump_velocity := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _air_jumps := 0
var _jump_held_cut := false
var _drop_timer := 0.0
var _hitstun_timer := 0.0
var _punch_cd := 0.0
var _punch_queued := 0.0
var _punch_t := -1.0 ## tempo dall'inizio del pugno (-1 = nessun pugno in corso)
var _punch_dir := Vector2.RIGHT
var _flash := 0.0
var _run_phase := 0.0
var _squash := 0.0
var _was_on_floor := false
var _on_one_way := false
var _free_aim := false ## true se la mira arriva da mouse o levetta destra
var _wall_lock := 0.0
var _shield_t := -1.0 ## tempo da quando hai alzato lo scudo (-1 = niente scudo)
var _shield_dir := Vector2.RIGHT
var _shield_flash := 0.0
var health := 100.0
var last_attacker: Player = null ## chi ti ha colpito per ultimo (per sapere chi ti ha fatto cadere)
var _last_attacker_timer := 0.0
## Se non è null, il personaggio è comandato dal computer (manichino d'allenamento).
var bot: DummyBrain = null


func _ready() -> void:
	add_to_group("players")
	_recompute_jump()


## Ricava gravità e velocità di salto dall'altezza e dal tempo voluti
## (formula consigliata dalla skill "platformer").
func _recompute_jump() -> void:
	_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_velocity = 2.0 * jump_height / time_to_apex
	_double_jump_velocity = sqrt(2.0 * _gravity * double_jump_height)


func act(a: String) -> StringName:
	return InputSetup.action(slot, a)


# Lettura dei comandi: da tastiera/joystick, oppure dal "cervello" del manichino.
func _axis() -> float:
	return bot.move_x if bot else Input.get_axis(act("left"), act("right"))


func _vector() -> Vector2:
	if bot:
		return Vector2(bot.move_x, 0.0)
	return Input.get_vector(act("left"), act("right"), act("up"), act("down"))


func _held(a: String) -> bool:
	return bot.is_held(a) if bot else Input.is_action_pressed(act(a))


func _just(a: String) -> bool:
	return bot.is_just(a) if bot else Input.is_action_just_pressed(act(a))


func _physics_process(delta: float) -> void:
	_recompute_jump() # così i cambi fatti dall'Inspector valgono subito
	_tick_timers(delta)
	if bot:
		bot.think(self, delta)

	var stunned := _hitstun_timer > 0.0
	var input_x := 0.0 if stunned else _axis()
	var down_held := not stunned and _held("down")
	var on_floor := is_on_floor()

	if on_floor:
		_coyote = coyote_time
		_air_jumps = max_air_jumps
	if not stunned and _just("jump"):
		_buffer = jump_buffer

	# Scendere da una piattaforma attraversabile: Giù + Salto.
	if on_floor and _on_one_way and down_held and _buffer > 0.0:
		_buffer = 0.0
		_drop_timer = 0.22
		set_collision_mask_value(LAYER_ONE_WAY, false)
		position.y += 2.0

	# Salto, in ordine di priorità: da terra (con coyote time e buffer),
	# poi dal muro, poi doppio salto in aria.
	var jump_now := not stunned and _just("jump")
	var wall_side := 0 if on_floor else _wall_side()
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -_jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		_jump_held_cut = true
		_squash = -0.6
	elif jump_now and _coyote <= 0.0 and wall_side != 0:
		var climbing := _held("up")
		var h := wall_climb_height if climbing else wall_jump_height
		velocity.y = -sqrt(2.0 * _gravity * h)
		velocity.x = -float(wall_side) * (wall_climb_push if climbing else wall_jump_push)
		_wall_lock = wall_jump_lock
		facing = -float(wall_side)
		_buffer = 0.0
		_jump_held_cut = false # dal muro il salto ha sempre la stessa altezza, anche toccando appena il tasto
		_squash = -0.5
	elif jump_now and _coyote <= 0.0 and _air_jumps > 0 and _drop_timer <= 0.0:
		velocity.y = -_double_jump_velocity
		_air_jumps -= 1
		_buffer = 0.0
		_jump_held_cut = true
		_squash = -0.5

	# Salto variabile: se lasci il tasto mentre sali, il salto si accorcia.
	if _jump_held_cut and velocity.y < 0.0 and not _held("jump"):
		velocity.y *= jump_cut
		_jump_held_cut = false
	if velocity.y >= 0.0:
		_jump_held_cut = false

	# Gravità: più forte in discesa, e ancora di più tenendo Giù.
	if not on_floor:
		var g := _gravity if velocity.y < 0.0 else _gravity * fall_gravity_mult
		var limit := max_fall_speed
		if down_held and velocity.y > 0.0:
			g *= 1.5
			limit = fast_fall_speed
		velocity.y = minf(velocity.y + g * delta, limit)

	# Movimento orizzontale con accelerazione (scattante ma non a scatti).
	var accel: float
	if stunned:
		accel = 900.0 # durante il contraccolpo si scivola indietro
	elif _wall_lock > 0.0:
		accel = 1200.0 # appena saltato dal muro: poco controllo, vieni spinto via
	elif on_floor:
		accel = ground_accel if absf(input_x) > 0.01 else ground_decel
	else:
		accel = air_accel if absf(input_x) > 0.01 else air_decel
	velocity.x = move_toward(velocity.x, input_x * run_speed, accel * delta)

	# Mira e verso in cui guarda il personaggio.
	_update_aim()
	if _free_aim and absf(aim.x) > 0.1:
		facing = signf(aim.x) # con mouse o levetta destra guardi dove miri
	elif absf(input_x) > 0.01 and not stunned:
		facing = signf(input_x)
	if not _free_aim and absf(aim.y) < 0.01:
		aim = Vector2(facing, 0.0)

	# Scudo: ogni pressione lo rigenera, nella direzione in cui stai mirando.
	if not stunned and _just("shield"):
		_shield_t = 0.0
		_shield_dir = aim
		_punch_queued = 0.0
	if shield_follows_aim and is_shielding():
		_shield_dir = aim

	# Pugno: si può "martellare" il tasto, i pugni partono appena possibile.
	# O scudo o attacco: con lo scudo alzato non si colpisce.
	if not stunned and not is_shielding() and _just("attack"):
		_punch_queued = punch_buffer
	if _punch_queued > 0.0 and _punch_cd <= 0.0 and not stunned and not is_shielding():
		_punch()

	move_and_slide()
	_read_floor()

	if is_on_floor() and not _was_on_floor:
		_squash = 1.0 # atterraggio: il pupazzetto si schiaccia un attimo
	_was_on_floor = is_on_floor()

	_run_phase += absf(velocity.x) / run_speed * delta * 14.0
	queue_redraw()

	if global_position.y > death_y or global_position.x < side_limits.x or global_position.x > side_limits.y:
		_die("fall")


## Calcola la direzione di mira a seconda del dispositivo.
func _update_aim() -> void:
	var dir := Vector2.ZERO
	_free_aim = false
	match aim_mode:
		"bot":
			dir = bot.aim if bot else Vector2.ZERO
			_free_aim = true
		"mouse":
			dir = get_global_mouse_position() - (global_position + BODY)
			_free_aim = dir.length() > 1.0
		"stick":
			var right_stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
			if right_stick.length() > aim_deadzone:
				dir = right_stick
				_free_aim = true
			else:
				var left_stick := _vector()
				if left_stick.length() > 0.5:
					dir = left_stick
		_:
			dir = _vector()
	if dir.length() > 0.1:
		aim = dir.normalized()
	else:
		aim = Vector2(facing, 0.0)


func _tick_timers(delta: float) -> void:
	_coyote -= delta
	_buffer -= delta
	_hitstun_timer -= delta
	_punch_cd -= delta
	_punch_queued -= delta
	if _punch_t >= 0.0:
		_punch_t += delta
		if _punch_t > punch_out_time + punch_back_time:
			_punch_t = -1.0
	_wall_lock -= delta
	_last_attacker_timer -= delta
	if _last_attacker_timer <= 0.0:
		last_attacker = null
	if _shield_t >= 0.0:
		_shield_t += delta
		if _shield_t > shield_duration:
			_shield_t = -1.0
	_shield_flash = maxf(_shield_flash - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_squash = move_toward(_squash, 0.0, delta * 6.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(LAYER_ONE_WAY, true)


## C'è un muro attaccato a me? -1 = a sinistra, 1 = a destra, 0 = nessuno.
func _wall_side() -> int:
	for side in [-1, 1]:
		var c := move_and_collide(Vector2(side * wall_detect, 0.0), true)
		if c and not (c.get_collider() as Node).is_in_group("bounds"):
			return side # i bordi invisibili dell'arena non contano come muri
	return 0


func is_shielding() -> bool:
	return _shield_t >= 0.0


## Apertura attuale dello scudo (metà dell'arco, in gradi): si restringe fino a 0.
func shield_half_angle() -> float:
	if not is_shielding():
		return 0.0
	return shield_max_half_angle * (1.0 - _shield_t / shield_duration)


func _read_floor() -> void:
	_on_one_way = false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if c.get_normal().y < -0.7 and other is Node and (other as Node).is_in_group("one_way"):
			_on_one_way = true


## Il colpo è istantaneo nel momento in cui premi: l'animazione è solo grafica.
func _punch() -> void:
	_punch_cd = punch_cooldown
	_punch_queued = 0.0
	_punch_t = 0.0
	_punch_dir = aim
	var center := global_position + BODY
	var hit_someone := false
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or p == self or not p.alive:
			continue
		var d := (p.global_position + BODY) - center
		var in_reach := d.length() < punch_range + BODY_RADIUS
		var in_cone := absf(rad_to_deg(aim.angle_to(d))) < punch_cone_deg
		if in_reach and (in_cone or d.length() < BODY_RADIUS * 1.5):
			if p.take_hit(aim, center, punch_damage, self):
				hit_someone = true
	# Pugno verso il basso in aria che colpisce: rimbalzi sopra l'avversario.
	if hit_someone and aim.y > 0.6 and not is_on_floor():
		velocity.y = -pogo_bounce
		if pogo_refreshes_double_jump:
			_air_jumps = max_air_jumps


## Chiamato da chi ti colpisce. from_pos = da dove arriva il colpo.
## Se lo scudo copre quella direzione il colpo è parato (ritorna false),
## altrimenti spinta nella direzione del colpo e un attimo senza controllo (ritorna true).
## Servirà uguale per i proiettili: from_pos sarà il punto da cui arriva la pallottola.
func take_hit(direction: Vector2, from_pos: Vector2, damage := 0.0, attacker: Player = null) -> bool:
	if not alive:
		return false
	if is_shielding():
		var incoming := from_pos - (global_position + BODY)
		if absf(rad_to_deg(_shield_dir.angle_to(incoming))) <= shield_half_angle():
			_shield_flash = 0.12
			velocity += direction * block_pushback
			return false
	if knockback_power > 0.0 or knockback_lift > 0.0:
		velocity = direction * knockback_power + Vector2(0.0, -knockback_lift)
	_hitstun_timer = hitstun
	_flash = hit_flash_time
	_jump_held_cut = false
	_shield_t = -1.0 # se ti colpiscono, lo scudo cade
	if attacker:
		last_attacker = attacker
		_last_attacker_timer = 4.0
	if damage > 0.0:
		var real_damage := minf(damage, health) # oltre la vita rimasta non conta
		health -= real_damage
		damaged.emit(self, attacker, real_damage)
		if health <= 0.0:
			_die("hp")
			return true
	if absf(direction.x) > 0.1:
		facing = -signf(direction.x)
	return true


func _die(cause: String) -> void:
	if not alive:
		return
	alive = false
	visible = false
	set_physics_process(false)
	died.emit(self, cause)


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_hitstun_timer = 0.0
	_drop_timer = 0.0
	_punch_t = -1.0
	_shield_t = -1.0
	_wall_lock = 0.0
	health = max_health
	last_attacker = null
	_last_attacker_timer = 0.0
	set_collision_mask_value(LAYER_ONE_WAY, true)
	alive = true
	visible = true
	set_physics_process(true)


## Quanto è allungata la mano (0 = a riposo, 1 = tutta fuori).
func _punch_extension() -> float:
	if _punch_t < 0.0:
		return 0.0
	if _punch_t < punch_out_time:
		return _punch_t / punch_out_time
	var back := (_punch_t - punch_out_time) / punch_back_time
	return 1.0 - ease(clampf(back, 0.0, 1.0), 0.5)


# ---------------------------------------------------------------------------
# Disegno del pupazzetto: corpo tondo, occhi, mani e piedi staccati.
# Sarà sostituito dalla grafica vera senza cambiare il movimento.
# ---------------------------------------------------------------------------
func _draw() -> void:
	var sy := 1.0 - _squash * 0.22
	var sx := 1.0 + _squash * 0.18
	# Colpito: il pupazzetto trema (solo il disegno, non si sposta davvero).
	var shake := Vector2.ZERO
	if _flash > 0.0:
		shake = Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
	draw_set_transform(shake, 0.0, Vector2(sx, sy))

	# Colpito: diventa tutto rosso (il personaggio rosso diventa bianco, sennò non si vedrebbe).
	var hit_color := Color.WHITE if color.r > 0.8 and color.g < 0.45 else Color(1.0, 0.12, 0.12)
	var col := hit_color if _flash > 0.0 else color
	var dark := col.darkened(0.3)
	var grounded := is_on_floor()
	var running := grounded and absf(velocity.x) > 40.0
	var bob := sin(_run_phase * 2.0) * 3.0 if running else 0.0
	var body := BODY + Vector2(0, bob)

	# Mano dietro
	_ball(body + Vector2(-facing * 30.0, 12.0), 9.0, dark)

	# Piedi
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var f := Vector2(side * 14.0, -10.0)
		if running:
			var ph := _run_phase + float(i) * PI
			f.x += sin(ph) * 16.0 * facing
			f.y -= maxf(0.0, cos(ph)) * 10.0
		elif not grounded:
			f = Vector2(side * 16.0, -18.0)
		_ball(f, 11.0, dark)

	# Corpo
	_ball(body, BODY_RADIUS, col)

	# Occhi (guardano verso la mira)
	for e in [-1.0, 1.0]:
		var eye: Vector2 = body + Vector2(facing * 11.0 + e * 9.0, -6.0)
		draw_circle(eye, 6.0, Color.WHITE)
		draw_circle(eye + aim * 2.5, 3.0, OUTLINE)

	# Indicatore di mira (puntino davanti al personaggio)
	var marker := Color(1, 1, 1, 0.55)
	draw_circle(body + aim * 66.0, 5.0, marker)

	# Mano davanti: a riposo sta nella direzione di mira, col pugno si allunga.
	var ext := _punch_extension()
	var dir := _punch_dir if _punch_t >= 0.0 else aim
	var hand := body + dir * (38.0 + 55.0 * ext)
	_ball(hand, 9.0 + 2.0 * ext, col)

	# Scudo: arco davanti al personaggio che si chiude col passare del tempo.
	if is_shielding():
		var half := deg_to_rad(shield_half_angle())
		var a := _shield_dir.angle()
		var sc := Color.WHITE if _shield_flash > 0.0 else Color(0.55, 0.9, 1.0, 0.9)
		draw_arc(body, shield_radius, a - half, a + half, 32, sc, 8.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# La vita non si mostra di proposito: non si sa mai qual è l'ultimo colpo.


func _ball(center: Vector2, radius: float, fill: Color) -> void:
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 40, OUTLINE, 3.0, true)
