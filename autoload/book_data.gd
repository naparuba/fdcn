extends Node
## Les données du livre COURANT, plus le registre de tous les livres.
##
## `books/books.json` est la seule liste de livres du dépôt — `{nom, titre}`, rien d'autre.
## Les couvertures du sélecteur, le livre par défaut, la conversion des vieilles
## sauvegardes et le compilateur Python en sortent tous : aucun nom de livre n'est écrit
## dans le code, pour qu'un livre s'ajoute en déposant un dossier et une ligne.
##
## Tout le reste d'un livre est **un fichier facultatif de son dossier**, jamais une
## déclaration : `audio/intro.mp3`, `audio/<chapitre>.mp3`. Le fichier existe, la
## fonctionnalité existe. Voir `books/README.md`.
##
## BookData est le 3ᵉ autoload, avant AppParameters : son `_ready()` a donc chargé le
## registre quand AppParameters demande le livre à ouvrir.
##
## ⚠️ **1 fichier compilé chargé, pas 10** (2026-08-13 puis 2026-08-29, todo 3.6).
## Cinq sorties ne servaient à personne (combats, secrets, les trois listes de fins), et
## quatre autres étaient des **doublons de valeur** : l'index des chapitres à succès
## répétait `-compilated-success.json`, qui répétait lui-même `<nom>.all_success.json` pour
## un champ ajouté — de même pour les objets. Les libellés, catégories et textes ne
## s'écrivent donc plus qu'à un seul endroit : le fichier que l'auteur édite. Ce que le
## compilateur ajoutait (`in_chapters`, `chapter`, l'index) se reconstruit ici en une passe
## sur les chapitres. Les 3 fichiers calculés + 2 tables recopiées qui restaient sont
## maintenant réunis en un seul `<nom>-compilated.json` (`chapters`/`nodes_by_chapter`/
## `nodes_by_sub_arc`/`objects`/`success`/`counters`/`ignored`) — les deux dernières clés
## depuis le 2026-08-29 (todo 3.8), quand `data/compteurs.json` a rejoint les autres tables
## du livre dans `scripts/src/<nom>/<nom>.livre.json`. Le détail est dans
## `scripts/README.md`.

const REGISTRE := "res://books/books.json"

const _CHAPTER_DATA := preload('res://entities/chapter_data.gd')

var _current_book_name := ''

## Chapitre -> `chapter_data`, et les deux tables de découpage en actes. Les noms sont
## ceux de `scripts/README.md`, qui dit quel fichier compilé alimente quoi.
var all_nodes = {}
var chapters_by_arc = {}
var chapters_by_sub_arc = {}
var all_success = []
var all_success_chapters = {}  # chapitre -> identifiant de succès
var all_objects = {}

## Le registre, dans l'ordre du fichier — **l'ordre est significatif**, voir
## `AppParameters._resoudre_livre_courant()`.
var books = []
var _books_by_name = {}

## Les compteurs propres au livre courant, relus à chaque changement de livre.
var counters = []

## Les clés de stat de chapitre que le livre déclare lui-même comme sans effet (todo 3.5,
## review §4.6) — `arc_et_couteau` pour fdcn : un trou de saisie dans le livre, pas une
## faute qu'un futur passage devrait "corriger" en lui inventant un effet.
var _ignorees: Array = []


func _ready() -> void:
	_load_registre()


#
#    Registre
#

## Un registre illisible n'est pas rattrapable : sans lui il n'y a aucun livre à ouvrir,
## aucune couverture à afficher et aucun défaut à proposer. D'où `push_error` et une liste
## vide plutôt qu'un livre inventé — l'app démarre et le dit, au lieu de chercher un dossier
## qui n'existe peut-être pas.
func _load_registre() -> void:
	books = []
	_books_by_name = {}

	var registre = Utils.load_json_file(REGISTRE)
	if not registre is Dictionary:
		push_error("BookData: registre illisible: %s" % REGISTRE)
		return

	for livre in registre.get("livres", []):
		var nom = livre.get("nom", "") if livre is Dictionary else ""
		if nom == "":
			push_warning("BookData: entrée sans `nom` dans %s: %s" % [REGISTRE, livre])
			continue
		books.append(livre)
		_books_by_name[nom] = livre


