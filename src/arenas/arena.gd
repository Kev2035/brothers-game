class_name Arena
extends Node2D
## Arena di base: piattaforme, punti di partenza e l'area inquadrata dalla telecamera.
## Come in Stick Fight si può uscire un po' dallo schermo di lato e in alto,
## ma poi ci sono muri invisibili. Sotto invece c'è il vuoto: si muore.

@export var arena_name := "Arena" ## nome che si vede in alto durante la partita
@export var bounds := Rect2(0, 0, 3200, 1800) ## area che la telecamera inquadra
@export var side_margin := 250.0 ## quanto si può uscire di lato prima del muro invisibile
@export var top_margin := 450.0 ## quanto si può salire sopra lo schermo
@export var death_margin := 250.0 ## quanto sotto il bordo dello schermo si muore

## Sotto questa altezza si muore.
var death_y: float:
	get:
		return bounds.end.y + death_margin

## Limiti laterali di sicurezza (normalmente non si raggiungono: ci sono i muri invisibili).
var side_limits: Vector2:
	get:
		return Vector2(bounds.position.x - side_margin - 600.0, bounds.end.x + side_margin + 600.0)


func _ready() -> void:
	_build_invisible_walls()


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for child in $Spawns.get_children():
		points.append((child as Node2D).global_position)
	return points


func _build_invisible_walls() -> void:
	var left := bounds.position.x - side_margin
	var right := bounds.end.x + side_margin
	var top := bounds.position.y - top_margin
	var bottom := death_y + 400.0
	var thick := 200.0
	_add_wall(Rect2(left - thick, top - thick, thick, bottom - top + thick)) # sinistra
	_add_wall(Rect2(right, top - thick, thick, bottom - top + thick)) # destra
	_add_wall(Rect2(left - thick, top - thick, right - left + 2.0 * thick, thick)) # soffitto


func _add_wall(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.add_to_group("bounds")
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = r.position + r.size / 2.0
	body.add_child(cs)
	add_child(body)
