extends Node
## Player — où en est le lecteur dans le livre, et par où il est passé.
##
## Détient le chapitre courant et les deux historiques de visite, et constitue
## le point d'entrée unique pour la navigation. Les objets vivent dans
## `Inventory`, les stats dans `PlayerStats`, les accès disque dans
## `SaveManager` ; cette classe les orchestre lors d'un changement de chapitre.
##
## `chapter_changed` est le signal global « le lecteur a bougé » : chaque écran
## qui affiche des données dépendant du chapitre s'y abonne et se rafraîchit
## tout seul, au lieu qu'un chef d'orchestre pousse les mises à jour dans
## chacun d'eux.

signal chapter_changed(node_id)

## Première visite d'un chapitre, **toutes parties confondues** — pas « nouveau pour ce
## Billy ». C'est la condition d'un nouveau succès : le revoir ne doit pas re-déclencher la
## fanfare.
signal chapter_discovered(node_id)

## Objets réellement gagnés / perdus en arrivant dans un chapitre. Les deux listes sont
## déjà filtrées par `Inventory` (un objet qu'on possède déjà n'est pas « gagné »), donc un
## retour en arrière n'émet rien.
signal chapter_items_changed(acquired, removed)

## Où en est le lecteur maintenant.
var current_node_id := 1

## Chapitres visités par *ce* Billy, dans l'ordre — le fil d'Ariane. Remis à
## zéro quand on démarre un nouveau Billy.
var session_visited_nodes := []

## Chapitres visités toutes parties confondues — sert au % de complétion et aux
## spoils. Jamais remis à zéro.
var visited_nodes_all_times := []


#
#    Démarrage
#

## Au lancement : on charge la sauvegarde du livre sélectionné, puis on se tient
## prêt à la recharger si le joueur change de livre (les sauvegardes sont par
## livre).
##
## AppParameters est déclaré avant Player dans la liste des autoloads, donc son
## `_ready()` (qui charge les paramètres et le livre dans BookData) a déjà tourné
## quand on arrive ici : les données du livre sont disponibles.
func _ready() -> void:
	AppParameters.book_changed.connect(_on_book_changed)
	do_load()


func _on_book_changed(_book_name) -> void:
	print('Player: changement de livre, rechargement de la sauvegarde')
	do_load()


#
#    Chargement
#

## Restaure tout depuis le disque pour le livre sélectionné. Peut être rappelé
## sans risque lors d'un changement de livre. Renvoie true si l'interface doit
## forcer l'ouverture de l'inventaire (une sauvegarde migrée a dû deviner ses
## objets, le joueur doit pouvoir corriger).
func do_load() -> bool:
	# Crée une sauvegarde vide si c'est une première partie, ou migre celle qui
	# existe si elle vient d'une version plus ancienne.
	SaveManager.prepare_save()

	load_all_times_already_visited()
	load_current_node_id()
	load_session_visited_nodes()
	Inventory.load_items()
	# On rejoue l'historique des chapitres pour que les stats gagnées en chemin
	# soient à jour même si les données du livre ont changé depuis la sauvegarde.
	_redo_all_my_chapters_stats()
	PlayerStats.recompute()
	# Après le recompute : les plafonds doivent être connus pour borner les
	# ressources relues.
	PlayerStats.load_resources()

	# Le chapitre courant vient de changer sans passer par `go_to_node()` : sans cette
	# émission, rien ne le sait. C'est ce qui laissait l'écran Aventure afficher le
	# chapitre de l'ancien livre après un changement de livre — tous ses composants
	# se peignent sur `chapter_changed`, et lui seul.
	chapter_changed.emit(current_node_id)
	return Inventory.need_force_display_options


func load_all_times_already_visited() -> void:
	visited_nodes_all_times = SaveManager.load_int_array(SaveManager.KEY_VISITED_ALL_TIMES)
	# Le chapitre 1 n'est pas toujours empilé au début d'une partie, on s'assure
	# qu'il y figure.
	if not (1 in visited_nodes_all_times):
		visited_nodes_all_times.append(1)


func save_all_times_already_visited() -> void:
	SaveManager.save_value(SaveManager.KEY_VISITED_ALL_TIMES, visited_nodes_all_times)


func load_current_node_id() -> void:
	current_node_id = int(SaveManager.load_value(SaveManager.KEY_CURRENT_NODE_ID, 1))