## Tous les livres déclarés, dans l'ordre du registre.
func get_books() -> Array:
	return books


## L'entrée de registre d'un livre, ou `{}` s'il n'est pas déclaré. Les appelants
## enchaînent sur `.get("champ", defaut)`, donc un livre inconnu se comporte comme un livre
## sans option : pas de son d'intro, pas de titre.
func get_book(book_name) -> Dictionary:
	return _books_by_name.get(book_name, {})


func book_exists(book_name) -> bool:
	return _books_by_name.has(book_name)


## Le premier livre du registre. C'est lui qu'on ouvre quand rien n'a été choisi, ou quand
## le choix enregistré pointe vers un livre qui n'existe plus.
func get_default_book_name() -> String:
	if books.is_empty():
		return ''
	return books[0].get("nom", "")


#
#    Chargement d'un livre
#

func do_load_book(book_name) -> void:
	_current_book_name = book_name
	print('BookData: chargement du livre %s' % book_name)
	var book_path = "res://books/%s/data/%s" % [book_name, book_name]

	# Un seul fichier compilé (todo 3.6) : `chapters` + les deux index générés pour l'UI +
	# les deux tables écrites à la main, recopiées telles quelles par le compilateur — il ne
	# peut pas aller les lire dans `scripts/`, un dossier que Godot ignore.
	var compiled = Utils.load_json_file(book_path + "-compilated.json")
	if compiled == null:
		push_error("BookData: impossible de charger %s-compilated.json" % book_path)
		return

	# On repart d'un dictionnaire vide : sinon, en changeant de livre, les chapitres de
	# l'ancien livre dont l'identifiant n'existe pas dans le nouveau resteraient
	# accessibles, et `get_chapter_node()` renverrait les données du mauvais livre.
	#
	# Cette ligne **libère** aussi les instances de l'ancien livre, depuis que
	# `chapter_data.gd` est un `RefCounted` : c'était un `Node`, jamais ajouté à l'arbre,
	# donc jamais libéré — ~600 objets fuités par changement de livre.
	all_nodes = {}
	var all_nodes_json = compiled["chapters"]
	for node_id_str in all_nodes_json.keys():
		var chapter_data = _CHAPTER_DATA.new()
		chapter_data.create(all_nodes_json[node_id_str])
		all_nodes[node_id_str] = chapter_data

	chapters_by_arc = compiled["nodes_by_chapter"]
	chapters_by_sub_arc = compiled["nodes_by_sub_arc"]
	# Objets et succès sont lus dans les fichiers **écrits à la main** puis complétés ici.
	# Le compilateur en produisait des copies enrichies : les mêmes libellés, catégories et
	# textes écrits deux fois dans le dépôt, pour deux champs ajoutés.
	all_objects = _completer_objets(compiled["objects"])
	all_success = _completer_succes(compiled["success"])
	all_success_chapters = _index_succes_par_chapitre()
	counters = _parse_counters(compiled.get("counters", []))
	_ignorees = compiled.get("ignored", [])


## Les compteurs déclarés par le livre — `compteurs` dans `<nom>.livre.json` côté source
## (todo 3.8), recopié tel quel dans le fichier compilé. Un livre qui ne compte rien
## déclare une liste vide, et ce n'est pas une anomalie : il n'aura simplement pas de ligne
## en plus dans la feuille de stats.
##
## Une entrée incomplète, elle, est bien une faute de saisie : on la signale et on l'ignore
## plutôt que d'afficher une ligne sans nom.
func _parse_counters(brut: Array) -> Array:
	var trouves := []
	for compteur in brut:
		var cle = compteur.get("cle", "") if compteur is Dictionary else ""
		var libelle = compteur.get("libelle", "") if compteur is Dictionary else ""
		if cle == "" or libelle == "":
			push_warning("BookData: compteur incomplet pour %s: %s" % [_current_book_name, compteur])
			continue
		trouves.append({"cle": cle, "libelle": libelle})
	return trouves


