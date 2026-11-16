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
@export var wall_jump_height := 210.0 ## salto dal muro normale: ti lanci verso l'altra parete, salendo
@export var wall_jump_push := 650.0 ## quanto ti spinge via dal muro
@export var wall_climb_height := 130.0 ## tenendo la direzione VERSO il muro (scalata): quanto sali a ogni salto...
@export var wall_climb_push := 400.0 ## ...e quanto ti stacchi: più è alto, più la scalata è faticosa
@export var wall_jump_lock := 0.18 ## secondi in cui non puoi subito tornare verso il muro
@export var wall_detect := 28.0 ## distanza (pixel) entro cui il muro "vale": non serve toccarlo al millimetro
@export var wall_slide_speed := 500.0 ## spingendo contro un muro scivoli giù al massimo a questa velocità (0 = niente)

@export_group("Piattaforme scivolose")
@export var slide_accel := 9000.0 ## quanto in fretta si prende velocità su una piattaforma obliqua
@export var slide_control := 0.3 ## quanto conta la direzione premuta: 0.3 = in discesa +30%, in salita -30%

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
const LAYER_PLAYERS := 3 ## i personaggi sono "solidi" tra loro: non ci si passa attraverso
const BODY_SIZE := Vector2(48, 88) ## ingombro del personaggio (come la forma di collisione)
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
## true mentre uno scivolo a spirale mi sta portando giù: non comando io e non posso essere colpito.
var riding := false
## true quando sono dentro un nascondiglio (cespuglio, zona di buio): non mi si disegna affatto.
var concealed := false
var _slide_dir := Vector2.ZERO ## se sto su una piattaforma scivolosa: direzione "in discesa" (sennò zero)
var _slide_speed := 0.0
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
## Arma in mano (null = mani nude: si tirano pugni).
var weapon: WeaponData = null
var ammo := 0
# Stato dell'arma in mano: lo leggono e lo cambiano le schede delle armi (WeaponData.tick).
var fire_cd := 0.0 ## tempo che manca al prossimo colpo
var fire_queued := 0.0 ## un attacco premuto troppo presto parte appena possibile
var muzzle_flash := 0.0
var charge := -1.0 ## armi a carica: da 0 a 1 mentre carichi, -1 = non stai caricando
var swing_t := -1.0 ## armi corpo a corpo: tempo dall'inizio del fendente (-1 = nessuno)
var swing_dir := Vector2.RIGHT
var aim_preview := PackedVector2Array() ## punti della linea tratteggiata (fionda)


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
	if riding:
		return # mi sta muovendo lo scivolo
	_recompute_jump() # così i cambi fatti dall'Inspector valgono subito
	_tick_timers(delta)
	if bot:
		bot.think(self, delta)

	_unstick_from_players()
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
	# Stai per toccare un muro? Allora il salto premuto un attimo prima non si spreca
	# come doppio salto: aspetta il muro e diventa un salto dal muro.
	var wall_soon := not on_floor and wall_side == 0 and _wall_ahead()
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -_jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		_jump_held_cut = true
		_squash = -0.6
	elif _buffer > 0.0 and _coyote <= 0.0 and wall_side != 0:
		# Spingi VERSO il muro = scalata a piccoli salti sullo stesso muro.
		# Altrimenti = salto forte verso la parete di fronte.
		var climbing := absf(input_x) > 0.3 and signf(input_x) == float(wall_side)
		var h := wall_climb_height if climbing else wall_jump_height
		velocity.y = -sqrt(2.0 * _gravity * h)
		velocity.x = -float(wall_side) * (wall_climb_push if climbing else wall_jump_push)
		_wall_lock = wall_jump_lock
		facing = -float(wall_side)
		_buffer = 0.0
		_jump_held_cut = false # dal muro il salto ha sempre la stessa altezza, anche toccando appena il tasto
		_squash = -0.5
	elif jump_now and _coyote <= 0.0 and _air_jumps > 0 and _drop_timer <= 0.0 and not wall_soon:
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
		# Scivolata sul muro: spingendo contro una parete si scende piano,
		# così c'è il tempo di premere il salto.
		if wall_slide_speed > 0.0 and wall_side != 0 and is_on_wall() and not down_held \
				and absf(input_x) > 0.3 and signf(input_x) == float(wall_side):
			velocity.y = minf(velocity.y, wall_slide_speed)

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
	if on_floor and _slide_dir != Vector2.ZERO:
		# Piattaforma obliqua e scivolosa: si va giù per forza. Spingere in discesa
		# accelera un po', spingere in salita frena un po' (ma non ci si ferma).
		var push := 1.0 + slide_control * input_x * signf(_slide_dir.x)
		var target := _slide_dir * _slide_speed * push
		velocity.x = move_toward(velocity.x, target.x, slide_accel * delta)
		if velocity.y >= 0.0: # se sto saltando, il salto non si tocca
			velocity.y = absf(velocity.x) * _slide_dir.y / maxf(absf(_slide_dir.x), 0.01)
	else:
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

	# Lasciare l'arma.
	if weapon != null and _just("drop"):
		throw_down_weapon()

	# Attacco. O scudo o attacco: con lo scudo alzato non si colpisce.
	if weapon != null:
		# Con un'arma: cosa succede lo decide la scheda dell'arma (sparo, fendente, carica...).
		var can_act := not stunned and not is_shielding()
		if can_act and _just("attack"):
			fire_queued = punch_buffer
		weapon.tick(self, delta, can_act)
	else:
		# A mani nude: pugni. Si può "martellare" il tasto, partono appena possibile.
		if not stunned and not is_shielding() and _just("attack"):
			_punch_queued = punch_buffer
		if _punch_queued > 0.0 and _punch_cd <= 0.0 and not stunned and not is_shielding():
			_punch()

	move_and_slide()
	_read_floor()
	_update_concealed()

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
	fire_cd -= delta
	fire_queued -= delta
	muzzle_flash = maxf(muzzle_flash - delta, 0.0)
	if swing_t >= 0.0:
		swing_t += delta
		if swing_t > 0.6:
			swing_t = -1.0
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
		if c and _is_wall(c.get_collider()):
			return side
	return 0


