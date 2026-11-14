extends Node2D
## Scena principale del prototipo (tappa 2a: vita, danni e round).
## - Un giocatore entra premendo il suo tasto di salto (fino a 4 posti).
## - F2 aggiunge il manichino d'allenamento / cambia cosa fa; F3 lo toglie.
## - Con almeno 2 partecipanti si gioca a round: chi resta vivo vince il round,
##   poi tutti ricompaiono con la vita piena. Da soli si ricompare subito.
## - R (tastiera) o Start (joystick) fa ripartire il round.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MAX_PLAYERS := 4
const COLORS: Array[Color] = [Color("e8524a"), Color("4a90e8"), Color("5cc46a"), Color("f2c84b")]
const COLOR_NAMES: Array[String] = ["Rosso", "Blu", "Verde", "Giallo"]
const DUMMY_COLOR := Color("9a9aa6")
const RESPAWN_DELAY := 1.0
const ROUND_END_DELAY := 2.5
## Le armi disponibili (le "schede" in src/weapons/). Per aggiungerne una: nuovo .tres e una riga qui.
const WEAPONS: Array[WeaponData] = [
	preload("res://src/weapons/pistol.tres"),
	preload("res://src/weapons/smg.tres"),
	preload("res://src/weapons/shotgun.tres"),
]
const WEAPON_FIRST_DELAY := 2.0 ## secondi dall'inizio del round alla prima arma
const WEAPON_INTERVAL := Vector2(4.0, 7.0) ## poi un'arma ogni 4-7 secondi
const MAX_PICKUPS := 3 ## al massimo 3 armi a terra insieme
## Scritte di vittoria a caso: chi ha vinto si capisce dal colore della scritta.
const WIN_PHRASES: Array[String] = [
	"GG", "GG EZ", "EZ", "TOO EASY", "GET REKT", "REKT", "OWNED", "FLAWLESS",
	"CLUTCH!", "SKILL DIFF", "GIT GUD", "NO CHANCE", "SHEESH", "BIG BRAIN",
	"DOMINATED", "SIT DOWN", "OUTPLAYED", "NICE TRY", "BOOM!", "UNSTOPPABLE",
	"TOO GOOD", "LET'S GOOO", "BUILT DIFFERENT", "CALCULATED",
]

@onready var arena: Arena = $TestArena
@onready var hud: Label = $HUD/Label

## Un posto per giocatore (null = posto libero). L'indice è lo "slot".
var players: Array = [null, null, null, null]
var names: Array[String] = ["", "", "", ""]
var wins: Array[int] = [0, 0, 0, 0]
var falls: Array[int] = [0, 0, 0, 0]
var kills: Array[int] = [0, 0, 0, 0]
var damage_dealt: Array[float] = [0.0, 0.0, 0.0, 0.0]
var dummy: Player = null
var round_over := false
## false = le armi non cadono da sole (utile per le prove, e in futuro per la lobby).
var auto_weapons := true
var _spawn_timer := WEAPON_FIRST_DELAY
var _give_index := 0
var _hud_timer := 0.0
var _round_id := 0 ## cambia a ogni round: i timer di un round vecchio non fanno danni

var _joined := {} # "kb_a" / "kb_b" / "joy_0" ... -> slot
var _banner: Label
var camera: Camera2D


func _ready() -> void:
	# Telecamera: inquadra tutta l'area dell'arena (più grande dello schermo),
	# così i personaggi appaiono più piccoli e l'arena più ampia.
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	frame_arena(arena)
	_banner = Label.new()
	_banner.position = Vector2(0, 400)
	_banner.size = Vector2(1920, 160)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 110)
	_banner.add_theme_constant_override("outline_size", 18)
	_banner.add_theme_color_override("font_outline_color", Color("1b1b2b"))
	_banner.visible = false
	$HUD.add_child(_banner)
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
			start_round()
			return
		elif k == KEY_F2:
			toggle_dummy()
			return
		elif k == KEY_F3:
			remove_dummy()
			return
		elif k == KEY_F4:
			give_weapon_to_all()
			return
	elif event is InputEventJoypadButton and event.pressed:
		var b := event as InputEventJoypadButton
		if b.button_index == JOY_BUTTON_A:
			key = "joy_%d" % b.device
			kind = InputSetup.JOYPAD
			device = b.device
		elif b.button_index == JOY_BUTTON_START:
			start_round()
			return

	if key != "" and not _joined.has(key):
		add_player(kind, device, key)


