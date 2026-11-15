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

## L'area inquadrata nel "mondo" (tiene conto di dove si trova l'arena:
## durante il cambio di arena quella nuova sta accanto a quella vecchia).
var world_bounds: Rect2:
	get:
		return Rect2(global_position + bounds.position, bounds.size)

## Sotto questa altezza si muore.
var death_y: float:
	get:
		return world_bounds.end.y + death_margin

## Limiti laterali di sicurezza (normalmente non si raggiungono: ci sono i muri invisibili).
var side_limits: Vector2:
	get:
		var wb := world_bounds
		return Vector2(wb.position.x - side_margin - 600.0, wb.end.x + side_margin + 600.0)


func _ready() -> void:
	# Lo sfondo sta sempre dietro a tutto, anche dietro alle piattaforme dell'arena
	# accanto (durante lo scorrimento gli sfondi delle due arene si sovrappongono).
	var bg := get_node_or_null("Background") as CanvasItem
	if bg != null:
		bg.z_index = -10
	_build_invisible_walls()


## Durante lo scorrimento taglia lo sfondo a una certa x del "mondo", così il confine
## tra i due ambienti cade nello spazio vuoto tra le arene e non in mezzo a una di esse.
## Senza argomenti rimette lo sfondo intero.
func clip_background(left_x := -INF, right_x := INF) -> void:
	var bg := get_node_or_null("Background") as Control
	if bg == null:
		return
	if not bg.has_meta("full_left"):
		bg.set_meta("full_left", bg.offset_left)
		bg.set_meta("full_right", bg.offset_right)
	var full_left: float = bg.get_meta("full_left")
	var full_right: float = bg.get_meta("full_right")
	bg.offset_left = maxf(full_left, left_x - global_position.x)
	bg.offset_right = minf(full_right, right_x - global_position.x)


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for child in $Spawns.get_children():
		points.append((child as Node2D).global_position)
	return points


func _build_invisible_walls() -> void:
	var left := bounds.position.x - side_margin
	var right := bounds.end.x + side_margin
	var top := bounds.position.y - top_margin
	var bottom := bounds.end.y + death_margin + 400.0
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
