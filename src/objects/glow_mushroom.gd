@tool
class_name GlowMushroom
extends Node2D
## Fungo luminoso (livelli bui del bosco): spento non si vede. Quando qualcuno
## ci passa sopra coi piedi si accende per un po' e illumina la zona: rivela
## chi l'ha calpestato. Per non farsi scoprire bisogna ricordarsi dov'è e
## saltarlo. Si può anche usare apposta, per vedere dove si è.
##
## La posizione del nodo è il punto in cui il fungo tocca il pavimento.

@export var trigger := 55.0 ## quanto vicino (pixel) bisogna passare coi piedi per accenderlo
@export var light_radius := 260.0 ## fin dove illumina
@export var glow_time := 1.8 ## secondi di luce dopo che ci si è passati sopra
@export var color := Color(0.5, 0.95, 1.0):
	set(value):
		color = value
		queue_redraw()

var _left := 0.0 ## secondi di luce che restano
var _light: PointLight2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("round_reset")
	_light = Fx.make_light(light_radius, color, 0.0)
	_light.position = Vector2(0.0, -30.0)
	add_child(_light)


func reset_round() -> void:
	_left = 0.0


func is_lit() -> bool:
	return _left > 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p != null and p.alive and not p.riding and p.global_position.distance_to(global_position) < trigger:
			_left = glow_time
	_left = maxf(_left - delta, 0.0)
	# Si accende di colpo e si spegne piano.
	_light.energy = 1.3 * minf(_left / (glow_time * 0.5), 1.0)
	queue_redraw()


func _draw() -> void:
	var lit := not Engine.is_editor_hint() and _left > 0.0
	var cap := color if lit else color.darkened(0.55)
	draw_rect(Rect2(-5.0, -22.0, 10.0, 22.0), Color(0.85, 0.85, 0.8) if lit else Color(0.45, 0.45, 0.42)) # gambo
	draw_circle(Vector2(0.0, -24.0), 17.0, cap) # cappello
	draw_rect(Rect2(-18.0, -24.0, 36.0, 10.0), Color(0.85, 0.85, 0.8) if lit else Color(0.45, 0.45, 0.42))
