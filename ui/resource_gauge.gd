extends VBoxContainer
## Jauge d'une ressource du Billy : un titre, une barre, et « courant / max ».
##
## **Affichage seul**, volontairement : les boutons + / − appartiennent à la page
## qui instancie la jauge (`popups/sub/stats.gd`). Elle peut donc être posée
## n'importe où en simple lecture — à côté du panneau de combat, par exemple.
##
## `kind` suffit à tout régler : titre, couleur et source des valeurs en découlent,
## il n'y a rien à configurer de travers. `show_title` sert quand l'hôte nomme déjà
## la ressource au-dessus, comme la feuille de stats.

## `Resource` est un nom de classe Godot, d'où `Kind`.
enum Kind {PV, CHANCE}

const _SETUP := {
	Kind.PV: {"titre": "PV", "couleur": Color('c0392b')},
	Kind.CHANCE: {"titre": "CHANCE", "couleur": Color('e2b007')},
}

const _FOND := Color('e9eaec')

@export var kind: Kind = Kind.PV

## À faux quand l'hôte affiche déjà le nom de la ressource juste au-dessus.
@export var show_title: bool = true

@onready var _titre: Label = $Titre
@onready var _bar: ProgressBar = $Bar
@onready var _valeur: Label = $Bar/Valeur


func _ready() -> void:
	_titre.text = _SETUP[kind]["titre"]
	_titre.visible = show_title
	_paint_bar(_SETUP[kind]["couleur"])

	PlayerStats.stats_changed.connect(_refresh)
	_refresh()


## La couleur de remplissage d'une `ProgressBar` vient de son thème : on la pose en
## override, pour ne pas dépendre d'un thème global que l'app n'a pas.
func _paint_bar(couleur: Color) -> void:
	var remplissage := StyleBoxFlat.new()
	remplissage.bg_color = couleur
	remplissage.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", remplissage)

	var fond := StyleBoxFlat.new()
	fond.bg_color = _FOND
	fond.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", fond)


func _refresh() -> void:
	var courant = _courant()
	var maximum = _maximum()
	# Un `max_value` à 0 rendrait la barre absurde ; on garde au moins 1, et elle
	# reste vide de toute façon puisque le courant vaut 0 lui aussi.
	_bar.max_value = maxi(maximum, 1)
	_bar.value = courant
	_valeur.text = "%d / %d" % [courant, maximum]


func _courant() -> int:
	return PlayerStats.get_pv() if kind == Kind.PV else PlayerStats.get_cha()


func _maximum() -> int:
	return PlayerStats.get_pv_max() if kind == Kind.PV else PlayerStats.get_chance_max()
