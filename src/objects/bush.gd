@tool
class_name Bush
extends Node2D
## Cespuglio (dal livello 8 del bosco): un nascondiglio. Chi ci sta dentro non
## si vede per niente: né il personaggio, né il puntino di mira, né l'arma.
## Si resta però colpibili, e i colpi che partono dal cespuglio si vedono.
## Quando qualcuno si muove o colpisce lì dentro il cespuglio si agita un po':
## un indizio per chi guarda con attenzione.
## Anche le armi cadute dentro restano nascoste.
##
## La posizione del nodo è l'angolo in alto a sinistra; il bordo in basso va
## appoggiato sul pavimento.

@export var size := Vector2(320, 150): ## larghezza e altezza (il personaggio è alto circa 90)
	set(value):
		size = value
		queue_redraw()
@export var color := Color("2f5a2c"):
	set(value):
		color = value
		queue_redraw()
@export var rustle := true ## true = si agita quando qualcuno dentro si muove o attacca
@export var edge := 26.0 ## quanto bisogna entrare (pixel dal bordo) per sparire del tutto

var _shake := 0.0


func _ready() -> void:
	z_index = 20 # si disegna SOPRA a personaggi e armi: è lui che li copre
	if Engine.is_editor_hint():
		return
	add_to_group("hide_zones")


## Un personaggio col centro del corpo in questo punto (del mondo) è nascosto?
func hides(point: Vector2) -> bool:
	return Rect2(global_position + Vector2(edge, 0.0), size - Vector2(edge * 2.0, 0.0)).has_point(point)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not rustle:
		return
	var moving := false
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p != null and p.alive and p.concealed and hides(p.global_position + Player.BODY) \
				and (p.velocity.length() > 60.0 or p.is_attacking()):
			moving = true
	_shake = move_toward(_shake, 1.0 if moving else 0.0, delta * (8.0 if moving else 3.0))
	if _shake > 0.0:
		queue_redraw()


func _draw() -> void:
	var wobble := Vector2.ZERO
	if _shake > 0.0:
		wobble = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * 3.0 * _shake
	# Corpo pieno (copre tutto quello che c'è dietro) con la cima a "ciuffi".
	draw_rect(Rect2(0.0, size.y * 0.3, size.x, size.y * 0.7), color)
	var bumps := maxi(int(size.x / 70.0), 2)
	var r := size.x / bumps * 0.62
	for i in bumps:
		var cx := size.x * (float(i) + 0.5) / bumps
		draw_circle(Vector2(cx, maxf(r, size.y * 0.34)) + wobble, r, color)
		draw_circle(Vector2(cx - r * 0.25, maxf(r, size.y * 0.34) - r * 0.25) + wobble, r * 0.45, color.lightened(0.12))
