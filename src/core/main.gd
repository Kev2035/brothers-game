extends Node2D
## Scena principale e "gestore partita" (tappa 2c: lobby e partita infinita).
## - Il gioco parte nella LOBBY: una piattaforma dove ci si può già picchiare.
##   Chi muore ricompare subito e le statistiche non contano.
## - Appena qualcuno fa fuori un avversario parte la PARTITA: le arene si
##   susseguono, una per round (chi resta vivo vince il round).
## - Dopo `arenas_per_lobby` arene si torna alla lobby, che mostra la classifica.
## - Cambio di arena "a scorrimento": la nuova arena compare accanto a quella
##   vecchia, i personaggi spariscono e la telecamera scorre fino a lì.
## - Un giocatore entra premendo il suo tasto di salto (fino a 4 posti).
## - F2 aggiunge il manichino d'allenamento / cambia cosa fa; F3 lo toglie.
## - Esc (tastiera) o Start (joystick) apre il menu di pausa.
## - R (tastiera) o Select/Back (joystick) fa ripartire il round (per le prove).

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
## Si scrive solo il percorso: ogni arena viene caricata in background quando serve,
## così anche con tante arene il gioco parte subito e non si blocca.
const ARENA_PATHS: Array[String] = [
	"res://src/arenas/bosco/radici.tscn",
	"res://src/arenas/bosco/tronchi.tscn",
	"res://src/arenas/bosco/piattaforme.tscn",
	"res://src/arenas/bosco/perni.tscn",
	"res://src/arenas/bosco/binari.tscn",
	"res://src/arenas/bosco/oblique.tscn",
	"res://src/arenas/bosco/ascensori.tscn",
	"res://src/arenas/bosco/sottobosco.tscn",
	"res://src/arenas/test_arena/test_arena.tscn",
	"res://src/arenas/torri/torri.tscn",
	"res://src/arenas/ponti/ponti.tscn",
]
## Le armi "di base" (le "schede" in src/weapons/): cadono nelle arene che non
## dicono quali armi vogliono. Ogni arena può scegliere le sue (vedi "sky_weapons" in arena.gd).
const WEAPONS: Array[WeaponData] = [
	preload("res://src/weapons/pistol.tres"),
	preload("res://src/weapons/smg.tres"),
	preload("res://src/weapons/shotgun.tres"),
]
## Tutte le armi, nell'ordine in cui le dà il tasto di prova F4.
const TEST_WEAPONS: Array[WeaponData] = [
	preload("res://src/weapons/sling.tres"),
	preload("res://src/weapons/wooden_sword.tres"),
	preload("res://src/weapons/knife.tres"),
	preload("res://src/weapons/axe.tres"),
	preload("res://src/weapons/crossbow.tres"),
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
## Quanti secondi dura lo scorrimento della telecamera da un'arena all'altra.
@export var scroll_time := 1.2
## Spazio vuoto tra un'arena e la successiva durante lo scorrimento.
@export var arena_gap := 400.0

## Le arene della partita, nell'ordine in cui si giocano (si parte da ARENA_PATHS).
var arena_paths: Array[String] = ARENA_PATHS.duplicate()

@onready var hud: Label = $HUD/Label

var arena: Arena
var phase := Phase.LOBBY
var arenas_played := 0 ## arene finite in questo giro (dall'ultima volta nella lobby)
var total_arenas := 0 ## arene finite in tutta la partita
var _match_starting := false
var transitioning := false ## true mentre la telecamera scorre verso la nuova arena
var _queue: Array[String] = [] ## prossime arene in coda (percorsi)
var _last_path := ""
var _next_path := "" ## la prossima arena, già in caricamento in background
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
var pause_menu: PauseMenu


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
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(close_pause)
	pause_menu.settings_changed.connect(_on_settings_changed)
	pause_menu.end_requested.connect(end_match)
	pause_menu.new_match_requested.connect(new_match)
	pause_menu.quit_requested.connect(func(): get_tree().quit())
	pause_menu.level_requested.connect(jump_to_arena)
	for path in arena_paths:
		pause_menu.level_names.append(path.get_file().get_basename().capitalize())
	if fixed_arena != null:
		phase = Phase.MATCH
		load_arena(fixed_arena)
	else:
		phase = Phase.LOBBY
		load_arena(LOBBY_SCENE)
		_prepare_next_arena()


## Toglie l'arena attuale e mette subito quella nuova (senza scorrimento);
## tutti ricompaiono ai punti di partenza.
func load_arena(scene: PackedScene) -> void:
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = scene.instantiate()
	add_child(arena)
	move_child(arena, 0) # dietro ai personaggi
	frame_arena(arena)
	_update_player_limits()
	start_round()


## Cambio di arena "a scorrimento" (come in Stick Fight):
## 1. la nuova arena compare a destra di quella vecchia e i personaggi spariscono;
## 2. la telecamera scorre fino alla nuova arena;
## 3. l'arena vecchia si toglie e tutti ricompaiono ai punti di partenza.
func scroll_to_arena(scene: PackedScene) -> void:
	if transitioning:
		return
	transitioning = true
	round_over = true # niente armi e niente fine round durante lo scorrimento
	_round_id += 1
	_banner.visible = false
	for node in get_tree().get_nodes_in_group("round_temp"):
		node.queue_free()
	for p in participants():
		_hide_player(p)

	var old := arena
	var next_arena: Arena = scene.instantiate()
	add_child(next_arena)
	move_child(next_arena, 0)
	var ob := old.world_bounds
	next_arena.position = Vector2(ob.end.x + arena_gap - next_arena.bounds.position.x, old.position.y)
	# I due sfondi si incontrano a metà dello spazio vuoto tra le arene.
	var border_x := ob.end.x + arena_gap / 2.0
	old.clip_background(-INF, border_x)
	next_arena.clip_background(border_x, INF)

	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "position", next_arena.world_bounds.get_center(), scroll_time)
	tw.tween_property(camera, "zoom", _zoom_for(next_arena), scroll_time)
	await tw.finished

	# Via l'arena vecchia. Quella nuova torna al punto (0, 0) insieme alla telecamera:
	# lo spostamento non si vede, e le posizioni restano sempre numeri piccoli.
	remove_child(old)
	old.queue_free()
	next_arena.position = Vector2.ZERO
	next_arena.clip_background() # di nuovo lo sfondo intero
	arena = next_arena
	frame_arena(arena)
	_update_player_limits()
	transitioning = false
	start_round()
	if phase == Phase.MATCH and fixed_arena == null and participants().size() <= 1:
		go_to_lobby() # nel frattempo è rimasto un solo giocatore


