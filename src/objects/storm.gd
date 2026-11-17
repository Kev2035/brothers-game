class_name Storm
extends Node2D
## Temporale (livello 14 del bosco; nel 15 resta solo una pioggia leggera).
## È solo SCENA, non cambia il gioco:
## - la pioggia: righe che cadono su tutta l'arena;
## - i lampi: ogni tanto la luce dell'arena si alza per un attimo (attenuata,
##   mai bianco pieno) e poi torna buio piano; insieme trema lo schermo.
## Le piattaforme scivolose invece sono le "Platform" con "wet" acceso.
##
## Si mette in un punto qualsiasi dell'arena (la posizione non conta).

@export var rain_drops := 160 ## quante gocce si vedono insieme (0 = non piove)
@export var rain_speed := 2400.0 ## velocità delle gocce
@export var rain_color := Color(0.75, 0.85, 1.0, 0.22)
@export var area := Rect2(-400, -500, 4000, 2800) ## dove piove (coordinate dell'arena)

@export_group("Lampi")
@export var lightning := true ## false = solo pioggia
@export var first_lightning := 6.0 ## secondi dall'inizio del round al primo lampo
@export var lightning_interval := Vector2(5.0, 9.0) ## poi un lampo ogni tot secondi (minimo, massimo)
@export var flash_color := Color(0.55, 0.6, 0.78) ## luce dell'arena durante il lampo (attenuata)
@export var flash_hold := 0.25 ## secondi di luce piena
@export var flash_fade := 1.0 ## secondi per tornare al buio
@export var shake := 14.0 ## di quanti pixel trema lo schermo (solo grafica)
@export var shake_time := 0.6

var lightnings := 0 ## quanti lampi ci sono stati in questo round
var _timer := 0.0
var _shake_left := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position = Vector2.ZERO
	z_index = 8 # la pioggia sta davanti a tutto
	_timer = first_lightning
	add_to_group("round_reset")
	# La pioggia si vede (poco) anche al buio.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func reset_round() -> void:
	_timer = first_lightning
	lightnings = 0
	_stop_shake()


func _exit_tree() -> void:
	_stop_shake()


func _stop_shake() -> void:
	_shake_left = 0.0
	if is_inside_tree():
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			cam.offset = Vector2.ZERO


func _process(delta: float) -> void:
	_time += delta
	if rain_drops > 0:
		queue_redraw()
	if _shake_left > 0.0:
		_shake_left -= delta
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			var k := maxf(_shake_left / maxf(shake_time, 0.01), 0.0)
			cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * k
	if not lightning:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(lightning_interval.x, lightning_interval.y)
		strike()


## Un lampo: la luce dell'arena si alza e torna giù, e lo schermo trema.
func strike() -> void:
	var game := get_tree().get_first_node_in_group("game_main")
	if game == null or not game.flash_ambient(flash_color, flash_hold, flash_fade):
		return # durante lo sguardo iniziale o il cambio di arena niente lampi
	lightnings += 1
	_shake_left = shake_time


func _draw() -> void:
	if rain_drops <= 0:
		return
	var slant := Vector2(-0.18, 1.0).normalized()
	for i in rain_drops:
		# Ogni goccia ha una sua colonna e una sua partenza, sempre le stesse.
		var fx := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var fy := fposmod(sin(float(i) * 78.233) * 12345.678 + _time * rain_speed / area.size.y * (0.8 + 0.4 * fx), 1.0)
		var top := area.position + Vector2(fx * area.size.x, fy * area.size.y)
		draw_line(top, top + slant * 70.0, rain_color, 3.0)
