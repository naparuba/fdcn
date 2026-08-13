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

## Titres **affichés**, dans le même ordre. Séparés de `page_names`, qui sont des clés
## internes : « succes » est un identifiant, « Succès » est ce que le joueur lit.
##
## Ils servent aux libellés des deux flèches, qui annoncent chacune la page où elle mène.
@export var page_titles: Array[String] = ["Aventure", "Chapitres", "Lore", "Succès", "À propos"]

## Distance minimale, en pixels, pour qu'un glissement compte comme un balayage.
@export var swipe_threshold: float = 100.0

var current_index: int = 0
var current_scene_instance: Node = null

var _confirm_scene = preload('res://popups/GenericConfirmationPopup.tscn')
var _settings_scene = preload('res://popups/SettingsPopup.tscn')

## La popup d'options s'ouvre sur l'inventaire : c'est son premier onglet.
const _TEXTE_REVISION := """Votre sauvegarde ne contenait pas la liste de vos objets.

Les chapitres traversés ont été rejoués pour retrouver ce que le livre vous a donné, mais
l'équipement choisi au départ, lui, ne peut pas être deviné.

Vérifiez votre inventaire et cochez ce que vous portez."""

@onready var scene_container = $SceneContainer
@onready var popup_container = $PopupContainer
## Les toasts (objet gagné / perdu) vivent dans **leur propre** couche, pas dans
## `PopupContainer` : celui-ci bloque la navigation tant qu'il a un enfant, et un message
## qui s'efface au bout de 3 s aurait donc figé les pages pendant 3 s. `mouse_filter = 2`
## la rend transparente aux clics.
@onready var toast_layer = $ToastLayer

var _item_popup_scene = preload('res://popups/ItemPopup.tscn')
var _success_popup_scene = preload('res://popups/SuccessPopup.tscn')
@onready var _nav_left = $NavLeft
@onready var _nav_right = $NavRight

var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false


## Nom de type de thème sous lequel vivent les deux retraits de cette page. `MenuPage`
## n'est pas une classe Godot : `get_theme_constant()` accepte un type explicite, donc
## aucune `theme_type_variation` n'est nécessaire sur le nœud.
const _TYPE_THEME := "MenuPage"


func _ready():
	_apply_insets()
	_load_scene(current_index)
	_nav_left._on_nav_pressed.connect(func(): _change_page(-1))
	_nav_right._on_nav_pressed.connect(func(): _change_page(1))

	# On suit l'ouverture/fermeture des popups pour griser les flèches.
	popup_container.child_entered_tree.connect(func(_n): _update_nav_state())
	popup_container.child_exiting_tree.connect(func(_n): _update_nav_state.call_deferred())

	# MenuPage est le seul nœud toujours vivant qui possède une couche d'affichage
	# par-dessus les pages : c'est donc lui qui montre ce qui doit apparaître quel que
	# soit l'écran courant.
	Player.chapter_items_changed.connect(_on_chapter_items_changed)
	Player.chapter_discovered.connect(_on_chapter_discovered)
	Player.items_need_review.connect(_on_items_need_review)


## Creuse la place des deux flèches latérales et du menu du haut.
##
## Ces retraits étaient écrits **quatre fois** en dur dans la scène (les trois `offset_*`
## de `SceneContainer` et le `offset_top` de `PopupContainer`) : changer la largeur d'une
## flèche demandait de retrouver les quatre. Ils viennent maintenant du thème, où ils sont
## déclarés une fois — `MenuPage/constants/inset_nav` et `inset_top`.
func _apply_insets() -> void:
	var nav := get_theme_constant("inset_nav", _TYPE_THEME)
	var haut := get_theme_constant("inset_top", _TYPE_THEME)
	scene_container.offset_left = nav
	scene_container.offset_right = -nav
	scene_container.offset_top = haut
	popup_container.offset_top = haut


#
#    Annonces : objets gagnés/perdus et nouveaux succès
#

## Un toast par objet, gagnés d'abord. `ItemPopup` porte son propre `Timer` de 3 s et se
## libère tout seul — rien à nettoyer ici.
func _on_chapter_items_changed(acquired: Array, removed: Array) -> void:
	for item_name in acquired:
		_toast_item(item_name, true)
	for item_name in removed:
		_toast_item(item_name, false)


func _toast_item(item_name: String, gagne: bool) -> void:
	# `get_item_data()` plante sur une clé absente, d'où le test préalable : le nom vient
	# des données du livre, une coquille y est possible.
	if not BookData.exists_item_data(item_name):
		push_warning("MenuPage: objet inconnu dans les données du livre: %s" % item_name)
		return
	var item_data = BookData.get_item_data(item_name)
	var toast = _item_popup_scene.instantiate()
	toast_layer.add_child(toast)
	toast.load_item_data(item_name, item_data)
	toast.set_is_new(gagne)


## Un succès ne se fête qu'à la **découverte** du chapitre : `chapter_discovered` ne part
## qu'à la première visite toutes parties confondues, donc repasser par là ne relance pas
## la fanfare.
func _on_chapter_discovered(node_id) -> void:
	if not BookData.is_success_chapter(node_id):
		return
	var success = BookData.get_success_from_chapter(node_id)
	if success == null:
		push_warning("MenuPage: chapitre %s marqué succès mais introuvable" % node_id)
		return
	# `SuccessPopup` a une racine `Popup`, donc sa propre fenêtre : elle n'a pas besoin
	# d'un conteneur, mais elle doit être dans l'arbre avant d'être montrée.
	var popup = _success_popup_scene.instantiate()
	add_child(popup)
	popup.update_and_show(success)


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


## La sauvegarde relue n'avait pas la liste des objets. On explique, puis on ouvre
## l'inventaire — c'est le seul écran où le joueur peut rétablir la vérité, et lui seul la
## connaît : l'équipement de départ se choisit **avant** le chapitre 1, aucun chapitre ne le
## donne, donc rien ne permet de le reconstituer.
##
## `call_deferred` parce que ce signal part depuis `Player.do_load()`, c'est-à-dire pendant
## le `_ready()` des autoloads : le conteneur de popups n'est pas encore dans l'arbre au
## premier chargement.
func _on_items_need_review() -> void:
	_demander_revision_inventaire.call_deferred()


func _demander_revision_inventaire() -> void:
	confirm(_TEXTE_REVISION, _ouvrir_inventaire, "Vérifier mon inventaire", "")


func _ouvrir_inventaire() -> void:
	open_popup(_settings_scene.instantiate())


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
	_refresh_nav_labels()


## Chaque flèche annonce **la page où elle mène**. Sans ça le chevron ne dit que le sens, pas
## la destination — et le joueur doit balayer pour savoir ce qu'il y a à côté.
func _refresh_nav_labels() -> void:
	_nav_left.set_txt(_titre_page(current_index - 1))
	_nav_right.set_txt(_titre_page(current_index + 1))


## Titre de la page à cet index, **bouclage compris** : la navigation tourne en rond
## (`wrapi` dans `_change_page`), donc la flèche gauche de la première page annonce bien la
## dernière. Repli sur la clé interne si un titre manque, plutôt qu'un libellé vide.
func _titre_page(index: int) -> String:
	if scenes.is_empty():
		return ""
	var i = wrapi(index, 0, scenes.size())
	if i < page_titles.size():
		return page_titles[i]
	if i < page_names.size():
		return page_names[i]
	return ""


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
