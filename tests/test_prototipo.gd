extends SceneTree
# Test automatico del prototipo: avvia la scena principale, aggiunge giocatori
# finti, simula i tasti e controlla che tutto funzioni. Uscita 0 = tutto ok.
#
# Come lanciarlo (da PowerShell, nella cartella del progetto):
#   & "<percorso>\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/test_prototipo.gd
# Il percorso di Godot è in STATO.md ("Strumenti installati").

var passed := 0
var failed := 0
var main: Node

const GROUND := 1448.0 # piedi appoggiati sul terreno (y)
const PIT_X := 1600.0 # centro del pozzo
const WALL_X := 386.0 # appena a destra del muro alto (faccia a x=360)
# Le tre arene grezze di prova: le prove su lobby, partita e menu usano queste.
var OLD_ARENAS: Array[String] = [
	"res://src/arenas/test_arena/test_arena.tscn",
	"res://src/arenas/torri/torri.tscn",
	"res://src/arenas/ponti/ponti.tscn",
]


func _initialize() -> void:
	create_timer(400.0).timeout.connect(func():
		print("TIMEOUT")
		quit(2))
	_run()


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  OK   ", label)
	else:
		failed += 1
		print("  FAIL ", label)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func tap(action: String, hold := 2) -> void:
	Input.action_press(action)
	await frames(hold)
	Input.action_release(action)


