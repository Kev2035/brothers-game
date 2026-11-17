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

	await _test_personaggi_solidi(p0, p1)
	await _test_armi_bosco(p0, p1)
	await _test_radici()
	await _test_bosco_2_3()
	await _test_perni()
	await _test_binari()
	await _test_oblique()
	await _test_ascensori()
	await _test_scivolo_aperto()
	await _test_sottobosco()
	await _test_notte()
	await _test_buio_varianti()
	await _test_bosco_finale()
	await _test_scorrimento_oggetti()
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


## Carica un'arena da sola (senza lobby) con due giocatori. Ritorna [a, b].
func _open_arena(path: String) -> Array:
	main.queue_free()
	await frames(3)
	main = load("res://src/core/main.tscn").instantiate()
	main.fixed_arena = load(path)
	root.add_child(main)
	await frames(2)
	main.auto_weapons = false
	var a = main.add_player("kb_b", -1, "kb_b")
	var b = main.add_player("joy", 0, "joy_0")
	await frames(60)
	return [a, b]


## Controlla che dal cielo cadano solo le armi permesse (nomi dei file .tres).
func _only_weapons(allowed: Array) -> bool:
	var ok := true
	for i in 40:
		var pk = main.spawn_weapon()
		var file: String = pk.data.resource_path.get_file().get_basename()
		if not allowed.has(file):
			ok = false
		pk.queue_free()
	await frames(2)
	return ok


## Livelli 2 e 3 del bosco.
func _test_bosco_2_3() -> void:
	const BOSCO_2 := ["sling", "wooden_sword", "knife", "axe"]
	check(main.ARENA_PATHS[1].ends_with("tronchi.tscn") and main.ARENA_PATHS[2].ends_with("piattaforme.tscn"), "i livelli 2 e 3 del bosco vengono dopo Le radici")

	# --- Livello 2: I tronchi sottili ---
	var pl: Array = await _open_arena("res://src/arenas/bosco/tronchi.tscn")
	var a = pl[0]
	var b = pl[1]
	check(main.arena.arena_name == "I tronchi sottili" and a.is_on_floor() and b.is_on_floor(), "Tronchi: si parte in piedi sulla base")
	check(await _only_weapons(BOSCO_2), "Tronchi: cadono solo fionde, spade di legno, coltelli e asce")
	check(a._wall_side() == 0, "Tronchi: si parte in mezzo a due alberi, staccati dai tronchi")
	# Non si passa da un corridoio all'altro camminando: i tronchi sono muri.
	var x_start: float = a.global_position.x
	Input.action_press("p0_left")
	await frames(60)
	Input.action_release("p0_left")
	check(a.global_position.x > 1160.0 and a.global_position.x < x_start - 50.0, "Tronchi: i tronchi sono muri (ci si ferma a x=%.0f)" % a.global_position.x)
	# Si sale rimbalzando da un tronco all'altro col salto dai muri.
	var dir := -1.0
	var t := 0
	var since := 99
	Input.action_press("p0_jump")
	await frames(3)
	Input.action_release("p0_jump")
	while t < 900 and not (a.is_on_floor() and a.global_position.y < 600.0):
		since += 1
		Input.action_release("p0_left")
		Input.action_release("p0_right")
		Input.action_press("p0_left" if dir < 0.0 else "p0_right")
		if since == 2:
			Input.action_release("p0_jump")
			Input.action_release("p0_up")
		if since > 4 and not a.is_on_floor() and a._wall_side() == int(dir):
			Input.action_press("p0_up") # sulla tastiera il tasto del salto è anche "su"
			Input.action_press("p0_jump")
			since = 0
			dir = -dir
		elif since > 20 and a.is_on_floor():
			Input.action_press("p0_jump") # ricaduto a terra: si riparte
			since = 0
		await physics_frame
		t += 1
	Input.action_release("p0_left")
	Input.action_release("p0_right")
	Input.action_release("p0_jump")
	Input.action_release("p0_up")
	print("    Tronchi: in cima in %.1f s rimbalzando tra due tronchi (y=%.0f)" % [t / 60.0, a.global_position.y])
	check(a.is_on_floor() and a.global_position.y < 600.0 and t < 240, "Tronchi: si arriva in cima rimbalzando tra i tronchi (%.1f s)" % (t / 60.0))

	# --- Livello 3: Il bosco delle piattaforme ---
	pl = await _open_arena("res://src/arenas/bosco/piattaforme.tscn")
	a = pl[0]
	b = pl[1]
	check(main.arena.arena_name == "Il bosco delle piattaforme" and a.is_on_floor() and b.is_on_floor(), "Piattaforme: si parte sulle due piattaforme laterali in basso")
	check(a.global_position.x < 700.0 and b.global_position.x > 2500.0, "Piattaforme: uno a sinistra e uno a destra")
	check(await _only_weapons(BOSCO_2), "Piattaforme: cadono solo le armi del bosco")
	# Dalla partenza si sale fino in cima saltando di piattaforma in piattaforma.
	a.global_position = Vector2(330, 1148) # piattaforma sul primo albero
	a.velocity = Vector2.ZERO
	await frames(20)
	check(a.is_on_floor(), "Piattaforme: si sta sulle piattaforme degli alberi")
	# In mezzo c'è il vuoto: cadere uccide.
	var falls_before: int = main.falls[1]
	b.global_position = Vector2(1800, 1500)
	b.velocity = Vector2.ZERO
	await _wait_for(func(): return not b.alive, 3.0)
	check(not b.alive and main.falls[1] == falls_before + 1, "Piattaforme: si puo cadere nel vuoto")
	await create_timer(2.8).timeout


## Livello 4 del bosco: piattaforme a perno, tutte insieme a fasi.
func _test_perni() -> void:
	check(main.ARENA_PATHS[3].ends_with("perni.tscn"), "il livello 4 del bosco viene dopo il 3")
	var pl: Array = await _open_arena("res://src/arenas/bosco/perni.tscn")
	var a = pl[0]
	var b = pl[1]
	check(main.arena.arena_name == "Le piattaforme a perno" and a.is_on_floor() and b.is_on_floor(), "Perni: si parte sulle piattaforme laterali")
	check(await _only_weapons(["knife", "axe", "crossbow"]), "Perni: cadono coltelli, asce e balestre")
	var pivots: Array = get_nodes_in_group("round_reset").filter(func(n): return n is PivotPlatform)
	check(pivots.size() == 15, "Perni: tutte le piattaforme sono a perno (%d)" % pivots.size())

	# Ponte basso (1010..1600, y=1300, perno a x=1305): nella prima fase cede la metà sinistra.
	var pv: PivotPlatform = main.arena.get_node("Platforms/Bridge23Low")
	main.start_round()
	await frames(2)
	a.global_position = Vector2(1150, 1298) # metà sinistra
	b.global_position = Vector2(1450, 1298) # metà destra
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO
	var gun = main.spawn_weapon(load("res://src/weapons/knife.tres"), 1250.0)
	gun.global_position = Vector2(1250, 1200) # un'arma appoggiata sulla metà sinistra
	await frames(90)
	check(a.is_on_floor() and b.is_on_floor() and pv.is_trembling(-1) and not pv.is_trembling(1), "Perni: la meta che sta per cedere trema, ma regge ancora")
	var trembling := 0
	for p in pivots:
		if p.is_trembling(-1) or p.is_trembling(1):
			trembling += 1
	check(trembling == 13, "Perni: tremano tante piattaforme insieme (%d su 15; le 2 di partenza aspettano)" % trembling)
	check(gun.global_position.y < 1300.0, "Perni: l'arma e' appoggiata sulla piattaforma")
	await frames(120) # siamo a ~3,5 s: la prima fase è scattata
	var down_left := 0
	var down_right := 0
	for p in pivots:
		down_left += 1 if p.is_down(-1) else 0
		down_right += 1 if p.is_down(1) else 0
	check(down_left + down_right == 13 and down_left >= 5 and down_right >= 5, "Perni: cedono tutte insieme, alcune a sinistra e altre a destra (%d + %d)" % [down_left, down_right])
	check(pv.is_down(-1) and a.global_position.y > 1400.0, "Perni: dopo 3 s la meta ruota giu e chi c'e' sopra cade (y=%.0f)" % a.global_position.y)
	check(b.is_on_floor() and absf(b.global_position.y - 1300.0) < 3.0, "Perni: l'altra meta resta solida")
	check(not is_instance_valid(gun) or gun.global_position.y > 1400.0, "Perni: anche l'arma appoggiata cade")
	await _wait_for(func(): return not a.alive, 3.0)
	check(not a.alive, "Perni: sotto c'e' il vuoto")
	await create_timer(2.8).timeout # nuovo round

	# La metà abbassata è un muro appeso al perno: ci si può saltare contro.
	main.start_round()
	await frames(2)
	b.global_position = Vector2(1450, 1298)
	a.global_position = Vector2(1550, 1298) # intanto aspetta al sicuro sulla metà destra
	a.velocity = Vector2.ZERO
	await _wait_for(func(): return pv.is_wall(-1), 5.0)
	await frames(2)
	a.global_position = Vector2(1345, 1400) # subito a destra della metà che pende
	a.velocity = Vector2.ZERO
	a._air_jumps = 0
	await frames(8)
	check(pv.is_wall(-1) and a._wall_side() == -1, "Perni: la meta abbassata e' un muro")
	await tap("p0_jump")
	check(a.velocity.y < -300.0 and a.velocity.x > 200.0, "Perni: dalla meta abbassata si puo fare il salto dal muro")
	await frames(60)

	# La sequenza è fissa: a ogni round riparte uguale. Si controlla tutto un giro.
	main.start_round()
	await frames(2)
	check(pv.time < 0.1 and pv.is_trembling(-1), "Perni: a ogni round la sequenza riparte da capo")
	b.global_position = Vector2(300, 1000) # lontano dalle prove
	var seq := ""
	var last := ""
	for i in int(pv.cycle_time() * 60.0) - 10:
		var now := "L" if pv.is_down(-1) else ("R" if pv.is_down(1) else "-")
		if now != last:
			seq += now
			last = now
		await physics_frame
	check(seq == "-L-R", "Perni: prima cede una meta, poi torna su, poi cede l'altra (%s)" % seq)
	# Tornata su, la metà regge di nuovo e il muro non c'è più.
	main.start_round()
	await frames(2)
	pv.time = pv.tremble_time + pv.down_time + 0.2
	await frames(3)
	a.global_position = Vector2(1150, 1250)
	a.velocity = Vector2.ZERO
	await frames(30)
	check(a.is_on_floor() and absf(a.global_position.y - 1300.0) < 3.0 and not pv.is_wall(-1), "Perni: tornata su, la meta regge di nuovo")
	main.start_round()


