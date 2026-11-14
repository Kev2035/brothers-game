class_name WeaponData
extends Resource
## "Scheda" di un'arma: tutti i numeri che la descrivono.
## Un'arma nuova = un nuovo file .tres con questa scheda, senza scrivere codice.
## In Godot: doppio clic su un file .tres in src/weapons/ e cambi i valori
## nell'Inspector.

enum Family { ONE_HAND, TWO_HAND } ## come si impugna (decide il disegno delle mani)

@export var display_name := "Arma"
@export var family := Family.ONE_HAND

@export_group("Sparo")
@export var damage := 10.0 ## vita tolta da UN proiettile (la vita totale è 100)
@export var pellets := 1 ## proiettili per colpo (il fucile a pompa ne spara tanti)
@export var spread_deg := 0.0 ## quanto si allargano i colpi (gradi)
@export var automatic := false ## true = tieni premuto e spara a raffica
@export var fire_interval := 0.25 ## secondi tra un colpo e l'altro
@export var ammo := 10 ## colpi totali; finiti, l'arma sparisce
@export var bullet_speed := 2500.0 ## pixel al secondo
@export var bullet_range := 2500.0 ## distanza massima percorsa da un proiettile

@export_group("Rinculo")
@export var recoil := 100.0 ## spinta all'indietro su chi spara, a ogni colpo
@export var recoil_air_mult := 1.0 ## in aria il rinculo pesa di più (es. 1.5)

@export_group("Aspetto")
@export var length := 50.0 ## lunghezza del disegno (pixel)
@export var thickness := 12.0
@export var color := Color("2e2e3a")
@export var accent := Color("8a8fa3") ## colore dei dettagli
@export var bullet_color := Color("ffe08a")
