class_name GiantCrow
extends Node2D
## Il corvo gigante, boss finale del bosco (livello 17).
## Segue sempre lo stesso giro, che si può imparare:
##   LONTANO   -> vola "in profondità" (piccolo, sullo sfondo): non può essere
##                colpito e non colpisce;
##   ARRIVA    -> si avvicina e diventa grande, sopra un giocatore;
##   AVVISO    -> resta sospeso e a terra compare un cerchio rosso: è lì che colpirà;
##   PICCHIATA -> scende con gli artigli su quel punto (chi è nel cerchio prende danno);
##   RISALE    -> torna su; dopo qualche picchiata...
##   STANCO    -> ...resta basso a riprendere fiato: è il momento migliore per colpirlo;
##   SE NE VA  -> torna lontano, e il giro ricomincia.
## Quando è vicino (grande) si può colpire con qualsiasi arma, anche a pugni.
## I giocatori sono alleati: quando muore, chi è ancora vivo prende una vittoria.
##
## La posizione del nodo è il punto in cui vola quando è LONTANO.

enum State { FAR, APPROACH, WARN, SWOOP, RISE, TIRED, RETREAT, DEAD }

@export_group("Vita e danni")
@export var max_health := 1000.0 ## 10 colpi di spada di Re Artù
@export var claw_damage := 25.0 ## vita tolta da un'artigliata (4 per morire)
@export var claw_radius := 150.0 ## raggio del cerchio rosso: chi è dentro viene colpito
@export var hit_radius := 140.0 ## quanto è "grosso" come bersaglio

@export_group("Tempi del giro")
@export var first_delay := 3.0 ## secondi lontano a inizio round
@export var far_time := 4.0 ## secondi lontano tra un attacco e l'altro
@export var approach_time := 1.2 ## secondi per arrivare (e per andarsene)
@export var warn_time := 0.9 ## secondi di avviso prima di ogni picchiata
@export var lock_time := 0.4 ## negli ultimi tot secondi dell'avviso il cerchio rosso non si sposta più
@export var swoops := 3 ## picchiate per ogni visita
@export var swoop_speed := 2600.0 ## velocità della picchiata
@export var rise_time := 0.6 ## secondi per risalire dopo una picchiata
@export var tired_time := 2.2 ## secondi in cui resta basso, stanco

@export_group("Dove vola")
@export var hover_height := 520.0 ## quanto sta sopra il bersaglio durante l'avviso
@export var tired_height := 230.0 ## quanto sta sopra il pavimento quando è stanco
@export var far_scale := 0.3 ## quanto è piccolo quando è lontano
@export var far_drift := 500.0 ## di quanto si sposta a destra e sinistra quando è lontano

@export_group("Arma rubata")
@export var drop_after_hits := 3 ## dopo quanti colpi ricevuti lascia cadere l'arma che tiene

const BLACK := Color(0.08, 0.08, 0.12)
const YELLOW := Color(0.95, 0.75, 0.2)

var state := State.FAR
var health := 1000.0
var held_weapon: WeaponData = null ## l'arma che gli hanno portato i corvi ladri
var held_ammo := 0
var size := 1.0 ## grandezza attuale (far_scale = lontano, 1 = vicino)
var strike_point := Vector2.ZERO ## dove colpirà (coordinate dell'arena)

var _home := Vector2.ZERO
var _timer := 0.0
var _time := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _from_size := 1.0
var _swoops_done := 0
var _target: Player = null
var _flash := 0.0
var _hits_while_holding := 0
var _rng := RandomNumberGenerator.new()
var _marker: Node2D


func _ready() -> void:
	_home = position
	add_to_group("round_reset")
	add_to_group("damageables")
	add_to_group("bosses")
	# Il cerchio rosso a terra è un disegno a parte: non segue il corvo e non rimpicciolisce.
	_marker = Node2D.new()
	_marker.top_level = true
	_marker.z_index = 4
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	reset_round()


func reset_round() -> void:
	health = max_health
	state = State.FAR
	_timer = first_delay
	_time = 0.0
	_swoops_done = 0
	_target = null
	held_weapon = null
	_hits_while_holding = 0
	position = _home
	size = far_scale
	visible = true
	_apply_look()


## Si può colpire solo quando è vicino.
func vulnerable() -> bool:
	return state != State.DEAD and size >= 0.9


## I corvi ladri gli possono portare un'arma solo se è vivo e ha le zampe libere.
func can_receive() -> bool:
	return state != State.DEAD and held_weapon == null