## I personaggi sono solidi tra loro: non ci si passa attraverso.
func _test_personaggi_solidi(p0, p1) -> void:
	main.start_round()
	await frames(20)
	p0.global_position = Vector2(1000, GROUND)
	p1.global_position = Vector2(1200, GROUND)
	await frames(5)
	Input.action_press("p0_right")
	await frames(60)
	Input.action_release("p0_right")
	var gap: float = p1.global_position.x - p0.global_position.x
	print("    P0 corre contro P1: si ferma a %.0f px (P1 a x=%.0f)" % [gap, p1.global_position.x])
	check(gap > 44.0 and gap < 56.0, "i personaggi non si sovrappongono: ci si ferma contro l'avversario")
	check(absf(p1.global_position.x - 1200.0) < 2.0, "correndogli contro l'avversario non viene spinto")
	# A contatto il pugno arriva.
	var hp: float = p1.health
	await tap("p0_attack")
	await frames(5)
	check(p1.health < hp, "a contatto il pugno colpisce")
	# Per passare dall'altra parte bisogna saltarlo.
	p1.global_position = Vector2(480, GROUND)
	p0.global_position = Vector2(600, GROUND)
	await frames(5)
	Input.action_press("p0_left")
	Input.action_press("p0_jump")
	await frames(45)
	Input.action_release("p0_jump")
	await frames(40)
	Input.action_release("p0_left")
	check(p0.global_position.x < p1.global_position.x - 40.0 and p0.is_on_floor() and p0.alive, "saltando si passa sopra l'avversario (x=%.0f)" % p0.global_position.x)
	# Si può stare in piedi sulla testa dell'altro.
	p0.global_position = Vector2(480, GROUND - 150)
	p0.velocity = Vector2.ZERO
	await frames(40)
	check(p0.is_on_floor() and absf(p0.global_position.y - (GROUND - 88.0)) < 4.0, "si puo stare in piedi sulla testa dell'avversario (y=%.0f)" % p0.global_position.y)
	# Due personaggi finiti nello stesso punto si separano da soli.
	p0.global_position = Vector2(1200, GROUND)
	p1.global_position = Vector2(1200, GROUND)
	await frames(40)
	gap = absf(p1.global_position.x - p0.global_position.x)
	check(gap > 40.0, "due personaggi nello stesso punto si separano (%.0f px)" % gap)
	# Un personaggio eliminato non fa da ostacolo invisibile.
	main.start_round()
	await frames(20)
	p0.global_position = Vector2(1000, GROUND)
	p1.global_position = Vector2(1200, GROUND)
	await frames(3)
	p1.take_hit(Vector2.RIGHT, p1.global_position, 999.0, null)
	Input.action_press("p0_right")
	await frames(40)
	Input.action_release("p0_right")
	check(not p1.alive and p0.global_position.x > 1250.0, "un personaggio eliminato non blocca il passaggio")
	await create_timer(2.8).timeout


## Livello 5 del bosco: i binari con le piattaforme che scorrono.
func _test_binari() -> void:
	check(main.ARENA_PATHS[4].ends_with("binari.tscn"), "il livello 5 del bosco viene dopo il 4")
	var pl: Array = await _open_arena("res://src/arenas/bosco/binari.tscn")
	var a = pl[0]
	var b = pl[1]
	var rails: Array = get_nodes_in_group("round_reset").filter(func(n): return n is Rail)
	rails.sort_custom(func(x, y): return x.global_position.y > y.global_position.y) # dal basso verso l'alto
	check(rails.size() == 5, "Binari: ci sono 5 piani di binari (%d)" % rails.size())
	var alternate := true
	for i in rails.size() - 1:
		if signf(rails[i].speed) == signf(rails[i + 1].speed):
			alternate = false
	check(alternate, "Binari: ogni piano scorre in senso opposto a quello sotto")
	check(await _only_weapons(["knife", "axe", "crossbow"]), "Binari: cadono coltelli, asce e balestre")

	# Si parte fermi, in piedi su una piattaforma.
	main.start_round()
	await frames(30)
	var ax0: float = a.global_position.x
	check(main.arena.arena_name == "I binari" and a.is_on_floor() and b.is_on_floor(), "Binari: si parte in piedi sulle piattaforme")
	await frames(60)
	check(absf(a.global_position.x - ax0) < 1.0 and rails[0].travelled() == 0.0, "Binari: all'inizio le piattaforme sono ferme")
	# Poi partono e trasportano chi c'è sopra (il piano più basso va verso destra).
	var gun = main.spawn_weapon(load("res://src/weapons/knife.tres"), b.global_position.x + 60.0)
	gun.global_position = Vector2(b.global_position.x + 90.0, b.global_position.y - 120.0)
	await frames(150) # siamo a 4 s dall'inizio del round
	var moved: float = a.global_position.x - ax0
	print("    Binari: dopo 4 s il personaggio e' stato trasportato di %.0f px (la fila di %.0f)" % [moved, rails[0].travelled()])
	check(a.is_on_floor() and moved > 100.0 and absf(moved - rails[0].travelled()) < 15.0, "Binari: la piattaforma trasporta chi c'e' sopra")
	check(is_instance_valid(gun) and gun.global_position.y < b.global_position.y + 30.0, "Binari: le armi restano appoggiate sulle piattaforme che si muovono")
	# Il piano sopra va dall'altra parte: saltandoci si viene portati indietro.
	var up_x0: float = rails[1].travelled()
	await frames(30)
	var up_moved: float = rails[1].travelled() - up_x0
	check(up_moved < -50.0 and up_moved > -200.0, "Binari: il secondo piano scorre verso sinistra (%.0f px in mezzo secondo)" % up_moved)
	# Le piattaforme che escono da un lato rientrano dall'altro, fuori dallo schermo.
	main.start_round() # da capo, così nei prossimi 7 secondi nessuno cade e il round non ricomincia
	await frames(2)
	var rail: Rail = rails[0]
	var wrapped := false
	var on_screen_jump := false
	var prev: Array = []
	for i in rail.lengths.size():
		prev.append(rail.platform_x(i))
	for f in 420:
		await physics_frame
		for i in rail.lengths.size():
			var x: float = rail.platform_x(i)
			if absf(x - prev[i]) > 500.0:
				wrapped = true
				var gx_old: float = rail.global_position.x + prev[i]
				var gx_new: float = rail.global_position.x + x
				# Né il punto da cui sparisce né quello in cui ricompare si devono vedere.
				if gx_old < 3450.0 or gx_new + rail.lengths[i] > -250.0:
					on_screen_jump = true
			prev[i] = x
	check(wrapped and not on_screen_jump, "Binari: le piattaforme rientrano dall'altro lato senza che si veda")
	# Restando fermi si finisce fuori: sotto c'è il vuoto.
	await _wait_for(func(): return not a.alive or not b.alive, 20.0)
	check(not a.alive or not b.alive, "Binari: restando fermi si viene portati fuori e si cade nel vuoto")
	await create_timer(2.8).timeout
	# Nuovo round: tutto torna al punto di partenza.
	main.start_round()
	await frames(20)
	check(rails[0].time < 0.5 and a.is_on_floor() and absf(a.global_position.x - ax0) < 2.0, "Binari: a ogni round le piattaforme ripartono dallo stesso punto")


