class_name SwordStone
extends Node2D
## La spada nella roccia (livello 16 del bosco, e nel 17 se nessuno ce l'ha già).
## Per estrarla bisogna stare vicino alla roccia, a mani nude, e TENERE PREMUTO
## il tasto di attacco per circa un secondo. Chi la sta estraendo è scoperto:
## se viene colpito, o lascia il tasto, o si allontana, deve ricominciare.
## A ogni inizio round la spada torna nella roccia.
##
## La posizione del nodo è il punto in cui la roccia tocca il pavimento (al centro).

@export var weapon: WeaponData ## l'arma che si estrae (la spada di Re Artù)
@export var pull_time := 1.0 ## secondi da tenere premuto
@export var pull_radius := 95.0 ## quanto vicino bisogna stare (pixel dal centro della roccia)
## true = questa roccia ha la spada solo se nessun giocatore se l'è portata dal
## livello prima (serve nel livello del boss giocato "a caso").
@export var only_without_king := false

var has_sword := true
var available := true ## false = roccia vuota per tutto il round
var progress := 0.0 ## da 0 a 1: quanto manca a estrarla
var puller: Player = null

var _puller_health := 0.0
var _time := 0.0


func _ready() -> void:
	add_to_group("round_reset")
	add_to_group("sword_stones")


func reset_round() -> void:
	has_sword = available
	progress = 0.0
	puller = null


## Il centro della presa (a metà roccia).
func grab_point() -> Vector2:
	return global_position + Vector2(0.0, -50.0)


func _can_pull(p: Player) -> bool:
	return p != null and is_instance_valid(p) and p.alive and p.weapon == null and not p.riding \
			and p.attack_held() and (p.global_position + Player.BODY).distance_to(grab_point()) < pull_radius


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not has_sword or weapon == null:
		return
	# Chi sta già tirando continua, a meno che molli, si allontani o venga colpito.
	if puller != null and (not _can_pull(puller) or puller.health < _puller_health):
		puller = null
		progress = 0.0
	if puller == null:
		for node in get_tree().get_nodes_in_group("players"):
			var p := node as Player
			if _can_pull(p):
				puller = p
				_puller_health = p.health
				break
	if puller == null:
		return
	progress += delta / maxf(pull_time, 0.01)
	if progress >= 1.0:
		puller.equip(weapon)
		Fx.sparks(get_parent(), grab_point() + Vector2(0.0, -60.0), Color(1.0, 0.95, 0.6), 24)
		has_sword = false
		progress = 0.0
		puller = null


func _draw() -> void:
	# La roccia
	var rock := PackedVector2Array([Vector2(-80, 0), Vector2(-64, -52), Vector2(-22, -78), Vector2(34, -72), Vector2(74, -40), Vector2(84, 0)])
	draw_colored_polygon(rock, Color(0.5, 0.52, 0.56))
	draw_colored_polygon(PackedVector2Array([Vector2(-64, -52), Vector2(-22, -78), Vector2(34, -72), Vector2(10, -50)]), Color(0.66, 0.68, 0.72))
	if not has_sword:
		return
	# La spada piantata: esce dalla roccia a mano a mano che la si estrae.
	var lift := progress * 46.0
	var base := Vector2(4.0, -70.0 - lift)
	draw_rect(Rect2(base.x - 7.0, base.y - 62.0, 14.0, 62.0 + lift * 0.5), Color(0.93, 0.96, 1.0)) # lama
	draw_rect(Rect2(base.x - 26.0, base.y - 70.0, 52.0, 10.0), Color(0.95, 0.78, 0.25)) # guardia
	draw_rect(Rect2(base.x - 5.0, base.y - 98.0, 10.0, 30.0), Color(0.6, 0.4, 0.2)) # manico
	draw_circle(base + Vector2(0.0, -102.0), 8.0, Color(0.95, 0.78, 0.25)) # pomo
	# Luccichio
	var glint := 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(base + Vector2(0.0, -30.0), 4.0 + 5.0 * glint, Color(1, 1, 1, 0.5 * glint))
	# Mentre si estrae: un arco che si riempie.
	if progress > 0.0:
		draw_arc(base + Vector2(0.0, -50.0), 70.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, Color(1.0, 0.95, 0.6), 9.0, true)
