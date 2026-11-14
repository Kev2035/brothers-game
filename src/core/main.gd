extends Node2D
## Scena principale del prototipo di movimento.
## - Un giocatore entra premendo il suo tasto di salto (fino a 4 giocatori).
## - Se cadi nel vuoto ricompari dopo un attimo e ti si conta una caduta.
## - R (tastiera) o Start (joystick) rimette tutti al punto di partenza.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MAX_PLAYERS := 4
const COLORS: Array[Color] = [Color("e8524a"), Color("4a90e8"), Color("5cc46a"), Color("f2c84b")]
const COLOR_NAMES: Array[String] = ["Rosso", "Blu", "Verde", "Giallo"]
const RESPAWN_DELAY := 1.0

@onready var arena: Arena = $TestArena
@onready var hud: Label = $HUD/Label

var players: Array[Player] = []
var falls: Array[int] = []
var device_names: Array[String] = []
var _joined := {} # "kb_a" / "kb_b" / "joy_0" ... -> indice giocatore


func _ready() -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	var key := ""
	var kind := ""
	var device := -1
	if event is InputEventKey and event.pressed and not event.is_echo():
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_W or k == KEY_SPACE:
			key = InputSetup.KEYBOARD_A
			kind = InputSetup.KEYBOARD_A
		elif k == KEY_UP:
			key = InputSetup.KEYBOARD_B
			kind = InputSetup.KEYBOARD_B
		elif k == KEY_R:
			reset_positions()
			return
	elif event is InputEventJoypadButton and event.pressed:
		var b := event as InputEventJoypadButton
		if b.button_index == JOY_BUTTON_A:
			key = "joy_%d" % b.device
			kind = InputSetup.JOYPAD
			device = b.device
		elif b.button_index == JOY_BUTTON_START:
			reset_positions()
			return

	if key != "" and not _joined.has(key) and players.size() < MAX_PLAYERS:
		add_player(kind, device, key)


func add_player(kind: String, device: int, key: String) -> Player:
	var slot := players.size()
	InputSetup.setup_player(slot, kind, device)
	var p: Player = PLAYER_SCENE.instantiate()
	p.slot = slot
	p.color = COLORS[slot]
	p.aim_mode = InputSetup.aim_mode_for(kind)
	p.device = device
	p.death_y = arena.death_y
	p.side_limits = arena.side_limits
	add_child(p)
	p.respawn(arena.spawn_points()[slot])
	p.died.connect(_on_player_died)
	players.append(p)
	falls.append(0)
	device_names.append(_describe(kind, device))
	_joined[key] = slot
	_update_hud()
	return p


func reset_positions() -> void:
	var spawns := arena.spawn_points()
	for p in players:
		p.respawn(spawns[p.slot])


func _on_player_died(p: Player) -> void:
	falls[p.slot] += 1
	_update_hud()
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_instance_valid(p):
		p.respawn(arena.spawn_points()[p.slot])


func _describe(kind: String, device: int) -> String:
	match kind:
		InputSetup.KEYBOARD_A:
			return "tastiera WASD"
		InputSetup.KEYBOARD_B:
			return "tastiera frecce"
		_:
			var joy_name := Input.get_joy_name(device)
			if joy_name.is_empty():
				return "joystick %d" % (device + 1)
			return "joystick %d - %s" % [device + 1, joy_name]


func _update_hud() -> void:
	var lines: Array[String] = []
	lines.append("PROTOTIPO 1 - MOVIMENTO        R / Start = rimetti tutti al via")
	if players.size() < MAX_PLAYERS:
		lines.append("Per entrare: W o Spazio (tastiera + mouse)  -  Freccia SU (tastiera frecce)  -  A sul joystick")
	lines.append("Tastiera + mouse: A/D muovi, W/Spazio salta, S giu, MIRA COL MOUSE, pugno clic sinistro (o F), SCUDO clic destro (o E)")
	lines.append("Tastiera frecce: frecce muovi e mira (8 direzioni), Freccia su salta, pugno Invio, scudo Shift destro")
	lines.append("Joystick: levetta sinistra muovi, levetta DESTRA mira a 360 gradi, A salta, X o RB pugno, B o LB scudo")
	lines.append("Doppio salto. Contro un muro premi salto per saltare dal muro (tieni SU per scalare). Giu + salto = scendi. Pugno in basso in aria = rimbalzo")
	for i in players.size():
		lines.append("%s (%s): cadute %d" % [COLOR_NAMES[i], device_names[i], falls[i]])
	hud.text = "\n".join(lines)
