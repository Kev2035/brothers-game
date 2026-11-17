@tool
class_name FlexBranch
extends AnimatableBody2D
## Ramo flessibile (livello 15 del bosco): una piattaforma di legno attaccata
## al tronco con un ramo che SI PIEGA sotto il peso. Finché qualcuno ci sta
## sopra scende piano; appena resta vuota torna su di scatto.
## Più personaggi ci sono sopra, più scende. Ci si sale da sotto saltando.
##
## La posizione del nodo è l'angolo in alto a sinistra della piattaforma quando
## è a riposo (scarica).

@export var size := Vector2(360, 22):
	set(value):
		size = value
		queue_redraw()
@export var sag_per_player := 200.0 ## di quanti pixel scende per ogni personaggio sopra
@export var max_sag := 340.0 ## più di così non scende
@export var bend_speed := 230.0 ## velocità con cui si piega (pixel al secondo)
@export var spring_speed := 900.0 ## velocità con cui torna su quando resta vuota
@export var anchor_right := false: ## true = il ramo è attaccato al tronco dal lato destro
	set(value):
		anchor_right = value
		queue_redraw()
@export var color := Color("7a9a3a"):
	set(value):
		color = value
		queue_redraw()

const LAYER_ONE_WAY := 2

var sag := 0.0 ## di quanto è sceso adesso
var _rest := Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_rest = position
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


## A ogni inizio round il ramo torna dritto.
func reset_round() -> void:
	sag = 0.0
	position = _rest


## Quanti personaggi ci stanno sopra in questo momento.
func riders() -> int:
	var n := 0
	var top := global_position
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or not p.alive or not p.is_on_floor():
			continue
		var feet := p.global_position
		if feet.x > top.x - 20.0 and feet.x < top.x + size.x + 20.0 and absf(feet.y - top.y) < 14.0:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var n := riders()
	if n > 0:
		sag = move_toward(sag, minf(sag_per_player * n, max_sag), bend_speed * delta)
	else:
		sag = move_toward(sag, 0.0, spring_speed * delta)
	# Tutta la posizione, non solo l'altezza: così il ramo segue l'arena quando
	# viene spostata (cambio di arena a scorrimento).
	position = _rest + Vector2(0.0, sag)
	queue_redraw()


func _draw() -> void:
	# Il ramo che lo tiene: parte dal tronco (fermo, all'altezza di riposo) e
	# arriva al bordo della piattaforma, piegandosi.
	var from := Vector2(size.x + 150.0 if anchor_right else -150.0, 8.0 - sag)
	var to := Vector2(size.x if anchor_right else 0.0, size.y / 2.0)
	var mid := Vector2((from.x + to.x) / 2.0, from.y + 4.0)
	draw_polyline(PackedVector2Array([from, mid, to]), Color(0.55, 0.4, 0.24), 14.0, true)
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_rect(Rect2(0.0, 0.0, size.x, minf(8.0, size.y)), color.lightened(0.3))
