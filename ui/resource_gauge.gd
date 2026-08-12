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
enum Kind {PV, CHANCE, ENNEMI}

const _SETUP := {
	Kind.PV: {"titre": "PV", "couleur": Color('c0392b')},
	Kind.CHANCE: {"titre": "CHANCE", "couleur": Color('e2b007')},
	# Rouge plus sombre que celui du joueur : deux barres de vie côte à côte, mais on
	# doit pouvoir dire d'un coup d'œil laquelle est la sienne.
	Kind.ENNEMI: {"titre": "ENNEMI", "couleur": Color('8e2f26')},
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

	# Chaque source a son signal : les ressources du joueur bougent sur
	# `stats_changed`, les pv de l'ennemi seulement quand un assaut est résolu.
	if kind == Kind.ENNEMI:
		CombatEngine.assault_resolved.connect(func(_rapport): refresh())
	else:
		PlayerStats.stats_changed.connect(refresh)
	refresh()


## La couleur de remplissage d'une `ProgressBar` vient de son thème. Elle reste posée en
## override ici, et c'est voulu même depuis que `themes/fdcn.tres` existe : la teinte
## dépend de `kind` (rouge joueur, jaune chance, rouge sombre ennemi), donc elle se décide
## à l'exécution. Le thème ne définit exprès aucune entrée `ProgressBar`, pour que ces
## trois couleurs restent la seule source de vérité.
func _paint_bar(couleur: Color) -> void:
	var remplissage := StyleBoxFlat.new()
	remplissage.bg_color = couleur
	remplissage.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", remplissage)

	var fond := StyleBoxFlat.new()
	fond.bg_color = _FOND
	fond.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", fond)


## Publique : l'écran de combat la rappelle au démarrage d'un affrontement, quand
## l'ennemi change sans qu'aucun signal ne soit parti.
func refresh() -> void:
	var courant = _courant()
	var maximum = _maximum()
	# Un `max_value` à 0 rendrait la barre absurde ; on garde au moins 1, et elle
	# reste vide de toute façon puisque le courant vaut 0 lui aussi.
	_bar.max_value = maxi(maximum, 1)
	_bar.value = courant
	_valeur.text = "%d / %d" % [courant, maximum]
	if kind == Kind.ENNEMI and show_title:
		_titre.text = CombatEngine.get_enemy().get("nom", "ENNEMI")


func _courant() -> int:
	match kind:
		Kind.PV:
			return PlayerStats.get_pv()
		Kind.CHANCE:
			return PlayerStats.get_cha()
		_:
			return CombatEngine.get_enemy_pv()


func _maximum() -> int:
	match kind:
		Kind.PV:
			return PlayerStats.get_pv_max()
		Kind.CHANCE:
			return PlayerStats.get_chance_max()
		_:
			return int(CombatEngine.get_enemy().get("pv", 0))