## Il personaggio sparisce durante lo scorrimento (ricompare con respawn).
func _hide_player(p: Player) -> void:
	p.visible = false
	p.velocity = Vector2.ZERO
	p.set_solid(false)
	p.set_physics_process(false)


func _update_player_limits() -> void:
	for p in participants():
		p.death_y = arena.death_y
		p.side_limits = arena.side_limits


## La prossima arena della partita: in ordine, oppure a caso senza ripetere subito la stessa.
func _pick_next_arena() -> String:
	if _queue.is_empty():
		_queue = arena_paths.duplicate()
		if random_order:
			_queue.shuffle()
			if _queue.size() > 1 and _queue[0] == _last_path:
				_queue.reverse()
	_last_path = _queue.pop_front()
	return _last_path


## Sceglie la prossima arena e comincia a caricarla in background, mentre si gioca.
func _prepare_next_arena() -> void:
	if _next_path != "" or fixed_arena != null:
		return
	_next_path = _pick_next_arena()
	ResourceLoader.load_threaded_request(_next_path)


## Prende la prossima arena (se il caricamento non ha ancora finito, aspetta qui).
func _take_next_arena() -> PackedScene:
	_prepare_next_arena()
	var path := _next_path
	_next_path = ""
	return ResourceLoader.load_threaded_get(path)


## Prima eliminazione nella lobby: si parte!
func _begin_match() -> void:
	_match_starting = true
	_show_banner("FIGHT!", Color.WHITE)
	await get_tree().create_timer(MATCH_START_DELAY, false).timeout
	if phase != Phase.LOBBY or not _match_starting:
		return
	_match_starting = false
	phase = Phase.MATCH
	arenas_played = 0
	scoreboard.visible = false
	await scroll_to_arena(_take_next_arena())
	_prepare_next_arena()


## Fine di un round della partita: arena successiva, o ritorno alla lobby.
func _after_round() -> void:
	arenas_played += 1
	total_arenas += 1
	if fixed_arena != null:
		start_round()
	elif arenas_played >= arenas_per_lobby:
		go_to_lobby()
	else:
		await scroll_to_arena(_take_next_arena())
		_prepare_next_arena()