func _run() -> void:
	main = load("res://src/core/main.tscn").instantiate()
	main.fixed_arena = load("res://src/arenas/test_arena/test_arena.tscn") # niente lobby: solo l'arena di prova
	root.add_child(main)
	await frames(2)

	main.auto_weapons = false # le armi cadono da sole solo nella prova apposita
	var p0 = main.add_player("kb_b", -1, "kb_b")
	var p1 = main.add_player("joy", 0, "joy_0")
	check(main.participants().size() == 2, "due giocatori entrati")
	check(p0.aim_mode == "keys" and p1.aim_mode == "stick", "modo di mira assegnato")
	print("    zoom telecamera: %.2f (arena %s)" % [main.camera.zoom.x, main.arena.bounds.size])
	check(absf(main.camera.zoom.x - 0.6) < 0.01, "la telecamera inquadra l'arena grande")

	await frames(60)
	check(p0.is_on_floor() and p1.is_on_floor(), "entrambi appoggiati a terra")

	# Corsa
	var x0: float = p0.global_position.x
	Input.action_press("p0_right")
	await frames(30)
	Input.action_release("p0_right")
	check(p0.global_position.x - x0 > 250.0, "P0 corre verso destra")
	await frames(30)

	# Salto pieno, salto corto, doppio salto
	var y_ground: float = p0.global_position.y
	var min_y := y_ground
	Input.action_press("p0_jump")
	for i in 40:
		await physics_frame
		min_y = minf(min_y, p0.global_position.y)
	Input.action_release("p0_jump")
	var h := y_ground - min_y
	check(absf(h - p0.jump_height) < 40.0, "altezza del salto corretta (%.0f px)" % h)
	await frames(60)
	y_ground = p0.global_position.y
	min_y = y_ground
	Input.action_press("p0_jump")
	await frames(3)
	Input.action_release("p0_jump")
	for i in 40:
		await physics_frame
		min_y = minf(min_y, p0.global_position.y)
	check(y_ground - min_y < h * 0.6, "salto variabile (tap = salto basso)")
	await frames(60)
	y_ground = p0.global_position.y
	min_y = y_ground
	Input.action_press("p0_jump")
	await frames(15)
	Input.action_release("p0_jump")
	await frames(2)
	Input.action_press("p0_jump")
	for i in 50:
		await physics_frame
		min_y = minf(min_y, p0.global_position.y)
	Input.action_release("p0_jump")
	check(y_ground - min_y > h + 100.0, "doppio salto va piu in alto")
	await frames(90)

	# --- COLPI: fanno danno ma NON spostano ---
	main.start_round()
	await frames(30)
	p0.global_position = Vector2(700, GROUND)
	p1.global_position = Vector2(780, GROUND)
	p0.facing = 1.0
	await frames(5)
	var p1x: float = p1.global_position.x
	await tap("p0_attack")
	await frames(10)
	print("    vita di P1: %.0f, spostamento: %.1f px" % [p1.health, p1.global_position.x - p1x])
	check(is_equal_approx(p1.health, p1.max_health - p0.punch_damage), "un pugno toglie vita")
	check(absf(p1.global_position.x - p1x) < 2.0 and p1.is_on_floor(), "il pugno NON sposta l'avversario")

	# Pugni a raffica
	main.start_round()
	await frames(30)
	var punches := 0
	var last_t: float = p0._punch_t
	for i in 60:
		if i % 3 == 0:
			Input.action_press("p0_attack")
		elif i % 3 == 1:
			Input.action_release("p0_attack")
		await physics_frame
		if p0._punch_t >= 0.0 and (last_t < 0.0 or p0._punch_t < last_t):
			punches += 1
		last_t = p0._punch_t
	Input.action_release("p0_attack")
	check(punches >= 8, "almeno 8 pugni al secondo (%d)" % punches)

	# Pugno in alto: fa danno, non lancia
	main.start_round()
	await frames(30)
	p0.global_position = Vector2(700, GROUND)
	p1.global_position = Vector2(700, GROUND - 110)
	p1.velocity = Vector2.ZERO
	Input.action_press("p0_up")
	await physics_frame
	var hp1: float = p1.health
	await tap("p0_attack", 3)
	Input.action_release("p0_up")
	check(p1.health < hp1, "il pugno in alto colpisce")
	await frames(60)

	# Pugno in basso in aria: rimbalzo
	main.start_round()
	await frames(30)
	p1.global_position = Vector2(700, GROUND)
	p0.global_position = Vector2(700, GROUND - 118)
	p0.velocity = Vector2(0, 300)
	Input.action_press("p0_down")
	await physics_frame
	Input.action_press("p0_attack")
	var vy_dn := 0.0
	for i in 4:
		await physics_frame
		vy_dn = minf(vy_dn, p0.velocity.y)
	Input.action_release("p0_attack")
	Input.action_release("p0_down")
	check(vy_dn < -500.0, "pugno in basso in aria fa rimbalzare")
	await frames(60)

	# --- SCUDO ---
	main.start_round()
	await frames(30)
	p0.global_position = Vector2(700, GROUND)
	p1.global_position = Vector2(780, GROUND)
	p0.facing = 1.0
	p1.facing = -1.0
	await frames(10)
	await tap("p1_shield")
	check(p1.is_shielding(), "scudo alzato")
	hp1 = p1.health
	await tap("p0_attack")
	await frames(5)
	check(p1.health == hp1, "lo scudo frontale para il pugno")
	await tap("p1_shield")
	await tap("p1_attack")
	check(p1._punch_t < 0.0, "con lo scudo non puoi tirare pugni")
	await frames(40)
	main.start_round()
	await frames(30)
	p1.global_position = Vector2(780, GROUND)
	p0.global_position = Vector2(860, GROUND)
	p1.facing = -1.0
	p0.facing = -1.0
	await frames(10)
	await tap("p1_shield")
	hp1 = p1.health
	await tap("p0_attack")
	await frames(5)
	check(p1.health < hp1, "un colpo alle spalle passa lo scudo")
	await frames(40)
	main.start_round()
	await frames(30)
	p1.facing = -1.0
	await frames(5)
	await tap("p1_shield")
	var wide: float = p1.shield_half_angle()
	await frames(16)
	var narrow: float = p1.shield_half_angle()
	check(wide > 80.0 and narrow < 40.0, "lo scudo si restringe (%.0f -> %.0f gradi)" % [wide, narrow])
	var from_diag: Vector2 = p1.global_position + Player.BODY + Vector2(-60, -70)
	check(p1.take_hit(Vector2(1, 0), from_diag), "colpo fuori dall'arco ristretto passa")
	await frames(60)

	# --- MURO ---
	p0.respawn(Vector2(WALL_X, 1100))
	p0._air_jumps = 0
	await frames(10)
	check(p0._wall_side() == -1, "P0 sente il muro a sinistra")
	await tap("p0_jump")
	check(p0.velocity.x > 200.0 and p0.velocity.y < -300.0, "salto dal muro spinge via e in alto")
	await frames(60)
	p0.respawn(Vector2(WALL_X, 1300))
	await frames(2)
	var start_y: float = p0.global_position.y
	var best_y := start_y
	var since := 99
	var jumps := 0
	Input.action_press("p0_up")
	Input.action_press("p0_left")
	for i in 300:
		since += 1
		if since > 4 and p0._wall_side() == -1 and not p0.is_on_floor():
			Input.action_press("p0_jump")
			since = 0
			jumps += 1
		elif since == 2:
			Input.action_release("p0_jump")
		await physics_frame
		best_y = minf(best_y, p0.global_position.y)
	Input.action_release("p0_jump")
	Input.action_release("p0_up")
	Input.action_release("p0_left")
	print("    scalata: %.0f px con %d salti" % [start_y - best_y, jumps])
	check(start_y - best_y > 250.0, "si puo scalare il muro con tanti salti")
	await frames(30)

	# --- BORDI INVISIBILI ---
	main.start_round()
	await frames(10)
	p0.global_position = Vector2(2850, GROUND)
	Input.action_press("p0_right")
	Input.action_press("p0_jump")
	for i in 120:
		await physics_frame
	Input.action_release("p0_right")
	Input.action_release("p0_jump")
	print("    x massima raggiunta verso destra: %.0f (schermo finisce a 3200)" % p0.global_position.x)
	check(p0.global_position.x > 3200.0 and p0.global_position.x < 3480.0, "si esce un po' dallo schermo ma c'e' un muro invisibile")
	await frames(120)
	p0.respawn(Vector2(3450 - 26, 1000))
	p0._air_jumps = 0
	await frames(10)
	check(p0._wall_side() == 0, "il bordo invisibile non e' un muro da cui saltare")
	await frames(120)

	# --- CADUTA NEL VUOTO E ROUND ---
	main.start_round()
	await frames(30)
	var wins0: int = main.wins[0]
	p1.global_position = Vector2(PIT_X, 1500)
	p1.velocity = Vector2.ZERO
	for i in 90:
		await physics_frame
	check(main.falls[1] >= 1 and not p1.alive, "cadere nel vuoto uccide")
	check(main.wins[0] == wins0 + 1 and main.round_over, "chi resta in piedi vince il round")
	check(main.WIN_PHRASES.has(main._banner.text), "scritta di vittoria a caso: '%s'" % main._banner.text)
	await create_timer(2.8).timeout
	check(p1.alive and p1.health == p1.max_health, "nuovo round: vita piena")

	# Piattaforma attraversabile
	p0.respawn(Vector2(750, GROUND))
	await frames(20)
	Input.action_press("p0_jump")
	await frames(40)
	Input.action_release("p0_jump")
	await frames(40)
	check(p0.is_on_floor() and p0.global_position.y < 1200.0, "attraversa da sotto e resta sopra la sporgenza")
	Input.action_press("p0_down")
	await frames(2)
	await tap("p0_jump", 3)
	Input.action_release("p0_down")
	await frames(40)
	check(p0.global_position.y > 1400.0, "scende dalla sporgenza con Giu + Salto")

	# --- ELIMINAZIONE A PUGNI ---
	main.start_round()
	await frames(30)
	var kills_before: int = main.kills[0]
	var n := 0
	while p1.alive and n < 20:
		p0.global_position = Vector2(700, GROUND)
		p1.global_position = Vector2(780, GROUND)
		p0.facing = 1.0
		await frames(1)
		await tap("p0_attack")
		await frames(12)
		n += 1
	check(not p1.alive and main.kills[0] == kills_before + 1 and n == 10, "10 pugni = eliminato (%d)" % n)
	await create_timer(2.8).timeout

	# --- MANICHINO ---
	main.toggle_dummy()
	var dm = main.dummy
	check(dm != null and dm.bot.mode == DummyBrain.Mode.STILL, "F2 aggiunge il manichino fermo")
	main.toggle_dummy()
	main.toggle_dummy()
	check(dm.bot.mode == DummyBrain.Mode.ATTACK, "F2 di nuovo: il manichino attacca")
	main.start_round()
	await frames(10)
	p1.global_position = Vector2(2550, GROUND)
	dm.global_position = Vector2(1000, GROUND)
	p0.global_position = Vector2(760, GROUND)
	var hp0: float = p0.health
	for i in 240:
		await physics_frame
		if not p0.alive:
			break
	check(p0.health < hp0 or not p0.alive, "il manichino attacca e fa danni (vita P0 %.0f)" % p0.health)
	await create_timer(3.0).timeout
	main.toggle_dummy()
	main.toggle_dummy()
	main.start_round()
	var falls_dm: int = main.falls[dm.slot]
	for i in 360:
		await physics_frame
	check(main.falls[dm.slot] == falls_dm, "il manichino che si muove non si butta nel vuoto")
	main.remove_dummy()
	check(main.dummy == null and main.participants().size() == 2, "F3 toglie il manichino")


	# --- ARMI ---
	var PISTOL: WeaponData = main.WEAPONS[0]
	var SMG: WeaponData = main.WEAPONS[1]
	var SHOTGUN: WeaponData = main.WEAPONS[2]
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0 # niente armi a caso durante queste prove
	p0.global_position = Vector2(700, GROUND)
	p1.global_position = Vector2(1150, GROUND)
	p0.facing = 1.0
	p0.equip(PISTOL)
	await frames(5)
	hp1 = p1.health
	await tap("p0_attack")
	await frames(20)
	print("    pistola: vita P1 %.0f, colpi rimasti %d" % [p1.health, p0.ammo])
	check(is_equal_approx(p1.health, hp1 - PISTOL.damage), "la pistola colpisce a distanza")
	check(p0.ammo == PISTOL.ammo - 1, "un colpo consuma una munizione")
	Input.action_press("p0_attack")
	await frames(40)
	Input.action_release("p0_attack")
	check(p0.ammo == PISTOL.ammo - 2, "pistola: tenendo premuto spara un colpo solo")
	check(p1.global_position.x > 1149.0 and p1.global_position.x < 1151.0, "i proiettili non spostano chi colpiscono")

	# Mitra: raffica tenendo premuto
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p0.global_position = Vector2(700, GROUND)
	p1.global_position = Vector2(1150, GROUND)
	p0.facing = 1.0
	p0.equip(SMG)
	await frames(5)
	Input.action_press("p0_attack")
	await frames(30)
	Input.action_release("p0_attack")
	await frames(20)
	var fired: int = SMG.ammo - p0.ammo
	print("    mitra: %d colpi in 0.5 s, vita P1 %.0f" % [fired, p1.health])
	check(fired >= 6 and fired <= 8, "il mitra spara a raffica")
	check(p1.health < 100.0, "il mitra fa danno")

	# Fucile a pompa: tanti pallini, danno forte da vicino, nulla da lontano
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p0.global_position = Vector2(700, GROUND)
	p1.global_position = Vector2(950, GROUND)
	p0.facing = 1.0
	p0.equip(SHOTGUN)
	await frames(5)
	await tap("p0_attack")
	await frames(20)
	var close_dmg: float = 100.0 - p1.health
	print("    pompa da vicino (250 px): danno %.0f" % close_dmg)
	check(close_dmg >= 27.0, "il fucile a pompa fa tanto danno da vicino")
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p0.global_position = Vector2(330, GROUND)
	p1.global_position = Vector2(1280, GROUND)
	p0.facing = 1.0
	p0.equip(SHOTGUN)
	await frames(5)
	await tap("p0_attack")
	await frames(30)
	check(p1.health == 100.0, "il fucile a pompa non arriva lontano")

	# Rinculo: pompa sparata verso il basso in aria = spinta verso l'alto
	p0.respawn(Vector2(700, 1000))
	p0.equip(SHOTGUN)
	p0.velocity = Vector2.ZERO
	Input.action_press("p0_down")
	await frames(2)
	Input.action_press("p0_attack")
	var vy_rec := 0.0
	for i in 4:
		await physics_frame
		vy_rec = minf(vy_rec, p0.velocity.y)
	Input.action_release("p0_attack")
	Input.action_release("p0_down")
	print("    rinculo pompa verso il basso in aria: velocita verticale %.0f" % vy_rec)
	check(vy_rec < -800.0, "il rinculo spinge chi spara")
	await frames(60)

	# Lo scudo para i proiettili
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p0.global_position = Vector2(700, GROUND)
	p1.global_position = Vector2(1150, GROUND)
	p0.facing = 1.0
	p1.facing = -1.0
	p0.equip(PISTOL)
	await frames(5)
	await tap("p1_shield")
	await tap("p0_attack")
	await frames(12)
	check(p1.health == 100.0, "lo scudo para i proiettili")
	await frames(30)
	await tap("p1_shield")
	await tap("p1_attack")
	p1.equip(PISTOL)
	await tap("p1_shield")
	var ammo_before: int = p1.ammo
	await tap("p1_attack")
	check(p1.ammo == ammo_before, "con lo scudo non si spara")

	# I muri fermano i proiettili
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p1.global_position = Vector2(150, 1100) # dietro il muro alto (fuori dall'arena a sinistra... appoggiato al bordo)
	p0.respawn(Vector2(700, GROUND))
	await frames(5)
	p1.global_position = Vector2(200, 900)
	p1.velocity = Vector2.ZERO
	p0.equip(PISTOL)
	p0.global_position = Vector2(700, GROUND)
	Input.action_press("p0_left")
	await frames(1)
	Input.action_release("p0_left")
	var bullets_before: int = get_nodes_in_group("bullets").size()
	await tap("p0_attack")
	await frames(30)
	check(get_nodes_in_group("bullets").size() == bullets_before, "il proiettile sparisce sul muro")

	# Munizioni finite: l'arma sparisce
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p0.equip(SHOTGUN)
	for i in SHOTGUN.ammo:
		await tap("p0_attack")
		await frames(int(SHOTGUN.fire_interval * 60.0) + 2)
	check(p0.weapon == null, "munizioni finite = arma sparisce, si torna ai pugni")

	# Arma che cade dal cielo e si raccoglie
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p0.global_position = Vector2(700, GROUND)
	var pk = main.spawn_weapon(SMG, 700.0)
	for i in 180:
		await physics_frame
		if p0.weapon != null:
			break
	check(p0.weapon == SMG and not is_instance_valid(pk), "l'arma cade dal cielo e si raccoglie passandoci")
	var pk2 = main.spawn_weapon(PISTOL, 700.0)
	await frames(150)
	check(is_instance_valid(pk2) and p0.weapon == SMG, "con un'arma in mano non se ne raccoglie un'altra")
	main.start_round()
	await frames(2)
	check(get_nodes_in_group("pickups").is_empty(), "nuovo round: via le armi a terra")
	main.auto_weapons = true
	main._spawn_timer = 0.5
	await frames(60)
	main.auto_weapons = false
	check(get_nodes_in_group("pickups").size() == 1, "le armi cadono da sole durante il round")
	main.start_round()


	# --- LASCIARE L'ARMA ---
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p0.global_position = Vector2(700, GROUND)
	p0.equip(PISTOL)
	await frames(3)
	await tap("p0_attack")
	await tap("p0_attack")
	await frames(20)
	var left_ammo: int = p0.ammo
	await tap("p0_drop")
	await frames(30)
	var dropped = get_nodes_in_group("pickups")
	check(p0.weapon == null and dropped.size() == 1, "il tasto lascia arma la fa cadere a terra")
	check(dropped.size() == 1 and dropped[0].ammo == left_ammo, "l'arma lasciata tiene i colpi rimasti (%d)" % left_ammo)
	await frames(60)
	check(p0.weapon == null, "chi la lascia non la riprende subito restandoci sopra")
	var spg = main.spawn_weapon(SHOTGUN, 700.0)
	for i in 150:
		await physics_frame
		if p0.weapon != null:
			break
	check(p0.weapon == SHOTGUN, "lasciata l'arma si puo prendere quella nuova passandoci sopra")
	await tap("p0_drop")
	p0.global_position = Vector2(1100, GROUND)
	await frames(20)
	p0.global_position = Vector2(700, GROUND)
	for i in 30:
		await physics_frame
	check(p0.weapon != null, "allontanandosi e tornando l'arma lasciata si riprende")
	main.start_round()

	await _test_armi_bosco(p0, p1)
	await _test_radici()
	await _test_lobby_e_partita()
	await _test_menu_pausa()

	print("Risultati: %d ok, %d falliti" % [passed, failed])
	quit(1 if failed > 0 else 0)