## Livello 6 del bosco: piattaforme oblique su cui si scivola.
func _test_oblique() -> void:
	check(main.ARENA_PATHS[5].ends_with("oblique.tscn"), "il livello 6 del bosco viene dopo il 5")
	var pl: Array = await _open_arena("res://src/arenas/bosco/oblique.tscn")
	var a = pl[0]
	var b = pl[1]
	check(main.arena.arena_name == "Le piattaforme oblique" and a.is_on_floor() and b.is_on_floor(), "Oblique: si parte in piedi sulle piattaforme piatte")
	check(await _only_weapons(["knife", "axe", "crossbow"]), "Oblique: cadono coltelli, asce e balestre")
	var ax0: float = a.global_position.x
	await frames(40)
	check(absf(a.global_position.x - ax0) < 1.0, "Oblique: sulle piattaforme piatte non si scivola")

	# Scivolo in alto a sinistra: parte da (760, 520) e scende verso destra.
	a.global_position = Vector2(900, 480)
	a.velocity = Vector2.ZERO
	await frames(16)
	var x1: float = a.global_position.x
	var y1: float = a.global_position.y
	check(a.is_on_floor() and a.velocity.x > 700.0, "Oblique: atterrando su una piattaforma obliqua si scivola (velocita %.0f)" % a.velocity.x)
	# Spingendo in salita si rallenta ma si continua a scendere.
	Input.action_press("p0_left")
	await frames(8)
	Input.action_release("p0_left")
	check(a.global_position.x > x1 + 40.0 and a.global_position.y > y1 + 15.0, "Oblique: non si puo risalire, si continua a scivolare giu")
	# In fondo si viene lanciati sulla piattaforma dopo (quella piatta al centro, y=860).
	await _wait_for(func(): return a.is_on_floor() and absf(a.global_position.y - 860.0) < 3.0, 3.0)
	await frames(30)
	print("    Oblique: dallo scivolo in alto si arriva a x=%.0f y=%.0f" % [a.global_position.x, a.global_position.y])
	check(a.is_on_floor() and absf(a.global_position.y - 860.0) < 3.0 and absf(a.velocity.x) < 5.0, "Oblique: in fondo allo scivolo si atterra sulla piattaforma dopo e ci si ferma")

	# Mentre si scivola si può saltare.
	a.global_position = Vector2(900, 480)
	a.velocity = Vector2.ZERO
	await frames(16)
	Input.action_press("p0_jump")
	await frames(3)
	check(a.velocity.y < -500.0 and not a.is_on_floor(), "Oblique: mentre si scivola si puo saltare")
	Input.action_release("p0_jump")
	await frames(90)

	# Lo scivolo verso sinistra funziona allo specchio.
	b.global_position = Vector2(2300, 480)
	b.velocity = Vector2.ZERO
	await frames(16)
	check(b.is_on_floor() and b.velocity.x < -700.0, "Oblique: lo scivolo a destra porta verso sinistra (velocita %.0f)" % b.velocity.x)
	await frames(90)

	# Anche le armi scivolano: cadute su uno scivolo finiscono sulla piattaforma dopo.
	main.start_round()
	await frames(5)
	var knife = main.spawn_weapon(load("res://src/weapons/knife.tres"), 900.0)
	knife.global_position = Vector2(900, 480)
	await frames(40)
	var kx: float = knife.global_position.x
	await frames(60)
	check(knife.global_position.x > kx + 100.0, "Oblique: anche le armi scivolano giu (%.0f px in 1 s)" % (knife.global_position.x - kx))
	await frames(180)
	print("    Oblique: l'arma si ferma a x=%.0f y=%.0f" % [knife.global_position.x, knife.global_position.y])
	check(knife.global_position.y > 800.0 and knife.global_position.y < 870.0 and knife.linear_velocity.length() < 20.0, "Oblique: l'arma si ferma sulla piattaforma piatta in fondo")
	main.start_round()


## Livello 7 del bosco: ascensori e scivoli a spirale.
func _test_ascensori() -> void:
	check(main.ARENA_PATHS[6].ends_with("ascensori.tscn"), "il livello 7 del bosco viene dopo il 6")
	var pl: Array = await _open_arena("res://src/arenas/bosco/ascensori.tscn")
	var a = pl[0]
	var b = pl[1]
	check(main.arena.arena_name == "Ascensori e scivoli" and a.is_on_floor() and b.is_on_floor(), "Ascensori: si parte in piedi sulle piattaforme basse")
	check(await _only_weapons(["knife", "axe", "crossbow"]), "Ascensori: cadono coltelli, asce e balestre")
	var elevators: Array = get_nodes_in_group("round_reset").filter(func(n): return n is Elevator)
	var spirals: Array = get_nodes_in_group("round_reset").filter(func(n): return n is SpiralSlide)
	check(elevators.size() == 3 and spirals.size() == 2, "Ascensori: 3 ascensori e 2 scivoli a spirale")

	# --- Ascensore: sale e scende di continuo e trasporta chi c'è sopra. ---
	var el: Elevator = main.arena.get_node("Platforms/ElevatorLeft")
	main.start_round()
	await frames(2)
	var top_y: float = el.global_position.y
	a.global_position = Vector2(260, top_y - 2.0)
	a.velocity = Vector2.ZERO
	var low := top_y
	var high := 99999.0
	var always_on := true
	var went_down := false
	for i in int((el.period + el.start_delay) * 60.0):
		await physics_frame
		low = maxf(low, a.global_position.y)
		if a.global_position.y > top_y + el.travel - 30.0:
			went_down = true
		if went_down:
			high = minf(high, a.global_position.y)
		if i > 20 and not a.is_on_floor():
			always_on = false
	print("    Ascensore: il personaggio scende fino a y=%.0f e risale a y=%.0f (corsa %.0f)" % [low, high, el.travel])
	check(low > top_y + el.travel - 30.0 and high < top_y + 40.0, "Ascensori: l'ascensore porta giu e poi di nuovo su chi c'e' sopra")
	check(always_on and a.alive, "Ascensori: sull'ascensore si resta appoggiati per tutto il giro")
	var center: Elevator = main.arena.get_node("Platforms/ElevatorCenter")
	check(center.start_low and center.drop() != el.drop(), "Ascensori: gli ascensori non si muovono tutti insieme")

	# --- Scivolo a spirale: prende chi arriva sull'imbocco e lo porta giù. ---
	var sp: SpiralSlide = main.arena.get_node("Platforms/SpiralLeft")
	main.start_round()
	await frames(5)
	b.global_position = Vector2(1600, 598) # P1 in mezzo alla piattaforma in alto: spara verso lo scivolo
	b.velocity = Vector2.ZERO
	a.global_position = sp.entry_point() + Vector2(80, -2) # sulla piattaforma, accanto all'imbocco
	a.velocity = Vector2.ZERO
	await frames(10)
	check(a.is_on_floor() and not a.riding, "Ascensori: accanto all'imbocco non succede niente")
	Input.action_press("p0_left")
	await _wait_for(func(): return a.riding, 1.0)
	Input.action_release("p0_left")
	check(a.riding and sp.is_riding(a), "Ascensori: arrivando sull'imbocco si viene presi dallo scivolo")
	var hp: float = a.health
	var hit: bool = a.take_hit(Vector2.LEFT, b.global_position, 50.0, b)
	check(not hit and a.health == hp, "Ascensori: sullo scivolo non si puo essere colpiti")
	var hidden := false
	var shown := false
	var went_left := false
	var went_right := false
	var t := 0
	Input.action_press("p0_right") # i comandi non contano: lo scivolo va da solo
	while a.riding and t < 240:
		await physics_frame
		t += 1
		if a.riding:
			hidden = hidden or not a.visible
			shown = shown or a.visible
			went_left = went_left or a.global_position.x < sp.global_position.x - 80.0
			went_right = went_right or a.global_position.x > sp.global_position.x + 80.0
	Input.action_release("p0_right")
	check(hidden and shown and went_left and went_right, "Ascensori: lo scivolo gira attorno al tronco e dietro il personaggio sparisce")
	check(absf(t / 60.0 - sp.duration) < 0.2, "Ascensori: la discesa dura quanto previsto (%.1f s)" % (t / 60.0))
	await frames(40)
	print("    Scivolo: uscita a %s (prevista %s)" % [a.global_position, sp.exit_point()])
	check(not a.riding and a.visible and a.is_on_floor() and absf(a.global_position.y - 1500.0) < 3.0 and a.global_position.x < sp.global_position.x, "Ascensori: in fondo si esce sulla piattaforma bassa, dall'altro lato del tronco")
	hit = a.take_hit(Vector2.LEFT, a.global_position + Vector2(100, -50), 10.0, b)
	check(hit and a.health == hp - 10.0, "Ascensori: usciti dallo scivolo si torna vulnerabili")

	# Nuovo round a metà discesa: il personaggio torna normale.
	main.start_round()
	await frames(5)
	a.global_position = sp.entry_point() + Vector2(0, -2)
	a.velocity = Vector2.ZERO
	await _wait_for(func(): return a.riding, 1.0)
	await frames(30)
	check(a.riding, "Ascensori: di nuovo sullo scivolo")
	main.start_round()
	await frames(20)
	check(not a.riding and a.visible and a.is_on_floor() and a.global_position.distance_to(main.arena.spawn_points()[0]) < 30.0, "Ascensori: col nuovo round chi era sullo scivolo riparte normale")


