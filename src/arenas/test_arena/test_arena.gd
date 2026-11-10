class_name Arena
extends Node2D
## Arena di base: contiene piattaforme, punti di partenza e i limiti oltre
## i quali un giocatore muore (il "vuoto"), un po' oltre il bordo dello schermo.

@export var death_y := 1250.0 ## sotto questa altezza si muore (lo schermo finisce a 1080)
@export var side_limits := Vector2(-300, 2220) ## oltre questi bordi laterali si muore


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for child in $Spawns.get_children():
		points.append((child as Node2D).global_position)
	return points