## Elimina `victim` a pugni (lo rimette ogni volta davanti a `attacker`, sul pavimento `floor_y`).
func _punch_out(attacker, victim, x: float, floor_y: float) -> int:
	var n := 0
	while victim.alive and n < 20:
		attacker.global_position = Vector2(x, floor_y)
		victim.global_position = Vector2(x + 80.0, floor_y)
		attacker.facing = 1.0
		await frames(1)
		await tap("p0_attack")
		await frames(12)
		n += 1
	return n


## Aspetta (al massimo `timeout` secondi) che la condizione diventi vera.
func _wait_for(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await physics_frame
		t += 1.0 / 60.0


func _test_lobby_e_partita() -> void:
	# Nuova partita "vera": parte dalla lobby.
	main.queue_free()
	await frames(3)
	main = load("res://src/core/main.tscn").instantiate()
	main.arenas_per_lobby = 2
	main.arena_paths = OLD_ARENAS
	root.add_child(main)
	await frames(2)
	check(main.phase == main.Phase.LOBBY and main.arena.arena_name == "Lobby", "il gioco parte nella lobby")
	var a = main.add_player("kb_b", -1, "kb_b")
	var b = main.add_player("joy", 0, "joy_0")
	await frames(40)
	check(a.is_on_floor() and b.is_on_floor(), "nella lobby si sta sulla piattaforma")
	const LOBBY_FLOOR := 1098.0

	# Cadere da soli nella lobby: si ricompare, la partita non parte, non conta.
	b.global_position = Vector2(250, 1300)
	b.velocity = Vector2.ZERO
	for i in 90:
		await physics_frame
		if not b.alive:
			break
	check(not b.alive and not main._match_starting and main.falls[1] == 0, "nella lobby cadere da soli non fa partire la partita e non conta")
	await create_timer(1.2).timeout
	check(b.alive, "nella lobby si ricompare subito")

	# Prima eliminazione nella lobby: parte la partita.
	await _punch_out(a, b, 1000.0, LOBBY_FLOOR)
	check(not b.alive and main._match_starting, "fare fuori qualcuno nella lobby fa partire la partita")
	check(main.kills[0] == 0 and main.damage_dealt[0] == 0.0, "nella lobby le statistiche non contano")
	# Scorrimento: la nuova arena compare a destra, i personaggi spariscono, la telecamera si muove.
	await _wait_for(func(): return main.transitioning, 3.0)
	await frames(10)
	var arenas_now := 0
	for c in main.get_children():
		if c is Arena:
			arenas_now += 1
	var cam_x0: float = main.camera.position.x
	check(arenas_now == 2 and not a.visible and not b.visible, "durante lo scorrimento ci sono due arene e i personaggi spariscono")
	# Il confine tra i due sfondi deve stare nello spazio vuoto tra le arene.
	var arenas_list: Array = main.get_children().filter(func(c): return c is Arena and c != main.arena)
	if arenas_list.size() == 1:
		var nxt: Arena = arenas_list[0]
		var old_bg: Rect2 = (main.arena.get_node("Background") as Control).get_global_rect()
		var new_bg := (nxt.get_node("Background") as Control).get_global_rect()
		var gap_l: float = main.arena.world_bounds.end.x
		var gap_r: float = nxt.world_bounds.position.x
		check(old_bg.end.x >= gap_l and old_bg.end.x <= gap_r and is_equal_approx(old_bg.end.x, new_bg.position.x),
			"il confine tra gli sfondi sta nello spazio vuoto tra le arene (%.0f tra %.0f e %.0f)" % [old_bg.end.x, gap_l, gap_r])
	else:
		check(false, "durante lo scorrimento trovo l'arena nuova")
	await create_timer(main.scroll_time * 0.4).timeout
	check(main.camera.position.x > cam_x0 + 300.0, "la telecamera scorre verso destra (%.0f -> %.0f)" % [cam_x0, main.camera.position.x])
	await _wait_for(func(): return not main.transitioning, 4.0)
	await frames(2)
	check(main.arena.position == Vector2.ZERO and main.get_children().filter(func(c): return c is Arena and not c.is_queued_for_deletion()).size() == 1, "finito lo scorrimento resta solo la nuova arena, rimessa al suo posto")
	check(main.phase == main.Phase.MATCH and main.arena.arena_name == "Arena di prova", "prima arena: %s" % main.arena.arena_name)
	check(a.alive and b.alive and a.is_inside_tree(), "nella nuova arena ricompaiono tutti")
	check(a.death_y == main.arena.death_y, "i personaggi conoscono il vuoto della nuova arena")

	# Round 1: B cade nel pozzo -> A vince -> arena successiva.
	await frames(20)
	b.global_position = Vector2(PIT_X, 1500)
	b.velocity = Vector2.ZERO
	await frames(90)
	check(main.wins[0] == 1 and main.falls[1] == 1, "in partita le statistiche contano")
	await create_timer(2.6).timeout
	await _wait_for(func(): return not main.transitioning, 4.0)
	check(main.arena.arena_name == "Torri" and main.arenas_played == 1, "dopo il round si passa all'arena dopo: %s" % main.arena.arena_name)
	var spawns: Array[Vector2] = main.arena.spawn_points()
	check(a.global_position.distance_to(spawns[0]) < 60.0, "si riparte dai punti di partenza della nuova arena")

	# Round 2: B cade tra le isole -> torna la lobby con la classifica.
	await frames(20)
	b.global_position = Vector2(1100, 1500)
	b.velocity = Vector2.ZERO
	await frames(90)
	await create_timer(2.6).timeout
	await _wait_for(func(): return not main.transitioning, 4.0)
	await frames(3)
	check(main.phase == main.Phase.LOBBY and main.arena.arena_name == "Lobby", "dopo %d arene si torna alla lobby" % main.arenas_per_lobby)
	check(main.scoreboard.visible and main.total_arenas == 2, "la lobby mostra la classifica")
	check(main.wins[0] == 2, "le statistiche restano per tutta la partita (vittorie A: %d)" % main.wins[0])

	# Si riparte: l'ordine continua con la terza arena.
	await frames(30)
	await _punch_out(a, b, 1000.0, LOBBY_FLOOR)
	await create_timer(1.6).timeout
	await _wait_for(func(): return not main.transitioning, 4.0)
	check(main.arena.arena_name == "Ponti" and not main.scoreboard.visible, "nuovo giro: si continua con l'arena dopo (%s)" % main.arena.arena_name)

	# Ordine a caso: mai la stessa arena due volte di fila, e prima o poi escono tutte.
	main.random_order = true
	main._queue.clear()
	var seen := {}
	var repeats := 0
	var prev = null
	for i in 40:
		var sc = main._pick_next_arena()
		if sc == prev:
			repeats += 1
		prev = sc
		seen[sc] = true
	check(repeats == 0 and seen.size() == main.arena_paths.size(), "ordine a caso: escono tutte e mai due uguali di fila")


## Simula un tasto premuto e lasciato (come se lo premesse Kevin).
func _press_key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	root.push_input(ev)
	await frames(1)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)
	await frames(1)


