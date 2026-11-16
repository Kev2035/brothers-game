@tool
class_name PivotPlatform
extends Node2D
## Piattaforma "a perno" (livello 4 del bosco): ha un perno al centro e due metà.
## A turno una metà trema per qualche secondo (avviso) e poi ruota giù di 90°:
## chi ci sta sopra cade, se non salta in tempo. Dopo un po' torna su, e più
## tardi tocca all'altra metà. La sequenza è sempre uguale e riparte da capo a
## ogni round, quindi si può imparare.
## Come le altre piattaforme di legno, ci si sale da sotto saltando.
## La metà abbassata diventa un muro solido appeso al perno: ferma i colpi e ci
## si può saltare contro (salto dai muri).
##
## Un giro completo:  [attesa] trema -> giù -> riposo -> (altra metà) trema -> giù -> riposo -> ...
## Per far cadere tante piattaforme INSIEME basta dare a tutte gli stessi tempi:
## con "right_first" si sceglie quale metà cede per prima.

@export var size := Vector2(600, 24): ## lunghezza totale (le due metà insieme) e spessore
	set(value):
		size = value
		queue_redraw()
@export var color := Color("99703f"):
	set(value):
		color = value
		queue_redraw()

@export_group("Tempi")
@export var start_delay := 0.0 ## secondi dall'inizio del round prima del primo tremolio
@export var tremble_time := 3.0 ## quanto trema una metà prima di cedere
@export var down_time := 3.0 ## quanto resta giù
@export var rest_time := 0.0 ## pausa (tutto fermo) prima che tocchi all'altra metà
@export var right_first := false ## true = cede prima la metà destra
@export var swing_time := 0.2 ## quanto ci mette a ruotare giù (solo grafica: si cade subito)

const LAYER_SOLID := 1
const LAYER_ONE_WAY := 2
const RETURN_TIME := 0.4 ## secondi che ci mette a tornare su (alla fine del tempo "giù")
const PIVOT_COLOR := Color("d8dce6")
const OUTLINE := Color("1b1b2b")
enum { SOLID, TREMBLE, DOWN }

var time := 0.0 ## secondi dall'inizio del round
var _shapes := {} ## lato (-1 sinistra, 1 destra) -> CollisionShape2D della metà orizzontale
var _walls := {} ## lato -> CollisionShape2D della metà quando pende giù (muro)
var _was_down := {-1: false, 1: false}
var _was_wall := {-1: false, 1: false}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("round_reset")
	var half := size.x / 2.0
	for side in [-1, 1]:
		var body := StaticBody2D.new()
		body.collision_layer = 0
		body.set_collision_layer_value(LAYER_ONE_WAY, true)
		body.collision_mask = 0
		body.add_to_group("one_way")
		var shape := RectangleShape2D.new()
		shape.size = Vector2(half, size.y)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = Vector2(half + side * half / 2.0, size.y / 2.0)
		cs.one_way_collision = true
		body.add_child(cs)
		add_child(body)
		_shapes[side] = cs
		# La stessa metà quando pende dal perno: un muro verticale, solido.
		var wall := StaticBody2D.new()
		wall.collision_layer = 0
		wall.set_collision_layer_value(LAYER_SOLID, true)
		wall.collision_mask = 0
		var wall_shape := RectangleShape2D.new()
		wall_shape.size = Vector2(size.y, half)
		var wcs := CollisionShape2D.new()
		wcs.shape = wall_shape
		wcs.position = Vector2(half, size.y / 2.0 + half / 2.0)
		wcs.disabled = true
		wall.add_child(wcs)
		add_child(wall)
		_walls[side] = wcs


## A ogni inizio round la sequenza riparte da capo (lo chiama il gestore partita).
func reset_round() -> void:
	time = 0.0
	_apply()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time += delta
	_apply()
	queue_redraw()


## Quanto dura un giro completo (tutte e due le metà).
func cycle_time() -> float:
	return 2.0 * (tremble_time + down_time + rest_time)


## Cosa sta facendo una metà (side: -1 sinistra, 1 destra) e da quanti secondi.
func _phase(side: int) -> Array:
	var first := 1 if right_first else -1
	var step := tremble_time + down_time + rest_time
	var t := time - start_delay - (0.0 if side == first else step)
	if t < 0.0:
		return [SOLID, 0.0]
	t = fposmod(t, 2.0 * step)
	if t < tremble_time:
		return [TREMBLE, t]
	if t < tremble_time + down_time:
		return [DOWN, t - tremble_time]
	return [SOLID, 0.0]


func is_trembling(side: int) -> bool:
	return _phase(side)[0] == TREMBLE


func is_down(side: int) -> bool:
	return _phase(side)[0] == DOWN


## La metà è appesa giù e fa da muro (dopo la rotazione, e finché non risale)?
func is_wall(side: int) -> bool:
	var ph := _phase(side)
	return ph[0] == DOWN and ph[1] >= swing_time and ph[1] <= down_time - RETURN_TIME


## Accende e spegne il "pavimento" delle due metà.
func _apply() -> void:
	for side in [-1, 1]:
		var down := is_down(side)
		if down == _was_down[side]:
			continue
		_was_down[side] = down
		(_shapes[side] as CollisionShape2D).set_deferred("disabled", down)
		if down:
			# Le armi appoggiate sopra devono "svegliarsi" per cadere anche loro.
			get_tree().call_group("pickups", "set_sleeping", false)
	for side in [-1, 1]:
		var wall := is_wall(side)
		if wall != _was_wall[side]:
			_was_wall[side] = wall
			(_walls[side] as CollisionShape2D).set_deferred("disabled", not wall)


func _draw() -> void:
	var half := size.x / 2.0
	var pivot := Vector2(half, size.y / 2.0)
	for side in [-1, 1]:
		var angle := 0.0
		var shake := Vector2.ZERO
		var c := color
		if not Engine.is_editor_hint():
			var ph := _phase(side)
			if ph[0] == TREMBLE:
				# Trema sempre più forte e si arrossa: sta per cedere.
				var k: float = ph[1] / maxf(tremble_time, 0.01)
				shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (2.0 + 4.0 * k)
				c = color.lerp(Color(0.95, 0.35, 0.2), 0.25 + 0.5 * k)
			elif ph[0] == DOWN:
				# Ruota giù in fretta, e torna su poco prima di ridiventare solida.
				var going: float = ph[1] / maxf(swing_time, 0.01)
				var coming: float = (down_time - ph[1]) / RETURN_TIME
				angle = float(side) * PI / 2.0 * clampf(minf(going, coming), 0.0, 1.0)
				c = color.darkened(0.1)
		draw_set_transform(pivot + shake, angle, Vector2.ONE)
		var r := Rect2(-half if side < 0 else 0.0, -size.y / 2.0, half, size.y)
		draw_rect(r, c)
		draw_rect(Rect2(r.position, Vector2(half, minf(8.0, size.y))), c.lightened(0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Il perno al centro.
	draw_circle(pivot, size.y * 0.75 + 3.0, OUTLINE)
	draw_circle(pivot, size.y * 0.75, PIVOT_COLOR)
