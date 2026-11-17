class_name CrowThief
extends Node2D
## Corvo ladro (livelli 13, 14 e 17 del bosco). Sta appollaiato in alto; ogni
## tanto sceglie un bersaglio (un personaggio con un'arma in mano, oppure
## un'arma a terra), avvisa gracchiando, scende in picchiata e RUBA L'ARMA.
## Non fa danno, non si può eliminare e non c'è modo di difendersi.
## Poi vola via con l'arma (oppure la porta al corvo gigante: "deliver_to").
##
## La posizione del nodo è il punto in cui sta appollaiato.

enum State { PERCH, WARN, DIVE, LEAVE, DELIVER, RETURN }

@export var first_delay := 5.0 ## secondi dall'inizio del round alla prima picchiata
@export var interval := Vector2(7.0, 11.0) ## poi una picchiata ogni tot secondi (minimo, massimo)
@export var warn_time := 0.8 ## secondi di avviso (sbatte le ali, occhi grandi) prima di partire
@export var dive_speed := 1500.0 ## velocità in picchiata (i personaggi corrono a 700)
@export var fly_speed := 900.0 ## velocità quando torna su
@export var grab_radius := 60.0 ## quanto deve arrivare vicino per rubare
@export var steal_from_hands := true ## ruba le armi dalle mani
@export var steal_from_ground := true ## ruba le armi a terra
## Se indicato (il corvo gigante), il ladro porta l'arma a lui invece di volare via.
@export var deliver_to: NodePath

const BLACK := Color(0.07, 0.07, 0.1)

var state := State.PERCH
var carried: WeaponData = null ## l'arma che sta portando via
var carried_ammo := 0
var steals := 0 ## quante armi ha rubato in questo round

var _home := Vector2.ZERO
var _timer := 0.0
var _target: Node2D = null
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _eyes: Node2D


func _ready() -> void:
	_home = position
	_timer = first_delay
	add_to_group("round_reset")
	add_to_group("crows")
	z_index = 6
	# Gli occhi rossi si vedono anche al buio (disegno a parte, non scurito).
	_eyes = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_eyes.material = mat
	_eyes.draw.connect(_draw_eyes)
	add_child(_eyes)


## A ogni inizio round torna al suo posto, senza niente tra le zampe.
func reset_round() -> void:
	position = _home
	state = State.PERCH
	_timer = first_delay
	_target = null
	carried = null
	steals = 0


func _boss() -> Node:
	return get_node_or_null(deliver_to) if not deliver_to.is_empty() else null


## I bersagli possibili in questo momento.
func _candidates() -> Array:
	var list := []
	if steal_from_hands:
		for node in get_tree().get_nodes_in_group("players"):
			var p := node as Player
			if p != null and p.alive and p.visible and p.weapon != null and not p.riding:
				list.append(p)
	if steal_from_ground:
		for node in get_tree().get_nodes_in_group("pickups"):
			var pk := node as WeaponPickup
			if pk != null and not pk.fixed and not pk.is_queued_for_deletion():
				list.append(pk)
	return list


func _target_ok() -> bool:
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		return false
	if _target is Player:
		var p := _target as Player
		return p.alive and p.weapon != null and not p.riding
	return true


## Dove sta il bersaglio, nelle coordinate dell'arena.
func _target_pos() -> Vector2:
	var g := _target.global_position
	if _target is Player:
		g += Player.BODY
	return g - (get_parent() as Node2D).global_position


