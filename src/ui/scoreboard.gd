class_name Scoreboard
extends PanelContainer
## Classifica che si vede nella lobby dopo un giro di arene.
## Ogni riga: posizione, nome (nel colore del giocatore), vittorie, eliminazioni, cadute, danni fatti.

const HEADERS: Array[String] = ["", "Giocatore", "Vittorie", "Eliminazioni", "Cadute", "Danni"]

@export var top_y := 300.0 ## distanza della tabella dal bordo alto dello schermo

var _title: Label
var _grid: GridContainer


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.82)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(28)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	box.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = HEADERS.size()
	_grid.add_theme_constant_override("h_separation", 48)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	visible = false


## rows: un Dictionary per giocatore con name, color, wins, kills, falls, damage.
## Vengono messi in ordine: prima chi ha più vittorie, a pari vittorie chi ha più eliminazioni.
## `title_color`: colore del titolo (per esempio il colore di chi ha vinto).
func show_table(title: String, rows: Array, title_color := Color.WHITE) -> void:
	sort_rows(rows)
	_title.text = title
	_title.add_theme_color_override("font_color", title_color)
	for child in _grid.get_children():
		child.queue_free()
	for h in HEADERS:
		_add_cell(h, Color(0.7, 0.7, 0.8), 24)
	for i in rows.size():
		var r: Dictionary = rows[i]
		_add_cell("%d°" % (i + 1), Color.WHITE, 30)
		_add_cell(r.name, r.color, 30)
		for v in [r.wins, r.kills, r.falls, int(r.damage)]:
			_add_cell(str(v), Color.WHITE, 30)
	visible = true
	# Al centro dello schermo, sotto le scritte in alto: si calcola dopo un fotogramma,
	# quando Godot sa quanto è grande la tabella.
	await get_tree().process_frame
	reset_size()
	var screen := get_viewport_rect().size
	position = Vector2((screen.x - size.x) / 2.0, top_y)


## Mette in ordine le righe: prima chi ha più vittorie, a pari vittorie chi ha più eliminazioni.
static func sort_rows(rows: Array) -> void:
	rows.sort_custom(func(a, b):
		if a.wins != b.wins:
			return a.wins > b.wins
		return a.kills > b.kills)


func _add_cell(text: String, color: Color, font_size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color("1b1b2b"))
	_grid.add_child(l)
