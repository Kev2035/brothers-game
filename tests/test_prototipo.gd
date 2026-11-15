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


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func():
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

	await _test_lobby_e_partita()

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


func _test_lobby_e_partita() -> void:
	# Nuova partita "vera": parte dalla lobby.
	main.queue_free()
	await frames(3)
	main = load("res://src/core/main.tscn").instantiate()
	main.arenas_per_lobby = 2
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
	await create_timer(1.8).timeout
	check(main.phase == main.Phase.MATCH and main.arena.arena_name == "Arena di prova", "prima arena: %s" % main.arena.arena_name)
	check(a.alive and b.alive and a.is_inside_tree(), "nella nuova arena ricompaiono tutti")
	check(a.death_y == main.arena.death_y, "i personaggi conoscono il vuoto della nuova arena")

	# Round 1: B cade nel pozzo -> A vince -> arena successiva.
	await frames(20)
	b.global_position = Vector2(PIT_X, 1500)
	b.velocity = Vector2.ZERO
	await frames(90)
	check(main.wins[0] == 1 and main.falls[1] == 1, "in partita le statistiche contano")
	await create_timer(2.8).timeout
	check(main.arena.arena_name == "Torri" and main.arenas_played == 1, "dopo il round si passa all'arena dopo: %s" % main.arena.arena_name)
	var spawns: Array[Vector2] = main.arena.spawn_points()
	check(a.global_position.distance_to(spawns[0]) < 60.0, "si riparte dai punti di partenza della nuova arena")

	# Round 2: B cade tra le isole -> torna la lobby con la classifica.
	await frames(20)
	b.global_position = Vector2(1100, 1500)
	b.velocity = Vector2.ZERO
	await frames(90)
	await create_timer(2.8).timeout
	check(main.phase == main.Phase.LOBBY and main.arena.arena_name == "Lobby", "dopo %d arene si torna alla lobby" % main.arenas_per_lobby)
	check(main.scoreboard.visible and main.total_arenas == 2, "la lobby mostra la classifica")
	check(main.wins[0] == 2, "le statistiche restano per tutta la partita (vittorie A: %d)" % main.wins[0])

	# Si riparte: l'ordine continua con la terza arena.
	await frames(30)
	await _punch_out(a, b, 1000.0, LOBBY_FLOOR)
	await create_timer(1.8).timeout
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
	check(repeats == 0 and seen.size() == main.ARENA_SCENES.size(), "ordine a caso: escono tutte e mai due uguali di fila")