## Un muro da cui si può saltare? I bordi invisibili dell'arena e gli altri
## personaggi non contano.
func _is_wall(collider: Object) -> bool:
	return collider is Node and not (collider as Node).is_in_group("bounds") and not collider is Player


## I personaggi sono solidi tra loro. Se per qualche motivo due si ritrovano uno
## dentro l'altro (per esempio ricomparendo nello stesso punto), si allontanano di lato.
func _unstick_from_players() -> void:
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or p == self or not p.alive:
			continue
		var d := global_position - p.global_position
		if absf(d.x) < BODY_SIZE.x - 4.0 and absf(d.y) < BODY_SIZE.y - 4.0:
			var away := signf(d.x) if absf(d.x) > 0.5 else (1.0 if slot > p.slot else -1.0)
			global_position.x += away * 6.0


## Acceso = gli altri personaggi mi urtano; spento quando sono morto o nascosto.
func set_solid(on: bool) -> void:
	set_collision_layer_value(LAYER_PLAYERS, on)


## Sto volando verso un muro e lo toccherò entro il tempo del "buffer" del salto?
func _wall_ahead() -> bool:
	if absf(velocity.x) < 50.0:
		return false
	var c := move_and_collide(Vector2(velocity.x * jump_buffer, 0.0), true)
	return c != null and _is_wall(c.get_collider()) and absf(c.get_normal().x) > 0.7


func is_shielding() -> bool:
	return _shield_t >= 0.0


## Apertura attuale dello scudo (metà dell'arco, in gradi): si restringe fino a 0.
func shield_half_angle() -> float:
	if not is_shielding():
		return 0.0
	return shield_max_half_angle * (1.0 - _shield_t / shield_duration)


func _read_floor() -> void:
	_on_one_way = false
	# Mentre si scorre lungo un pavimento Godot non segnala l'urto a ogni fotogramma:
	# per questo la scivolata "si ricorda" finché si resta a terra e non si tocca un altro pavimento.
	if not is_on_floor():
		_slide_dir = Vector2.ZERO
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		var n := c.get_normal()
		if n.y >= -0.7:
			continue # non è un pavimento
		if other is Node and (other as Node).is_in_group("one_way"):
			_on_one_way = true
		if other is SlidePlatform and is_on_floor():
			# La direzione "in discesa" lungo la piattaforma.
			var along := Vector2(-n.y, n.x)
			_slide_dir = along if along.y > 0.0 else -along
			_slide_speed = (other as SlidePlatform).slide_speed
		else:
			_slide_dir = Vector2.ZERO


## Sono dentro un nascondiglio? (I nascondigli stanno nel gruppo "hide_zones" e
## hanno la funzione hides(punto).)
func _update_concealed() -> void:
	concealed = false
	var center := global_position + BODY
	for zone in get_tree().get_nodes_in_group("hide_zones"):
		if zone.hides(center):
			concealed = true
			return


