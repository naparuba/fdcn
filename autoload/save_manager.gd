extends Node
## SaveManager — persistance JSON des sauvegardes dans `user://`.
##
## Chaque fichier de sauvegarde est lié à un livre, identifié par son **nom** — le même
## que celui du dossier `books/<nom>/`. Un fichier s'appelle donc
## `<clé>-<nom du livre>.json`.
##
## Cette classe ne connaît que la mécanique « poser une valeur sur le disque et
## la relire » : ce sont les propriétaires des données (Player, Inventory) qui
## décident de ce qu'ils stockent.
##
## VERSIONNAGE
## Une sauvegarde porte un numéro de version, dans son propre fichier.
## `prepare_save()` doit être appelé avant toute lecture : il crée une
## sauvegarde vide s'il n'y en a aucune, ou applique les migrations nécessaires
## si celle du disque est plus ancienne que la version courante.

## Racine des sauvegardes. Les tests la remplacent par un dossier jetable pour
## ne jamais toucher la vraie sauvegarde du joueur.
var base_dir := "user://"

## Clés de sauvegarde — un fichier par clé, par livre.
const KEY_VISITED_ALL_TIMES := "all_times_already_visited"
const KEY_CURRENT_NODE_ID := "current_node_id"
const KEY_SESSION_VISITED := "session_visited_nodes"
const KEY_POSSESSED_ITEMS := "possessed_item"
const KEY_SAVE_VERSION := "save_version"

## Les ressources consommables du Billy. Contrairement aux couches de stats, elles
## ne peuvent PAS être redérivées de l'historique des chapitres (une perte en
## combat ou un ajustement manuel ne se rejoue pas), elles vont donc sur le
## disque. Voir la section « Ressources » de `player_stats.gd`.
const KEY_PV := "pv"
const KEY_CHANCE := "chance"

## Les clés qui contiennent réellement de la progression. Sert à savoir si une
## sauvegarde existe (le fichier de version seul ne compte pas).
const _GAMEPLAY_KEYS := [
	KEY_VISITED_ALL_TIMES,
	KEY_CURRENT_NODE_ID,
	KEY_SESSION_VISITED,
	KEY_POSSESSED_ITEMS,
	KEY_PV,
	KEY_CHANCE,
]

## Les clés qui existaient au format v1 (fichiers suffixés par le NUMÉRO du
## livre). Seules celles-là concernent la migration v1 -> v2 : chercher un
## `pv-1.json` n'aurait aucun sens, ce format n'a jamais existé.
const _V1_KEYS := [
	KEY_VISITED_ALL_TIMES,
	KEY_CURRENT_NODE_ID,
	KEY_SESSION_VISITED,
	KEY_POSSESSED_ITEMS,
]

## Les migrations, dans l'ordre : l'entrée i fait passer de la version (i+1) à
## la version (i+2). `_MIGRATIONS[0]` migre donc une v1 vers une v2.
##
## La version courante en est déduite (`CURRENT_SAVE_VERSION`), il est donc
## impossible d'ajouter une migration en oubliant d'incrémenter la version, ou
## l'inverse.
var _migrations: Array[Callable] = []

## Version du format produite par cette version du code.
var CURRENT_SAVE_VERSION: int:
	get:
		return _migrations.size() + 1


func _init() -> void:
	_migrations = [
		_migrate_1_to_2,
	]


#
#    Chemins et accès bruts
#

func get_save_path(key: String) -> String:
	return _path_for(key, AppParameters.get_book_name())


## Le nom d'un fichier de sauvegarde. Le suffixe est le nom du livre aujourd'hui, son
## numéro dans les sauvegardes v1 — c'est tout ce qui distingue les deux formats.
func _path_for(key: String, suffixe) -> String:
	return "%s%s-%s.json" % [base_dir, key, suffixe]


func has_save(key: String) -> bool:
	return FileAccess.file_exists(get_save_path(key))