func save_current_node_id() -> void:
	SaveManager.save_value(SaveManager.KEY_CURRENT_NODE_ID, current_node_id)


func load_session_visited_nodes() -> void:
	session_visited_nodes = SaveManager.load_int_array(SaveManager.KEY_SESSION_VISITED)


func save_session_visited_nodes() -> void:
	SaveManager.save_value(SaveManager.KEY_SESSION_VISITED, session_visited_nodes)


## Reconstruit les stats issues des chapitres depuis l'historique courant. Public
## parce qu'un retour en arrière doit pouvoir s'en servir : après avoir dépilé le fil
## d'Ariane, c'est ce qui rend la couche « chapitres » exacte à nouveau.
func rebuild_chapter_stats() -> void:
	_redo_all_my_chapters_stats()
	PlayerStats.recompute()


## Rejoue tous les chapitres de l'historique de ce Billy pour reconstruire la
## couche de stats « chapitres ».
##
## Les ressources (pv, chance) sont exclues du rejeu : elles se lisent dans la
## sauvegarde. Les rejouer les remonterait au total de tout ce que les chapitres
## ont jamais donné, effaçant chaque dégât de combat et chaque ajustement manuel.
func _redo_all_my_chapters_stats() -> void:
	print('redo_all_my_chapters_stats:')
	# La couche « chapitres » s'accumule avec +=, elle doit donc repartir de zéro,
	# sinon un second do_load() compterait tout l'historique en double.
	PlayerStats.reset_chapter_layer()
	for chapter_id in session_visited_nodes:
		PlayerStats.apply_chapter_stats(chapter_id, false)


#
#    Lecture
#

func get_current_node_id() -> int:
	return current_node_id


func get_session_visited_nodes() -> Array:
	return session_visited_nodes


func get_visited_nodes_all_times() -> Array:
	return visited_nodes_all_times


func get_nb_all_time_seen() -> int:
	return len(visited_nodes_all_times)


## Vu par le Billy courant (cette partie).
##
## NOTE: on force l'entier. Le JSON du livre rend les identifiants de chapitre en
## float, et en GDScript `26.0 in [26]` vaut **false** : sans cette conversion,
## tous les marqueurs « déjà vu » restent éteints.
func did_billy_seen(chapter_id) -> bool:
	return int(chapter_id) in session_visited_nodes


## Vu au cours de n'importe quelle partie, depuis toujours. Voir la note
## ci-dessus sur la conversion en entier.
func did_all_times_seen(chapter_id) -> bool:
	return int(chapter_id) in visited_nodes_all_times


func have_previous_chapters() -> bool:
	return len(session_visited_nodes) > 1


## La fin du fil d'Ariane, du plus ancien au plus récent.
func get_last_visited_nodes(nb_chapters: int = 5) -> Array:
	var nb_previous = len(session_visited_nodes)
	if nb_previous > nb_chapters:
		return session_visited_nodes.slice(nb_previous - nb_chapters, nb_previous)
	return session_visited_nodes


#
#    Navigation
#

## Photo de l'état du joueur **avant** que le chapitre courant n'applique ses effets.
## C'est ce qui permet d'annuler une arrivée : pv, chance, objets, et le chapitre d'où
## l'on venait.
##
## Elle est prise ici et pas ailleurs : `CombatEngine.start()` la prenait sur
## `chapter_changed`, donc **après** les effets du chapitre, et les 6 chapitres de combat
## qui donnent aussi des pv (fdcn 54/58/133, cdsi 40/68/73) conservaient ce gain quand on
## annulait. Ici, l'instantané précède tout.
var arrival_snapshot := {}