## Sto colpendo o sparando in questo momento? (Serve ai cespugli per agitarsi.)
func is_attacking() -> bool:
	return _punch_t >= 0.0 or muzzle_flash > 0.0 or (swing_t >= 0.0 and swing_t < 0.2) or charge >= 0.0


## Il colpo è istantaneo nel momento in cui premi: l'animazione è solo grafica.
func _punch() -> void:
	_punch_cd = punch_cooldown
	_punch_queued = 0.0
	_punch_t = 0.0
	_punch_dir = aim
	melee_hit(punch_range, punch_cone_deg, punch_damage)


## Colpo ravvicinato nella direzione di mira (pugno o arma corpo a corpo):
## colpisce chi sta entro "reach" pixel e dentro il cono. Ritorna true se ha colpito.
func melee_hit(reach: float, cone_deg: float, damage: float) -> bool:
	var center := global_position + BODY
	var hit_someone := false
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or p == self or not p.alive:
			continue
		var d := (p.global_position + BODY) - center
		var in_reach := d.length() < reach + BODY_RADIUS
		var in_cone := absf(rad_to_deg(aim.angle_to(d))) < cone_deg
		if in_reach and (in_cone or d.length() < BODY_RADIUS * 1.5):
			if p.take_hit(aim, center, damage, self):
				hit_someone = true
	# Colpo verso il basso in aria che va a segno: rimbalzi sopra l'avversario.
	if hit_someone and aim.y > 0.6 and not is_on_floor():
		velocity.y = -pogo_bounce
		if pogo_refreshes_double_jump:
			_air_jumps = max_air_jumps
	return hit_someone


## Chiamato da chi ti colpisce. from_pos = da dove arriva il colpo.
## Se lo scudo copre quella direzione il colpo è parato (ritorna false),
## altrimenti spinta nella direzione del colpo e un attimo senza controllo (ritorna true).
## Servirà uguale per i proiettili: from_pos sarà il punto da cui arriva la pallottola.
func take_hit(direction: Vector2, from_pos: Vector2, damage := 0.0, attacker: Player = null) -> bool:
	if not alive or riding:
		return false # sullo scivolo a spirale non si può essere colpiti
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
	set_solid(false)
	set_physics_process(false)
	died.emit(self, cause)


## Raccoglie un'arma. ammo = colpi rimasti (-1 = caricatore pieno).
func equip(data: WeaponData, with_ammo := -1) -> void:
	weapon = data
	ammo = data.ammo if with_ammo < 0 else with_ammo
	fire_cd = 0.0
	fire_queued = 0.0
	swing_t = -1.0
	cancel_charge()
	_punch_t = -1.0


func drop_weapon() -> void:
	weapon = null
	ammo = 0
	swing_t = -1.0
	cancel_charge()


## Interrompe la carica (fionda) senza tirare.
func cancel_charge() -> void:
	charge = -1.0
	aim_preview = PackedVector2Array()


## Consuma un colpo dell'arma in mano; finiti i colpi, l'arma sparisce.
## Le armi con "ammo = 0" nella scheda hanno colpi infiniti.
func use_ammo() -> void:
	if weapon == null or weapon.ammo <= 0:
		return
	ammo -= 1
	if ammo <= 0:
		drop_weapon()


func attack_held() -> bool:
	return _held("attack")


## Punto in cui si vede la punta dell'arma (lampo dello sparo).
func muzzle_position() -> Vector2:
	return grip_position() + aim * weapon.length


## Punto da cui parte davvero il colpo: il bordo del corpo, non la punta dell'arma.
## Così si colpisce anche un avversario attaccato a noi, e non si spara "oltre" un muro sottile.
func shot_origin() -> Vector2:
	return global_position + BODY + aim * BODY_RADIUS


## Lascia cadere l'arma in mano: cade dov'è e resta lì con i colpi rimasti,
## così si può prendere un'arma migliore passandoci sopra.
func throw_down_weapon() -> WeaponPickup:
	if weapon == null:
		return null
	var pickup := WeaponPickup.new()
	pickup.data = weapon
	pickup.ammo = ammo
	pickup.death_y = death_y
	pickup.ignore_player = self
	pickup.position = global_position + BODY
	get_parent().add_child(pickup)
	drop_weapon()
	return pickup


## Punto in cui si impugna l'arma (davanti al corpo, nella direzione di mira).
func grip_position() -> Vector2:
	return global_position + BODY + aim * 30.0


