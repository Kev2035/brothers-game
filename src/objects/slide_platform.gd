@tool
class_name SlidePlatform
extends StaticBody2D
## Piattaforma obliqua e scivolosa (livello 6 del bosco): chi ci atterra sopra
## scivola giù fino in fondo e viene "lanciato" verso la piattaforma dopo.
## Si scivola veloci: per non farsi trascinare giù bisogna saltare subito.
## Mentre si scivola si può saltare e colpire; spingendo in salita si rallenta
## un po', ma non ci si ferma. Anche le armi che ci cadono sopra scivolano giù.
## A differenza delle piattaforme di legno piatte, questa è solida: non ci si
## passa attraverso da sotto.
##
## La posizione del nodo è l'estremo SINISTRO della piattaforma.

@export var length := 600.0: ## lunghezza (pixel)
	set(value):
		length = value
		queue_redraw()
@export var thickness := 28.0:
	set(value):
		thickness = value
		queue_redraw()
@export var tilt_deg := 22.0: ## inclinazione: positivo = scende verso destra, negativo = scende verso sinistra
	set(value):
		tilt_deg = value
		rotation = deg_to_rad(value)
		queue_redraw()
@export var slide_speed := 1200.0 ## velocità con cui si scivola (pixel al secondo; la corsa è 700)
@export var color := Color("6f8f4a"):
	set(value):
		color = value
		queue_redraw()

const LAYER_SOLID := 1


func _ready() -> void:
	rotation = deg_to_rad(tilt_deg)
	if Engine.is_editor_hint():
		return
	add_to_group("slide")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, thickness)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(length, thickness) / 2.0
	add_child(cs)
	collision_layer = 0
	set_collision_layer_value(LAYER_SOLID, true)
	collision_mask = 0
	# Superficie senza attrito: anche le armi che ci cadono sopra scivolano giù.
	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	physics_material_override = mat


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, length, thickness), color)
	draw_rect(Rect2(0.0, 0.0, length, minf(8.0, thickness)), color.lightened(0.35))
	# Freccette che indicano da che parte si scivola.
	var dir := 1.0 if tilt_deg >= 0.0 else -1.0
	var mid := thickness / 2.0 + 3.0
	var x := 50.0
	while x < length - 30.0:
		draw_polyline(PackedVector2Array([Vector2(x - dir * 9.0, mid - 7.0), Vector2(x, mid), Vector2(x - dir * 9.0, mid + 7.0)]),
			color.darkened(0.45), 3.0, true)
		x += 70.0