## Scivolo a spirale "aperto": ci si atterra in un punto qualsiasi e si salta fuori quando si vuole.
## (Si usa l'arena del livello 7 già aperta da _test_ascensori.)
func _test_scivolo_aperto() -> void:
	var a = main.participants()[0]
	var sp: SpiralSlide = main.arena.get_node("Platforms/SpiralLeft")
	main.start_round()
	await frames(5)

	# Atterrando a metà scivolo (su un tratto davanti al tronco) la scivolata parte da lì.
	a.global_position = sp.global_position + sp.point(0.5) + Vector2(0, -90)
	a.velocity = Vector2.ZERO
	a._air_jumps = 0
	await _wait_for(func(): return a.riding, 1.0)
	var start_k: float = sp._riders.get(a, -1.0) / sp.duration
	print("    Scivolo aperto: atterrato a meta, la scivolata parte dal %.0f%% del percorso" % (start_k * 100.0))
	check(a.riding and start_k > 0.4 and start_k < 0.6, "Scivolo: atterrando a meta si scivola da quel punto")
	var t := 0
	while a.riding and t < 240:
		await physics_frame
		t += 1
	await frames(30)
	check(absf(t / 60.0 - sp.duration * (1.0 - start_k)) < 0.2 and a.is_on_floor() and absf(a.global_position.y - 1500.0) < 3.0, "Scivolo: da meta si arriva in fondo in meta tempo (%.1f s)" % (t / 60.0))

	# Un tratto dietro al tronco non si può prendere al volo: ci si passa davanti.
	main.start_round()
	await frames(5)
	a.global_position = sp.global_position + sp.point(0.3) + Vector2(0, -60)
	a.velocity = Vector2.ZERO
	check(sp.is_behind(0.3), "Scivolo: al 30% il percorso passa dietro al tronco")
	await frames(6)
	check(not a.riding, "Scivolo: i tratti dietro al tronco non ti prendono")
	await _wait_for(func(): return a.riding or a.is_on_floor(), 2.0)

	# Dallo scivolo si salta fuori quando si vuole (e si riparte col doppio salto).
	main.start_round()
	await frames(5)
	a.global_position = sp.entry_point() + Vector2(0, -2)
	a.velocity = Vector2.ZERO
	await _wait_for(func(): return a.riding, 1.0)
	await frames(25)
	check(a.riding, "Scivolo: sto scivolando")
	var y_before: float = a.global_position.y
	Input.action_press("p0_jump")
	await frames(2)
	check(not a.riding and a.visible and a.velocity.y < -500.0 and a._air_jumps == a.max_air_jumps, "Scivolo: col tasto del salto si salta fuori (velocita verticale %.0f)" % a.velocity.y)
	await frames(8)
	Input.action_release("p0_jump")
	check(not a.riding and a.global_position.y < y_before - 60.0, "Scivolo: saltato fuori, lo scivolo non ti riprende subito")
	# Tornando giù su un tratto dello scivolo, si riparte a scivolare da lì.
	await _wait_for(func(): return a.riding or a.is_on_floor() or not a.alive, 3.0)
	print("    Scivolo aperto: dopo il salto -> di nuovo sullo scivolo %s, a terra %s" % [a.riding, a.is_on_floor()])

	# Con Giù ci si lascia cadere.
	main.start_round()
	await frames(5)
	a.global_position = sp.entry_point() + Vector2(0, -2)
	a.velocity = Vector2.ZERO
	await _wait_for(func(): return a.riding, 1.0)
	await frames(20)
	Input.action_press("p0_down")
	await frames(3)
	Input.action_release("p0_down")
	check(not a.riding and a.velocity.y > 0.0, "Scivolo: con Giu ci si lascia cadere")

	# In piedi sulla piattaforma d'arrivo lo scivolo non ti riprende.
	main.start_round()
	await frames(5)
	a.global_position = sp.exit_point() + Vector2(0, -2)
	a.velocity = Vector2.ZERO
	await frames(40)
	check(not a.riding and a.is_on_floor(), "Scivolo: fermi all'uscita non si viene ripresi")
	main.start_round()


## Livello 8 del bosco: il sottobosco con i cespugli in cui nascondersi.
func _test_sottobosco() -> void:
	check(main.ARENA_PATHS[7].ends_with("sottobosco.tscn"), "il livello 8 del bosco viene dopo il 7")
	var pl: Array = await _open_arena("res://src/arenas/bosco/sottobosco.tscn")
	var a = pl[0]
	var b = pl[1]
	check(main.arena.arena_name == "Il sottobosco" and a.is_on_floor() and b.is_on_floor(), "Sottobosco: si parte in piedi sul terreno")
	check(not a.concealed and not b.concealed, "Sottobosco: alla partenza nessuno e' nascosto")
	check(await _only_weapons(["knife", "axe", "crossbow"]), "Sottobosco: cadono coltelli, asce e balestre")
	var bushes: Array = get_nodes_in_group("hide_zones")
	check(bushes.size() == 7, "Sottobosco: ci sono 7 cespugli (%d)" % bushes.size())
	var bush: Bush = main.arena.get_node("Bushes/BushLeft2") # sul terreno, da x=880 a x=1180
	check(bush.z_index > 0, "Sottobosco: il cespuglio si disegna sopra ai personaggi")

	# Entrando nel cespuglio si sparisce, uscendo si ricompare.
	a.global_position = Vector2(780, 1498)
	await frames(5)
	Input.action_press("p0_right")
	await _wait_for(func(): return a.concealed, 2.0)
	var hidden_x: float = a.global_position.x
	Input.action_release("p0_right")
	await frames(20)
	check(a.concealed and hidden_x > 880.0 and hidden_x < 1000.0, "Sottobosco: entrando nel cespuglio si sparisce (da x=%.0f)" % hidden_x)
	check(a.visible and a.alive, "Sottobosco: nascosto non vuol dire tolto dal gioco")
	# Dentro si resta colpibili.
	var hp: float = a.health
	check(a.take_hit(Vector2.LEFT, a.global_position + Vector2(100, -50), 10.0, b) and a.health == hp - 10.0, "Sottobosco: nel cespuglio si puo essere colpiti")
	# Il cespuglio si agita se chi è dentro si muove, e si calma se sta fermo.
	await frames(60)
	var calm: float = bush._shake
	Input.action_press("p0_right")
	await frames(10)
	var moving: float = bush._shake
	Input.action_release("p0_right")
	check(calm < 0.05 and moving > 0.5, "Sottobosco: il cespuglio si agita quando ci si muove dentro (%.2f -> %.2f)" % [calm, moving])
	Input.action_press("p0_right")
	await _wait_for(func(): return not a.concealed, 2.0)
	Input.action_release("p0_right")
	check(not a.concealed and a.global_position.x > 1140.0, "Sottobosco: uscendo dal cespuglio si ricompare (x=%.0f)" % a.global_position.x)
	# Saltando sopra il cespuglio non si è nascosti.
	a.global_position = Vector2(1030, 1498 - 260)
	a.velocity = Vector2.ZERO
	await frames(2)
	check(not a.concealed, "Sottobosco: sopra il cespuglio non si e' nascosti")
	main.start_round()
	await frames(5)
	check(not a.concealed, "Sottobosco: a ogni round si riparte visibili")


## Livello 9 del bosco: buio pesto, solo lucciole, lampi di luce quando si colpisce.
func _test_notte() -> void:
	check(main.ARENA_PATHS[8].ends_with("notte.tscn"), "il livello 9 del bosco viene dopo l'8")
	var pl: Array = await _open_arena("res://src/arenas/bosco/notte.tscn")
	var a = pl[0]
	var b = pl[1]
	var arena: Arena = main.arena
	check(arena.arena_name == "Notte fonda" and a.is_on_floor() and b.is_on_floor(), "Notte: si parte in piedi sulle piattaforme laterali")
	check(await _only_weapons(["knife", "sling", "crossbow"]), "Notte: cadono coltelli, fionde e balestre (niente asce)")
	check(arena.is_dark() and arena.ambient.get_luminance() < 0.05 and Arena.night, "Notte: buio pesto (luce d'ambiente %.3f)" % arena.ambient.get_luminance())
	var lights: Array = get_nodes_in_group("lights")
	check(lights.size() == 5 and lights.all(func(l): return not l.hanging and l.wander > 0.0), "Notte: solo lucciole che girano, niente lanterne (%d)" % lights.size())
	check(get_nodes_in_group("hide_zones").is_empty(), "Notte: non servono zone di buio a parte, e' buia tutta l'arena")
	var fly_pos: Vector2 = lights[0].global_position
	await frames(60)
	check(lights[0].global_position.distance_to(fly_pos) > 60.0 and lights[0].get_child(0) is PointLight2D, "Notte: le lucciole si muovono e fanno luce")

	# Sguardo iniziale: a inizio round l'arena è illuminata, poi si spegne.
	main.start_round()
	await frames(3)
	check(main.ambient_light.color.is_equal_approx(arena.intro_ambient), "Notte: a inizio round l'arena e' illuminata per guardarsi intorno")
	await create_timer(arena.intro_light_time + arena.intro_fade_time * 0.5).timeout
	var half: float = main.ambient_light.color.get_luminance()
	await create_timer(arena.intro_fade_time * 0.5 + 0.3).timeout
	check(half < arena.intro_ambient.get_luminance() - 0.03 and main.ambient_light.color.is_equal_approx(arena.ambient), "Notte: dopo %.0f secondi la luce si spegne piano (a meta %.2f)" % [arena.intro_light_time, half])

	# Buio totale: degli avversari non si vede niente, nemmeno gli occhi.
	check(not a._eyes.visible and not b._eyes.visible and not arena.eyes_in_dark, "Notte: al buio non si vedono nemmeno gli occhi")
	# (Gli occhi si possono riaccendere dall'arena, se il buio totale risulta ingiocabile.)
	arena.eyes_in_dark = true
	main._start_light()
	await frames(3)
	check(a._eyes.visible and a._eyes.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "Notte: gli occhi si possono riaccendere dall'arena")
	arena.eyes_in_dark = false
	main._start_light()
	main.ambient_light.color = arena.ambient
	await frames(3)
	check(not a._eyes.visible, "Notte: e si spengono di nuovo")

	# Chi spara si fa vedere: lampo di luce, e il colpo in volo fa luce.
	main._spawn_timer = 999.0
	a.global_position = Vector2(300, 1448)
	b.global_position = Vector2(650, 1448)
	a.facing = 1.0
	a.equip(load("res://src/weapons/crossbow.tres"))
	await frames(5)
	check(get_nodes_in_group("flashes").is_empty(), "Notte: senza colpi nessun lampo")
	Input.action_press("p0_attack")
	await frames(2)
	Input.action_release("p0_attack")
	var flashes: Array = get_nodes_in_group("flashes").filter(func(f): return not f.is_queued_for_deletion())
	var bolts: Array = get_nodes_in_group("bullets")
	check(flashes.size() >= 1 and flashes[0].global_position.distance_to(a.global_position) < 80.0, "Notte: sparando parte un lampo di luce su chi spara")
	check(bolts.size() == 1 and bolts[0].get_children().any(func(c): return c is PointLight2D), "Notte: il colpo in volo fa luce")
	await frames(12)
	flashes = get_nodes_in_group("flashes").filter(func(f): return not f.is_queued_for_deletion())
	check(b.health == 60.0 and flashes.any(func(f): return f.global_position.distance_to(b.global_position) < 80.0), "Notte: chi viene colpito si illumina per un attimo")
	await frames(60)
	check(get_nodes_in_group("flashes").filter(func(f): return not f.is_queued_for_deletion()).is_empty(), "Notte: i lampi si spengono da soli")
	# Anche i pugni fanno un piccolo lampo.
	a.drop_weapon()
	await tap("p0_attack")
	check(get_nodes_in_group("flashes").size() >= 1, "Notte: anche un pugno fa un piccolo lampo")
	# Le armi a terra fanno luce.
	var pk = main.spawn_weapon(load("res://src/weapons/knife.tres"), 1600.0)
	check(pk.get_children().any(func(c): return c is PointLight2D), "Notte: le armi a terra fanno un po' di luce")
	pk.queue_free()
	# Si può cadere: bisogna ricordarsi dove finisce la piattaforma.
	Input.action_press("p0_left")
	await _wait_for(func(): return not a.alive, 4.0)
	Input.action_release("p0_left")
	check(not a.alive, "Notte: un passo falso e si cade nel vuoto")
	await create_timer(2.8).timeout

	# Passando a un'arena di giorno tutto torna normale.
	await main.scroll_to_arena(load("res://src/arenas/bosco/radici.tscn"))
	await frames(5)
	check(main.ambient_light.color.is_equal_approx(Color.WHITE) and not Arena.night and not a._eyes.visible, "passando a un'arena di giorno torna la luce piena")
	var day_pk = main.spawn_weapon(load("res://src/weapons/knife.tres"), 1600.0)
	a.equip(load("res://src/weapons/crossbow.tres"))
	await tap("p0_attack")
	check(not day_pk.get_children().any(func(c): return c is PointLight2D) and get_nodes_in_group("flashes").is_empty(), "di giorno niente lampi e niente luci sulle armi")
	a.drop_weapon()
	main.scroll_to_arena(load("res://src/arenas/bosco/notte.tscn"))
	await create_timer(main.scroll_time * 0.5).timeout
	var mid: float = main.ambient_light.color.get_luminance()
	await _wait_for(func(): return not main.transitioning, 4.0)
	await frames(5)
	check(mid < 0.95 and mid > 0.4 and main.ambient_light.color.is_equal_approx(main.arena.intro_ambient) and Arena.night, "passando a un'arena di notte la luce cala piano (a meta scorrimento %.2f)" % mid)