func frame_arena(a: Arena) -> void:
	var view := Vector2(get_viewport().get_visible_rect().size)
	if view.x <= 0.0:
		view = Vector2(1920, 1080)
	camera.position = a.bounds.get_center()
	camera.zoom = Vector2.ONE * minf(view.x / a.bounds.size.x, view.y / a.bounds.size.y)


func _free_slot() -> int:
	for i in MAX_PLAYERS:
		if players[i] == null:
			return i
	return -1


func participants() -> Array[Player]:
	var list: Array[Player] = []
	for p in players:
		if p != null:
			list.append(p)
	return list


func _spawn(slot: int, color: Color) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.slot = slot
	p.color = color
	p.death_y = arena.death_y
	p.side_limits = arena.side_limits
	add_child(p)
	p.respawn(arena.spawn_points()[slot])
	p.died.connect(_on_player_died)
	p.damaged.connect(_on_player_damaged)
	players[slot] = p
	wins[slot] = 0
	falls[slot] = 0
	kills[slot] = 0
	damage_dealt[slot] = 0.0
	return p


func add_player(kind: String, device: int, key: String) -> Player:
	var slot := _free_slot()
	if slot < 0:
		return null
	InputSetup.setup_player(slot, kind, device)
	var p := _spawn(slot, COLORS[slot])
	p.aim_mode = InputSetup.aim_mode_for(kind)
	p.device = device
	names[slot] = "%s (%s)" % [COLOR_NAMES[slot], _describe(kind, device)]
	_joined[key] = slot
	_update_hud()
	return p


## F2: se non c'è, aggiunge il manichino fermo; se c'è, gli cambia comportamento.
func toggle_dummy() -> void:
	if dummy != null:
		dummy.bot.next_mode()
		_update_hud()
		return
	var slot := _free_slot()
	if slot < 0:
		return
	dummy = _spawn(slot, DUMMY_COLOR)
	dummy.bot = DummyBrain.new()
	dummy.aim_mode = "bot"
	dummy.facing = -1.0
	_update_hud()


func remove_dummy() -> void:
	if dummy == null:
		return
	players[dummy.slot] = null
	dummy.queue_free()
	dummy = null
	start_round()


## Nuovo round: tutti ricompaiono al loro punto di partenza con la vita piena.
func start_round() -> void:
	_round_id += 1
	round_over = false
	_banner.visible = false
	# Via proiettili, armi a terra ed effetti del round precedente.
	for node in get_tree().get_nodes_in_group("round_temp"):
		node.queue_free()
	_spawn_timer = WEAPON_FIRST_DELAY
	var spawns := arena.spawn_points()
	for p in participants():
		p.respawn(spawns[p.slot])
	_update_hud()


func _physics_process(delta: float) -> void:
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.2
		_update_hud() # tiene aggiornate le munizioni nella scritta
	if round_over or participants().is_empty() or not auto_weapons:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(WEAPON_INTERVAL.x, WEAPON_INTERVAL.y)
		if get_tree().get_nodes_in_group("pickups").size() < MAX_PICKUPS:
			spawn_weapon()


## Fa cadere un'arma dal cielo (a caso, se non si dice quale) in un punto a caso dell'arena.
func spawn_weapon(data: WeaponData = null, x := NAN) -> WeaponPickup:
	var b := arena.bounds
	var pickup := WeaponPickup.new()
	pickup.data = data if data != null else WEAPONS.pick_random()
	pickup.death_y = arena.death_y
	if is_nan(x):
		x = randf_range(b.position.x + b.size.x * 0.12, b.end.x - b.size.x * 0.12)
	pickup.position = Vector2(x, b.position.y - 120.0)
	add_child(pickup)
	return pickup


