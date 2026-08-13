extends Node
## Inventory — ce que porte le Billy, et le type de Billy qui en découle.
##
## Données pures : on n'y construit jamais de nœud d'interface. Les vues
## (popups/sub/inventory.gd) demandent `get_visible_item_names()` et fabriquent
## leurs propres lignes. Les métadonnées des objets viennent toujours de
## `BookData.get_all_objects()`, jamais d'une scène.
##
## Le type de Billy est *déduit*, pas choisi : porter 2 objets ou plus d'une même
## catégorie détermine le type. Voir `compute_billy_for_option()`.

signal items_changed
signal billy_changed(billy_type)

## Nombre maximum d'objets ARME/EQUIPEMENT/OUTIL portés par un Billy.
const MAX_CARRIED := 3

## Seules ces catégories comptent pour le type de Billy. Le reste (notamment la
## catégorie "BILLY", qui contient les marqueurs de type eux-mêmes) est ignoré.
const BILLY_CATEGORIES := ["ARME", "EQUIPEMENT", "OUTIL"]

## Ce que porte le Billy, dans l'ordre où il l'a ramassé. Sauvegardé tel quel.
var possessed_items := []

## Noms d'objets + type de Billy courant, c'est-à-dire tout ce qu'une condition
## de saut peut tester. Reconstruit à chaque changement d'inventaire.
var all_matched_conditions := []

## Vrai quand la sauvegarde relue ne contenait pas la liste des objets : ce qui a pu être
## reconstitué l'a été en rejouant les chapitres, mais **l'équipement de départ, lui, est
## perdu** — aucun chapitre ne le donne, c'est le lecteur qui l'a choisi dans le livre.
## `Player` en fait un signal, et l'interface ouvre l'inventaire pour que le joueur corrige.
var need_force_display_options := false


#
#    Lecture
#

func get_possessed_items() -> Array:
	return possessed_items


func have_item(item_name) -> bool:
	return item_name in possessed_items


func get_all_matched_conditions() -> Array:
	return all_matched_conditions


## Tous les noms d'objets à afficher dans l'inventaire, dans l'ordre du livre.
## Exclut les marqueurs de catégorie "BILLY", qui ne sont pas de vrais objets.
func get_visible_item_names() -> Array:
	var names := []
	var all_objects = BookData.get_all_objects()
	for item_name in all_objects.keys():
		if all_objects[item_name].get('category', '') == 'BILLY':
			continue
		names.append(item_name)
	return names


func get_item_category(item_name) -> String:
	var all_objects = BookData.get_all_objects()
	if not all_objects.has(item_name):
		return ''
	return all_objects[item_name].get('category', '')


#
#    Persistance
#

func load_items() -> void:
	possessed_items = []
	var did_guess := false
	if SaveManager.has_save(SaveManager.KEY_POSSESSED_ITEMS):
		var data = SaveManager.load_value(SaveManager.KEY_POSSESSED_ITEMS, [])
		possessed_items = data if data is Array else []
	else:
		_guess_after_migration()
		did_guess = true
	# D'une version à l'autre, un objet a pu être renommé ou retiré du livre.
	_clean_not_existing_items()
	_recompute_matched_conditions()
	# On écrit tout de suite l'inventaire deviné : sans ça il serait redeviné à
	# chaque lancement, et la demande de correction reviendrait sans arrêt.
	if did_guess:
		save_items()


func save_items() -> void:
	SaveManager.save_value(SaveManager.KEY_POSSESSED_ITEMS, possessed_items)


## Pas de fichier d'objets : on **rejoue les chapitres visités**, et rien d'autre.
##
## On ne devine plus l'équipement de départ. Une table `type de Billy -> 3 objets` existait
## par livre, écrite à la main : elle **inventait une information que la sauvegarde n'avait
## jamais eue** (le type, oui ; les objets, non), et elle empilait ses 3 objets par-dessus le
## rejeu sans passer par `clean_overload()` — un Billy migré pouvait porter 6 objets, tous
## comptés dans ses stats.
##
## Le rejeu, lui, ne restitue que du réel : ce que les chapitres traversés ont donné. Ce qui
## manque à l'arrivée, c'est l'équipement choisi **avant** le chapitre 1, qu'aucun chapitre
## ne donne — et c'est justement ce que le joueur est le seul à savoir. D'où le drapeau, et
## l'inventaire ouvert d'office.
func _guess_after_migration() -> void:
	need_force_display_options = true
	print('SAVE: sauvegarde sans liste d\'objets, reconstitution depuis les chapitres visités')
	for chapter_id in Player.get_session_visited_nodes():
		apply_chapter_items(chapter_id)


func _clean_not_existing_items() -> void:
	var to_del := []
	for item_name in possessed_items:
		if not BookData.exists_item_data(item_name):
			to_del.append(item_name)
	for item_name in to_del:
		_raw_remove(item_name)


func reset() -> void:
	possessed_items = []
	save_items()
	_recompute_matched_conditions()


## Repose une liste d'objets telle quelle, sans repasser par les règles de
## surcharge : c'est une restauration, pas un choix du joueur. Sert aux retours en
## arrière (`CombatEngine.cancel()`), qui reposent un état déjà valide.
func restore_items(items: Array) -> void:
	possessed_items = items.duplicate()
	save_items()
	_recompute_matched_conditions()
	PlayerStats.recompute()
	items_changed.emit()


#
#    Modifications
#