## Le tre varianti del buio: funghi (livello 10), interruttori (11), lanterna (12).
func _test_buio_varianti() -> void:
	const DARK_WEAPONS := ["knife", "sling", "crossbow"]
	check(main.ARENA_PATHS[9].ends_with("funghi.tscn") and main.ARENA_PATHS[10].ends_with("interruttori.tscn") and main.ARENA_PATHS[11].ends_with("lanterna.tscn"), "i tre livelli bui nuovi vengono dopo il 9")

	# ---------- Livello 10: Il sentiero dei funghi ----------
	var pl: Array = await _open_arena("res://src/arenas/bosco/funghi.tscn")
	var a = pl[0]
	var b = pl[1]
	check(main.arena.arena_name == "Il sentiero dei funghi" and a.is_on_floor() and b.is_on_floor() and Arena.night, "Funghi: si parte in piedi, al buio")
	check(await _only_weapons(DARK_WEAPONS), "Funghi: cadono coltelli, fionde e balestre")
	var shrooms: Array = get_nodes_in_group("round_reset").filter(func(n): return n is GlowMushroom)
	check(shrooms.size() == 13 and shrooms.all(func(m): return not m.is_lit()), "Funghi: 13 funghi, tutti spenti alla partenza (%d)" % shrooms.size())
	# Non si cade: il terreno è pieno, ai lati c'è il bordo.
	b.global_position = Vector2(3300, 1558)
	b.velocity = Vector2(900, 0)
	await frames(120)
	check(b.alive and b.is_on_floor() and b.global_position.y < 1570.0, "Funghi: in questo livello non si puo cadere nel vuoto")
	# Calpestando un fungo si accende e poi si spegne; saltandolo resta spento.
	var m: GlowMushroom = main.arena.get_node("Mushrooms/Mushroom2") # sul terreno a x=800
	a.global_position = Vector2(640, 1558)
	await frames(5)
	check(not m.is_lit(), "Funghi: da lontano il fungo resta spento")
	Input.action_press("p0_right")
	await _wait_for(func(): return m.is_lit(), 2.0)
	Input.action_release("p0_right")
	await frames(3)
	check(m.is_lit() and m._light.energy > 0.5, "Funghi: calpestando un fungo si accende e illumina (luce %.1f)" % m._light.energy)
	a.global_position = Vector2(1050, 1558)
	await create_timer(m.glow_time + 0.3).timeout
	check(not m.is_lit() and m._light.energy < 0.05, "Funghi: dopo un po' il fungo si spegne")
	a.global_position = Vector2(700, 1558)
	a.velocity = Vector2.ZERO
	await frames(10)
	Input.action_press("p0_right")
	Input.action_press("p0_jump")
	await frames(40)
	Input.action_release("p0_jump")
	Input.action_release("p0_right")
	await frames(30)
	check(a.global_position.x > 900.0 and not m.is_lit(), "Funghi: saltando sopra il fungo non lo si accende (x=%.0f)" % a.global_position.x)

	# ---------- Livello 11: Gli interruttori ----------
	pl = await _open_arena("res://src/arenas/bosco/interruttori.tscn")
	a = pl[0]
	b = pl[1]
	check(main.arena.arena_name == "Gli interruttori" and a.is_on_floor() and b.is_on_floor() and Arena.night, "Interruttori: si parte in piedi, al buio")
	check(await _only_weapons(DARK_WEAPONS), "Interruttori: cadono coltelli, fionde e balestre")
	var switches: Array = get_nodes_in_group("hittables")
	var lamps: Array = get_nodes_in_group("lights")
	check(switches.size() == 4 and lamps.size() == 4 and lamps.all(func(l): return not l.is_on() and l._light.energy == 0.0), "Interruttori: 4 interruttori e 4 lanterne, tutte spente")
	var sw: LightSwitch = main.arena.get_node("Switches/SwitchLowLeft") # a terra a sinistra (x=230)
	var far: LightSource = main.arena.get_node("Lights/LampTopRight")
	check(sw.lamp() == far and far.global_position.x > 2000.0 and far.global_position.y < 800.0, "Interruttori: quello in basso a sinistra comanda la lanterna in alto a destra")
	# Un pugno sull'interruttore accende la zona opposta, per qualche secondo.
	a.global_position = Vector2(330, 1558)
	a.velocity = Vector2.ZERO
	await frames(5)
	Input.action_press("p0_left")
	await frames(2)
	Input.action_release("p0_left")
	await tap("p0_attack")
	await frames(20)
	check(far.is_on() and far._light.energy > 0.8, "Interruttori: un pugno sull'interruttore accende la lanterna lontana (luce %.1f)" % far._light.energy)
	check(lamps.filter(func(l): return l.is_on()).size() == 1, "Interruttori: si accende solo quella zona")
	await create_timer(sw.on_time + 1.2).timeout
	check(not far.is_on() and far._light.energy < 0.05, "Interruttori: dopo %.0f secondi la lanterna si spegne da sola" % sw.on_time)
	# Funziona anche con un colpo da lontano.
	a.global_position = Vector2(700, 1558)
	a.equip(load("res://src/weapons/crossbow.tres"))
	await frames(3)
	Input.action_press("p0_left")
	await frames(2)
	Input.action_release("p0_left")
	a.global_position = Vector2(700, 1558)
	a.velocity = Vector2.ZERO
	await frames(2)
	await tap("p0_attack")
	await frames(20)
	check(far.is_on(), "Interruttori: si attivano anche con una freccia da lontano")
	main.start_round()
	await frames(5)
	check(not far.is_on() and far._light.energy == 0.0, "Interruttori: a ogni round le lanterne ripartono spente")

	# ---------- Livello 12: La lanterna ----------
	pl = await _open_arena("res://src/arenas/bosco/lanterna.tscn")
	a = pl[0]
	b = pl[1]
	var LANTERN: WeaponData = load("res://src/weapons/lantern.tres")
	check(main.arena.arena_name == "La lanterna" and a.is_on_floor() and b.is_on_floor() and Arena.night, "Lanterna: si parte in piedi, al buio")
	check(await _only_weapons(DARK_WEAPONS), "Lanterna: cadono coltelli, fionde e balestre")
	var fixed := _fixed_pickups()
	check(fixed.size() == 1 and fixed[0].data == LANTERN and fixed[0].get_children().any(func(c): return c is PointLight2D and c.texture_scale > 2.0), "Lanterna: al centro c'e' la lanterna, che fa luce")
	# Chi la prende fa luce attorno a sé.
	a.global_position = Vector2(1500, 1078)
	a.velocity = Vector2.ZERO
	Input.action_press("p0_right")
	await _wait_for(func(): return a.weapon != null, 2.0)
	Input.action_release("p0_right")
	await frames(5)
	check(a.weapon == LANTERN and a._held_light != null and a._held_light.visible, "Lanterna: chi la prende fa luce attorno a se")
	# Si può usare per colpire (poco danno).
	b.global_position = a.global_position + Vector2(90, 0)
	b.velocity = Vector2.ZERO
	await frames(5)
	await tap("p0_attack")
	await frames(5)
	check(is_equal_approx(b.health, 100.0 - LANTERN.damage), "Lanterna: si puo usare per colpire (vita dell'altro %.0f)" % b.health)
	# Lasciandola, la luce resta dove cade.
	await tap("p0_drop")
	await frames(30)
	var dropped := get_nodes_in_group("pickups").filter(func(n): return not n.is_queued_for_deletion())
	check(a.weapon == null and not a._held_light.visible and dropped.size() == 1 and dropped[0].get_children().any(func(c): return c is PointLight2D and c.texture_scale > 2.0), "Lanterna: lasciata a terra continua a fare luce li")
	main.start_round()
	await frames(5)
	check(_fixed_pickups().size() == 1 and a.weapon == null, "Lanterna: a ogni round torna al centro")