## Il pulsante del menu di pausa il cui testo comincia con `start`.
func _menu_button(start: String) -> Button:
	for b in main.pause_menu._buttons.get_children():
		if b is Button and not b.is_queued_for_deletion() and b.text.begins_with(start):
			return b
	return null


func _test_menu_pausa() -> void:
	main.queue_free()
	await frames(3)
	main = load("res://src/core/main.tscn").instantiate()
	main.arena_paths = OLD_ARENAS
	root.add_child(main)
	await frames(2)
	var a = main.add_player("kb_b", -1, "kb_b")
	var b = main.add_player("joy", 0, "joy_0")
	await frames(30)
	var menu = main.pause_menu

	# Esc apre il menu e ferma tutto.
	await _press_key(KEY_ESCAPE)
	check(paused and menu.is_open and menu.visible and menu.page == "main", "Esc apre il menu di pausa e ferma il gioco")
	b.global_position = Vector2(1000, 600) # in aria: senza pausa cadrebbe
	var y0: float = b.global_position.y
	await frames(30)
	check(b.global_position.y == y0, "in pausa i personaggi restano fermi")

	# Impostazioni nella lobby: si possono cambiare.
	_menu_button("Impostazioni").pressed.emit()
	await frames(3)
	var order := _menu_button("Ordine")
	var count := _menu_button("Arene")
	check(menu.page == "settings" and order != null and not order.disabled and not count.disabled, "nella lobby le impostazioni si possono cambiare")
	order.pressed.emit()
	count.pressed.emit()
	check(main.random_order and main.arenas_per_lobby == 5 and order.text.ends_with("a caso"), "il menu cambia ordine delle arene e numero di arene (%d)" % main.arenas_per_lobby)
	order.pressed.emit()
	check(not main.random_order and main._next_path == main.arena_paths[0], "tornando all'ordine fisso si riparte dalla prima arena")
	await _press_key(KEY_ESCAPE)
	check(menu.page == "main" and paused, "Esc nelle impostazioni torna alla pagina principale")
	await _press_key(KEY_ESCAPE)
	check(not paused and not menu.is_open, "Esc dalla pagina principale fa riprendere il gioco")
	await frames(10)
	check(b.global_position.y > y0, "dopo la pausa il gioco riparte")

	# Si gioca una partita.
	main.arenas_per_lobby = 2
	await frames(60)
	await _punch_out(a, b, 1000.0, 1098.0)
	await create_timer(1.6).timeout
	await _wait_for(func(): return not main.transitioning, 4.0)
	check(main.phase == main.Phase.MATCH, "la partita parte")

	# Round vinto e subito pausa: il gioco aspetta, non passa all'arena dopo.
	await frames(20)
	b.global_position = Vector2(PIT_X, 1500)
	b.velocity = Vector2.ZERO
	await _wait_for(func(): return not b.alive, 2.0)
	main.open_pause()
	await create_timer(3.5).timeout
	check(not main.transitioning and main.arenas_played == 0 and main.arena.arena_name == "Arena di prova", "in pausa anche i timer si fermano (il round non passa)")

	# In partita le impostazioni sono bloccate.
	_menu_button("Impostazioni").pressed.emit()
	await frames(3)
	check(_menu_button("Ordine").disabled and _menu_button("Arene").disabled, "durante la partita le impostazioni sono bloccate")
	_menu_button("Indietro").pressed.emit()
	await frames(3)

	# Esci dalla partita: classifica finale con il vincitore.
	_menu_button("Esci").pressed.emit()
	await frames(6)
	var title: String = menu._end_table._title.text
	check(menu.page == "end" and menu._end_table.visible and title.begins_with("VINCE ROSSO"), "fine partita: classifica finale con il vincitore (%s)" % title)
	check(_menu_button("Nuova partita") != null and _menu_button("Chiudi") != null, "fine partita: si puo fare una nuova partita o chiudere il gioco")

	# Nuova partita: statistiche a zero, si torna alla lobby.
	_menu_button("Nuova partita").pressed.emit()
	await frames(3)
	check(not paused and not menu.is_open, "nuova partita: il menu si chiude")
	await _wait_for(func(): return main.phase == main.Phase.LOBBY and not main.transitioning, 5.0)
	await frames(3)
	check(main.arena.arena_name == "Lobby" and main.wins[0] == 0 and main.kills[0] == 0 and main.total_arenas == 0, "nuova partita: si torna alla lobby con le statistiche a zero")
	check(not main.scoreboard.visible, "nuova partita: nella lobby non c'e la classifica vecchia")
	await create_timer(3.0).timeout
	check(main.phase == main.Phase.LOBBY and main.arena.arena_name == "Lobby", "il vecchio round non fa partire niente dopo la nuova partita")


