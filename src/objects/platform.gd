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