## Déplace le lecteur vers `node_id` : enregistre la visite, applique les objets
## du chapitre et (à la première visite seulement) ses stats, puis prévient toute
## l'app via `chapter_changed`.
## Renvoie [est_nouveau_chapitre, objets_gagnés, objets_perdus].
func go_to_node(node_id) -> Array:
	# AVANT toute modification : d'où l'on vient et dans quel état on part.
	#
	# ⚠️ Le chapitre de retour est `session_visited_nodes[-1]`, PAS `[-2]` : à cet instant
	# `node_id` n'a pas encore été empilé, donc le dernier élément est bien celui qu'on
	# quitte. (`jump_to_previous_chapter()` renvoie `[-2]`, ce qui est correct *après*
	# l'empilement — s'en servir ici sauterait un chapitre.)
	arrival_snapshot = {
		"pv": PlayerStats.get_pv(),
		"cha": PlayerStats.get_cha(),
		"items": Inventory.get_possessed_items().duplicate(),
		"retour": session_visited_nodes[-1] if len(session_visited_nodes) > 0 else -1,
	}

	current_node_id = node_id
	save_current_node_id()

	var is_new_for_this_billy = not (current_node_id in session_visited_nodes)

	# On ne réempile pas si on ne fait que relancer l'app sur le même chapitre.
	if len(session_visited_nodes) == 0 or session_visited_nodes[-1] != node_id:
		session_visited_nodes.append(current_node_id)
		save_session_visited_nodes()

	var is_new_node = not (current_node_id in visited_nodes_all_times)
	if is_new_node:
		visited_nodes_all_times.append(current_node_id)
		save_all_times_already_visited()

	var acquired_and_removed = Inventory.apply_chapter_items(node_id)

	# Les stats de chapitre sont acquises une fois par Billy, pas à chaque repassage.
	if is_new_for_this_billy:
		print('%s is a NEW chapter for this billy, updating its stats' % node_id)
		PlayerStats.apply_chapter_stats(node_id)
	else:
		print('%s is a ALREADY VIEW chapter for this billy, NOT updating its stats' % node_id)

	chapter_changed.emit(current_node_id)

	# Après `chapter_changed` : les vues sont déjà repeintes quand les popups arrivent.
	if is_new_node:
		chapter_discovered.emit(current_node_id)
	if not acquired_and_removed[0].is_empty() or not acquired_and_removed[1].is_empty():
		chapter_items_changed.emit(acquired_and_removed[0], acquired_and_removed[1])

	return [is_new_node, acquired_and_removed[0], acquired_and_removed[1]]


## Le chapitre d'où l'on vient, ou -1 s'il n'y a nulle part où revenir.
func jump_to_previous_chapter() -> int:
	if len(session_visited_nodes) <= 1:
		print('jump_back::CANNOT GO BACK')
		return -1
	return session_visited_nodes[-2]


## Revient à un chapitre déjà visité, **et remet les stats d'aplomb**.
##
## À utiliser partout plutôt que d'enchaîner `jump_back()` + `go_to_node()` à la main :
## `jump_back()` dépile le chapitre de destination, si bien que le `go_to_node()` qui
## suit le croit neuf et **réapplique ses stats de chapitre**. Les trois écrans qui
## faisaient l'enchaînement eux-mêmes gonflaient donc les stats à chaque aller-retour.
## Le rejeu final, depuis un fil d'Ariane désormais plus court, rend la couche
## « chapitres » exacte.
func go_back_to(node_id) -> bool:
	if not jump_back(node_id):
		return false
	go_to_node(node_id)
	rebuild_chapter_stats()
	return true


## Dépile le fil d'Ariane jusqu'à retrouver `previous_id`. Renvoie false s'il
## n'est pas du tout dans l'historique.
##
## ⚠️ Bas niveau : préférer `go_back_to()`, qui enchaîne correctement.
func jump_back(previous_id) -> bool:
	print('jump_back::Jumping back to %s' % previous_id)
	if len(session_visited_nodes) == 1:
		print('jump_back::CANNOT GO BACK')
		return false

	while len(session_visited_nodes) > 0:
		var node_id = session_visited_nodes.pop_back()
		if node_id == previous_id:
			print('jump_back::BACK: get back at %s' % previous_id)
			return true
	print('jump_back::CRITICAL: cannot find the jump back node %s' % previous_id)
	return false


## On repart avec un Billy tout neuf : on efface le fil d'Ariane, les objets et
## les stats de cette partie. `visited_nodes_all_times` est volontairement gardé.
func launch_new_billy() -> void:
	session_visited_nodes = []
	save_session_visited_nodes()
	Inventory.reset()
	PlayerStats.full_reset()
	# `full_reset()` laisse les plafonds périmés et les ressources à zéro : il faut
	# recalculer avant de faire le plein, sinon un Billy neuf démarrerait à 0 pv.
	PlayerStats.recompute()
	PlayerStats.fill_resources()