func _raw_add(item_name) -> void:
	possessed_items.append(item_name)


func _raw_remove(item_name) -> void:
	possessed_items.erase(item_name)


func _recompute_matched_conditions() -> void:
	all_matched_conditions = possessed_items.duplicate()
	all_matched_conditions.append(AppParameters.get_billy_type().to_upper())


## Objet donné en entrant dans un chapitre. Renvoie true s'il a réellement été
## ajouté (on peut déjà le posséder).
func add_item_from_chapter(item_name) -> bool:
	if have_item(item_name):
		return false
	_raw_add(item_name)
	_after_change()
	return true


## Objet retiré par un chapitre. Renvoie true si on l'avait réellement.
func remove_item_from_chapter(item_name) -> bool:
	if not have_item(item_name):
		return false
	_raw_remove(item_name)
	_after_change()
	return true


## Objet coché par l'utilisateur dans l'inventaire. Peut changer le type de Billy
## et faire sortir un autre objet (3 portés au maximum).
func add_item_from_options(item_name) -> void:
	if have_item(item_name):
		return
	_raw_add(item_name)
	compute_billy_for_option(item_name)
	_after_change()


## Objet décoché par l'utilisateur dans l'inventaire.
func remove_item_from_options(item_name) -> void:
	if not have_item(item_name):
		return
	_raw_remove(item_name)
	compute_billy_for_option(item_name)
	_after_change()


func _after_change() -> void:
	save_items()
	_recompute_matched_conditions()
	PlayerStats.recompute()
	items_changed.emit()


## Applique les listes aquire/remove d'un chapitre. Renvoie
## [réellement_gagnés, réellement_perdus] pour que l'appelant puisse afficher les
## popups « nouvel objet » / « objet perdu ».
func apply_chapter_items(chapter_id) -> Array:
	var node = BookData.get_chapter_node(chapter_id)
	var really_acquired := []
	for item_name in node.get_aquire():
		if add_item_from_chapter(item_name):
			really_acquired.append(item_name)
	var really_removed := []
	for item_name in node.get_remove():
		if remove_item_from_chapter(item_name):
			really_removed.append(item_name)
	return [really_acquired, really_removed]


#
#    Déduction du type de Billy
#

## {catégorie: [nom_objet, ...]} pour les objets portés qui comptent pour le type.
func _items_by_category() -> Dictionary:
	var by_category := {}
	for category in BILLY_CATEGORIES:
		by_category[category] = []
	for item_name in possessed_items:
		var category = get_item_category(item_name)
		if by_category.has(category):
			by_category[category].append(item_name)
	return by_category


## Nombre d'objets au-delà de MAX_CARRIED que porte le Billy.
func overload_size() -> int:
	var by_category = _items_by_category()
	var nb_objs := 0
	for category in BILLY_CATEGORIES:
		nb_objs += by_category[category].size()
	return maxi(0, nb_objs - MAX_CARRIED)


## Retire des objets jusqu'à revenir à MAX_CARRIED, sans jamais retirer
## `keep_item_name` (celui que l'utilisateur vient de choisir).
func clean_overload(keep_item_name) -> void:
	var to_remove = overload_size()
	if to_remove == 0:
		return

	var by_category = _items_by_category()
	var candidates := []
	for category in BILLY_CATEGORIES:
		for item_name in by_category[category]:
			if item_name != keep_item_name:
				candidates.append(item_name)

	# On parcourt la liste des candidats une seule fois : impossible de boucler à
	# l'infini quand il n'y a plus rien à retirer (ce que faisait l'ancien while).
	for item_name in candidates:
		if to_remove <= 0:
			break
		_raw_remove(item_name)
		to_remove -= 1


func compute_billy() -> void:
	compute_billy_for_option('')
	PlayerStats.recompute()


## Recalcule le type de Billy à partir des objets portés.
## Règles : 3 objets max ; 2+ dans une catégorie => ce type ; un de chaque =>
## débrouillard ; tout le reste => pégu.
func compute_billy_for_option(new_option) -> void:
	clean_overload(new_option)

	var by_category = _items_by_category()
	var nb_armes = by_category["ARME"].size()
	var nb_equipements = by_category["EQUIPEMENT"].size()
	var nb_outils = by_category["OUTIL"].size()

	var billy_type := 'pegu'
	if nb_armes + nb_equipements + nb_outils >= MAX_CARRIED:
		if nb_armes >= 2:
			billy_type = 'guerrier'
		elif nb_equipements >= 2:
			billy_type = 'prudent'
		elif nb_outils >= 2:
			billy_type = 'paysan'
		elif nb_armes == 1 and nb_equipements == 1 and nb_outils == 1:
			billy_type = 'debrouillard'
	_switch_to_billy(billy_type)


## Impose un type de Billy depuis l'interface (les boutons du menu du haut) au
## lieu de le déduire des objets portés. Les modificateurs du type entrent dans
## les stats, il faut donc les recalculer.
func force_billy_type(billy_type: String) -> void:
	if not _switch_to_billy(billy_type):
		return
	PlayerStats.recompute()


## Renvoie vrai si le type a réellement changé (et donc si `billy_changed` a été
## émis), pour que l'appelant ne relance pas de calcul pour rien.
func _switch_to_billy(billy_type) -> bool:
	if AppParameters.get_billy_type() == billy_type:
		return false
	AppParameters.set_billy_type(billy_type)
	_recompute_matched_conditions()
	billy_changed.emit(billy_type)
	return true
