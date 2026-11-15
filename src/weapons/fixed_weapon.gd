class_name FixedWeapon
extends Marker2D
## "Arma fissa nel livello": un'arma che non cade dal cielo ma è già piazzata
## in un punto dell'arena (es. la spada di legno sulla piattaforma centrale).
## Come si usa: in una scena arena aggiungi un nodo Marker2D con questo script,
## lo metti nel punto voluto (circa 30 pixel sopra il pavimento) e scegli
## l'arma nell'Inspector. Torna al suo posto all'inizio di ogni round.

@export var weapon: WeaponData

var _pickup: WeaponPickup


func _ready() -> void:
	add_to_group("fixed_weapons")
	place()


## Mette (o rimette) l'arma al suo posto.
func place() -> void:
	if weapon == null:
		return
	if is_instance_valid(_pickup) and not _pickup.is_queued_for_deletion():
		_pickup.queue_free()
	_pickup = WeaponPickup.new()
	_pickup.data = weapon
	_pickup.fixed = true
	add_child(_pickup)