## Valeur lue pour `key`, ou `default` si le fichier est absent ou corrompu.
func load_value(key: String, default = null):
	var pth = get_save_path(key)
	if not FileAccess.file_exists(pth):
		return default
	var data = _load_json_safe(pth)
	if data == null:
		return default
	return data


## Raccourci pour les sauvegardes « liste d'identifiants de chapitres » :
## le JSON nous les rend en float.
func load_int_array(key: String) -> Array:
	var data = load_value(key, [])
	if not data is Array:
		return []
	return (data as Array).map(func(x): return int(x))


func save_value(key: String, value) -> void:
	var pth = get_save_path(key)
	var f = FileAccess.open(pth, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: impossible d'écrire %s" % pth)
		return
	f.store_string(JSON.stringify(value))


## Lit un fichier json. Un fichier vide ou illisible est supprimé (il échouerait
## de la même façon à chaque démarrage suivant) et null est renvoyé.
func _load_json_safe(pth: String):
	var f = FileAccess.open(pth, FileAccess.READ)
	if f == null:
		return null
	var text = f.get_as_text().strip_edges()
	if text.is_empty():
		_delete(pth)
		return null
	var data = JSON.parse_string(text)
	if data == null:
		print('SAVE: fichier invalide, suppression: %s' % pth)
		_delete(pth)
	return data


## Efface la sauvegarde d'une clé. Sert à revenir à l'état « jamais enregistré »,
## qui n'est pas la même chose qu'une valeur à zéro : c'est l'absence de fichier
## qui fait dire à `PlayerStats.load_resources()` « démarre au plein ».
func delete_save(key: String) -> void:
	_delete(get_save_path(key))


func _delete(pth: String) -> void:
	var dir = DirAccess.open(base_dir)
	if dir != null:
		dir.remove(pth)


#
#    Versionnage et migrations
#

## Version de la sauvegarde présente sur le disque pour le livre courant.
## Pas de fichier de version = sauvegarde écrite avant l'existence du
## versionnage = version 1.
func get_save_version() -> int:
	return int(load_value(KEY_SAVE_VERSION, 1))


## Vrai s'il existe au moins un fichier de progression au format actuel.
func has_any_save() -> bool:
	for key in _GAMEPLAY_KEYS:
		if has_save(key):
			return true
	return false


## À appeler avant de lire la sauvegarde (au chargement, et à chaque changement
## de livre) :
##  - aucune sauvegarde, même ancienne -> on en crée une vide, déjà à jour ;
##  - sauvegarde ancienne              -> on applique les migrations une par une ;
##  - sauvegarde à jour                -> on ne touche à rien.
func prepare_save() -> void:
	var version = get_save_version()

	# Le test d'existence doit accepter les anciens formats, sinon une vieille
	# sauvegarde passerait pour inexistante et serait écrasée par une neuve.
	if not has_any_save() and not _has_any_legacy_save():
		print('SAVE: aucune sauvegarde pour ce livre, création d\'une nouvelle')
		_create_empty_save()
		return

	if version == CURRENT_SAVE_VERSION:
		return

	if version > CURRENT_SAVE_VERSION:
		# Sauvegarde écrite par une version plus récente de l'app : on ne sait
		# pas la relire correctement, on la laisse telle quelle plutôt que de
		# risquer de l'abîmer.
		push_warning("SaveManager: sauvegarde en version %s, plus récente que %s" % [version, CURRENT_SAVE_VERSION])
		return

	print('SAVE: migration de la sauvegarde v%s vers v%s' % [version, CURRENT_SAVE_VERSION])
	while version < CURRENT_SAVE_VERSION:
		version = _migrate(version)
	save_value(KEY_SAVE_VERSION, CURRENT_SAVE_VERSION)
	print('SAVE: migration terminée (v%s)' % CURRENT_SAVE_VERSION)


## Nouvelle sauvegarde vierge : le joueur démarre au chapitre 1, sans objet et
## sans historique.
##
## `KEY_PV` / `KEY_CHANCE` sont volontairement absents : leur valeur de plein
## dépend de plafonds que seul `PlayerStats.recompute()` connaît, et qui n'est pas
## encore passé ici. L'absence du fichier veut dire « jamais enregistré » et
## `PlayerStats.load_resources()` la traduit en « au maximum ».
func _create_empty_save() -> void:
	save_value(KEY_VISITED_ALL_TIMES, [1])
	save_value(KEY_CURRENT_NODE_ID, 1)
	save_value(KEY_SESSION_VISITED, [])
	save_value(KEY_POSSESSED_ITEMS, [])
	save_value(KEY_SAVE_VERSION, CURRENT_SAVE_VERSION)


## Applique UNE étape de migration et renvoie la version atteinte.
func _migrate(from_version: int) -> int:
	var index = from_version - 1
	if index < 0 or index >= _migrations.size():
		# Palier inconnu : on avance quand même pour ne pas boucler à l'infini,
		# mais on le signale.
		push_warning("SaveManager: pas de migration connue depuis la v%s" % from_version)
		return from_version + 1
	_migrations[index].call()
	return from_version + 1


#
#    Migrations (une fonction par palier, référencée dans `_migrations`)
#

## Les toutes premières sauvegardes suffixaient les fichiers par le NUMÉRO du livre. Ce
## numéro était le **rang du livre dans le registre** (1 = le premier déclaré), c'est donc
## `books/books.json` qui le traduit — même règle que
## `AppParameters._resoudre_livre_courant()`, et raison pour laquelle un nouveau livre
## s'ajoute à la FIN du registre.
##
## Cette conversion ne sert plus QU'À la migration v1 -> v2 ci-dessous : partout ailleurs,
## un livre est identifié par son nom.
func _legacy_book_numbers() -> Dictionary:
	var table := {}
	var livres = BookData.get_books()
	for rang in livres.size():
		table[rang + 1] = livres[rang].get("nom", "")
	return table


## Vrai s'il reste des fichiers à l'ancien format (suffixés par un numéro).
func _has_any_legacy_save() -> bool:
	for book_number in _legacy_book_numbers():
		for key in _V1_KEYS:
			if FileAccess.file_exists(_path_for(key, book_number)):
				return true
	return false


## v1 -> v2 : les fichiers étaient suffixés par le numéro du livre
## (`possessed_item-1.json`) ; ils le sont maintenant par son nom
## (`possessed_item-fdcn.json`), comme le dossier `books/<nom>/`.
##
## On renomme les fichiers des deux livres d'un coup : c'est peu coûteux et ça
## évite de laisser la sauvegarde de l'autre livre à moitié convertie.
## L'opération est idempotente (relancée, elle ne trouve plus rien à renommer).
func _migrate_1_to_2() -> void:
	var dir = DirAccess.open(base_dir)
	if dir == null:
		push_error("SaveManager: dossier de sauvegarde introuvable: %s" % base_dir)
		return

	var legacy_book_numbers = _legacy_book_numbers()
	for book_number in legacy_book_numbers:
		var book_name = legacy_book_numbers[book_number]
		for key in _V1_KEYS:
			var old_path = _path_for(key, book_number)
			if not FileAccess.file_exists(old_path):
				continue
			var new_path = _path_for(key, book_name)
			if FileAccess.file_exists(new_path):
				# Un fichier au nouveau nom existe déjà : il fait foi, on se
				# contente de supprimer le doublon hérité.
				dir.remove(old_path)
				continue
			print('SAVE: %s -> %s' % [old_path, new_path])
			dir.rename(old_path, new_path)

		# Le fichier de version numéroté ne sert plus à rien : la version est
		# désormais écrite sous le nom du livre.
		var old_version = _path_for(KEY_SAVE_VERSION, book_number)
		if FileAccess.file_exists(old_version):
			dir.remove(old_version)
