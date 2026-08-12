extends Node

var chapter_data_cls = preload('res://entities/chapter_data.gd')

var _current_book_name = 'fdcn'  # Which book is currently selected (matches books/{name}/)
var all_nodes = {}
var chapters_by_arc = {}
var chapters_by_sub_arc = {}

var secret_node_ids = []

## Les compteurs PROPRES au livre courant, dans l'ordre d'affichage :
## `[{cle, libelle}, ...]`. Mesuré : fdcn compte `gloire` et `info`, cdsi `rancune` et
## `respect`, et aucun des deux ne connaît les compteurs de l'autre. Les coder en dur
## affichait donc une ligne « Gloire: 0 » pour toujours sur cdsi, et y rendait deux
## compteurs sur trois invisibles.
##
## `richesse` n'est **pas** là-dedans : c'est le seul compteur commun aux deux livres
## (15 occurrences dans fdcn, 13 dans cdsi), il reste une variable en dur de
## `PlayerStats` avec sa ligne dans la scène des stats.
var counters = []
var _counter_keys = []

var all_success = []
var all_success_chapters = {} # chapter id -> success id
var all_endings = []
var good_endings = []
var end_endings = []
var all_objects = {}


func _init():
	print('BookData: init')


func do_load_book(book_name):
	self._current_book_name = book_name
	print('BookData: switch to book:'+self._current_book_name)
	var book_path = "res://books/"+book_name+"/"+book_name
	# Load chapter data in chapter_data class
	var all_nodes_json = Utils.load_json_file(book_path+"-compilated-data.json")
	if all_nodes_json == null:
		push_error("BookData: impossible de charger %s-compilated-data.json" % book_path)
		return
	# On repart d'un dictionnaire vide : sinon, en changeant de livre, les
	# chapitres de l'ancien livre dont l'identifiant n'existe pas dans le nouveau
	# resteraient accessibles (et get_chapter_node renverrait les données du
	# mauvais livre).
	#
	# Cette ligne **libère** aussi les instances de l'ancien livre, depuis que
	# `chapter_data.gd` est un `RefCounted` : c'était un `Node`, jamais ajouté à l'arbre,
	# donc jamais libéré — ~600 objets fuités par changement de livre.
	self.all_nodes = {}
	for node_id_str in all_nodes_json.keys():
		var chapter_data = chapter_data_cls.new()
		chapter_data.create(all_nodes_json[node_id_str])
		self.all_nodes[node_id_str] = chapter_data

	# Just the list of int of the secret chapters
	self.secret_node_ids = Utils.load_json_file(book_path+"-compilated-secrets.json")

	# Just a dict arc -> [ chapters ]
	self.chapters_by_arc = Utils.load_json_file(book_path+"-compilated-nodes-by-chapter.json")

	# Just a dict sub_arc -> [ chapters ]
	self.chapters_by_sub_arc = Utils.load_json_file(book_path+"-compilated-nodes-by-sub-arc.json")

	# All the success, in a list {id, chapter, txt}
	self.all_success = Utils.load_json_file(book_path+"-compilated-success.json")
	# All the success chapters id in a list
	self.all_success_chapters = Utils.load_json_file(book_path+"-compilated-success-chapters.json")

	# Endings: want all, good and bad
	self.all_endings = Utils.load_json_file(book_path+"-compilated-endings.json")
	self.good_endings = Utils.load_json_file(book_path+"-compilated-good-endings.json")
	self.end_endings = Utils.load_json_file(book_path+"-compilated-bad-endings.json")

	# Objects, so we can insert them in the options
	self.all_objects = Utils.load_json_file(book_path+"-compilated-all-objects.json")

	# Vocabulaire du livre : écrit à la main, pas compilé — le compilateur n'a rien à
	# en dire, il recopie les clés de stats telles quelles.
	self._load_vocabulaire(book_path)


