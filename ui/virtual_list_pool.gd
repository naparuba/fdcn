class_name VirtualListPool
extends RefCounted
## Fabrique et recycle les lignes d'une liste virtualisée : `screens/succes_menu.gd` et
## `screens/chapitres_menu.gd` partageaient ~90 lignes identiques (pool + repositionnement
## au défilement) qui n'avaient divergé qu'à force de copier-coller.
##
## Porte aussi le câblage commun autour du pool (review-code.md 7.3), pas seulement le pool
## lui-même : `item_count`/`update_row`, fournis une fois au constructeur, laissent
## `on_scroll_resized()`/`refresh_rows(force)` ne prendre plus aucun paramètre — chaque écran
## n'a donc plus qu'à connecter ses deux signaux ici, sans réécrire de wrapper.
##
## Ne connaît ni le type de ligne ni ce qu'une ligne affiche : `update_row` reçoit
## `(row, index, refresh)` et décide seule quoi faire — chaque écran garde donc son propre
## contenu (`set_from_success_object()` + `update()` d'un côté, `set_chapitre()` +
## `update_when_in_all_chapters()` avec son propre test « a changé de chapitre » de l'autre).

var _row_scene: PackedScene
var _content: Control
var _scroll: ScrollContainer
var _main: Node
var _row_height: float
var _buffer_rows: int
var _item_count: Callable
var _update_row: Callable

## Les lignes recyclées. `rows[i]` affiche l'élément `first_index + i`.
var rows: Array = []
var first_index := -1


func _init(row_scene: PackedScene, content: Control, scroll: ScrollContainer, main: Node,
		row_height: float, buffer_rows: int, item_count: Callable, update_row: Callable) -> void:
	_row_scene = row_scene
	_content = content
	_scroll = scroll
	_main = main
	_row_height = row_height
	_buffer_rows = buffer_rows
	_item_count = item_count
	_update_row = update_row


## Crée ou libère des lignes pour couvrir la hauteur visible de `_scroll`, sans jamais en
## garder plus que `item_count` (une liste plus courte que l'écran n'a pas besoin de plus).
func ensure_pool() -> void:
	var visible_height = _scroll.size.y
	if visible_height <= 0.0:
		return
	var item_count = _item_count.call()
	var needed = int(ceil(visible_height / _row_height)) + _buffer_rows * 2
	needed = mini(needed, item_count)

	while rows.size() < needed:
		var row = _row_scene.instantiate()
		row.set_main(_main)
		# Ancrages gauche/droite conservés : la ligne suit la largeur du conteneur.
		row.offset_left = 0
		row.offset_right = 0
		_content.add_child(row)
		rows.append(row)

	while rows.size() > needed:
		var row = rows.pop_back()
		row.queue_free()


## À connecter sur `_scroll.resized` : la hauteur visible a changé, il faut refaire le pool
## avant de repositionner.
func on_scroll_resized() -> void:
	ensure_pool()
	refresh_rows(true)


## Replace les lignes recyclées sur la position de défilement courante, et appelle
## `update_row(row, index, refresh)` pour chacune — `refresh` vaut `true` si `force` est
## passé ou si la ligne a changé d'élément depuis le dernier appel.
func refresh_rows(force := false) -> void:
	if rows.is_empty():
		ensure_pool()
		if rows.is_empty():
			return

	var item_count = _item_count.call()
	var first = int(_scroll.scroll_vertical / _row_height) - _buffer_rows
	first = clampi(first, 0, maxi(0, item_count - rows.size()))

	var moved = first != first_index
	first_index = first

	for i in rows.size():
		var row = rows[i]
		var index = first + i
		if index >= item_count:
			row.visible = false
			continue

		row.visible = true
		var y = index * _row_height
		row.offset_top = y
		row.offset_bottom = y + _row_height

		_update_row.call(row, index, force or moved)
