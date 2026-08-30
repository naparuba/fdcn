extends RefCounted
## Lecture seule sur un chapitre compilé : une enveloppe d'accesseurs autour du dictionnaire
## que `BookData` sort du json.
##
## **`RefCounted` et non `Node`.** Ces instances ne sont **jamais ajoutées à l'arbre** —
## `BookData` en crée une par chapitre avec `.new()` et les garde dans un dictionnaire. Or un
## `Node` n'est pas compté par référence : vider le dictionnaire n'en libérait aucun, donc
## chaque changement de livre **fuyait ~600 objets**. En `RefCounted`, ils partent tout seuls
## quand `BookData.all_nodes` est réinitialisé.
##
## Aucune méthode de `Node` n'était utilisée : les 27 fonctions ci-dessous sont toutes des
## accesseurs de données, et aucun appelant ne traite le résultat comme un nœud.

## Une entrée de la clé `chapters` de `<nom>-compilated.json` ne porte **que ce qui n'est
## pas neutre** :
##
##     {"id": 212, "chapter": "Forteresse", "arc": "Catacombes", "sons": [25],
##      "remove": ["MEDAILLON D'EDIRE"]}
##
## ⚠️ **C'est pourquoi tous les accesseurs ci-dessous passent par `.get(clé, défaut)`.** Le
## défaut écrit ici doit être le même que la valeur neutre de `Node.NEUTRES`, côté
## générateur : les deux listes sont les deux moitiés d'un seul contrat. Une clé absente
## veut dire « rien à signaler », jamais « donnée manquante » — c'est 61 % du fichier qui
## ne s'écrit plus.
var _book_data = {}

## Accepte les deux formes de l'entrée compilée, et c'est volontaire :
##
##   `{"computed": {…}}`  ce que le compilateur écrit encore aujourd'hui, la source du
##                        chapitre étant recopiée à côté ;
##   `{…}`                les données allégées, où la source ne figure plus qu'une fois —
##                        dans `<nom>.json`, à côté.
##
## Sans cette ligne, alléger les données et reprendre le compilateur devraient se faire
## dans le même mouvement, sous peine d'une app qui ne lit plus rien entre les deux.
func create(book_data):
	_book_data = book_data.get("computed", book_data)


func get_id():
	return _book_data['id']


func get_chapter():
	return _book_data.get('chapter', null)

func get_arc():
	return _book_data.get('arc', null)

func get_jump_conditions():
	return _book_data.get('jump_conditions', {})

func get_jump_conditions_txts():
	return _book_data.get('jump_conditions_txts', {})

func get_stats():
	return _book_data.get('stats', {})

func get_stats_cond():
	return _book_data.get('stats_cond', [])

## Dérivé, comme côté générateur : une fin est un chapitre qui déclare son type.
func get_ending():
	return _book_data.get('ending_type', null) != null

func get_ending_id():
	return _book_data.get('ending_id', null)

func get_ending_txt():
	return _book_data.get('ending_txt', null)

func get_ending_type():
	return _book_data.get('ending_type', null)

func get_success():
	return _book_data.get('success', null)

func get_label():
	return _book_data.get('label', null)


func get_secret():
	return _book_data.get('secret', false)

## `sons` liste des identifiants de chapitre (des int, malgré le json qui les rend en
## float) : `choice_next_chapiter.gd` les compare aux chapitres visités, où `26.0 in [26]`
## vaut faux (voir `test_chapter_ids.gd`).
func get_sons() -> Array:
	return _book_data.get('sons', []).map(func(id): return int(id))

func get_secret_jumps() -> Array:
	return _book_data.get('secret_jumps', []).map(func(id): return int(id))

## Dérivé : un chapitre de combat est un chapitre qui porte un adversaire.
func is_combat():
	return _book_data.get('combat', null) != null


## TOUS les adversaires du chapitre, dans l'ordre où ils se présentent.
##
## Le livre écrit un dictionnaire pour un adversaire, un tableau pour plusieurs — et
## **l'ordre du tableau est l'ordre du combat**. Un seul chapitre s'en sert, fdcn ch274
## (GUARDES CORROMPUS puis TROLESSE). On normalise les deux formes pour que l'appelant
## n'ait jamais à les distinguer.
func get_combats() -> Array:
	var combat = _book_data.get('combat', null)
	if combat == null:
		return []
	if typeof(combat) == TYPE_ARRAY:
		return combat
	return [combat]


## Le premier adversaire. Les accesseurs unitaires ci-dessous s'en servent : ils
## alimentent la fiche affichée, qui montre l'ennemi en cours. Pour mener un combat en
## plusieurs manches, passer par `get_combats()`.
func _get_combat():
	var combats = get_combats()
	return combats[0] if not combats.is_empty() else null


func get_combat_name():
	return _get_combat()['nom']
	
func get_combat_hab():
	return _get_combat()['hab']

func get_combat_pv():
	return _get_combat()['pv']

func get_combat_pyro():
	return _get_combat()['pyro']

func get_combat_armure():
	return _get_combat()['arm']

func get_combat_degat():
	return _get_combat()['deg']

func get_aquire():
	return _book_data.get('aquire', [])
	
func get_remove():
	return _book_data.get('remove', [])
