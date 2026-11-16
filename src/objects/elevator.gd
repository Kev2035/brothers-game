@tool
class_name Elevator
extends AnimatableBody2D
## Ascensore (livello 7 del bosco): una piattaforma appesa a due funi che sale
## e scende di continuo, sempre con lo stesso ritmo. Trasporta chi c'è sopra
## (e le armi appoggiate). Ci si sale da sotto saltando, come sulle piattaforme
## di legno. Sopra si è esposti: niente ripari.
##
## La posizione del nodo è il punto PIÙ ALTO della corsa; da lì scende di
## "travel" pixel e risale.

@export var size := Vector2(220, 24):
	set(value):
		size = value
		queue_redraw()
@export var travel := 800.0 ## quanti pixel scende dal punto più alto
@export var period := 8.0 ## secondi per un giro completo (giù e di nuovo su)
@export var start_delay := 1.0 ## secondi fermo a inizio round
@export var start_low := false ## true = a inizio round è in basso (e parte salendo)
@export var color := Color("b98a55"):
	set(value):
		color = value
		queue_redraw()

const LAYER_ONE_WAY := 2
const ROPE := Color(0.82, 0.76, 0.6, 0.9)

var time := 0.0 ## secondi dall'inizio del round
var _top := Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_top = position
	add_to_group("round_reset")
	add_to_group("one_way")
	collision_layer = 0
	set_collision_layer_value(LAYER_ONE_WAY, true)
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = size / 2.0
	cs.one_way_collision = true
	add_child(cs)
	position = _top + Vector2(0.0, drop()) # tutta la posizione, non solo l'altezza (vedi nota sotto)


## A ogni inizio round l'ascensore riparte dal suo punto di partenza.
func reset_round() -> void:
	time = 0.0
	position = _top + Vector2(0.0, drop()) # tutta la posizione, non solo l'altezza (vedi nota sotto)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time += delta
	position = _top + Vector2(0.0, drop()) # tutta la posizione, non solo l'altezza (vedi nota sotto)


# Nota: i corpi che si muovono (AnimatableBody2D) "tengono" la loro posizione nel
# mondo. Quando l'arena viene spostata (cambio di arena a scorrimento) resterebbero
# indietro: per questo a ogni fotogramma si rimette la posizione completa rispetto all'arena.


## Di quanti pixel è sceso rispetto al punto più alto (movimento morbido: rallenta in cima e in fondo).
func drop() -> float:
	var t := maxf(time - start_delay, 0.0)
	var wave := 0.5 - 0.5 * cos(TAU * t / maxf(period, 0.1)) # 0 = in alto, 1 = in basso
	return travel * (1.0 - wave if start_low else wave)


func _draw() -> void:
	# Le due funi salgono fino a sparire sopra lo schermo.
	for x in [14.0, size.x - 14.0]:
		draw_line(Vector2(x, 0.0), Vector2(x, -4000.0), ROPE, 4.0)
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_rect(Rect2(0.0, 0.0, size.x, minf(8.0, size.y)), color.lightened(0.3))
