class_name WeaponData
extends Resource
## "Scheda" di un'arma: la parte comune a TUTTE le armi (nome, danno, cadenza,
## colpi, aspetto). Ogni famiglia di armi ha poi la sua scheda, che aggiunge
## i suoi numeri e il suo modo di funzionare:
##   GunData    -> armi da fuoco e da tiro (pistola, mitra, pompa, balestra)
##   ChargeData -> armi a carica: tieni premuto e lasci (fionda)
##   MeleeData  -> armi corpo a corpo (spada di legno, coltello, ascia)
## Un'arma nuova di una famiglia che esiste già = un nuovo file .tres, senza codice.
## Un'arma "strana" = una nuova famiglia: un piccolo script che estende questa
## scheda e riscrive tick() (cosa succede mentre l'arma è in mano).
##
## Come si ragiona sui danni: la vita è 100 e non si vede, quindi contano due cose:
## quanti colpi servono per uccidere e quanto tempo passa tra un colpo e l'altro.

enum Family { ONE_HAND, TWO_HAND } ## come si impugna (decide il disegno delle mani)
enum Look { GUN, SWORD, KNIFE, AXE, SLING, CROSSBOW, LANTERN } ## disegno provvisorio

@export var display_name := "Arma"
@export var family := Family.ONE_HAND

@export_group("Colpo")
@export var damage := 10.0 ## vita tolta da UN colpo (la vita totale è 100)
@export var fire_interval := 0.25 ## secondi tra un colpo e l'altro
@export var ammo := 10 ## colpi totali; finiti, l'arma sparisce. 0 = infiniti

## Luce che fa mentre la tieni in mano o sta a terra (pixel; 0 = nessuna).
## Conta solo nelle arene buie. La lanterna è l'arma che fa luce.
@export var light_radius := 0.0

@export_group("Aspetto")
@export var look := Look.GUN
@export var length := 50.0 ## lunghezza del disegno (pixel)
@export var thickness := 12.0
@export var color := Color("2e2e3a")
@export var accent := Color("8a8fa3") ## colore dei dettagli


## Chiamata a ogni fotogramma mentre l'arma è in mano a "p".
## can_act = false quando non può attaccare (per esempio ha lo scudo alzato).
func tick(_p: Player, _delta: float, _can_act: bool) -> void:
	pass


## Direzione in cui si disegna l'arma in mano (di solito la mira).
func held_direction(p: Player) -> Vector2:
	return p.aim


## Da che parte "guarda" l'arma (per specchiarla quando si mira a sinistra).
func held_side(p: Player) -> float:
	return p.aim.x


## true = l'arma è pronta a colpire (la balestra scarica si disegna senza freccia).
func is_ready(p: Player) -> bool:
	return p.fire_cd <= 0.0


## Quanti colpi servono per uccidere un personaggio con la vita piena.
func hits_to_kill(health := 100.0) -> int:
	return ceili(health / maxf(damage, 0.001))


# --- Indicazioni per il manichino d'allenamento ---

## Da che distanza il manichino prova ad attaccare.
func bot_range() -> float:
	return 140.0


## A che distanza dal bersaglio il manichino si ferma.
func bot_keep_distance() -> float:
	return 80.0


## Di quanto il manichino deve mirare più in alto per un bersaglio a "dist" pixel
## (serve solo alle armi il cui colpo cade, come la fionda).
func bot_aim_lift(_dist: float) -> float:
	return 0.0


## Come preme il tasto: "tap" (un colpo alla volta), "hold" (tiene premuto), "charge" (carica e lascia).
func bot_style() -> StringName:
	return &"tap"
