extends Control
## Conteneur de pages : affiche un écran à la fois, et permet d'en changer par
## balayage ou par les flèches latérales.
##
## Remplace l'ancien autoload `Swiper` (supprimé), qui déplaçait une caméra entre
## cinq pages posées côte à côte dans une seule grande scène, avec des positions
## en dur. Ici chaque écran est une scène indépendante, instanciée à la demande.
##
## NAVIGATION NEUTRALISÉE QUAND UNE POPUP EST OUVERTE
## Les popups sont ajoutées dans `PopupContainer`, qui recouvre la page. Sans
## garde-fou, un balayage fait *dans* la popup changerait la page derrière elle,
## et les flèches resteraient actives sous la popup. Toute la navigation est donc
## bloquée tant qu'une popup est affichée, et les flèches sont grisées pour que
## ce soit visible.

@export var scenes: Array[PackedScene] = []

## Noms des pages, dans le même ordre que `scenes`. Utilisé par `go_to_page()`,
## que le menu du haut appelle pour aller directement sur un écran.
@export var page_names: Array[String] = ["aventure", "chapitres", "lore", "succes", "about"]

## Distance minimale, en pixels, pour qu'un glissement compte comme un balayage.
@export var swipe_threshold: float = 100.0

var current_index: int = 0
var current_scene_instance: Node = null

var _confirm_scene = preload('res://popups/GenericConfirmationPopup.tscn')

@onready var scene_container = $SceneContainer
@onready var popup_container = $PopupContainer
@onready var _nav_left = $NavLeft
@onready var _nav_right = $NavRight

var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false


func _ready():
	_load_scene(current_index)
	_nav_left._on_nav_pressed.connect(func(): _change_page(-1))
	_nav_right._on_nav_pressed.connect(func(): _change_page(1))

	# On suit l'ouverture/fermeture des popups pour griser les flèches.
	popup_container.child_entered_tree.connect(func(_n): _update_nav_state())
	popup_container.child_exiting_tree.connect(func(_n): _update_nav_state.call_deferred())


#
#    Popups
#

## Ouvre une popup par-dessus la page. Cherché par nom de méthode
## (`Utils.find_ancestor_with_method(self, "open_popup")`) par les composants qui en ont
## besoin, comme `go_to_page` : ils n'ont ainsi aucune référence à tenir.
##
## ⚠️ La popup doit se **libérer** en se fermant, pas se masquer : `is_popup_open()`
## compte tout enfant non détruit, donc une popup seulement cachée bloquerait la
## navigation pour de bon.
func open_popup(popup: Node) -> void:
	popup_container.add_child(popup)


## Demande une confirmation, et n'appelle `on_accept` que si le joueur accepte.
##
## Centralisé ici parce que deux pages en ont besoin (nouveau Billy depuis les choix de
## chapitre et depuis « À propos ») et qu'une confirmation dupliquée finit toujours par
## divergerence. La popup est **instanciée à chaque fois** et se libère en se fermant :
## elle vit dans `PopupContainer`, donc elle bloque la navigation tant qu'elle est là,
## ce qu'une instance posée à même une page ne ferait pas.
func confirm(texte: String, on_accept: Callable, libelle_accepter := "Confirmer",
		libelle_annuler := "Annuler") -> void:
	var popup = _confirm_scene.instantiate()
	popup.content = texte
	popup.accept_button = libelle_accepter
	popup.cancel_button = libelle_annuler
	popup.generic_popup_accept.connect(on_accept)
	open_popup(popup)
	popup.open()


## Vrai si une popup est actuellement affichée par-dessus la page.
func is_popup_open() -> bool:
	for child in popup_container.get_children():
		# Un nœud en cours de suppression compte encore comme enfant pendant
		# une frame : on l'ignore, sinon la navigation resterait bloquée.
		if not child.is_queued_for_deletion():
			return true
	return false


func _update_nav_state() -> void:
	var blocked = is_popup_open()
	_nav_left.setDisabled(blocked)
	_nav_right.setDisabled(blocked)


#
#    Changement de page
#

func _load_scene(index: int):
	if current_scene_instance:
		current_scene_instance.queue_free()
	current_scene_instance = scenes[index].instantiate()
	scene_container.add_child(current_scene_instance)


## Va directement à la page nommée (voir `page_names`).
func go_to_page(page_name: String) -> void:
	if is_popup_open():
		return
	var index = page_names.find(page_name)
	if index == -1:
		push_warning("MenuPage: page inconnue: %s" % page_name)
		return
	if index == current_index:
		return
	current_index = index
	_load_scene(current_index)


## Page suivante (+1) ou précédente (-1), en boucle.
func _change_page(direction: int):
	if is_popup_open():
		return
	current_index = wrapi(current_index + direction, 0, scenes.size())
	_load_scene(current_index)


#
#    Balayage
#

func _input(event):
	if is_popup_open():
		_is_dragging = false
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_start_pos = event.position
			_is_dragging = true
		else:
			if _is_dragging:
				_check_swipe(event.position)
			_is_dragging = false


func _check_swipe(end_pos: Vector2):
	var delta_x = end_pos.x - _drag_start_pos.x
	if abs(delta_x) < swipe_threshold:
		return
	if delta_x > 0:
		_change_page(-1)  # glissé vers la droite -> page précédente
	else:
		_change_page(1)   # glissé vers la gauche -> page suivante
