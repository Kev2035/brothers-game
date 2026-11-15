extends Node2D
## Scena principale e "gestore partita" (tappa 2c: lobby e partita infinita).
## - Il gioco parte nella LOBBY: una piattaforma dove ci si può già picchiare.
##   Chi muore ricompare subito e le statistiche non contano.
## - Appena qualcuno fa fuori un avversario parte la PARTITA: le arene si
##   susseguono, una per round (chi resta vivo vince il round).
## - Dopo `arenas_per_lobby` arene si torna alla lobby, che mostra la classifica.
## - Un giocatore entra premendo il suo tasto di salto (fino a 4 posti).
## - F2 aggiunge il manichino d'allenamento / cambia cosa fa; F3 lo toglie.
## - R (tastiera) o Start (joystick) fa ripartire il round.

enum Phase { LOBBY, MATCH }

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MAX_PLAYERS := 4
const COLORS: Array[Color] = [Color("e8524a"), Color("4a90e8"), Color("5cc46a"), Color("f2c84b")]
const COLOR_NAMES: Array[String] = ["Rosso", "Blu", "Verde", "Giallo"]
const DUMMY_COLOR := Color("9a9aa6")
const RESPAWN_DELAY := 1.0
const ROUND_END_DELAY := 2.5
const MATCH_START_DELAY := 1.5 ## secondi tra la prima eliminazione nella lobby e la prima arena
const LOBBY_SCENE := preload("res://src/arenas/lobby/lobby.tscn")
## Le arene della partita. Per aggiungerne una: nuova scena in src/arenas/ e una riga qui.
const ARENA_SCENES: Array[PackedScene] = [
	preload("res://src/arenas/test_arena/test_arena.tscn"),
	preload("res://src/arenas/torri/torri.tscn"),
	preload("res://src/arenas/ponti/ponti.tscn"),
]
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

## Quante arene si giocano prima di tornare alla lobby con la classifica.
## Per le prove è 3; nel gioco vero sarà circa 20.
@export var arenas_per_lobby := 3
## false = arene sempre nello stesso ordine; true = a caso (in futuro si sceglierà dal menu).
@export var random_order := false
## true = anche nella lobby cadono le armi dal cielo.
@export var lobby_weapons := false
## Se scegli qui un'arena, si gioca solo su quella, senza lobby e senza cambi:
## comodo per provare un'arena nuova (lo usa anche il test automatico).
@export var fixed_arena: PackedScene

@onready var hud: Label = $HUD/Label

var arena: Arena
var phase := Phase.LOBBY
var arenas_played := 0 ## arene finite in questo giro (dall'ultima volta nella lobby)
var total_arenas := 0 ## arene finite in tutta la partita
var _match_starting := false
var _queue: Array[PackedScene] = [] ## prossime arene in coda
var _last_scene: PackedScene
var scoreboard: Scoreboard

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
	_banner = Label.new()
	_banner.position = Vector2(0, 400)
	_banner.size = Vector2(1920, 160)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 110)
	_banner.add_theme_constant_override("outline_size", 18)
	_banner.add_theme_color_override("font_outline_color", Color("1b1b2b"))
	_banner.visible = false
	$HUD.add_child(_banner)
	scoreboard = Scoreboard.new()
	$HUD.add_child(scoreboard)
	if fixed_arena != null:
		phase = Phase.MATCH
		load_arena(fixed_arena)
	else:
		phase = Phase.LOBBY
		load_arena(LOBBY_SCENE)


## Toglie l'arena attuale e mette quella nuova; tutti ricompaiono ai punti di partenza.
func load_arena(scene: PackedScene) -> void:
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = scene.instantiate()
	add_child(arena)
	move_child(arena, 0) # dietro ai personaggi
	frame_arena(arena)
	for p in participants():
		p.death_y = arena.death_y
		p.side_limits = arena.side_limits
	start_round()


