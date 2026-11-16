@tool
class_name LightSwitch
extends Node2D
## Interruttore (livelli bui del bosco): si attiva con un colpo qualsiasi (pugno,
## arma, freccia, pietra). Accende per qualche secondo una lanterna lontana,
## scelta nell'Inspector ("target"): di solito quella della zona opposta, dove
## potrebbe nascondersi l'avversario. Poi la lanterna si spegne da sola.
## L'interruttore fa una lucina sua, così al buio si riesce a ritrovarlo.
##
## La posizione del nodo è il centro del pulsante.

@export var target: NodePath ## la lanterna (LightSource) che questo interruttore accende
@export var on_time := 4.0 ## per quanti secondi resta accesa
@export var hit_radius := 36.0 ## quanto è "grosso" come bersaglio
@export var color := Color(1.0, 0.75, 0.3):
	set(value):
		color = value
		queue_redraw()

var _pressed := 0.0 ## secondi in cui il pulsante resta "premuto" (solo grafica)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("hittables")
	add_child(Fx.make_light(80.0, color, 0.55)) # lucina per ritrovarlo al buio


## La lanterna comandata da questo interruttore.
func lamp() -> LightSource:
	return get_node_or_null(target) as LightSource


## Chiamata quando un colpo lo prende (pugni, armi corpo a corpo, proiettili).
func on_hit(_by: Player) -> void:
	_pressed = 0.25
	var l := lamp()
	if l != null:
		l.turn_on(on_time)
	Fx.sparks(get_parent(), global_position, color, 8)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_pressed = maxf(_pressed - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var l: LightSource = null if Engine.is_editor_hint() else lamp()
	var active := l != null and l.is_on()
	draw_rect(Rect2(-7.0, 0.0, 14.0, 44.0), Color(0.35, 0.3, 0.25)) # il palo
	draw_circle(Vector2.ZERO, 26.0, Color(0.2, 0.18, 0.16))
	draw_circle(Vector2.ZERO, 20.0 - 4.0 * (_pressed / 0.25), color.lightened(0.4) if active else color)