## Uno scivolo a spirale prende il personaggio: da qui lo muove lui.
func start_ride() -> void:
	riding = true
	velocity = Vector2.ZERO
	_shield_t = -1.0
	_punch_t = -1.0
	cancel_charge()
	set_solid(false)


## Fine dello scivolo: il personaggio torna comandabile, con una spinta di uscita.
## Si riparte col doppio salto disponibile, come se si fosse toccato terra.
func end_ride(exit_velocity: Vector2) -> void:
	riding = false
	visible = alive
	velocity = exit_velocity
	_air_jumps = max_air_jumps
	_jump_held_cut = false
	_buffer = 0.0
	set_solid(alive)


## Per gli oggetti che portano in giro il personaggio (scivolo a spirale):
## ha appena premuto il salto? Sta tenendo giù? (Il manichino non risponde.)
func jump_just_pressed() -> bool:
	return bot == null and _just("jump")


func down_is_held() -> bool:
	return bot == null and _held("down")


## Velocità verso l'alto di un salto normale.
func jump_speed() -> float:
	return _jump_velocity


func respawn(at: Vector2) -> void:
	riding = false
	concealed = false
	global_position = at
	velocity = Vector2.ZERO
	_hitstun_timer = 0.0
	_drop_timer = 0.0
	_punch_t = -1.0
	_shield_t = -1.0
	_wall_lock = 0.0
	drop_weapon()
	health = max_health
	last_attacker = null
	_last_attacker_timer = 0.0
	set_collision_mask_value(LAYER_ONE_WAY, true)
	alive = true
	visible = true
	set_solid(true)
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
	if concealed:
		return # nascosto: non si vede niente (né corpo, né mira, né arma)
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

	# Mano dietro (con un'arma a due mani sta sull'arma, la disegniamo dopo)
	if weapon == null or weapon.family == WeaponData.Family.ONE_HAND:
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

	if weapon == null:
		# Mano davanti: a riposo sta nella direzione di mira, col pugno si allunga.
		var ext := _punch_extension()
		var dir := _punch_dir if _punch_t >= 0.0 else aim
		var hand := body + dir * (38.0 + 55.0 * ext)
		_ball(hand, 9.0 + 2.0 * ext, col)
	else:
		# Arma in mano: si disegna dall'impugnatura verso la mira.
		var grip := body + aim * 30.0
		var squashed := shake + Vector2(grip.x * sx, grip.y * sy)
		var wdir := weapon.held_direction(self) # col fendente l'arma ruota
		WeaponDraw.draw_weapon(self, squashed, wdir, weapon, weapon.held_side(self), weapon.is_ready(self))
		draw_set_transform(shake, 0.0, Vector2(sx, sy))
		if muzzle_flash > 0.0:
			draw_circle(grip + aim * (weapon.length + 10.0), 14.0, Color(1, 0.9, 0.5, 0.9))
		# Fendente: una scia bianca fa vedere fin dove arriva il colpo.
		var melee := weapon as MeleeData
		if melee != null and swing_t >= 0.0 and swing_t < 0.1:
			var half_cone := deg_to_rad(melee.cone_deg)
			var sa := swing_dir.angle()
			draw_arc(body, melee.reach, sa - half_cone, sa + half_cone, 24, Color(1, 1, 1, 0.8 * (1.0 - swing_t / 0.1)), 10.0, true)
		_ball(grip, 9.0, col)
		if weapon.family == WeaponData.Family.TWO_HAND:
			_ball(grip + wdir * weapon.length * 0.45, 9.0, col)

	# Scudo: arco davanti al personaggio che si chiude col passare del tempo.
	if is_shielding():
		var half := deg_to_rad(shield_half_angle())
		var a := _shield_dir.angle()
		var sc := Color.WHITE if _shield_flash > 0.0 else Color(0.55, 0.9, 1.0, 0.9)
		draw_arc(body, shield_radius, a - half, a + half, 32, sc, 8.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Linea tratteggiata della traiettoria mentre si carica la fionda.
	for i in range(0, aim_preview.size() - 1, 2):
		var fade := 1.0 - float(i) / float(aim_preview.size())
		draw_line(aim_preview[i], aim_preview[i + 1], Color(1, 1, 1, 0.25 + 0.6 * fade), 7.0, true)
	# La vita non si mostra di proposito: non si sa mai qual è l'ultimo colpo.


func _ball(center: Vector2, radius: float, fill: Color) -> void:
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 40, OUTLINE, 3.0, true)
