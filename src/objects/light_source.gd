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
@export var start_off := false ## true = parte spenta: la accende un interruttore, per qualche secondo

var time := 0.0
var _home := Vector2.ZERO
var _light: PointLight2D
var _on_left := 0.0 ## luci a interruttore: secondi di luce che restano


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_home = position
	add_to_group("lights")
	add_to_group("round_reset")
	_light = Fx.make_light(radius, light_color, 0.0 if start_off else energy)
	add_child(_light)


## A ogni inizio round le luci a interruttore tornano spente.
func reset_round() -> void:
	_on_left = 0.0
	if start_off and _light != null:
		_light.energy = 0.0


## Accende la luce per "seconds" secondi (la chiamano gli interruttori).
func turn_on(seconds: float) -> void:
	_on_left = seconds


## La luce è accesa in questo momento?
func is_on() -> bool:
	return not start_off or _on_left > 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if start_off:
		_on_left = maxf(_on_left - delta, 0.0)
		# Si accende in fretta e si spegne piano.
		_light.energy = move_toward(_light.energy, energy if _on_left > 0.0 else 0.0, delta * (6.0 if _on_left > 0.0 else 2.0))
		queue_redraw()
	if wander <= 0.0:
		return
	time += delta
	# Un giro a "otto" attorno al punto di partenza: sempre uguale, si può imparare.
	var a := TAU * (time / maxf(wander_time, 0.1) + phase)
	position = _home + Vector2(cos(a), sin(a * 2.0) * 0.5) * wander


func _draw() -> void:
	if hanging:
		draw_line(Vector2(0.0, -26.0), Vector2(0.0, -3000.0), Color(0.3, 0.26, 0.2), 3.0) # la corda
		draw_rect(Rect2(-14.0, -28.0, 28.0, 8.0), Color(0.25, 0.2, 0.15))
		var lamp_on := Engine.is_editor_hint() or is_on()
		draw_rect(Rect2(-12.0, -20.0, 24.0, 34.0), light_color if lamp_on else light_color.darkened(0.75))
		draw_rect(Rect2(-14.0, 14.0, 28.0, 6.0), Color(0.25, 0.2, 0.15))
	else:
		draw_circle(Vector2.ZERO, 9.0, Color(light_color, 0.5))
		draw_circle(Vector2.ZERO, 5.0, light_color.lightened(0.5))
