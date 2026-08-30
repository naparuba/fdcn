extends CheckButton
## Interrupteur oui/non : **vert et « Oui »** quand il est actif, **rouge et « Non »**
## sinon.
##
## RÉPARTITION AVEC LE THÈME — ce n'est pas un choix, c'est une contrainte de Godot.
## Les deux couleurs vivent dans `themes/fdcn.tres`, sous les variations `SwitchOui` et
## `SwitchNon` ; ce script ne fait que basculer le **nom de la variation** et le libellé.
## Un thème sait habiller un nœud selon son type et son état, mais il ne sait pas changer
## le **texte** d'un nœud : « Oui » / « Non » ne peut donc venir que d'un script. Le
## partage suit cette frontière — la palette reste au même endroit que le reste de l'app.
##
## ⚠️ `flat = true` empêche le dessin de la stylebox, donc de la couleur. Un interrupteur
## qui porte ce script doit rester `flat = false`.

## Libellés surchargeables : un interrupteur peut vouloir dire « Porté » / « Rangé »
## plutôt que oui/non.
@export var libelle_oui: String = "Oui"
@export var libelle_non: String = "Non"


func _ready() -> void:
	# La scène garde ses propres connexions de `toggled` vers son parent ; une connexion
	# de plus est sans conséquence, chaque abonné reçoit le signal.
	toggled.connect(_on_toggled)
	_repaint()


func _on_toggled(_actif: bool) -> void:
	_repaint()


## Change l'état **sans émettre `toggled`**, pour les rafraîchissements d'affichage — qui
## ne sont pas des actions du joueur.
##
## À utiliser partout où l'on écrivait `set_pressed_no_signal()` : celui-ci ne prévient
## personne, donc la couleur et le libellé resteraient sur l'état précédent.
func set_state(actif: bool) -> void:
	set_pressed_no_signal(actif)
	_repaint()


func _repaint() -> void:
	if button_pressed:
		text = libelle_oui
		theme_type_variation = &"SwitchOui"
	else:
		text = libelle_non
		theme_type_variation = &"SwitchNon"
