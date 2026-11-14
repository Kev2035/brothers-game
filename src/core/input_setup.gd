class_name InputSetup
extends RefCounted
## Crea i comandi (azioni) di ogni giocatore a partita in corso.
## Ogni giocatore ha le sue azioni: "p0_left", "p0_jump", "p1_left", ...
## Così il codice del personaggio legge solo "il mio salto", senza sapere
## se arriva dalla tastiera o da un joystick. Funziona per N giocatori.

const ACTIONS: Array[String] = ["left", "right", "up", "down", "jump", "attack", "shield"]

## Tipi di dispositivo con cui un giocatore può entrare in partita.
const KEYBOARD_A := "kb_a" # W A S D + Spazio, mira col mouse, pugno clic sinistro / F
const KEYBOARD_B := "kb_b" # frecce + Invio
const JOYPAD := "joy"


static func action(slot: int, action_name: String) -> StringName:
	return StringName("p%d_%s" % [slot, action_name])


static func setup_player(slot: int, kind: String, device: int) -> void:
	for a in ACTIONS:
		var n := action(slot, a)
		if InputMap.has_action(n):
			InputMap.erase_action(n)
		InputMap.add_action(n, 0.3) # 0.3 = zona morta della levetta

	match kind:
		KEYBOARD_A:
			_key(slot, "left", KEY_A)
			_key(slot, "right", KEY_D)
			_key(slot, "up", KEY_W)
			_key(slot, "down", KEY_S)
			_key(slot, "jump", KEY_W)
			_key(slot, "jump", KEY_SPACE)
			_key(slot, "attack", KEY_F)
			_mouse(slot, "attack", MOUSE_BUTTON_LEFT)
			_key(slot, "shield", KEY_E)
			_mouse(slot, "shield", MOUSE_BUTTON_RIGHT)
		KEYBOARD_B:
			_key(slot, "left", KEY_LEFT)
			_key(slot, "right", KEY_RIGHT)
			_key(slot, "up", KEY_UP)
			_key(slot, "down", KEY_DOWN)
			_key(slot, "jump", KEY_UP)
			_key(slot, "attack", KEY_ENTER)
			_key(slot, "attack", KEY_KP_0)
			_key(slot, "shield", KEY_SHIFT, KEY_LOCATION_RIGHT) # solo lo Shift destro
			_key(slot, "shield", KEY_KP_1)
		JOYPAD:
			_axis(slot, "left", device, JOY_AXIS_LEFT_X, -1.0)
			_axis(slot, "right", device, JOY_AXIS_LEFT_X, 1.0)
			_axis(slot, "up", device, JOY_AXIS_LEFT_Y, -1.0)
			_axis(slot, "down", device, JOY_AXIS_LEFT_Y, 1.0)
			_button(slot, "left", device, JOY_BUTTON_DPAD_LEFT)
			_button(slot, "right", device, JOY_BUTTON_DPAD_RIGHT)
			_button(slot, "up", device, JOY_BUTTON_DPAD_UP)
			_button(slot, "down", device, JOY_BUTTON_DPAD_DOWN)
			_button(slot, "jump", device, JOY_BUTTON_A)
			_button(slot, "attack", device, JOY_BUTTON_X)
			_button(slot, "attack", device, JOY_BUTTON_RIGHT_SHOULDER)
			_button(slot, "shield", device, JOY_BUTTON_LEFT_SHOULDER)
			_button(slot, "shield", device, JOY_BUTTON_B)


static func _key(slot: int, a: String, physical: Key, location := KEY_LOCATION_UNSPECIFIED) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = physical # tasto fisico: stessa posizione su ogni layout
	e.location = location
	e.device = -1
	InputMap.action_add_event(action(slot, a), e)


static func _mouse(slot: int, a: String, button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.device = -1
	InputMap.action_add_event(action(slot, a), e)


## Come mira ogni tipo di dispositivo (vedi Player.aim_mode).
static func aim_mode_for(kind: String) -> String:
	match kind:
		KEYBOARD_A:
			return "mouse"
		JOYPAD:
			return "stick"
		_:
			return "keys"


static func _button(slot: int, a: String, device: int, button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device # solo QUESTO joystick comanda questo giocatore
	InputMap.action_add_event(action(slot, a), e)


static func _axis(slot: int, a: String, device: int, axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = device
	InputMap.action_add_event(action(slot, a), e)