## Gli oggetti che si muovono devono stare al loro posto anche quando l'arena arriva
## "a scorrimento" (come nel gioco vero), non solo quando viene caricata da sola.
## E il menu "Scegli livello" deve portare subito al livello scelto.
func _test_scorrimento_oggetti() -> void:
	var pl: Array = await _open_arena("res://src/arenas/bosco/radici.tscn")
	var a = pl[0]

	# Livello 7 raggiunto scorrendo: gli ascensori devono essere dentro l'arena.
	await main.scroll_to_arena(load("res://src/arenas/bosco/ascensori.tscn"))
	await frames(20)
	var el: Elevator = main.arena.get_node("Platforms/ElevatorLeft")
	var ec: Elevator = main.arena.get_node("Platforms/ElevatorCenter")
	print("    dopo lo scorrimento: ascensore sinistro a x=%.0f, centrale a x=%.0f" % [el.global_position.x, ec.global_position.x])
	check(absf(el.global_position.x - 150.0) < 2.0 and absf(ec.global_position.x - 1490.0) < 2.0, "dopo lo scorrimento gli ascensori sono al loro posto")
	a.global_position = Vector2(260, el.global_position.y - 2.0)
	a.velocity = Vector2.ZERO
	await frames(30)
	check(a.is_on_floor(), "dopo lo scorrimento sull'ascensore ci si sta sopra")
	# Dal basso si arriva in cima anche a salti, senza ascensori (piattaforma per piattaforma).
	var steps: Array = [["LowLeft", 1500.0], ["MidLeft", 1170.0], ["MidLeftHigh", 850.0], ["TopLeft", 520.0]]
	var jumpable := true
	for i in steps.size() - 1:
		if steps[i][1] - steps[i + 1][1] > a.jump_height + a.double_jump_height - 120.0:
			jumpable = false
		if main.arena.get_node_or_null("Platforms/" + steps[i + 1][0]) == null:
			jumpable = false
	check(jumpable, "Ascensori: le piattaforme a sinistra si salgono a salti, con margine")

	# Livello 5 raggiunto scorrendo: le piattaforme dei binari devono essere sui binari.
	await main.scroll_to_arena(load("res://src/arenas/bosco/binari.tscn"))
	await frames(20)
	var ok := true
	for rail in get_nodes_in_group("round_reset").filter(func(n): return n is Rail and main.arena.is_ancestor_of(n)):
		for i in rail._bodies.size():
			var body: Node2D = rail._bodies[i]
			if absf(body.global_position.y - rail.global_position.y) > 1.0 or absf(body.global_position.x - (rail.global_position.x + rail.platform_x(i))) > 1.0:
				ok = false
	check(ok and a.is_on_floor(), "dopo lo scorrimento le piattaforme dei binari sono al loro posto")

	# Menu di pausa: "Scegli livello".
	main.open_pause()
	await frames(3)
	var pick := _menu_button("Scegli livello")
	check(pick != null, "il menu di pausa ha la voce per scegliere il livello")
	pick.pressed.emit()
	await frames(3)
	var level7 := _menu_button("7.")
	check(main.pause_menu.page == "levels" and level7 != null and _menu_button("1.") != null, "la pagina elenca i livelli (%s)" % (level7.text if level7 else "?"))
	level7.pressed.emit()
	await frames(10)
	check(not paused and main.arena.arena_name == "Ascensori e scivoli" and a.alive, "scegliendo un livello ci si va subito")
	var el2: Elevator = main.arena.get_node("Platforms/ElevatorLeft")
	check(absf(el2.global_position.x - 150.0) < 2.0, "anche scegliendo il livello gli ascensori sono al loro posto")