## Les objets du livre, complétés de ce que les chapitres en disent :
##
##   `in_chapters`  où l'objet se gagne ou se perd — ce qui décide s'il est montrable sans
##                  spoiler. Un objet qu'aucun chapitre ne cite est **connu depuis le
##                  début** (`[1]`) : c'est l'équipement que le lecteur choisit avant le
##                  chapitre 1 ;
##   `stats`        un dictionnaire vide plutôt qu'une clé absente, pour les appelants.
func _completer_objets(objets) -> Dictionary:
	if not objets is Dictionary:
		push_error("BookData: objets illisibles pour %s" % _current_book_name)
		return {}

	var par_objet := {}
	for node_id_str in all_nodes:
		var chapitre = int(node_id_str)
		var chapter_data = all_nodes[node_id_str]
		for item_name in chapter_data.get_aquire() + chapter_data.get_remove():
			if not par_objet.has(item_name):
				par_objet[item_name] = []
			if not (chapitre in par_objet[item_name]):
				par_objet[item_name].append(chapitre)

	for item_name in objets:
		var complet = objets[item_name].duplicate()
		complet['in_chapters'] = par_objet.get(item_name, [1])
		complet['stats'] = complet.get('stats', {})
		objets[item_name] = complet
	return objets


## Les succès du livre, complétés du chapitre qui les donne.
##
## ⚠️ **Un succès par identifiant, même s'il se gagne à deux endroits.** Le fichier compilé
## était une liste de paires (succès × chapitre) : `PHOBIE-ADMINISTRATIVE` de cdsi, déclaré
## par les chapitres 98 et 498, y figurait **deux fois** — et l'écran des succès affichait
## donc deux lignes identiques. `chapter` garde le premier chapitre, pour l'afficher ;
## savoir si le succès est obtenu passe par `is_success_obtenu()`, qui les regarde tous.
func _completer_succes(succes) -> Array:
	if not succes is Array:
		push_error("BookData: succès illisibles pour %s" % _current_book_name)
		return []

	var par_succes := {}
	for node_id_str in all_nodes:
		var success_id = all_nodes[node_id_str].get_success()
		if success_id == null:
			continue
		if not par_succes.has(success_id):
			par_succes[success_id] = []
		par_succes[success_id].append(int(node_id_str))

	var complets := []
	for success in succes:
		var chapitres = par_succes.get(success['id'], [])
		chapitres.sort()
		var complet = success.duplicate()
		complet['chapter'] = chapitres[0] if not chapitres.is_empty() else 1
		complets.append(complet)
	return complets


## Chapitre -> identifiant de succès. Tous les chapitres qui donnent un succès y sont, y
## compris quand deux en donnent le même.
func _index_succes_par_chapitre() -> Dictionary:
	var index := {}
	for node_id_str in all_nodes:
		var success_id = all_nodes[node_id_str].get_success()
		if success_id != null:
			index['%d' % int(node_id_str)] = success_id
	return index


## Vrai si le joueur a traversé **l'un** des chapitres qui donnent ce succès.
func is_success_obtenu(success_id) -> bool:
	for node_id_str in all_success_chapters:
		if all_success_chapters[node_id_str] == success_id and Player.did_all_times_seen(int(node_id_str)):
			return true
	return false


#
#    Chapitres
#

func get_all_nodes():
	return all_nodes


func get_chapter_node(node_id):
	return all_nodes['%s' % int(node_id)]


## Pourcentage de chapitres déjà vus dans l'acte de `node_id`.
func get_acte_completion(node_id, visited_nodes_all_times) -> int:
	var chapter = get_chapter_node(node_id).get_chapter()
	return _completion(chapters_by_arc.get(chapter, []), visited_nodes_all_times)