func go_to_lobby() -> void:
	if transitioning:
		return
	phase = Phase.LOBBY
	_match_starting = false
	await scroll_to_arena(LOBBY_SCENE)
	_prepare_next_arena()
	if total_arenas > 0 and phase == Phase.LOBBY:
		scoreboard.show_table("CLASSIFICA  -  %s" % _arenas_text(total_arenas), _score_rows())


## --- Menu di pausa ---

## Esc / Start: tutto si ferma (personaggi, proiettili, timer, scorrimento) e si apre il menu.
func open_pause() -> void:
	get_tree().paused = true
	hud.visible = false # le scritte di aiuto non si sovrappongono al menu
	# Le impostazioni si cambiano solo nella lobby, prima che la partita parta.
	pause_menu.open(phase == Phase.LOBBY and not _match_starting, random_order, arenas_per_lobby)


func close_pause() -> void:
	pause_menu.close()
	hud.visible = true
	get_tree().paused = false


func _on_settings_changed(new_random: bool, new_count: int) -> void:
	arenas_per_lobby = new_count
	if new_random != random_order:
		random_order = new_random
		# Si rifà la coda delle arene col nuovo ordine (anche quella già preparata).
		_queue.clear()
		if _next_path != "":
			ResourceLoader.load_threaded_get(_next_path) # chiude il caricamento iniziato
			_next_path = ""
		_prepare_next_arena()
	_update_hud()


## "Esci dalla partita": classifica finale con il vincitore (il gioco resta in pausa).
func end_match() -> void:
	var rows := _score_rows()
	Scoreboard.sort_rows(rows)
	var title := "Nessuna arena giocata"
	var color := Color.WHITE
	# Conta anche un round appena vinto, se si esce prima di passare all'arena dopo.
	var played := total_arenas + (1 if phase == Phase.MATCH and round_over and not transitioning else 0)
	if played > 0 and not rows.is_empty():
		var first: Dictionary = rows[0]
		var tie: bool = rows.size() > 1 and rows[1].wins == first.wins and rows[1].kills == first.kills
		if tie:
			title = "PAREGGIO!  -  %s" % _arenas_text(played)
		else:
			title = "VINCE %s!  -  %s" % [String(first.name).to_upper(), _arenas_text(played)]
			color = first.color
	pause_menu.show_end(title, color, rows)


## "Nuova partita": statistiche a zero e si torna alla lobby.
func new_match() -> void:
	close_pause()
	_match_starting = false
	for i in MAX_PLAYERS:
		wins[i] = 0
		falls[i] = 0
		kills[i] = 0
		damage_dealt[i] = 0.0
	total_arenas = 0
	arenas_played = 0
	scoreboard.visible = false
	while transitioning: # se la telecamera sta scorrendo, si aspetta che arrivi
		await get_tree().process_frame
	if phase == Phase.MATCH and fixed_arena == null:
		go_to_lobby()
	else:
		start_round()


## "Scegli livello" del menu di pausa (provvisorio, per le prove): si va subito
## all'arena scelta, e la partita prosegue da lì nell'ordine normale.
func jump_to_arena(index: int) -> void:
	close_pause()
	while transitioning: # se la telecamera sta scorrendo, si aspetta che arrivi
		await get_tree().process_frame
	_match_starting = false
	phase = Phase.MATCH
	arenas_played = 0
	scoreboard.visible = false
	if _next_path != "":
		ResourceLoader.load_threaded_get(_next_path) # chiude il caricamento già iniziato
		_next_path = ""
	_queue = arena_paths.slice(index + 1)
	_last_path = arena_paths[index]
	load_arena(load(arena_paths[index]))
	_prepare_next_arena()


func _arenas_text(n: int) -> String:
	return "1 arena giocata" if n == 1 else "%d arene giocate" % n


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
		elif k == KEY_ESCAPE:
			open_pause()
			get_viewport().set_input_as_handled()
			return
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
			open_pause()
			get_viewport().set_input_as_handled()
			return
		elif b.button_index == JOY_BUTTON_BACK:
			start_round()
			return

	if key != "" and not _joined.has(key):
		add_player(kind, device, key)


func frame_arena(a: Arena) -> void:
	camera.position = a.world_bounds.get_center()
	camera.zoom = _zoom_for(a)


