@tool
class_name Rail
extends Node2D
## Un "binario" (livello 5 del bosco): una fila di piattaforme di lunghezze
## diverse che scorrono in orizzontale, tutte alla stessa velocità. Quando una
## piattaforma esce da un lato rientra dall'altro (fuori dallo schermo), quindi
## la fila non finisce mai. Chi sta sopra viene trasportato.
## A inizio round le piattaforme stanno ferme per un po', poi partono piano.
## La sequenza è sempre uguale e riparte da capo a ogni round.
##
## Il binario comincia dove si trova questo nodo e va verso destra per
## "track_length" pixel: deve essere più lungo dello schermo, così le
## piattaforme "saltano" da un capo all'altro dove non si vedono.

@export var lengths: Array[float] = [300.0, 220.0, 400.0]: ## lunghezza di ogni piattaforma, in ordine
	set(value):
		lengths = value
		queue_redraw()
@export var track_length := 4600.0: ## lunghezza del binario; lo spazio tra le piattaforme si calcola da solo
	set(value):
		track_length = value
		queue_redraw()
@export var speed := 160.0 ## pixel al secondo; negativo = verso sinistra
@export var start_delay := 2.0 ## secondi fermi a inizio round
@export var ramp_time := 1.5 ## secondi per arrivare alla velocità piena
@export var shift := 0.0: ## sposta in avanti tutta la fila (per sfalsare i binari tra loro)
	set(value):
		shift = value
		queue_redraw()
@export var thickness := 24.0
@export var color := Color("99703f"):
	set(value):
		color = value
		queue_redraw()

const LAYER_ONE_WAY := 2
const RAIL_COLOR := Color(0.12, 0.12, 0.16, 0.8)

var time := 0.0 ## secondi dall'inizio del round
var _bodies: Array[AnimatableBody2D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("round_reset")
	for i in lengths.size():
		var body := AnimatableBody2D.new()
		body.collision_layer = 0
		body.set_collision_layer_value(LAYER_ONE_WAY, true)
		body.collision_mask = 0
		body.add_to_group("one_way")
		var shape := RectangleShape2D.new()
		shape.size = Vector2(lengths[i], thickness)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = Vector2(lengths[i] / 2.0, thickness / 2.0)
		cs.one_way_collision = true
		body.add_child(cs)
		body.position = Vector2(platform_x(i), 0.0)
		add_child(body)
		_bodies.append(body)


## A ogni inizio round le piattaforme tornano al punto di partenza.
func reset_round() -> void:
	time = 0.0
	_place()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time += delta
	_place()
	queue_redraw()


func _place() -> void:
	for i in _bodies.size():
		_bodies[i].position.x = platform_x(i)


## Spazio vuoto tra una piattaforma e la successiva.
func gap() -> float:
	var total := 0.0
	for l in lengths:
		total += l
	return maxf((track_length - total) / maxf(lengths.size(), 1.0), 0.0)


## Di quanti pixel si è spostata la fila dall'inizio del round.
func travelled() -> float:
	var t := maxf(time - start_delay, 0.0)
	if t < ramp_time:
		return speed * t * t / (2.0 * maxf(ramp_time, 0.01)) # partenza morbida
	return speed * (t - ramp_time / 2.0)


## Posizione (bordo sinistro, rispetto al binario) della piattaforma numero i.
func platform_x(i: int) -> float:
	var base := 0.0
	var g := gap()
	for k in i:
		base += lengths[k] + g
	return fposmod(base + shift + travelled(), track_length)


func _draw() -> void:
	# Il binario: una linea scura lungo tutta la corsa.
	draw_line(Vector2(0.0, thickness / 2.0), Vector2(track_length, thickness / 2.0), RAIL_COLOR, 6.0)
	for i in lengths.size():
		var r := Rect2(platform_x(i), 0.0, lengths[i], thickness)
		draw_rect(r, color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, minf(8.0, thickness))), color.lightened(0.3))
		# Le "ruote" che la tengono sul binario.
		for wx in [r.position.x + 14.0, r.end.x - 14.0]:
			draw_circle(Vector2(wx, thickness / 2.0), 7.0, RAIL_COLOR)