## Même chose pour le sous-arc — un découpage plus fin que l'acte.
func get_sub_arc_completion(node_id, visited_nodes_all_times) -> int:
	var sub_arc = get_chapter_node(node_id).get_arc()
	return _completion(chapters_by_sub_arc.get(sub_arc, []), visited_nodes_all_times)


## Un chapitre hors de tout acte n'a rien à compléter : 100 % plutôt que 0, sinon la barre
## de progression accuserait le joueur d'un retard imaginaire.
func _completion(chapters: Array, visited) -> int:
	if chapters.is_empty():
		return 100
	var nb_visited := 0
	for chapter_id in chapters:
		# `chapters` vient du json (donc des float) ; `in` ne confond jamais un 26.0 avec un
		# 26 de `visited` (des int) — voir `test_chapter_ids.gd`. D'où le cast.
		if int(chapter_id) in visited:
			nb_visited += 1
	return int(100.0 * nb_visited / chapters.size())


#
#    Objets et succès
#

func get_all_objects():
	return all_objects


## À appeler avant `get_item_data()` quand le nom vient d'une source incertaine.
func exists_item_data(item_name) -> bool:
	return all_objects != null and all_objects.has(item_name)


## ⚠️ Plante si l'objet n'existe pas — c'est voulu : les appelants enchaînent sur
## `.get('stats', {})`, donc renvoyer `null` ne ferait que déplacer l'erreur. Tester avec
## `exists_item_data()` d'abord.
func get_item_data(item_name):
	return all_objects[item_name]


func get_all_success():
	return all_success


func get_success_txt(success_id) -> String:
	var success = _success_by_id(success_id)
	return success['txt'] if success else ''


## ⚠️ Les clés de `all_success_chapters` sont des **chaînes** (merci json), alors que les
## identifiants de chapitre circulent en int — parfois même en float.
func is_success_chapter(node_id) -> bool:
	return ('%d' % int(node_id)) in all_success_chapters


func get_success_from_chapter(node_id):
	return _success_by_id(all_success_chapters['%d' % int(node_id)])


func _success_by_id(success_id):
	for success in all_success:
		if success['id'] == success_id:
			return success
	return null


#
#    Compteurs
#

## Les compteurs PROPRES au livre courant, `[{cle, libelle}, ...]` dans l'ordre où la
## feuille de stats doit les afficher. Mesuré : fdcn compte `gloire` et `info`, cdsi
## `rancune` et `respect`, et aucun des deux ne connaît les compteurs de l'autre.
##
## `richesse` n'en fait **pas** partie : c'est le seul compteur commun aux deux livres
## (15 occurrences dans fdcn, 13 dans cdsi), il reste une variable en dur de `PlayerStats`
## avec sa ligne dans la scène des stats.
func get_counters() -> Array:
	return counters


## Vrai si cette clé de stat de chapitre est un compteur déclaré par le livre courant.
## C'est ce qui sépare `rancune` (déclaré par cdsi) d'une faute de frappe : la seconde
## finit dans l'avertissement de `PlayerStats.apply_chapter_stat()`.
func is_counter(cle) -> bool:
	for compteur in counters:
		if compteur.get("cle", "") == cle:
			return true
	return false


## Vrai si le livre courant déclare explicitement cette clé de stat de chapitre comme sans
## effet (todo 3.5). C'est ce qui distingue `arc_et_couteau` (un trou de saisie connu, dans
## le livre) d'une clé qui doit rester visible comme une anomalie.
func is_ignored(cle) -> bool:
	return cle in _ignorees


#
#    Effets et conditions d'un chapitre
#

## `{stats, stats_conds}` : les effets inconditionnels du chapitre, plus ceux dont la
## condition est remplie par l'inventaire du moment.
func get_chapter_stats(node_id) -> Dictionary:
	var chapter_data = get_chapter_node(node_id)
	var stats_conds := []
	for condition_pack in chapter_data.get_stats_cond():
		if _check_cond_rec(condition_pack['condition'], Inventory.get_all_matched_conditions()):
			stats_conds.append(condition_pack['stats'])
	return {"stats": chapter_data.get_stats(), "stats_conds": stats_conds}