## Lo zoom che fa stare tutta l'arena nello schermo.
func _zoom_for(a: Arena) -> Vector2:
	var view := Vector2(get_viewport().get_visible_rect().size)
	if view.x <= 0.0:
		view = Vector2(1920, 1080)
	return Vector2.ONE * minf(view.x / a.bounds.size.x, view.y / a.bounds.size.y)


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
	if transitioning:
		_hide_player(p) # entra durante lo scorrimento: compare nella nuova arena
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
	if transitioning:
		return
	_round_id += 1
	round_over = false
	_banner.visible = false
	# Via proiettili, armi a terra ed effetti del round precedente.
	for node in get_tree().get_nodes_in_group("round_temp"):
		node.queue_free()
	_spawn_timer = WEAPON_FIRST_DELAY
	arena.place_fixed_weapons()
	# Gli oggetti che si muovono a tempo (piattaforme a perno...) ripartono da capo.
	get_tree().call_group("round_reset", "reset_round")
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
	if not arena.sky_weapons_enabled:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(WEAPON_INTERVAL.x, WEAPON_INTERVAL.y)
		if get_tree().get_nodes_in_group("pickups").size() < MAX_PICKUPS:
			spawn_weapon()


## Fa cadere un'arma dal cielo in un punto a caso dell'arena. Se non si dice quale,
## la sceglie a caso tra quelle previste dall'arena.
func spawn_weapon(data: WeaponData = null, x := NAN) -> WeaponPickup:
	var b := arena.world_bounds
	var pickup := WeaponPickup.new()
	pickup.data = data if data != null else arena.pick_sky_weapon(WEAPONS)
	pickup.death_y = arena.death_y
	if is_nan(x):
		x = randf_range(b.position.x + b.size.x * 0.12, b.end.x - b.size.x * 0.12)
	pickup.position = Vector2(x, b.position.y - 120.0)
	add_child(pickup)
	return pickup


## F4 (per le prove): dà a tutti la stessa arma; a ogni pressione si passa alla successiva
## (fionda -> spada di legno -> coltello -> ascia -> balestra -> pistola -> mitra -> pompa).
func give_weapon_to_all() -> void:
	var data := TEST_WEAPONS[_give_index]
	_give_index = (_give_index + 1) % TEST_WEAPONS.size()
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
		await get_tree().create_timer(RESPAWN_DELAY, false).timeout
		if is_instance_valid(p) and not p.alive and arena == where and not transitioning:
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
	await get_tree().create_timer(ROUND_END_DELAY, false).timeout
	if round_over and this_round == _round_id:
		_after_round()


## Sbuffo di fumo del colore del personaggio quando muore.
func _spawn_puff(pos: Vector2, color: Color) -> void:
	var b := arena.world_bounds
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
	lines.append("PROTOTIPO 3a (Bosco)     Esc / Start = PAUSA     R / Select = nuovo round     F2 = manichino (premi ancora: cambia cosa fa)   F3 = togli manichino   F4 = arma a tutti (premi ancora: cambia arma)")
	if _free_slot() >= 0:
		lines.append("Per entrare: W o Spazio (tastiera + mouse)  -  Freccia SU (tastiera frecce)  -  A sul joystick")
	lines.append("Tastiera + mouse: A/D muovi, W/Spazio salta, S giu, mira col mouse, pugno o SPARO clic sinistro (o F; FIONDA: tieni premuto e lascia), scudo clic destro (o E), lascia arma Q")
	lines.append("Tastiera frecce: frecce muovi e mira, Freccia su salta, pugno/sparo Invio, scudo Shift destro, lascia arma Ctrl destro  |  Joystick: levette muovi/mira, A salta, X/RB pugno/sparo, B/LB scudo, Y lascia arma")
	for p in participants():
		var label: String = names[p.slot]
		if p == dummy:
			label = "Manichino (%s)" % dummy.bot.mode_name()
		var held := "mani nude"
		if p.weapon != null: # le armi con colpi infiniti non mostrano il numero
			held = p.weapon.display_name if p.weapon.ammo <= 0 else "%s (%d colpi)" % [p.weapon.display_name, p.ammo]
		lines.append("%s:  vittorie %d  ·  eliminazioni %d  ·  cadute %d  ·  danni fatti %d  ·  %s" % [label, wins[p.slot], kills[p.slot], falls[p.slot], int(damage_dealt[p.slot]), held])
	hud.text = "\n".join(lines)