## Mette i due giocatori uno di fronte all'altro, a `dist` pixel, in un round nuovo.
func _face_off(p0, p1, dist: float, weapon: WeaponData) -> void:
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p0.global_position = Vector2(700, GROUND)
	p1.global_position = Vector2(700 + dist, GROUND)
	p0.facing = 1.0
	p1.facing = -1.0
	p0.equip(weapon)
	await frames(5)


## Blocco A: armi corpo a corpo, fionda (carica e curva), balestra (ricarica).
func _test_armi_bosco(p0, p1) -> void:
	var SWORD: WeaponData = load("res://src/weapons/wooden_sword.tres")
	var KNIFE: WeaponData = load("res://src/weapons/knife.tres")
	var AXE: WeaponData = load("res://src/weapons/axe.tres")
	var SLING: ChargeData = load("res://src/weapons/sling.tres")
	var CROSSBOW: WeaponData = load("res://src/weapons/crossbow.tres")
	check(SWORD is MeleeData and SLING is ChargeData and CROSSBOW is GunData and main.WEAPONS[0] is GunData, "ogni arma ha la scheda della sua famiglia")
	print("    colpi per uccidere: spada %d, coltello %d, ascia %d, fionda %d, balestra %d" % [SWORD.hits_to_kill(), KNIFE.hits_to_kill(), AXE.hits_to_kill(), SLING.hits_to_kill(), CROSSBOW.hits_to_kill()])
	check(SWORD.hits_to_kill() == 5 and KNIFE.hits_to_kill() == 3 and AXE.hits_to_kill() == 2 and CROSSBOW.hits_to_kill() == 3, "colpi per uccidere come nel documento del bosco")

	# Spada di legno: arriva più lontano del pugno, 20 di danno, non si consuma.
	await _face_off(p0, p1, 190.0, SWORD)
	await tap("p0_attack")
	await frames(3)
	check(is_equal_approx(p1.health, 80.0), "la spada di legno colpisce piu lontano del pugno (vita P1 %.0f)" % p1.health)
	check(absf(p1.global_position.x - 890.0) < 2.0, "la spada non sposta chi colpisce")
	for i in 3:
		await frames(14)
		await tap("p0_attack")
	check(p0.weapon == SWORD and is_equal_approx(p1.health, 20.0), "la spada non si consuma (vita P1 %.0f)" % p1.health)

	# Lo scudo para la spada.
	await _face_off(p0, p1, 150.0, SWORD)
	await tap("p1_shield")
	await tap("p0_attack")
	await frames(3)
	check(p1.health == 100.0, "lo scudo para la spada")

	# Coltello: portata corta, 34 di danno, veloce.
	await _face_off(p0, p1, 190.0, KNIFE)
	await tap("p0_attack")
	await frames(3)
	check(p1.health == 100.0, "il coltello ha la portata corta (a 190 px non arriva)")
	await _face_off(p0, p1, 100.0, KNIFE)
	for i in 3:
		await tap("p0_attack")
		await frames(9)
	check(not p1.alive, "3 coltellate = eliminato")
	await create_timer(2.8).timeout

	# Ascia: 50 di danno, lenta.
	await _face_off(p0, p1, 210.0, AXE)
	await tap("p0_attack")
	await frames(12)
	await tap("p0_attack") # troppo presto: l'ascia è lenta
	await frames(3)
	check(is_equal_approx(p1.health, 50.0), "l'ascia toglie 50 ed e' lenta (vita P1 %.0f)" % p1.health)
	await frames(30)
	await tap("p0_attack")
	await frames(3)
	check(not p1.alive, "2 colpi d'ascia = eliminato")
	await create_timer(2.8).timeout

	# Fionda: toccando appena il tasto la pietra cade subito; caricando arriva.
	await _face_off(p0, p1, 500.0, SLING)
	await tap("p0_attack")
	await frames(40)
	check(p1.health == 100.0 and p0.ammo == SLING.ammo - 1, "fionda senza carica: la pietra cade prima di arrivare")
	# A raffica: toccando il tasto di continuo partono tante pietre al secondo.
	var ammo_start: int = p0.ammo
	for i in 60:
		if i % 6 == 0:
			Input.action_press("p0_attack")
		elif i % 6 == 3:
			Input.action_release("p0_attack")
		await physics_frame
	Input.action_release("p0_attack")
	await frames(40)
	print("    fionda a raffica: %d pietre in 1 s" % (ammo_start - p0.ammo))
	check(ammo_start - p0.ammo >= 5 and SLING.ammo >= 30, "la fionda si puo usare a raffica e ha tante pietre")
	await _face_off(p0, p1, 300.0, SLING)
	Input.action_press("p0_attack")
	await frames(10)
	var half_charge: float = p0.charge
	var preview_n: int = p0.aim_preview.size()
	await frames(30)
	check(half_charge > 0.3 and half_charge < 0.8 and is_equal_approx(p0.charge, 1.0), "tenendo premuto la fionda si carica (%.2f -> %.2f)" % [half_charge, p0.charge])
	check(preview_n >= 3, "mentre carichi si vede la traiettoria (%d punti)" % preview_n)
	Input.action_release("p0_attack")
	await frames(1)
	var stones := get_nodes_in_group("bullets")
	check(stones.size() == 1 and stones[0].gravity > 0.0, "lasciando il tasto parte la pietra, che cade per gravita")
	await frames(25)
	check(is_equal_approx(p1.health, 80.0) and p0.aim_preview.is_empty(), "fionda carica: la pietra arriva e colpisce (vita P1 %.0f)" % p1.health)

	# La pietra fa una curva: tirata in diagonale verso l'alto sale e poi ricade,
	# e arriva dove diceva la linea tratteggiata.
	main.start_round()
	await frames(20)
	main._spawn_timer = 999.0
	p1.global_position = Vector2(2600, GROUND)
	p0.global_position = Vector2(1900, GROUND)
	p0.equip(SLING)
	# Con le frecce si mira in diagonale tenendo SU + DESTRA (intanto il personaggio corre).
	Input.action_press("p0_up")
	Input.action_press("p0_right")
	await frames(3)
	# Carica minima: la linea (1,3 s di volo) arriva fino a dove la pietra tocca terra.
	Input.action_press("p0_attack")
	await frames(2)
	var predicted: Vector2 = p0.global_position + p0.aim_preview[p0.aim_preview.size() - 1]
	var aim_now: Vector2 = p0.aim
	Input.action_release("p0_attack")
	await frames(1)
	Input.action_release("p0_up")
	Input.action_release("p0_right")
	var flying := get_nodes_in_group("bullets")
	var stone = flying[0] if flying.size() == 1 else null
	var had_stone: bool = stone != null # (un oggetto già tolto dal gioco risulta "null")
	var top_y := 99999.0
	var last := Vector2.ZERO
	while stone != null and is_instance_valid(stone):
		top_y = minf(top_y, stone.global_position.y)
		last = stone.global_position
		await physics_frame
	print("    pietra tirata in diagonale (mira %s): sale fino a y=%.0f, ricade a x=%.0f; la linea diceva x=%.0f" % [aim_now, top_y, last.x, predicted.x])
	check(had_stone and aim_now.y < -0.5 and aim_now.x > 0.5 and top_y < GROUND - 150.0 and last.y > GROUND - 120.0, "la pietra sale e poi ricade (curva)")
	check(absf(last.x - predicted.x) < 60.0, "la pietra cade dove mostrava la linea tratteggiata")

	# Balestra: 40 di danno, poi ~1,2 s per ricaricare.
	await _face_off(p0, p1, 450.0, CROSSBOW)
	await tap("p0_attack")
	await frames(20)
	check(is_equal_approx(p1.health, 60.0), "la balestra tira dritto e toglie 40")
	await tap("p0_attack")
	await frames(20)
	check(is_equal_approx(p1.health, 60.0) and p0.ammo == CROSSBOW.ammo - 1, "la balestra non tira mentre ricarica")
	await frames(40)
	await tap("p0_attack")
	await frames(20)
	check(is_equal_approx(p1.health, 20.0), "dopo ~1,2 s la balestra tira di nuovo")

	# Il manichino sa usare le armi nuove.
	main.toggle_dummy()
	main.toggle_dummy()
	main.toggle_dummy()
	var dm = main.dummy
	for w in [SWORD, SLING]:
		main.start_round()
		await frames(10)
		main._spawn_timer = 999.0
		p1.global_position = Vector2(2550, GROUND)
		dm.global_position = Vector2(1100, GROUND)
		p0.global_position = Vector2(700, GROUND)
		dm.equip(w)
		for i in 300:
			await physics_frame
			if p0.health < 100.0:
				break
		check(p0.health < 100.0, "il manichino attacca con: %s" % w.display_name)
	main.remove_dummy()
	main.start_round()