## Vrai si le saut de `node_from_id` vers `node_to_id` est gardé par une condition —
## indépendamment du fait qu'elle soit remplie.
func have_chapter_conditions(node_from_id, node_to_id) -> bool:
	return _jump_condition(node_from_id, node_to_id) != null


func match_chapter_conditions(node_from_id, node_to_id) -> bool:
	var jump_condition = _jump_condition(node_from_id, node_to_id)
	if jump_condition == null:
		return false
	return _check_cond_rec(jump_condition, Inventory.get_all_matched_conditions())


## Le libellé de la condition (« ARC et COUTEAU »), ou "" si le saut est libre.
func get_condition_txt(node_from_id, node_to_id) -> String:
	var txts = get_chapter_node(node_from_id).get_jump_conditions_txts()
	return txts.get('%s' % node_to_id, '')


func _jump_condition(node_from_id, node_to_id):
	var conditions = get_chapter_node(node_from_id).get_jump_conditions()
	return conditions.get('%s' % node_to_id)


## Évalue un arbre de condition de saut contre les faits du joueur — `facts` étant
## `Inventory.get_all_matched_conditions()` : les noms d'objets portés plus le type de
## Billy en majuscules.
##
## Trois opérateurs, et trois seulement : `$end` (une feuille — ce fait est-il vrai ?),
## `$or`, `$and`.
##
## ⚠️ Le `return false` final n'est pas décoratif. Sans lui, la fonction retombait au bout
## et renvoyait `null` implicitement, ce qui se lit comme « condition non remplie » : une
## faute de frappe dans les données **fermait donc un chemin de l'aventure en silence**.
## D'où l'avertissement plutôt qu'un retour muet — les 620 conditions des deux livres
## n'emploient que ces trois opérateurs, donc une clé inconnue est forcément une anomalie
## à corriger, jamais un cas normal.
func _check_cond_rec(jump_condition, facts) -> bool:
	if not jump_condition is Dictionary:
		push_warning("BookData: condition de saut malformée, dictionnaire attendu: %s" % [jump_condition])
		return false

	var end = jump_condition.get('$end')
	if end != null:
		return end in facts

	var ors = jump_condition.get('$or')
	if ors != null:
		for sub_condition in ors:
			if _check_cond_rec(sub_condition, facts):
				return true
		return false

	var ands = jump_condition.get('$and')
	if ands != null:
		for sub_condition in ands:
			if not _check_cond_rec(sub_condition, facts):
				return false
		return true

	push_warning("BookData: condition sans opérateur connu ($end/$or/$and): %s" % [jump_condition])
	return false


#
#    Spoils
#

## Peut-on montrer ce chapitre dans la liste de TOUS les chapitres ?
##
## Le caractère secret n'entre pas en compte ici, contrairement à
## `is_node_id_freely_showable()` : cette liste montre le livre entier, chapitre par
## chapitre, et un secret jamais atteint y a sa ligne comme les autres. Seul compte le fait
## de l'avoir déjà vu — sinon la liste raconterait l'aventure d'avance.
func is_node_id_freely_full_on_all_chapters(node_id) -> bool:
	if AppParameters.are_spoils_ok():
		return true
	return Player.did_all_times_seen(node_id)


## Peut-on montrer ce chapitre comme CHOIX depuis le chapitre courant ?
##
## Trois cas où oui : le joueur accepte les spoils, le chapitre n'est ni secret ni atteint
## par un saut secret, ou bien il l'est mais on l'a déjà vu une fois.
func is_node_id_freely_showable(node_id, secret_jumps) -> bool:
	if AppParameters.are_spoils_ok():
		return true
	var node = get_chapter_node(node_id)
	if not node.get_secret() and not (node_id in secret_jumps):
		return true
	return Player.did_all_times_seen(node_id)