## Blocchi D ed E del bosco: livelli 13 (corvi ladri), 14 (tempesta), 15 (alba),
## 16 (la chioma e il nido, spada di Re Artù) e 17 (il corvo gigante).
func _test_bosco_finale() -> void:
	const FOREST := ["knife", "axe", "crossbow"]
	var KNIFE: WeaponData = load("res://src/weapons/knife.tres")
	var AXE: WeaponData = load("res://src/weapons/axe.tres")
	var EXCALIBUR: WeaponData = load("res://src/weapons/excalibur.tres")
	var P: Array = main.ARENA_PATHS
	check(P[12].ends_with("corvi.tscn") and P[13].ends_with("tempesta.tscn") and P[14].ends_with("alba.tscn")
			and P[15].ends_with("nido.tscn") and P[16].ends_with("corvo_gigante.tscn"), "i livelli 13-17 del bosco vengono dopo il 12")

	# ---------- Livello 13: I corvi ladri ----------
	var pl: Array = await _open_arena("res://src/arenas/bosco/corvi.tscn")
	var a = pl[0]
	var b = pl[1]
	check(main.arena.arena_name == "I corvi ladri" and a.is_on_floor() and b.is_on_floor() and not Arena.night, "Corvi: si parte in piedi, di notte ma con la luna (si vede)")
	check(await _only_weapons(FOREST), "Corvi: cadono coltelli, asce e balestre")
	var crows: Array = get_nodes_in_group("crows")
	check(crows.size() == 3, "Corvi: tre corvi appollaiati (%d)" % crows.size())
	var c1: CrowThief = main.arena.get_node("Crows/Crow1")
	for c in crows:
		c._timer = 999.0
	# Nessuno ha un'arma: il corvo non parte.
	c1._timer = 0.0
	await frames(30)
	check(c1.state == CrowThief.State.PERCH and c1.position.distance_to(c1._home) < 1.0, "Corvi: senza armi in giro il corvo resta appollaiato")
	# Ruba l'arma dalle mani, senza fare danno.
	a.equip(KNIFE)
	c1._timer = 0.0
	await frames(10)
	check(c1.state == CrowThief.State.WARN, "Corvi: prima di partire il corvo avvisa")
	await _wait_for(func(): return c1.steals > 0, 6.0)
	check(a.weapon == null and c1.steals == 1 and c1.carried == KNIFE, "Corvi: il corvo ruba l'arma dalle mani")
	check(is_equal_approx(a.health, a.max_health) and a.alive, "Corvi: il corvo non fa danno")
	await _wait_for(func(): return c1.state == CrowThief.State.PERCH, 8.0)
	check(c1.carried == null and c1.position.distance_to(c1._home) < 6.0, "Corvi: vola via con l'arma e poi torna al suo posto")
	# Ruba anche le armi a terra.
	c1._timer = 999.0
	main.spawn_weapon(AXE, 350.0)
	await frames(150)
	check(get_nodes_in_group("pickups").size() == 1, "Corvi: c'e' un'arma a terra")
	var c2: CrowThief = main.arena.get_node("Crows/Crow2")
	c2._timer = 0.0
	await _wait_for(func(): return c2.steals > 0, 6.0)
	await frames(3)
	check(c2.steals == 1 and get_nodes_in_group("pickups").is_empty() and c2.carried == AXE, "Corvi: il corvo ruba anche le armi a terra")
	# Chi lascia l'arma in tempo fa tornare su il corvo a zampe vuote.
	await _wait_for(func(): return c2.state == CrowThief.State.PERCH, 8.0)
	b.equip(KNIFE)
	c2._timer = 0.0
	await _wait_for(func(): return c2.state == CrowThief.State.DIVE, 3.0)
	b.drop_weapon()
	await frames(5)
	check(c2.state != CrowThief.State.DIVE and c2.carried == null and c2.steals == 1, "Corvi: se il bersaglio non ha piu' l'arma il corvo torna su")
	main.start_round()
	await frames(3)
	check(c2.position.distance_to(c2._home) < 1.0 and c2.state == CrowThief.State.PERCH and c2.steals == 0, "Corvi: a ogni round i corvi ripartono dal loro posto")

	# ---------- Livello 14: La tempesta ----------
	pl = await _open_arena("res://src/arenas/bosco/tempesta.tscn")
	a = pl[0]
	b = pl[1]
	var storm: Storm = main.arena.get_node("Storm")
	check(main.arena.arena_name == "La tempesta" and a.is_on_floor() and b.is_on_floor() and Arena.night, "Tempesta: si parte in piedi, al buio")
	check(await _only_weapons(FOREST), "Tempesta: cadono coltelli, asce e balestre")
	check(get_nodes_in_group("crows").size() == 0 and get_nodes_in_group("wet").size() == 4, "Tempesta: niente corvi e quattro piattaforme bagnate")
	storm._timer = 999.0
	# Durante lo sguardo iniziale niente lampi.
	storm.strike()
	check(storm.lightnings == 0, "Tempesta: niente lampi durante lo sguardo iniziale")
	# Sull'asciutto ci si ferma, sul bagnato no.
	Input.action_press("p0_right")
	await frames(15)
	Input.action_release("p0_right")
	await frames(20)
	check(absf(a.velocity.x) < 5.0, "Tempesta: sull'asciutto lasciando il tasto ci si ferma")
	a.global_position = Vector2(1350, 998) # sulla piattaforma bagnata al centro (1250-1950)
	a.velocity = Vector2.ZERO
	await frames(10)
	check(a.is_on_floor() and a._on_wet and absf(a.velocity.x) < 1.0, "Tempesta: fermi sul bagnato si resta fermi")
	Input.action_press("p0_right")
	await frames(14)
	Input.action_release("p0_right")
	var wet_v: float = a.velocity.x
	await frames(12)
	print("    sul bagnato: velocita' %.0f -> %.0f px/s" % [wet_v, a.velocity.x])
	check(a.is_on_floor() and a.velocity.x >= a.wet_min_speed - 1.0 and a.velocity.x >= wet_v - 1.0, "Tempesta: sul bagnato si continua a scivolare")
	Input.action_press("p0_left")
	await frames(10)
	Input.action_release("p0_left")
	check(a.velocity.x >= a.wet_min_speed - 1.0, "Tempesta: sul bagnato non si frena e non si torna indietro")
	await tap("p0_jump", 6)
	await frames(3)
	check(not a.is_on_floor() and a.velocity.y < 0.0, "Tempesta: dal bagnato si esce saltando")
	a.global_position = Vector2(1350, 998)
	a.velocity = Vector2(500, 0)
	await _wait_for(func(): return not a.alive or a.global_position.x > 1990.0, 4.0)
	check(a.global_position.x > 1990.0 or not a.alive, "Tempesta: chi non salta scivola fino in fondo e cade dalla piattaforma")
	# Il lampo: la luce sale (ma non e' bianco pieno), lo schermo trema, poi torna buio.
	main.start_round()
	await _wait_for(func(): return main.ambient_light.color.is_equal_approx(main.arena.ambient), 6.0)
	await frames(5)
	storm._timer = 999.0
	storm.strike()
	await frames(3)
	var lit: Color = main.ambient_light.color
	print("    luce durante il lampo: %.2f (buio: %.2f)" % [lit.get_luminance(), main.arena.ambient.get_luminance()])
	check(storm.lightnings == 1 and lit.get_luminance() > 0.4 and lit.get_luminance() < 0.8, "Tempesta: il lampo illumina tutta l'arena, attenuato")
	check(main.camera.offset.length() > 0.1, "Tempesta: col lampo trema lo schermo")
	var ax: float = a.global_position.x
	await frames(110)
	check(main.ambient_light.color.is_equal_approx(main.arena.ambient) and main.camera.offset.length() < 0.01, "Tempesta: dopo il lampo torna il buio e lo schermo e' fermo")
	check(absf(a.global_position.x - ax) < 1.0 and a.is_on_floor(), "Tempesta: il lampo e' solo scena, non sposta nessuno")

	# ---------- Livello 15: L'alba ----------
	pl = await _open_arena("res://src/arenas/bosco/alba.tscn")
	a = pl[0]
	b = pl[1]
	check(main.arena.arena_name == "L'alba" and a.is_on_floor() and b.is_on_floor() and not Arena.night, "Alba: si parte in piedi, con la luce")
	check(await _only_weapons(FOREST), "Alba: cadono coltelli, asce e balestre")
	var rain: Storm = main.arena.get_node("Storm")
	var branches: Array = get_nodes_in_group("round_reset").filter(func(n): return n is FlexBranch)
	check(not rain.lightning and branches.size() == 6 and get_nodes_in_group("wet").size() == 2, "Alba: pioggia senza lampi, sei rami flessibili, due piattaforme ancora bagnate")
	var br: FlexBranch = main.arena.get_node("Platforms/BranchLeft") # a riposo: x 690-1050, y 1260
	a.global_position = Vector2(870, 1258)
	a.velocity = Vector2.ZERO
	await frames(20)
	check(a.is_on_floor() and br.riders() == 1 and br.sag > 10.0, "Alba: il ramo comincia a piegarsi sotto il peso")
	await frames(90)
	print("    ramo con un personaggio: sceso di %.0f px, piedi a y=%.0f" % [br.sag, a.global_position.y])
	check(is_equal_approx(br.sag, br.sag_per_player) and a.is_on_floor() and absf(a.global_position.y - (1260.0 + br.sag)) < 6.0, "Alba: con un personaggio il ramo scende e lo porta giu' con se'")
	b.global_position = Vector2(960, a.global_position.y - 2.0)
	b.velocity = Vector2.ZERO
	await frames(90)
	check(is_equal_approx(br.sag, br.max_sag) and a.is_on_floor() and b.is_on_floor(), "Alba: in due il ramo scende di piu' (%.0f px)" % br.sag)
	a.global_position = Vector2(250, 1448)
	b.global_position = Vector2(420, 1448)
	await frames(40)
	check(is_zero_approx(br.sag) and absf(br.position.y - 1260.0) < 0.5, "Alba: rimasto vuoto il ramo torna su di scatto")
	# Arrivandoci con lo scorrimento i rami sono al loro posto.
	await main.scroll_to_arena(load("res://src/arenas/bosco/alba.tscn"))
	await frames(20)
	br = main.arena.get_node("Platforms/BranchLeft")
	check(absf(br.global_position.x - 690.0) < 1.0 and absf(br.global_position.y - 1260.0) < 1.0, "Alba: dopo lo scorrimento i rami sono al loro posto")
	a.global_position = Vector2(870, 1258)
	a.velocity = Vector2.ZERO
	await frames(30)
	check(a.is_on_floor() and br.sag > 10.0, "Alba: dopo lo scorrimento sul ramo ci si sta sopra e si piega")

	# ---------- Livello 16: La chioma e il nido ----------
	pl = await _open_arena("res://src/arenas/bosco/nido.tscn")
	a = pl[0]
	b = pl[1]
	var stone: SwordStone = main.arena.get_node("SwordStone")
	check(main.arena.arena_name == "La chioma e il nido" and a.is_on_floor() and b.is_on_floor() and not main.arena.sky_weapons_enabled, "Nido: si parte in piedi e non cadono armi")
	b.global_position = Vector2(3300, 1558)
	b.velocity = Vector2(900, 0)
	await frames(120)
	check(b.alive and b.is_on_floor() and b.global_position.y < 1570.0, "Nido: in questo livello non si puo' cadere nel vuoto")
	check(stone.has_sword and stone.weapon == EXCALIBUR, "Nido: la spada di Re Artu' e' nella roccia")
	# Per estrarla bisogna tenere premuto: un tocco non basta.
	a.global_position = Vector2(2630, 738)
	a.velocity = Vector2.ZERO
	a.facing = 1.0
	await frames(10)
	check(a.is_on_floor() and a.weapon == null and stone.has_sword, "Nido: passarci accanto non basta per prendere la spada")
	Input.action_press("p0_attack")
	await frames(25)
	check(stone.puller == a and stone.progress > 0.3 and a.weapon == null, "Nido: tenendo premuto si comincia a estrarla (%.2f)" % stone.progress)
	Input.action_release("p0_attack")
	await frames(3)
	check(stone.progress == 0.0 and stone.puller == null and stone.has_sword, "Nido: lasciando il tasto si ricomincia da capo")
	# Chi viene colpito mentre la estrae deve ricominciare.
	Input.action_press("p0_attack")
	await frames(30)
	a.take_hit(Vector2.RIGHT, a.global_position + Vector2(-80, -50), 10.0, b)
	await frames(2)
	check(stone.progress < 0.1 and a.weapon == null, "Nido: un colpo interrompe chi la sta estraendo")
	await frames(70)
	Input.action_release("p0_attack")
	check(a.weapon == EXCALIBUR and not stone.has_sword, "Nido: tenendo premuto circa un secondo la spada e' tua")
	# Non si lascia.
	await tap("p0_drop")
	await frames(5)
	check(a.weapon == EXCALIBUR and get_nodes_in_group("pickups").is_empty(), "Spada di Re Artu': non si puo' lasciare")
	# Lama volante: 34 di danno da lontano.
	a.global_position = Vector2(2400, 738)
	b.global_position = Vector2(3000, 738)
	a.facing = 1.0
	await frames(8)
	await tap("p0_attack")
	await frames(2)
	var blades: Array = get_nodes_in_group("bullets")
	check(blades.size() == 1 and blades[0].blade, "Spada di Re Artu': ogni colpo lancia una lama volante")
	await frames(40)
	check(is_equal_approx(b.health, 100.0 - 34.0), "Spada di Re Artu': la lama volante toglie 34 (vita di B: %.0f)" % b.health)
	# Scudo tutto intorno: para anche i colpi alle spalle.
	a.global_position = Vector2(2600, 738)
	b.global_position = Vector2(2520, 738)
	a.facing = 1.0
	b.facing = 1.0
	await frames(5)
	await tap("p0_shield")
	await frames(6)
	check(is_equal_approx(a.shield_half_angle(), 180.0), "Spada di Re Artu': lo scudo copre tutto intorno")
	var before: float = a.health
	await tap("p1_attack")
	await frames(8)
	check(is_equal_approx(a.health, before), "Spada di Re Artu': lo scudo para anche i colpi alle spalle")
	await frames(40)
	check(a.is_shielding() and a.shield_half_angle() < 150.0 and a.shield_half_angle() > 0.0, "Spada di Re Artu': poi lo scudo si restringe (%.0f gradi)" % a.shield_half_angle())
	await frames(40)
	check(not a.is_shielding(), "Spada di Re Artu': e alla fine sparisce")
	# Colpo diretto: uccide in un colpo. Chi vince con la spada in mano diventa "il re".
	a.global_position = Vector2(2600, 738)
	b.global_position = Vector2(2700, 738)
	a.facing = 1.0
	await frames(5)
	await tap("p0_attack")
	await frames(5)
	check(not b.alive and main.round_over, "Spada di Re Artu': il colpo diretto uccide in un colpo")
	check(main.king_slot == a.slot, "Nido: chi vince con la spada se la porta nel livello dopo")

	# Dal nido al boss con lo scorrimento: il re arriva con la spada, la roccia e' vuota.
	await main.scroll_to_arena(load("res://src/arenas/bosco/corvo_gigante.tscn"))
	await frames(20)
	var boss: GiantCrow = main.arena.get_node("GiantCrow")
	var stone2: SwordStone = main.arena.get_node("SwordStone")
	check(main.arena.arena_name == "Il corvo gigante" and a.weapon == EXCALIBUR and b.weapon == null, "Boss: chi ha vinto il nido arriva con la spada di Re Artu'")
	check(not stone2.has_sword, "Boss: se qualcuno ha gia' la spada, la roccia e' vuota")
	check(absf(boss.global_position.x - 1600.0) < boss.far_drift + 5.0 and boss.global_position.y < 500.0, "Boss: dopo lo scorrimento il corvo gigante e' al suo posto")
	# Se chi ha la spada muore, la spada resta a terra per gli altri.
	a.global_position = Vector2(1200, 1298)
	await frames(10)
	a._die("hp")
	await frames(5)
	var left: Array = get_nodes_in_group("pickups")
	check(left.size() == 1 and left[0].data == EXCALIBUR and not main.round_over, "Boss: se muore chi ha la spada, la spada cade a terra e il round continua")
	b.global_position = Vector2(1200, 1298)
	await frames(10)
	check(b.weapon == EXCALIBUR, "Boss: un altro giocatore puo' raccogliere la spada")

	# ---------- Livello 17: Il corvo gigante ----------
	pl = await _open_arena("res://src/arenas/bosco/corvo_gigante.tscn")
	a = pl[0]
	b = pl[1]
	boss = main.arena.get_node("GiantCrow")
	stone2 = main.arena.get_node("SwordStone")
	var thief: CrowThief = main.arena.get_node("Crows/Crow1")
	thief._timer = 999.0
	check(a.is_on_floor() and b.is_on_floor() and Arena.coop_now and main.arena.coop, "Boss: si parte in piedi, tutti alleati")
	check(await _only_weapons(FOREST), "Boss: cadono coltelli, asce e balestre")
	check(stone2.has_sword and a.weapon == null, "Boss: senza un vincitore del nido la spada e' piantata al centro")
	check(is_equal_approx(boss.health, 1000.0) and boss.state == GiantCrow.State.FAR and not boss.vulnerable(), "Boss: il corvo ha 1000 di vita e parte lontano")
	check(not boss.take_damage(50.0, a) and is_equal_approx(boss.health, 1000.0), "Boss: quando e' lontano non si puo' colpire")
	# Tra giocatori non ci si fa danno.
	a.global_position = Vector2(1000, 1298)
	b.global_position = Vector2(1080, 1298)
	a.facing = 1.0
	await frames(5)
	await tap("p0_attack")
	await frames(8)
	check(is_equal_approx(b.health, b.max_health), "Boss: i colpi tra giocatori non fanno danno")
	# Il corvo arriva, avvisa col cerchio rosso e colpisce: 25 di danno a chi e' nel cerchio.
	await _wait_for(func(): return boss.state == GiantCrow.State.WARN, 8.0)
	check(boss.vulnerable() and boss.state == GiantCrow.State.WARN, "Boss: il corvo si avvicina e avvisa prima di colpire")
	check(boss.strike_point.distance_to(Vector2(1040, 1298)) < 120.0, "Boss: il cerchio rosso e' sul bersaglio")
	await _wait_for(func(): return boss.state == GiantCrow.State.RISE, 4.0)
	print("    dopo la prima artigliata: vita A %.0f, vita B %.0f" % [a.health, b.health])
	check(is_equal_approx(a.health, 75.0) and is_equal_approx(b.health, 75.0), "Boss: l'artigliata toglie 25 a chi e' nel cerchio")
	check(absf(a.global_position.x - 1000.0) < 30.0, "Boss: l'artigliata non sposta chi colpisce")
	# Seconda picchiata: spostandosi quando il cerchio e' bloccato la si schiva.
	await _wait_for(func(): return boss.state == GiantCrow.State.WARN and boss._timer <= boss.lock_time, 4.0)
	var away: float = 2400.0 if boss.strike_point.x < 1600.0 else 800.0
	a.global_position = Vector2(away, 1298)
	b.global_position = Vector2(away + 90.0, 1298)
	await _wait_for(func(): return boss.state == GiantCrow.State.RISE, 4.0)
	check(is_equal_approx(a.health, 75.0) and is_equal_approx(b.health, 75.0), "Boss: uscendo dal cerchio rosso si schiva l'artigliata")
	# Dopo le picchiate resta basso, stanco: lo si colpisce da sotto mirando in alto.
	await _wait_for(func(): return boss.state == GiantCrow.State.TIRED, 8.0)
	check(boss.state == GiantCrow.State.TIRED and boss._swoops_done == boss.swoops, "Boss: dopo %d picchiate resta basso, stanco" % boss.swoops)
	await frames(30)
	b.global_position = Vector2(400, 1298)
	a.equip(EXCALIBUR)
	a.global_position = Vector2(boss.global_position.x, 1298)
	a.velocity = Vector2.ZERO
	await frames(3)
	Input.action_press("p0_up")
	await frames(2)
	await tap("p0_attack")
	Input.action_release("p0_up")
	await frames(25)
	print("    vita del corvo dopo un colpo di spada: %.0f" % boss.health)
	check(is_equal_approx(boss.health, 900.0), "Boss: un colpo di spada toglie 100 (10 colpi per ucciderlo), la lama dello stesso colpo non conta")
	check(main.damage_dealt[a.slot] >= 100.0, "Boss: i danni al corvo contano nelle statistiche")
	# Poi se ne va e torna intoccabile.
	await _wait_for(func(): return boss.state == GiantCrow.State.FAR, 6.0)
	check(not boss.vulnerable() and absf(boss.size - boss.far_scale) < 0.01, "Boss: poi torna lontano e intoccabile")
	# Il corvo ladro porta l'arma al corvo gigante, che la lascia dopo qualche colpo.
	boss._timer = 999.0
	a.drop_weapon()
	a.equip(AXE)
	thief._timer = 0.0
	await _wait_for(func(): return boss.held_weapon != null, 10.0)
	check(boss.held_weapon == AXE and a.weapon == null, "Boss: il corvo ladro porta l'arma rubata al corvo gigante")
	thief._timer = 0.0
	a.equip(KNIFE)
	await frames(60)
	check(a.weapon == KNIFE and thief.state != CrowThief.State.DIVE, "Boss: finche' il corvo gigante ha un'arma tra le zampe, il ladro non ruba")
	thief._timer = 999.0
	a.drop_weapon()
	boss.set_physics_process(false)
	boss.size = 1.0
	boss.take_damage(10.0, a)
	boss.take_damage(10.0, a)
	check(boss.held_weapon == AXE, "Boss: due colpi non bastano a fargli lasciare l'arma")
	boss.take_damage(10.0, a)
	await frames(3)
	var fallen: Array = get_nodes_in_group("pickups")
	check(boss.held_weapon == null and fallen.size() == 1 and fallen[0].data == AXE, "Boss: al terzo colpo lascia cadere l'arma, che si puo' riprendere")
	# Fine del livello: chi e' vivo quando il corvo muore prende una vittoria.
	var wa: int = main.wins[a.slot]
	var wb: int = main.wins[b.slot]
	b._die("hp")
	await frames(3)
	check(not main.round_over, "Boss: se muore un giocatore solo, il round continua")
	boss.health = 50.0
	boss.take_damage(100.0, a)
	await frames(3)
	check(boss.state == GiantCrow.State.DEAD and main.round_over, "Boss: a zero vita il corvo muore e il round finisce")
	check(main.wins[a.slot] == wa + 1 and main.wins[b.slot] == wb, "Boss: la vittoria va a chi e' ancora vivo, non a chi e' morto")
	# Nuovo round: il corvo torna con tutta la vita. Se muoiono tutti, nessuno vince.
	main.start_round()
	await frames(5)
	boss.set_physics_process(true)
	check(is_equal_approx(boss.health, 1000.0) and boss.state == GiantCrow.State.FAR and boss.visible and a.alive and b.alive, "Boss: a ogni round il corvo riparte con tutta la vita")
	wa = main.wins[a.slot]
	wb = main.wins[b.slot]
	a._die("fall")
	b._die("hp")
	await frames(3)
	check(main.round_over and main.wins[a.slot] == wa and main.wins[b.slot] == wb, "Boss: se muoiono tutti nessuno prende la vittoria")
	# Sopravvivono tutti: vittoria a tutti.
	main.start_round()
	await frames(5)
	boss.set_physics_process(false)
	boss.size = 1.0
	boss.health = 10.0
	boss.take_damage(10.0, b)
	await frames(3)
	check(main.wins[a.slot] == wa + 1 and main.wins[b.slot] == wb + 1, "Boss: se sopravvivono tutti, la vittoria va a tutti")
	Arena.coop_now = false