## Lit `books/<nom>/<nom>.vocabulaire.json` et en tire la liste des compteurs.
##
## Un livre sans fichier de vocabulaire n'a **pas** de compteur propre : c'est un
## avertissement, pas une erreur — le reste du livre s'affiche normalement, seule la
## feuille de stats est plus courte. Une entrée sans `cle` ou sans `libelle` est ignorée
## avec son avertissement plutôt que de faire planter la feuille de stats plus tard.
func _load_vocabulaire(book_path: String) -> void:
	self.counters = []
	self._counter_keys = []

	var vocabulaire = Utils.load_json_file(book_path+".vocabulaire.json")
	if not vocabulaire is Dictionary:
		push_warning("BookData: pas de vocabulaire pour %s, aucun compteur propre au livre" % book_path)
		return

	for compteur in vocabulaire.get("compteurs", []):
		var cle = compteur.get("cle", "") if compteur is Dictionary else ""
		var libelle = compteur.get("libelle", "") if compteur is Dictionary else ""
		if cle == "" or libelle == "":
			push_warning("BookData: compteur incomplet dans le vocabulaire: %s" % [compteur])
			continue
		self.counters.append({"cle": cle, "libelle": libelle})
		self._counter_keys.append(cle)


# Called when the node enters the scene tree for the first time.
func get_all_nodes():
	return self.all_nodes


func get_all_objects():
	return self.all_objects


## `[{cle, libelle}, ...]` dans l'ordre où la feuille de stats doit les afficher.
func get_counters() -> Array:
	return self.counters


## Vrai si cette clé de stat de chapitre est un compteur déclaré par le livre courant.
## C'est ce qui distingue `rancune` (compteur de cdsi) de `critique` (faute de frappe) :
## le premier est déclaré, le second finit dans l'avertissement de `apply_chapter_stat()`.
func is_counter(cle) -> bool:
	return cle in self._counter_keys


## À appeler avant `get_item_data()` quand le nom vient d'une source incertaine.
func exists_item_data(item_name) -> bool:
	return self.all_objects != null and self.all_objects.has(item_name)


## ⚠️ Plante si l'objet n'existe pas — c'est voulu : les appelants enchaînent sur
## `.get('stats', {})`, donc renvoyer `null` ne ferait que déplacer l'erreur. Tester avec
## `exists_item_data()` d'abord.
func get_item_data(item_name):
	return self.all_objects[item_name]

func get_all_success():
	return self.all_success

func get_chapter_node(node_id):
	return self.all_nodes['%s' % int(node_id)]
	

func get_all_nodes_in_the_same_chapter(node_id):
	var chapter_data = self.get_chapter_node(node_id)
	var chapter = chapter_data.get_chapter()
	if chapter == null:
		return []
	var other_nodes = self.chapters_by_arc[chapter]
	return other_nodes


func get_acte_completion(node_id, visited_nodes_all_times):
	var other_nodes = self.get_all_nodes_in_the_same_chapter(node_id)
	if other_nodes == []:  # void chatper, let's say 100%
		return 100
	var nb_visited = 0
	for other_id in other_nodes:
		if other_id in visited_nodes_all_times:
			nb_visited += 1
	var pct100 = int(100 * float(nb_visited) / len(other_nodes))
	return pct100



func get_all_nodes_in_the_same_sub_arc(node_id):
	var chapter_data = self.get_chapter_node(node_id)
	var sub_arc = chapter_data.get_arc()
	if sub_arc == null:
		return []
	var other_nodes = self.chapters_by_sub_arc[sub_arc]
	return other_nodes


func get_sub_arc_completion(node_id, visited_nodes_all_times):
	var other_nodes = self.get_all_nodes_in_the_same_sub_arc(node_id)
	if other_nodes == []:  # void chatper, let's say 100%
		return 100
	var nb_visited = 0
	for other_id in other_nodes:
		if other_id in visited_nodes_all_times:
			nb_visited += 1
	var pct100 = int(100 * float(nb_visited) / len(other_nodes))
	return pct100


func is_node_id_secret(node_id):
	# int() obligatoire : les identifiants venant du JSON sont des float.
	return int(node_id) in self.secret_node_ids


func get_success_txt(success_id):
	for success in self.all_success:
		if success_id == success['id']:
			return success['txt']
	return ''


func is_success_chapter(node_id):
	# WARNING: the all_success_chapters is with str keys, not INT (thanks json)
	var node_id_str = '%d' % node_id
	return node_id_str in self.all_success_chapters