## F4 (per le prove): dà a tutti la stessa arma, a turno pistola -> mitra -> pompa.
func give_weapon_to_all() -> void:
	var data := WEAPONS[_give_index]
	_give_index = (_give_index + 1) % WEAPONS.size()
	for p in participants():
		if p.alive:
			p.equip(data)
	_update_hud()


func _on_player_damaged(_victim: Player, attacker: Player, amount: float) -> void:
	if attacker != null and is_instance_valid(attacker):
		damage_dealt[attacker.slot] += amount


func _on_player_died(p: Player, cause: String) -> void:
	_spawn_puff(p.global_position, p.color)
	if cause == "fall":
		falls[p.slot] += 1
	var killer := p.last_attacker
	if killer != null and is_instance_valid(killer) and killer != p:
		kills[killer.slot] += 1
	_update_hud()

	var everyone := participants()
	if everyone.size() <= 1:
		# Da soli non ci sono round: si ricompare dopo un attimo.
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		if is_instance_valid(p) and not p.alive:
			p.respawn(arena.spawn_points()[p.slot])
		return

	if round_over:
		return
	var alive: Array[Player] = []
	for q in everyone:
		if q.alive:
			alive.append(q)
	if alive.size() > 1:
		return

	round_over = true
	if alive.size() == 1:
		var winner := alive[0]
		wins[winner.slot] += 1
		_banner.text = WIN_PHRASES.pick_random()
		_banner.add_theme_color_override("font_color", winner.color)
	else:
		_banner.text = "PAREGGIO!"
		_banner.add_theme_color_override("font_color", Color.WHITE)
	_banner.visible = true
	_update_hud()
	var this_round := _round_id
	await get_tree().create_timer(ROUND_END_DELAY).timeout
	if round_over and this_round == _round_id:
		start_round()


## Sbuffo di fumo del colore del personaggio quando muore.
func _spawn_puff(pos: Vector2, color: Color) -> void:
	var b := arena.bounds
	Fx.puff(self, Vector2(clampf(pos.x, b.position.x + 40.0, b.end.x - 40.0), minf(pos.y - 50.0, b.end.y - 60.0)), color)


func _short_name(p: Player) -> String:
	return "Manichino" if p == dummy else COLOR_NAMES[p.slot]


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
	lines.append("PROTOTIPO 2b - ARMI     R / Start = nuovo round     F2 = manichino (premi ancora: cambia cosa fa)   F3 = togli manichino   F4 = arma a tutti")
	if _free_slot() >= 0:
		lines.append("Per entrare: W o Spazio (tastiera + mouse)  -  Freccia SU (tastiera frecce)  -  A sul joystick")
	lines.append("Tastiera + mouse: A/D muovi, W/Spazio salta, S giu, mira col mouse, pugno o SPARO clic sinistro (o F), scudo clic destro (o E), lascia arma Q")
	lines.append("Tastiera frecce: frecce muovi e mira, Freccia su salta, pugno/sparo Invio, scudo Shift destro, lascia arma Ctrl destro  |  Joystick: levette muovi/mira, A salta, X/RB pugno/sparo, B/LB scudo, Y lascia arma")
	for p in participants():
		var label: String = names[p.slot]
		if p == dummy:
			label = "Manichino (%s)" % dummy.bot.mode_name()
		var held := "mani nude" if p.weapon == null else "%s (%d colpi)" % [p.weapon.display_name, p.ammo]
		lines.append("%s:  vittorie %d  ·  eliminazioni %d  ·  cadute %d  ·  danni fatti %d  ·  %s" % [label, wins[p.slot], kills[p.slot], falls[p.slot], int(damage_dealt[p.slot]), held])
	hud.text = "\n".join(lines)