## Le armi fisse dell'arena che sono ancora al loro posto.
func _fixed_pickups() -> Array:
	return get_nodes_in_group("pickups").filter(func(n): return n.fixed and not n.is_queued_for_deletion())


## Livello 1 del bosco "Le radici": armi dell'arena, spada fissa, piattaforma centrale.
func _test_radici() -> void:
	var SWORD: WeaponData = load("res://src/weapons/wooden_sword.tres")
	var SLING: WeaponData = load("res://src/weapons/sling.tres")
	main.queue_free()
	await frames(3)
	main = load("res://src/core/main.tscn").instantiate()
	main.fixed_arena = load("res://src/arenas/bosco/radici.tscn")
	root.add_child(main)
	await frames(2)
	main.auto_weapons = false
	var a = main.add_player("kb_b", -1, "kb_b")
	var b = main.add_player("joy", 0, "joy_0")
	await frames(60)
	check(main.arena.arena_name == "Le radici" and a.is_on_floor() and b.is_on_floor(), "Le radici: si parte in piedi sulle radici")
	check(main.ARENA_PATHS[0].ends_with("radici.tscn"), "Le radici e' la prima arena della partita")

	# Dal cielo cadono solo fionde.
	var only_slings := true
	for i in 12:
		var pk = main.spawn_weapon()
		if pk.data != SLING:
			only_slings = false
		pk.queue_free()
	await frames(2)
	check(only_slings, "Le radici: dal cielo cadono solo fionde")

	# La spada di legno è già sulla piattaforma centrale e non cade.
	var fixed := _fixed_pickups()
	check(fixed.size() == 1 and fixed[0].data == SWORD, "Le radici: c'e' la spada di legno fissa")
	var sword_pos: Vector2 = fixed[0].global_position if fixed.size() == 1 else Vector2.ZERO
	await frames(60)
	check(fixed.size() == 1 and fixed[0].global_position.distance_to(sword_pos) < 1.0 and absf(sword_pos.x - 1600.0) < 5.0, "la spada fissa resta ferma al centro")

	# Da terra la piattaforma centrale non si raggiunge (salto + doppio salto).
	const CENTER_TOP := 900.0
	a.global_position = Vector2(1300, 1548)
	await frames(10)
	var best := 99999.0
	Input.action_press("p0_right")
	Input.action_press("p0_jump")
	for i in 22:
		await physics_frame
		best = minf(best, a.global_position.y)
	Input.action_release("p0_jump")
	await frames(2)
	Input.action_press("p0_jump")
	for i in 70:
		await physics_frame
		best = minf(best, a.global_position.y)
	Input.action_release("p0_jump")
	Input.action_release("p0_right")
	print("    salto + doppio salto da terra: arriva a y=%.0f (la piattaforma centrale e' a %.0f)" % [best, CENTER_TOP])
	check(best > CENTER_TOP + 60.0 and a.weapon == null, "da terra la piattaforma centrale non si raggiunge")

	# Lasciandosi cadere dalla piattaforma lunga in cima ci si arriva, e si prende la spada.
	a.respawn(Vector2(1100, 538))
	await frames(10)
	check(a.is_on_floor(), "si sta sulla piattaforma lunga in cima")
	Input.action_press("p0_right")
	for i in 120:
		await physics_frame
		if a.weapon != null:
			break
	Input.action_release("p0_right")
	await frames(30)
	check(a.weapon == SWORD and a.is_on_floor() and absf(a.global_position.y - CENTER_TOP) < 3.0, "cadendo dall'alto si atterra al centro e si prende la spada")
	check(_fixed_pickups().is_empty(), "presa la spada, al centro non ce n'e' un'altra")

	# Nuovo round: la spada torna al suo posto.
	main.start_round()
	await frames(3)
	check(_fixed_pickups().size() == 1 and a.weapon == null, "nuovo round: la spada fissa torna al centro")