func _physics_process(delta: float) -> void:
	_time += delta
	match state:
		State.PERCH:
			_timer -= delta
			if _timer <= 0.0:
				var boss := _boss()
				var list := _candidates()
				# Se il corvo gigante ha già un'arma tra le zampe (o non c'è più), niente furti.
				if list.is_empty() or (not deliver_to.is_empty() and (boss == null or not boss.can_receive())):
					_timer = 1.5
				else:
					_target = list[_rng.randi() % list.size()]
					state = State.WARN
					_timer = warn_time
		State.WARN:
			_timer -= delta
			if _timer <= 0.0:
				state = State.DIVE if _target_ok() else State.RETURN
				_timer = 5.0
		State.DIVE:
			_timer -= delta
			if not _target_ok() or _timer <= 0.0:
				state = State.RETURN # il bersaglio non ha più l'arma: torna su a mani vuote
			elif _fly_to(_target_pos(), dive_speed, delta, grab_radius):
				_steal()
		State.LEAVE:
			# Vola via in alto, fuori dallo schermo, e l'arma sparisce con lui.
			if _fly_to(Vector2(position.x, _home.y - 900.0), fly_speed, delta):
				carried = null
				state = State.RETURN
		State.DELIVER:
			var boss := _boss()
			if boss == null or not boss.can_receive():
				state = State.LEAVE
			elif _fly_to((boss as Node2D).global_position - (get_parent() as Node2D).global_position, fly_speed * 1.4, delta, 120.0):
				boss.receive_weapon(carried, carried_ammo)
				carried = null
				state = State.RETURN
		State.RETURN:
			if _fly_to(_home, fly_speed, delta):
				state = State.PERCH
				_timer = _rng.randf_range(interval.x, interval.y)
	queue_redraw()
	_eyes.queue_redraw()


## Si sposta verso "to" (coordinate dell'arena). Ritorna true quando è arrivato.
func _fly_to(to: Vector2, speed: float, delta: float, near := 4.0) -> bool:
	position = position.move_toward(to, speed * delta)
	return position.distance_to(to) <= near


func _steal() -> void:
	if _target is Player:
		var p := _target as Player
		carried = p.weapon
		carried_ammo = p.ammo
		p.drop_weapon()
	else:
		var pk := _target as WeaponPickup
		carried = pk.data
		carried_ammo = pk.ammo
		pk.queue_free()
	steals += 1
	_target = null
	Fx.sparks(get_parent(), global_position, BLACK.lightened(0.25), 10) # qualche piuma
	if Arena.night:
		Fx.flash(get_parent(), global_position, Color(1.0, 0.5, 0.45), 220.0, 0.4)
	state = State.DELIVER if not deliver_to.is_empty() else State.LEAVE


func _draw() -> void:
	var flying := state != State.PERCH and state != State.WARN
	var flap_speed := 26.0 if state == State.WARN else 16.0
	var flap := sin(_time * flap_speed) if (flying or state == State.WARN) else -0.2
	var shake := Vector2(randf_range(-2.0, 2.0), 0.0) if state == State.WARN else Vector2.ZERO
	# L'arma rubata, tra le zampe.
	if carried != null:
		WeaponDraw.draw_weapon(self, Vector2(-carried.length / 2.0, 34.0), Vector2.RIGHT, carried)
	# Ali
	for s in [-1.0, 1.0]:
		var tip: Vector2 = shake + Vector2(s * 58.0, -12.0 - flap * 34.0)
		draw_colored_polygon(PackedVector2Array([shake + Vector2(s * 10.0, -8.0), tip, shake + Vector2(s * 16.0, 14.0)]), BLACK)
	# Corpo, testa, becco
	draw_circle(shake, 22.0, BLACK)
	draw_circle(shake + Vector2(0.0, -20.0), 14.0, BLACK)
	draw_colored_polygon(PackedVector2Array([shake + Vector2(-6.0, -18.0), shake + Vector2(6.0, -18.0), shake + Vector2(0.0, -2.0)]), Color(0.95, 0.75, 0.2))
	# Zampe
	for s in [-1.0, 1.0]:
		draw_line(shake + Vector2(s * 8.0, 18.0), shake + Vector2(s * 8.0, 30.0), Color(0.95, 0.75, 0.2), 3.0)


func _draw_eyes() -> void:
	var r := 5.5 if state == State.WARN or state == State.DIVE else 3.5
	for s in [-1.0, 1.0]:
		_eyes.draw_circle(Vector2(s * 6.0, -24.0), r, Color(1.0, 0.15, 0.1))
