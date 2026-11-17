@tool
class_name Platform
extends StaticBody2D
## Piattaforma rettangolare per i prototipi (si disegna da sola).
## Nell'editor di Godot puoi spostarla e cambiarne la misura dall'Inspector.
## one_way = true -> ci sali da sotto saltando, e ci scendi con Giù + Salto.

@export var size := Vector2(400, 40):
	set(value):
		size = value
		queue_redraw()
@export var one_way := false:
	set(value):
		one_way = value
		queue_redraw()
@export var color := Color("3d4a6b"):
	set(value):
		color = value
		queue_redraw()

## true = piattaforma bagnata (tempesta): sopra si scivola e non ci si ferma.
@export var wet := false:
	set(value):
		wet = value
		queue_redraw()

const LAYER_SOLID := 1
const LAYER_ONE_WAY := 2


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = size / 2.0
	cs.one_way_collision = one_way
	add_child(cs)
	collision_mask = 0
	if wet:
		add_to_group("wet")
	if one_way:
		collision_layer = 0
		set_collision_layer_value(LAYER_ONE_WAY, true)
		add_to_group("one_way")
	else:
		collision_layer = 0
		set_collision_layer_value(LAYER_SOLID, true)


func _draw() -> void:
	var c := color.lightened(0.15) if one_way else color
	draw_rect(Rect2(Vector2.ZERO, size), c)
	draw_rect(Rect2(0, 0, size.x, minf(8.0, size.y)), c.lightened(0.3))
	if wet:
		# Lo strato d'acqua: una striscia azzurra sopra, con qualche riflesso.
		draw_rect(Rect2(0.0, -7.0, size.x, 13.0), Color(0.45, 0.75, 1.0, 0.85))
		var x := 20.0
		while x < size.x - 50.0:
			draw_rect(Rect2(x, -5.0, 34.0, 3.0), Color(0.9, 0.97, 1.0, 0.9))
			x += 110.0
