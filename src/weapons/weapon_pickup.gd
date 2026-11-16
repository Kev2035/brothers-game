class_name WeaponPickup
extends RigidBody2D
## Un'arma a terra (o che cade dal cielo). Cade con la fisica e si appoggia sulle
## piattaforme. Chi la tocca a mani vuote la raccoglie.
## Strato 4: i personaggi ci passano attraverso, i proiettili la ignorano.

const PICKUP_RADIUS := 75.0

var data: WeaponData
var ammo := -1 ## colpi rimasti (-1 = caricatore pieno, per le armi nuove)
## Chi ha appena lasciato quest'arma non la riprende finché non se ne allontana.
var ignore_player: Player = null
var death_y := 99999.0
## true = arma fissa nel livello: non cade, resta sospesa dove è stata messa.
var fixed := false
var _bob := 0.0


func _ready() -> void:
	add_to_group("round_temp")
	add_to_group("pickups")
	lock_rotation = true
	can_sleep = false # resta sempre "sveglia": cade se il pavimento sparisce e segue le piattaforme che si muovono
	gravity_scale = 1.6
	collision_layer = 0
	set_collision_layer_value(4, true)
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(data.length + 10.0, 26.0)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.one_way_collision = false
	add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.0
	mat.friction = 1.0
	physics_material_override = mat
	if fixed:
		freeze = true


func _physics_process(delta: float) -> void:
	_bob += delta
	queue_redraw()
	if is_queued_for_deletion():
		return # sta per sparire (nuovo round): non si può più raccogliere
	if global_position.y > death_y:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or not p.alive or p.weapon != null:
			continue
		var near := (p.global_position + Player.BODY).distance_to(global_position) < PICKUP_RADIUS
		if p == ignore_player:
			if not near:
				ignore_player = null # se n'è andato: ora può riprenderla
			continue
		if near:
			p.equip(data, ammo)
			queue_free()
			return


func _draw() -> void:
	# Alone chiaro che "pulsa", così si nota che si può raccogliere.
	var glow := 0.25 + 0.15 * sin(_bob * 6.0)
	draw_circle(Vector2.ZERO, data.length * 0.6 + 10.0, Color(1, 1, 0.8, glow * 0.6))
	WeaponDraw.draw_weapon(self, Vector2(-data.length / 2.0, 0.0), Vector2.RIGHT, data)
