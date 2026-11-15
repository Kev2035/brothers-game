class_name Bullet
extends Node2D
## Un proiettile. A ogni passo controlla se tra la posizione di prima e quella
## nuova c'è un personaggio o un muro (così anche se va velocissimo non
## "salta" oltre le cose). Le piattaforme attraversabili non lo fermano.
## Con "gravity" maggiore di 0 cade facendo una curva (pietra della fionda).

const WORLD_MASK := 1 ## solo i muri/pavimenti solidi (strato 1)
const OUTLINE := Color("1b1b2b")

var velocity := Vector2.ZERO
var damage := 10.0
var shooter: Player = null
var max_distance := 2500.0
var gravity := 0.0 ## caduta (pixel al secondo, ogni secondo); 0 = va dritto
var radius := 0.0 ## 0 = scia luminosa; più di 0 = palla
var color := Color("ffe08a")
var _travelled := 0.0


func _ready() -> void:
	add_to_group("round_temp")
	add_to_group("bullets")


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + velocity * delta + Vector2(0.0, 0.5 * gravity * delta * delta)
	var dir := (to - from).normalized()

	# Il personaggio più vicino lungo il tragitto (chi spara non si colpisce).
	var best_t := INF
	var victim: Player = null
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or p == shooter or not p.alive:
			continue
		var t := _segment_circle(from, to, p.global_position + Player.BODY, Player.BODY_RADIUS + 4.0)
		if t >= 0.0 and t < best_t:
			best_t = t
			victim = p

	# Il muro più vicino lungo il tragitto.
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	var wall := get_world_2d().direct_space_state.intersect_ray(query)
	var wall_t := INF
	if not wall.is_empty():
		wall_t = from.distance_to(wall.position) / maxf(from.distance_to(to), 0.001)

	if victim != null and best_t <= wall_t:
		var hit_pos := from.lerp(to, best_t)
		var hit := victim.take_hit(dir, hit_pos - dir * 60.0, damage, shooter)
		Fx.sparks(get_parent(), hit_pos, Color(1, 0.3, 0.3) if hit else Color(0.6, 0.9, 1.0), 8)
		queue_free()
		return
	if not wall.is_empty():
		Fx.sparks(get_parent(), wall.position, color, 6)
		queue_free()
		return

	global_position = to
	velocity.y += gravity * delta
	_travelled += from.distance_to(to)
	if _travelled > max_distance:
		queue_free()
	queue_redraw()


## Dove il segmento a->b entra nel cerchio (0..1), oppure -1 se non lo tocca.
static func _segment_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> float:
	var d := b - a
	var f := a - c
	var aa := d.dot(d)
	if aa < 0.0001:
		return 0.0 if f.length() <= r else -1.0
	var bb := 2.0 * f.dot(d)
	var cc := f.dot(f) - r * r
	if cc <= 0.0:
		return 0.0 # parte già dentro
	var disc := bb * bb - 4.0 * aa * cc
	if disc < 0.0:
		return -1.0
	var t := (-bb - sqrt(disc)) / (2.0 * aa)
	return t if t >= 0.0 and t <= 1.0 else -1.0


func _draw() -> void:
	if radius > 0.0:
		draw_circle(Vector2.ZERO, radius + 3.0, OUTLINE)
		draw_circle(Vector2.ZERO, radius, color)
		return
	var tail := -velocity.normalized() * 30.0
	draw_line(tail, Vector2.ZERO, Color(color, 0.35), 7.0, true)
	draw_line(tail * 0.5, Vector2.ZERO, color, 5.0, true)
