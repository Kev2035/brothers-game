class_name Player
extends CharacterBody2D
## Personaggio del prototipo: movimento arcade veloce + pugno con contraccolpo.
## La grafica per ora è fatta di cerchi disegnati da Godot (corpo, mani, piedi).
## Tutti i numeri con @export si possono cambiare dall'Inspector di Godot
## mentre si prova, senza toccare il codice.

signal died(player: Player)

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

@export_group("Pugno e contraccolpo")
@export var punch_range := 115.0
@export var punch_cooldown := 0.35
@export var knockback := Vector2(950, -520) ## spinta subita (orizzontale, verticale)
@export var hitstun := 0.28 ## secondi in cui chi è colpito non controlla il personaggio

const LAYER_SOLID := 1
const LAYER_ONE_WAY := 2
const OUTLINE := Color("1b1b2b")

var slot := 0
var color := Color.WHITE
var alive := true
var death_y := 1250.0
var side_limits := Vector2(-300, 2220)
var facing := 1.0

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
var _punch_anim := 0.0
var _flash := 0.0
var _run_phase := 0.0
var _squash := 0.0
var _was_on_floor := false
var _on_one_way := false


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


func _physics_process(delta: float) -> void:
	_recompute_jump() # così i cambi fatti dall'Inspector valgono subito
	_tick_timers(delta)

	var stunned := _hitstun_timer > 0.0
	var input_x := 0.0 if stunned else Input.get_axis(act("left"), act("right"))
	var down_held := not stunned and Input.is_action_pressed(act("down"))
	var on_floor := is_on_floor()

	if on_floor:
		_coyote = coyote_time
		_air_jumps = max_air_jumps
	if not stunned and Input.is_action_just_pressed(act("jump")):
		_buffer = jump_buffer

	# Scendere da una piattaforma attraversabile: Giù + Salto.
	if on_floor and _on_one_way and down_held and _buffer > 0.0:
		_buffer = 0.0
		_drop_timer = 0.22
		set_collision_mask_value(LAYER_ONE_WAY, false)
		position.y += 2.0

	# Salto da terra (con coyote time e buffer) oppure doppio salto in aria.
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -_jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		_jump_held_cut = true
		_squash = -0.6
	elif not stunned and Input.is_action_just_pressed(act("jump")) and _coyote <= 0.0 and _air_jumps > 0 and _drop_timer <= 0.0:
		velocity.y = -_double_jump_velocity
		_air_jumps -= 1
		_buffer = 0.0
		_jump_held_cut = true
		_squash = -0.5

	# Salto variabile: se lasci il tasto mentre sali, il salto si accorcia.
	if _jump_held_cut and velocity.y < 0.0 and not Input.is_action_pressed(act("jump")):
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
	elif on_floor:
		accel = ground_accel if absf(input_x) > 0.01 else ground_decel
	else:
		accel = air_accel if absf(input_x) > 0.01 else air_decel
	velocity.x = move_toward(velocity.x, input_x * run_speed, accel * delta)
	if absf(input_x) > 0.01:
		facing = signf(input_x)

	if not stunned and Input.is_action_just_pressed(act("attack")) and _punch_cd <= 0.0:
		_punch()

	move_and_slide()
	_read_floor()

	if is_on_floor() and not _was_on_floor:
		_squash = 1.0 # atterraggio: il pupazzetto si schiaccia un attimo
	_was_on_floor = is_on_floor()

	_run_phase += absf(velocity.x) / run_speed * delta * 14.0
	queue_redraw()

	if global_position.y > death_y or global_position.x < side_limits.x or global_position.x > side_limits.y:
		_die()


func _tick_timers(delta: float) -> void:
	_coyote -= delta
	_buffer -= delta
	_hitstun_timer -= delta
	_punch_cd -= delta
	_punch_anim = maxf(_punch_anim - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_squash = move_toward(_squash, 0.0, delta * 6.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(LAYER_ONE_WAY, true)


func _read_floor() -> void:
	_on_one_way = false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if c.get_normal().y < -0.7 and other is Node and (other as Node).is_in_group("one_way"):
			_on_one_way = true


func _punch() -> void:
	_punch_cd = punch_cooldown
	_punch_anim = 0.12
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or p == self or not p.alive:
			continue
		var d := p.global_position - global_position
		if absf(d.y) < 90.0 and d.x * facing > -15.0 and absf(d.x) < punch_range:
			p.take_hit(facing)


## Chiamato da chi ti colpisce: spinta indietro e un attimo senza controllo.
func take_hit(direction: float) -> void:
	velocity = Vector2(direction * knockback.x, knockback.y)
	_hitstun_timer = hitstun
	_flash = 0.12
	_jump_held_cut = false
	facing = -direction


func _die() -> void:
	if not alive:
		return
	alive = false
	visible = false
	set_physics_process(false)
	died.emit(self)


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_hitstun_timer = 0.0
	_drop_timer = 0.0
	set_collision_mask_value(LAYER_ONE_WAY, true)
	alive = true
	visible = true
	set_physics_process(true)


# ---------------------------------------------------------------------------
# Disegno del pupazzetto: corpo tondo, occhi, mani e piedi staccati.
# Sarà sostituito dalla grafica vera senza cambiare il movimento.
# ---------------------------------------------------------------------------
func _draw() -> void:
	var sy := 1.0 - _squash * 0.22
	var sx := 1.0 + _squash * 0.18
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))

	var col := Color.WHITE if _flash > 0.0 else color
	var dark := col.darkened(0.3)
	var body := Vector2(0, -52)
	var grounded := is_on_floor()
	var running := grounded and absf(velocity.x) > 40.0
	var bob := sin(_run_phase * 2.0) * 3.0 if running else 0.0

	# Mano dietro
	_ball(body + Vector2(-facing * 30.0, 12.0 + bob), 9.0, dark)

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
	_ball(body + Vector2(0, bob), 32.0, col)

	# Occhi (guardano dove sei girato)
	for e in [-1.0, 1.0]:
		var eye: Vector2 = body + Vector2(facing * 11.0 + e * 9.0, -6.0 + bob)
		draw_circle(eye, 6.0, Color.WHITE)
		draw_circle(eye + Vector2(facing * 2.0, 0.0), 3.0, OUTLINE)

	# Mano davanti (si allunga quando tiri un pugno)
	var reach := 34.0 + (50.0 if _punch_anim > 0.0 else 0.0)
	_ball(body + Vector2(facing * reach, 10.0 + bob), 10.0 if _punch_anim > 0.0 else 9.0, col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ball(center: Vector2, radius: float, fill: Color) -> void:
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 40, OUTLINE, 3.0, true)
