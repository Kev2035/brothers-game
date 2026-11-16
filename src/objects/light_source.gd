@tool
class_name LightSource
extends Node2D
## Fonte di luce per le arene buie (dal livello 9 del bosco): una lanterna
## appesa oppure una lucciola che vola in giro. Nelle arene di notte si vede
## bene solo dentro il cerchio di luce; fuori è tutto scuro.
## Quanto è buia un'arena si decide con "ambient" nell'arena stessa.

@export var radius := 380.0 ## fin dove arriva la luce (pixel)
@export var light_color := Color(1.0, 0.86, 0.6) ## colore della luce
@export var energy := 1.1 ## quanto è forte
@export var hanging := true: ## true = lanterna appesa a una corda; false = lucciola
	set(value):
		hanging = value
		queue_redraw()
@export var wander := 0.0 ## le lucciole girano attorno al loro punto: di quanti pixel si allontanano (0 = ferma)
@export var wander_time := 9.0 ## secondi per fare un giro
@export var phase := 0.0 ## sfasa il giro, così le lucciole non si muovono tutte uguali

var time := 0.0
var _home := Vector2.ZERO
var _light: PointLight2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_home = position
	add_to_group("lights")
	_light = Fx.make_light(radius, light_color, energy)
	add_child(_light)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or wander <= 0.0:
		return
	time += delta
	# Un giro a "otto" attorno al punto di partenza: sempre uguale, si può imparare.
	var a := TAU * (time / maxf(wander_time, 0.1) + phase)
	position = _home + Vector2(cos(a), sin(a * 2.0) * 0.5) * wander


func _draw() -> void:
	if hanging:
		draw_line(Vector2(0.0, -26.0), Vector2(0.0, -3000.0), Color(0.3, 0.26, 0.2), 3.0) # la corda
		draw_rect(Rect2(-14.0, -28.0, 28.0, 8.0), Color(0.25, 0.2, 0.15))
		draw_rect(Rect2(-12.0, -20.0, 24.0, 34.0), light_color)
		draw_rect(Rect2(-14.0, 14.0, 28.0, 6.0), Color(0.25, 0.2, 0.15))
	else:
		draw_circle(Vector2.ZERO, 9.0, Color(light_color, 0.5))
		draw_circle(Vector2.ZERO, 5.0, light_color.lightened(0.5))