func receive_weapon(data: WeaponData, ammo: int) -> void:
	held_weapon = data
	held_ammo = ammo
	_hits_while_holding = 0


## Chiamata da pugni, armi e proiettili. Ritorna true se il colpo è andato a segno.
func take_damage(amount: float, attacker: Player) -> bool:
	if not vulnerable():
		return false
	var real := minf(amount, health)
	health -= real
	_flash = 0.15
	get_tree().call_group("game_main", "boss_damaged", attacker, real)
	Fx.sparks(get_parent(), global_position + Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 40.0)), BLACK.lightened(0.3), 8) # piume
	if held_weapon != null:
		_hits_while_holding += 1
		if _hits_while_holding >= drop_after_hits:
			_drop_held()
	if health <= 0.0:
		_die()
	return true


## Lascia cadere l'arma che teneva: chiunque può riprenderla.
func _drop_held() -> void:
	if held_weapon == null:
		return
	var pickup := WeaponPickup.new()
	pickup.data = held_weapon
	pickup.ammo = held_ammo
	if get_parent() is Arena:
		pickup.death_y = (get_parent() as Arena).death_y
	pickup.position = global_position + Vector2(0.0, 120.0)
	get_parent().add_child.call_deferred(pickup)
	held_weapon = null


func _die() -> void:
	_drop_held()
	state = State.DEAD
	visible = false
	_marker.queue_redraw()
	for i in 4:
		Fx.puff(get_parent(), global_position + Vector2(randf_range(-120.0, 120.0), randf_range(-90.0, 90.0)), BLACK.lightened(0.2))
	get_tree().call_group("game_main", "coop_victory")


## Un giocatore vivo a caso (null se non ce ne sono).
func _pick_target() -> Player:
	var list: Array[Player] = []
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p != null and p.alive and p.visible:
			list.append(p)
	return null if list.is_empty() else list[_rng.randi() % list.size()]


## Posizione nelle coordinate dell'arena.
func _local(global_point: Vector2) -> Vector2:
	return global_point - (get_parent() as Node2D).global_position


func _target_alive() -> bool:
	return _target != null and is_instance_valid(_target) and _target.alive


func _go(next: State, time: float) -> void:
	state = next
	_timer = time
	_from = position
	_from_size = size


func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_timer -= delta
	match state:
		State.FAR:
			size = far_scale
			position = _home + Vector2(sin(_time * 0.8) * far_drift, sin(_time * 1.7) * 40.0)
			if _timer <= 0.0:
				_target = _pick_target()
				if _target == null:
					_timer = 1.0
				else:
					_swoops_done = 0
					_go(State.APPROACH, approach_time)
		State.APPROACH:
			if _target_alive():
				_to = _local(_target.global_position) + Vector2(0.0, -hover_height)
			var k := 1.0 - clampf(_timer / approach_time, 0.0, 1.0)
			position = _from.lerp(_to, smoothstep(0.0, 1.0, k))
			size = lerpf(_from_size, 1.0, k)
			if _timer <= 0.0:
				_start_warn()
		State.WARN:
			# Finché il cerchio non è bloccato, segue il bersaglio.
			if _timer > lock_time and _target_alive():
				strike_point = _local(_target.global_position)
			var hover := Vector2(strike_point.x, strike_point.y - hover_height)
			position = position.move_toward(hover, 1100.0 * delta)
			if _timer <= 0.0:
				_go(State.SWOOP, 2.0)
		State.SWOOP:
			var claws_at := strike_point + Vector2(0.0, -110.0) # il corpo si ferma poco sopra il punto
			position = position.move_toward(claws_at, swoop_speed * delta)
			if position.distance_to(claws_at) < 4.0 or _timer <= 0.0:
				_claw()
				_swoops_done += 1
				_to = Vector2(position.x, position.y - hover_height + 110.0)
				_go(State.RISE, rise_time)
		State.RISE:
			var k := 1.0 - clampf(_timer / rise_time, 0.0, 1.0)
			position = _from.lerp(_to, smoothstep(0.0, 1.0, k))
			if _timer <= 0.0:
				if _swoops_done < swoops and _pick_target() != null:
					_target = _pick_target()
					_start_warn()
				else:
					_to = Vector2(position.x, strike_point.y - tired_height)
					_go(State.TIRED, tired_time)
		State.TIRED:
			position = position.move_toward(_to + Vector2(0.0, sin(_time * 5.0) * 14.0), 500.0 * delta)
			if _timer <= 0.0:
				_go(State.RETREAT, approach_time)
		State.RETREAT:
			var k := 1.0 - clampf(_timer / approach_time, 0.0, 1.0)
			position = _from.lerp(_home, smoothstep(0.0, 1.0, k))
			size = lerpf(_from_size, far_scale, k)
			if _timer <= 0.0:
				_go(State.FAR, far_time)
		State.DEAD:
			pass
	_apply_look()
	queue_redraw()
	_marker.queue_redraw()