func get_success_from_chapter(node_id):
	# WARNING: the all_success_chapters is with str keys, not INT (thanks json)
	var node_id_str = '%d' % node_id
	var success_id = self.all_success_chapters[node_id_str]

	for success in self.get_all_success():
		if success['id'] == success_id:
			return success
	return null


func get_chapter_stats(node_id):
	var chapter_data = self.get_chapter_node(node_id)
	var stats = chapter_data.get_stats()
	var stats_cond_raw = chapter_data.get_stats_cond()
	var stats_conds = []
	for condition_pack in stats_cond_raw:
		var condition = condition_pack['condition']
		var b = self._check_cond_rec(condition, Inventory.get_all_matched_conditions())
		print('IS CONDITION MATCH: %s' % str(condition), "=> %s" % b)
		if b:
			var stats_cond = condition_pack['stats']
			stats_conds.append(stats_cond)
			print('IS OK: %s' % str(stats_cond))
		
	var r = {"stats":stats, "stats_conds":stats_conds}
	print('GIVE BACK %s' % str(r))
	return r


func have_chapter_conditions(node_from_id, node_to_id):
	var chapter_data = self.get_chapter_node(node_from_id)
	var node_to_id_str = '%s' % node_to_id
	var all_jump_conditions = chapter_data.get_jump_conditions()
	var jump_condition = all_jump_conditions.get(node_to_id_str)
	if jump_condition == null:
		return false
	return true
	

func match_chapter_conditions(node_from_id, node_to_id):
	var chapter_data = self.get_chapter_node(node_from_id)
	var node_to_id_str = '%s' % node_to_id
	var all_jump_conditions = chapter_data.get_jump_conditions()
	var jump_condition = all_jump_conditions.get(node_to_id_str)
	if jump_condition == null:
		return false
	var r = self._check_cond_rec(jump_condition, Inventory.get_all_matched_conditions())
	return r


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
			if self._check_cond_rec(sub_condition, facts):
				return true
		return false

	var ands = jump_condition.get('$and')
	if ands != null:
		for sub_condition in ands:
			if not self._check_cond_rec(sub_condition, facts):
				return false
		return true

	push_warning("BookData: condition sans opérateur connu ($end/$or/$and): %s" % [jump_condition])
	return false


func get_condition_txt(node_from_id, node_to_id):
	var chapter_data = self.get_chapter_node(node_from_id)
	var node_to_id_str = '%s' % node_to_id
	var all_txts = chapter_data.get_jump_conditions_txts()
	var txt = all_txts.get(node_to_id_str)
	if txt == null:
		return ''
	return txt
	

# on the all chapters, the "is not a secret" is not a criteria, as we don't want to see this
# and also secret jumps is not useful here (not link to a specific src jump node)
func is_node_id_freely_full_on_all_chapters(node_id):
	if AppParameters.are_spoils_ok():
			return true
	# spoils are not known
	var node = self.get_chapter_node(node_id)
	# node is a secret, last hope is if we already see it in the past (not a spoil if already see ^^)
	if Player.did_all_times_seen(node_id):
		return true
	# ok, no hope for this one, hide it
	#print('SPOILS: %s is a secret and CANNOT see it' % node_id)
	return false


# We can show a Choice if:
# * we are ok with spoils
# * we are NOT spoils but the node is NOT a secret, and not a secret jump
# * we are NOT spoils, the node IS a secret but we ALREADY see it
func is_node_id_freely_showable(node_id, secret_jumps):
	if AppParameters.are_spoils_ok():
		return true
	
	# spoils are not known
	var node = BookData.get_chapter_node(node_id)
	
	var is_in_secret_jump = node_id in secret_jumps
	
	# NOT a secret node, we can show without problem, but only
	# if it's not a secret jump
	if !node.get_secret() and !is_in_secret_jump:
		return true
		
	# node is a secret (or in secret jumps), last hope is if we already see it in the past (not a spoil if already see ^^)
	if Player.did_all_times_seen(node_id):
		print('SPOILS: %s is a secret (or a secret jump) but already see it' % node_id)
		return true
	# ok, no hope for this one, hide it
	#print('SPOILS: %s is a secret and CANNOT see it' % node_id)
	return false
