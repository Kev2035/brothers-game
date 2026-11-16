@tool
class_name SpiralSlide
extends Node2D
## Scivolo a spirale (livello 7 del bosco): gira attorno a un albero sottile e
## porta a una piattaforma più in basso. È uno scivolo APERTO:
## - ci si sale dall'imbocco in alto, oppure atterrandoci sopra in un punto
##   qualsiasi (dei tratti davanti al tronco): la scivolata parte da lì;
## - si scende da soli, ma si può saltare fuori quando si vuole (tasto del salto)
##   o lasciarsi cadere (Giù);
## - finché si scivola NON si può essere colpiti;
## - quando lo scivolo passa dietro al tronco il personaggio sparisce e ricompare
##   dall'altra parte (non è 3D vero: è un trucco).
##
## La posizione del nodo è il centro del tronco, all'altezza dell'imbocco.
## L'imbocco è a destra (a sinistra con "mirrored"); con un numero di giri che
## finisce con ",5" l'uscita è dal lato opposto, "height" pixel più in basso.
## Sia l'imbocco sia l'uscita vanno messi all'altezza di una piattaforma.

@export var radius := 130.0: ## quanto sporge lo scivolo dal centro del tronco
	set(value):
		radius = value
		queue_redraw()
@export var height := 900.0: ## dislivello tra imbocco e uscita
	set(value):
		height = value
		queue_redraw()
@export var turns := 2.5: ## giri attorno al tronco (2.5 = esce dal lato opposto)
	set(value):
		turns = value
		queue_redraw()
@export var duration := 1.8 ## secondi per arrivare in fondo
@export var mirrored := false: ## true = l'imbocco è a sinistra
	set(value):
		mirrored = value
		queue_redraw()
@export var trunk_width := 120.0: ## larghezza del tronco disegnato
	set(value):
		trunk_width = value
		queue_redraw()
@export var entry_radius := 45.0 ## quanto bisogna avvicinarsi all'imbocco per essere presi
@export var catch_radius := 36.0 ## quanto vicino allo scivolo bisogna atterrare per salirci al volo
@export var regrab_time := 0.3 ## secondi in cui, dopo essere saltati fuori, lo scivolo non ti riprende
@export var exit_speed := 300.0 ## spinta di lato quando si esce
@export var color := Color("6f8f4a")
@export var trunk_color := Color(0.3, 0.22, 0.15)

var _riders := {} ## personaggio -> secondi di scivolo già fatti (0 = imbocco, "duration" = uscita)
var _cooldown := {} ## personaggio -> secondi in cui lo scivolo non lo riprende


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("round_reset")


func _exit_tree() -> void:
	_release_all()


## Nuovo round: chi era sullo scivolo viene lasciato andare.
func reset_round() -> void:
	_release_all()


func _release_all() -> void:
	for p in _riders.keys():
		if is_instance_valid(p) and p.riding:
			p.end_ride(Vector2.ZERO)
	_riders.clear()
	_cooldown.clear()


## Angolo lungo la spirale (k: 0 = imbocco, 1 = uscita).
func _angle(k: float) -> float:
	return turns * TAU * k


## Punto dello scivolo rispetto al nodo.
func point(k: float) -> Vector2:
	var side := -1.0 if mirrored else 1.0
	return Vector2(side * radius * cos(_angle(k)), height * k)


## In questo punto lo scivolo passa dietro al tronco?
func is_behind(k: float) -> bool:
	return sin(_angle(k)) < -0.05


func entry_point() -> Vector2:
	return global_position + point(0.0)


func exit_point() -> Vector2:
	return global_position + point(1.0)


func is_riding(p: Player) -> bool:
	return _riders.has(p)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for p in _cooldown.keys():
		_cooldown[p] -= delta
		if _cooldown[p] <= 0.0:
			_cooldown.erase(p)
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or not p.alive or p.riding or _cooldown.has(p):
			continue
		if p.is_on_floor():
			# Coi piedi per terra si sale solo dall'imbocco.
			if p.global_position.distance_to(entry_point()) < entry_radius:
				_start(p, 0.0)
		elif p.velocity.y >= 0.0:
			# In caduta: se atterra su un tratto davanti al tronco, scivola da lì.
			var k := _catch_point(p, delta)
			if k >= 0.0:
				_start(p, k)
	for p in _riders.keys():
		if not is_instance_valid(p) or not p.riding:
			_riders.erase(p) # nel frattempo è cambiato il round
			continue
		var t: float = _riders[p] + delta
		var k := t / maxf(duration, 0.05)
		if k >= 1.0:
			_riders.erase(p)
			p.global_position = exit_point()
			p.end_ride(Vector2(signf(point(1.0).x) * exit_speed, 0.0))
			continue
		# Scivolo aperto: col salto si salta fuori, con Giù ci si lascia cadere.
		if p.jump_just_pressed() or p.down_is_held():
			var side := (point(k + 0.01).x - point(k).x) / (0.01 * maxf(duration, 0.05)) # velocità laterale dello scivolo in quel punto
			_riders.erase(p)
			_cooldown[p] = regrab_time
			if p.down_is_held():
				p.end_ride(Vector2(0.0, 200.0))
			else:
				p.end_ride(Vector2(clampf(side, -p.run_speed, p.run_speed), -p.jump_speed()))
			continue
		_riders[p] = t
		p.global_position = global_position + point(k)
		p.visible = not is_behind(k) # dietro al tronco non si vede
		p.facing = 1.0 if point(k + 0.01).x > point(k).x else -1.0


func _start(p: Player, k: float) -> void:
	_riders[p] = k * duration
	p.start_ride()
	p.global_position = global_position + point(k)


## Se il personaggio sta atterrando sullo scivolo, il punto in cui lo tocca (da 0 a 1);
## altrimenti -1. Contano solo i tratti davanti al tronco, e non l'ultimo pezzetto
## (lì c'è già la piattaforma d'arrivo).
func _catch_point(p: Player, delta: float) -> float:
	var feet := p.global_position - global_position
	var before := feet - p.velocity * delta * 0.5 # a metà dell'ultimo passo: chi cade veloce non "salta oltre"
	var steps := int(turns * 40.0)
	var best := -1.0
	var best_d := catch_radius
	for i in range(1, steps):
		var k := float(i) / steps
		if k > 0.95 or is_behind(k):
			continue
		var pt := point(k)
		var d := minf(pt.distance_to(feet), pt.distance_to(before))
		if d < best_d:
			best_d = d
			best = k
	return best


func _draw() -> void:
	var steps := int(turns * 28.0) + 4
	# 1) I tratti che passano DIETRO al tronco.
	_draw_band(steps, true)
	# 2) Il tronco, che li copre.
	draw_rect(Rect2(-trunk_width / 2.0, -80.0, trunk_width, height + 160.0), trunk_color)
	# 3) I tratti davanti.
	_draw_band(steps, false)
	# Imbocco e uscita.
	draw_circle(point(0.0), 16.0, color.lightened(0.4))
	draw_circle(point(1.0), 12.0, color.darkened(0.2))


func _draw_band(steps: int, behind: bool) -> void:
	for i in steps:
		var k0 := float(i) / steps
		var k1 := float(i + 1) / steps
		if (sin(_angle((k0 + k1) / 2.0)) < 0.0) != behind:
			continue
		var c := color.darkened(0.45) if behind else color
		draw_line(point(k0) + Vector2(0, 14), point(k1) + Vector2(0, 14), c.darkened(0.3), 34.0)
		draw_line(point(k0) + Vector2(0, 8), point(k1) + Vector2(0, 8), c, 22.0)