func _start_warn() -> void:
	if _target_alive():
		strike_point = _local(_target.global_position)
	_go(State.WARN, warn_time)


## L'artigliata: chi è dentro il cerchio rosso prende danno (lo scudo la para).
func _claw() -> void:
	var center := (get_parent() as Node2D).global_position + strike_point
	Fx.sparks(get_parent(), center, Color(1.0, 0.85, 0.5), 16)
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or not p.alive:
			continue
		var d := (p.global_position + Player.BODY) - (center + Vector2(0.0, -60.0))
		if d.length() < claw_radius:
			p.take_hit(Vector2(signf(d.x) if absf(d.x) > 1.0 else 1.0, 0.0), global_position, claw_damage, null)


## Lontano è piccolo, sullo sfondo e sbiadito; vicino è grande e davanti a tutto.
func _apply_look() -> void:
	scale = Vector2.ONE * size
	var near := inverse_lerp(far_scale, 1.0, size)
	z_index = 5 if near > 0.5 else -4
	modulate = Color(0.55, 0.62, 0.8).lerp(Color.WHITE, near)


func _draw_marker() -> void:
	if state != State.WARN and state != State.SWOOP:
		return
	var center := (get_parent() as Node2D).global_position + strike_point + Vector2(0.0, -60.0)
	var locked := state == State.SWOOP or _timer <= lock_time
	var pulse := 0.6 + 0.4 * sin(_time * 18.0)
	var col := Color(1.0, 0.2, 0.15, 0.9 if locked else 0.45 * pulse + 0.2)
	_marker.draw_arc(center, claw_radius, 0.0, TAU, 48, col, 8.0 if locked else 5.0, true)
	if locked:
		_marker.draw_circle(center, claw_radius, Color(1.0, 0.2, 0.15, 0.16))


func _draw() -> void:
	var col := Color(1.0, 0.25, 0.2) if _flash > 0.0 else BLACK
	var flap_speed := 4.0 if state == State.TIRED else 9.0
	var flap := sin(_time * flap_speed)
	if state == State.SWOOP:
		flap = 1.0 # ali chiuse all'indietro
	# Ali
	for s in [-1.0, 1.0]:
		var tip := Vector2(s * 330.0, -40.0 - flap * 150.0)
		draw_colored_polygon(PackedVector2Array([Vector2(s * 50.0, -50.0), tip, Vector2(s * 210.0, 30.0 - flap * 40.0), Vector2(s * 70.0, 60.0)]), col)
	# Coda
	draw_colored_polygon(PackedVector2Array([Vector2(-50.0, 60.0), Vector2(0.0, 190.0), Vector2(50.0, 60.0)]), col)
	# Corpo e testa
	draw_circle(Vector2.ZERO, 110.0, col)
	draw_circle(Vector2(0.0, -110.0), 66.0, col)
	# Becco
	draw_colored_polygon(PackedVector2Array([Vector2(-26.0, -100.0), Vector2(26.0, -100.0), Vector2(0.0, -30.0)]), YELLOW)
	# Occhi (più rossi quando sta per colpire)
	var eye := Color(1.0, 0.15, 0.1) if state == State.WARN or state == State.SWOOP else Color(0.95, 0.9, 0.8)
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(s * 26.0, -124.0), 13.0, eye)
		draw_circle(Vector2(s * 26.0, -120.0), 5.0, Color.BLACK)
	# Zampe con gli artigli (allungate in picchiata)
	var leg := 70.0 if state == State.SWOOP else 40.0
	for s in [-1.0, 1.0]:
		var foot := Vector2(s * 46.0, 100.0 + leg)
		draw_line(Vector2(s * 40.0, 90.0), foot, YELLOW, 12.0)
		for c in [-1.0, 0.0, 1.0]:
			draw_line(foot, foot + Vector2(c * 20.0, 26.0), YELLOW, 7.0)
	# L'arma rubata, nella zampa destra.
	if held_weapon != null:
		WeaponDraw.draw_weapon(self, Vector2(46.0 - held_weapon.length / 2.0, 150.0 + leg), Vector2.RIGHT, held_weapon)