## La prossima arena della partita: in ordine, oppure a caso senza ripetere subito la stessa.
func _pick_next_arena() -> PackedScene:
	if _queue.is_empty():
		_queue = ARENA_SCENES.duplicate()
		if random_order:
			_queue.shuffle()
			if _queue.size() > 1 and _queue[0] == _last_scene:
				_queue.reverse()
	_last_scene = _queue.pop_front()
	return _last_scene


## Prima eliminazione nella lobby: si parte!
func _begin_match() -> void:
	_match_starting = true
	_show_banner("FIGHT!", Color.WHITE)
	await get_tree().create_timer(MATCH_START_DELAY).timeout
	if phase != Phase.LOBBY or not _match_starting:
		return
	_match_starting = false
	phase = Phase.MATCH
	arenas_played = 0
	scoreboard.visible = false
	load_arena(_pick_next_arena())


## Fine di un round della partita: arena successiva, o ritorno alla lobby.
func _after_round() -> void:
	arenas_played += 1
	total_arenas += 1
	if fixed_arena != null:
		start_round()
	elif arenas_played >= arenas_per_lobby:
		go_to_lobby()
	else:
		load_arena(_pick_next_arena())


func go_to_lobby() -> void:
	phase = Phase.LOBBY
	_match_starting = false
	load_arena(LOBBY_SCENE)
	if total_arenas > 0:
		scoreboard.show_table("CLASSIFICA  -  %d arene giocate" % total_arenas, _score_rows())


func _score_rows() -> Array:
	var rows := []
	for p in participants():
		rows.append({"name": _short_name(p), "color": p.color, "wins": wins[p.slot],
			"kills": kills[p.slot], "falls": falls[p.slot], "damage": damage_dealt[p.slot]})
	return rows


## Le statistiche contano solo durante la partita, non nella lobby.
func counting_stats() -> bool:
	return phase == Phase.MATCH


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true


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
	if phase == Phase.MATCH and fixed_arena == null and participants().size() <= 1:
		go_to_lobby() # da soli non si fa una partita
	else:
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
	if phase == Phase.LOBBY and not lobby_weapons:
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
	if attacker != null and is_instance_valid(attacker) and counting_stats():
		damage_dealt[attacker.slot] += amount


func _on_player_died(p: Player, cause: String) -> void:
	_spawn_puff(p.global_position, p.color)
	var killer := p.last_attacker
	var by_enemy := killer != null and is_instance_valid(killer) and killer != p
	if counting_stats():
		if cause == "fall":
			falls[p.slot] += 1
		if by_enemy:
			kills[killer.slot] += 1
	_update_hud()

	var everyone := participants()
	if phase == Phase.LOBBY or everyone.size() <= 1:
		# Nella lobby (o da soli) non ci sono round: si ricompare dopo un attimo.
		if phase == Phase.LOBBY and by_enemy and not _match_starting:
			_begin_match()
		var where := arena
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		if is_instance_valid(p) and not p.alive and arena == where:
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
		_show_banner(WIN_PHRASES.pick_random(), winner.color)
	else:
		_show_banner("PAREGGIO!", Color.WHITE)
	_update_hud()
	var this_round := _round_id
	await get_tree().create_timer(ROUND_END_DELAY).timeout
	if round_over and this_round == _round_id:
		_after_round()


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
	if phase == Phase.LOBBY:
		lines.append("LOBBY  -  fai fuori un avversario per iniziare la partita")
	elif fixed_arena != null:
		lines.append("PROVA ARENA: %s" % arena.arena_name)
	else:
		lines.append("PARTITA  -  arena %d di %d: %s" % [arenas_played + 1, arenas_per_lobby, arena.arena_name])
	lines.append("PROTOTIPO 2c - PARTITA     R / Start = nuovo round     F2 = manichino (premi ancora: cambia cosa fa)   F3 = togli manichino   F4 = arma a tutti")
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
