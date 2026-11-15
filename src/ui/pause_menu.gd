class_name PauseMenu
extends CanvasLayer
## Menu di pausa (Esc sulla tastiera, Start sul joystick).
## Tre pagine:
## - principale: Riprendi, Impostazioni, Esci dalla partita;
## - impostazioni: ordine delle arene e quante arene prima della classifica
##   (si cambiano solo nella lobby, prima di iniziare la partita);
## - fine partita: classifica finale con il vincitore, Nuova partita o Chiudi il gioco.
## Si usa con frecce/levetta + Invio/A, oppure col mouse. Esc/B torna indietro.
## Il menu non cambia niente da solo: avvisa il gestore partita (main.gd) con i segnali.

signal resume_requested
signal new_match_requested
signal quit_requested
signal end_requested
signal settings_changed(random_order: bool, arenas_per_lobby: int)

## Le scelte possibili per "quante arene prima di tornare alla lobby".
const ARENA_CHOICES: Array[int] = [3, 5, 10, 20]

var is_open := false
var page := "" ## "main", "settings" o "end"

var _random_order := false
var _arenas := 3
var _can_edit := true

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _buttons: VBoxContainer
var _note: Label
var _end_table: Scoreboard


func _init() -> void:
	layer = 20 # sopra a tutto il resto
	process_mode = Node.PROCESS_MODE_ALWAYS # funziona anche col gioco in pausa
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_end_table = Scoreboard.new()
	_end_table.top_y = 200.0
	add_child(_end_table)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(32)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 52)
	box.add_child(_title)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_buttons)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 22)
	_note.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	box.add_child(_note)


func _ready() -> void:
	# Così anche la levetta sinistra del joystick muove la scelta nel menu (non solo le frecce).
	_add_axis_event("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis_event("ui_down", JOY_AXIS_LEFT_Y, 1.0)


func _add_axis_event(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	if InputMap.has_action(action) and not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


## Apre il menu. `can_edit` = false durante la partita (le impostazioni si cambiano nella lobby).
func open(can_edit: bool, random_order: bool, arenas_per_lobby: int) -> void:
	_can_edit = can_edit
	_random_order = random_order
	_arenas = arenas_per_lobby
	is_open = true
	visible = true
	show_main()


func close() -> void:
	is_open = false
	visible = false
	_end_table.visible = false
	page = ""


func show_main() -> void:
	page = "main"
	_end_table.visible = false
	_title.text = "PAUSA"
	_title.remove_theme_color_override("font_color")
	_note.text = ""
	_clear_buttons()
	_add_button("Riprendi", func(): resume_requested.emit())
	_add_button("Impostazioni", show_settings)
	_add_button("Esci dalla partita", func(): end_requested.emit())
	_place_panel(-1.0)


func show_settings() -> void:
	page = "settings"
	_title.text = "IMPOSTAZIONI"
	_clear_buttons()
	var order := _add_button(_order_text(), func(): pass)
	order.pressed.connect(func():
		_random_order = not _random_order
		order.text = _order_text()
		settings_changed.emit(_random_order, _arenas))
	var count := _add_button(_count_text(), func(): pass)
	count.pressed.connect(func():
		var i := ARENA_CHOICES.find(_arenas)
		_arenas = ARENA_CHOICES[(i + 1) % ARENA_CHOICES.size()]
		count.text = _count_text()
		settings_changed.emit(_random_order, _arenas))
	order.disabled = not _can_edit
	count.disabled = not _can_edit
	_add_button("Indietro", show_main)
	if _can_edit:
		_note.text = "Premi su una voce per cambiarla"
	else:
		_note.text = "Si possono cambiare solo nella lobby, prima di iniziare la partita"
	_place_panel(-1.0)


## Pagina di fine partita: classifica finale (`rows` come nella classifica della lobby).
func show_end(title: String, title_color: Color, rows: Array) -> void:
	page = "end"
	_title.text = "FINE PARTITA"
	_title.remove_theme_color_override("font_color")
	_note.text = ""
	_clear_buttons()
	_add_button("Nuova partita", func(): new_match_requested.emit())
	_add_button("Chiudi il gioco", func(): quit_requested.emit())
	await _end_table.show_table(title, rows, title_color)
	_place_panel(_end_table.position.y + _end_table.size.y + 30.0)


func _order_text() -> String:
	return "Ordine delle arene:  %s" % ("a caso" if _random_order else "sempre lo stesso")


func _count_text() -> String:
	return "Arene prima della classifica:  %d" % _arenas


func _clear_buttons() -> void:
	for b in _buttons.get_children():
		_buttons.remove_child(b)
		b.queue_free()


func _add_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 34)
	b.custom_minimum_size = Vector2(620, 70)
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


## Mette il pannello al centro dello schermo (o a un'altezza precisa, se `y` >= 0)
## e seleziona il primo pulsante, così si può usare subito col joystick.
func _place_panel(y: float) -> void:
	_note.visible = _note.text != "" # niente spazio vuoto in fondo se non c'è la nota
	await get_tree().process_frame
	_panel.reset_size()
	var screen := _panel.get_viewport_rect().size
	var top := y if y >= 0.0 else (screen.y - _panel.size.y) / 2.0
	_panel.position = Vector2((screen.x - _panel.size.x) / 2.0, top)
	for b in _buttons.get_children():
		if b is Button and not b.disabled:
			b.grab_focus()
			break


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var back := event.is_action_pressed("ui_cancel")
	var start: bool = event is InputEventJoypadButton and event.pressed \
		and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	if not (back or start):
		return
	get_viewport().set_input_as_handled()
	if page == "settings" and back:
		show_main()
	elif page == "main":
		resume_requested.emit() # Esc, B o Start: si torna a giocare
