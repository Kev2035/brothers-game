class_name DummyBrain
extends RefCounted
## "Cervello" del manichino d'allenamento: decide quali tasti premere al posto
## di una persona. Non è un vero avversario intelligente: serve per provare
## il gioco da soli.
##   FERMO    -> sta immobile (bersaglio per provare danni, scudo, armi)
##   SI MUOVE -> cammina avanti e indietro, salta e alza lo scudo ogni tanto
##   ATTACCA  -> ti viene addosso e tira pugni (e para ogni tanto)

enum Mode { STILL, MOVE, ATTACK }
const MODE_NAMES: Array[String] = ["fermo", "si muove", "attacca"]

var mode := Mode.STILL
var move_x := 0.0
var aim := Vector2.LEFT

var _held := {}
var _just := {}
var _timer := 0.0
var _walk_dir := 1.0
var _attack_timer := 0.0
var _rng := RandomNumberGenerator.new()


func mode_name() -> String:
	return MODE_NAMES[mode]


func next_mode() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode


func is_held(a: String) -> bool:
	return _held.get(a, false)


func is_just(a: String) -> bool:
	return _just.get(a, false)


## Chiamato ogni fotogramma dal personaggio, prima di muoversi.
func think(me: Player, delta: float) -> void:
	_just.clear()
	_held.clear()
	move_x = 0.0
	_timer -= delta
	_attack_timer -= delta
	match mode:
		Mode.STILL:
			aim = Vector2(me.facing, 0.0)
		Mode.MOVE:
			_think_move(me)
		Mode.ATTACK:
			_think_attack(me)


func _think_move(me: Player) -> void:
	if _timer <= 0.0:
		_timer = _rng.randf_range(0.8, 2.0)
		if _rng.randf() < 0.4:
			_walk_dir = -_walk_dir
		if _rng.randf() < 0.5 and not _edge_ahead(me, _walk_dir, 320.0):
			_press("jump") # salta solo se davanti c'è pavimento per un bel tratto
		elif _rng.randf() < 0.3:
			_press("shield")
	if me.is_on_floor() and _edge_ahead(me, _walk_dir, 70.0):
		_walk_dir = -_walk_dir # non buttarti nel vuoto
	move_x = _walk_dir
	aim = Vector2(_walk_dir, 0.0)
	_held["jump"] = true # salti pieni


func _think_attack(me: Player) -> void:
	var target := _nearest_enemy(me)
	if target == null:
		_think_move(me)
		return
	var d := (target.global_position + Player.BODY) - (me.global_position + Player.BODY)
	aim = d.normalized()
	var dir := signf(d.x)

	# Con un'arma: si tiene alla distanza giusta per quell'arma e attacca.
	if me.weapon != null:
		var w := me.weapon
		if absf(d.x) > w.bot_keep_distance() and not (me.is_on_floor() and _edge_ahead(me, dir)):
			move_x = dir
		if d.y < -110.0 and _timer <= 0.0:
			_press("jump")
			_held["jump"] = true
			_timer = 0.6
		if d.length() < w.bot_range():
			match w.bot_style():
				&"hold":
					_held["attack"] = true
				&"charge":
					# Mira un po' più in alto (la pietra cade), carica per mezzo secondo e lascia.
					aim = (aim + Vector2(0.0, -w.bot_aim_lift(d.length()))).normalized()
					if _attack_timer <= 0.0:
						_press("attack")
						_attack_timer = 1.0
					elif _attack_timer > 0.45:
						_held["attack"] = true
				_:
					if _attack_timer <= 0.0:
						_press("attack")
						_attack_timer = w.fire_interval + _rng.randf_range(0.15, 0.4)
		return

	if absf(d.x) > 80.0:
		if not (me.is_on_floor() and _edge_ahead(me, dir) and d.y >= -40.0):
			move_x = dir
	# Il bersaglio sta più in alto: salta.
	if d.y < -110.0 and _timer <= 0.0:
		_press("jump")
		_held["jump"] = true
		_timer = 0.45
	# A portata di pugno: colpisci, ogni tanto para.
	if d.length() < 140.0 and _attack_timer <= 0.0:
		if _rng.randf() < 0.2:
			_press("shield")
			_attack_timer = 0.5
		else:
			_press("attack")
			_attack_timer = _rng.randf_range(0.2, 0.4)


func _press(a: String) -> void:
	_just[a] = true
	_held[a] = true


func _nearest_enemy(me: Player) -> Player:
	var best: Player = null
	var best_d := INF
	for node in me.get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or p == me or not p.alive:
			continue
		var dist := p.global_position.distance_to(me.global_position)
		if dist < best_d:
			best_d = dist
			best = p
	return best


## C'è il vuoto davanti ai piedi, entro "distance" pixel?
func _edge_ahead(me: Player, dir: float, distance := 40.0) -> bool:
	var step := 40.0
	var x := step
	while x <= distance:
		var probe := me.global_transform.translated(Vector2(dir * x, 0.0))
		if not me.test_move(probe, Vector2(0.0, 60.0)):
			return true
		x += step
	return false
