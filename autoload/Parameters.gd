extends Node
## AppParameters — les réglages du joueur, et le livre qu'il a ouvert.
##
## Quatre valeurs, un fichier json dans `user://`, et deux signaux pour que l'interface se
## repeigne. Le livre courant est ici plutôt que dans `BookData` parce que c'est un CHOIX
## du joueur, au même titre que le son : `BookData` détient les données, pas la préférence.

var parameters_file := "user://parameters.json"
var parameters = {
	'billy': 'guerrier',
	'spoils': true,
	'sound': true,
	# Résolu au démarrage depuis le registre (`books/books.json`) : on ne peut pas nommer
	# un livre en dur ici, ce serait le seul endroit du code à en connaître un.
	'current_book': '',
}

## Unique signal « les réglages valent maintenant ceci, repeins-toi ». Il couvre
## aussi bien le chargement initial que chaque modification ultérieure : un
## abonné se branche sans condition et fait sa première peinture lui-même (voir
## `ui/top_menu.gd`, `screens/chapitres_menu.gd`). Signal gros-grain : il part
## pour n'importe quel réglage, spoils comme type de Billy.
signal settings_changed

## Émis quand le joueur change de livre. Les sauvegardes étant rangées par
## livre, Player s'y abonne pour recharger la sienne.
signal book_changed(book_name)

func _ready():
	_load_parameters()
	_apply_sound()
	_apply_book()
	# Les autoloads étant prêts avant la scène principale, personne n'écoute
	# encore : cette émission ne sert qu'à repeindre une interface qui aurait
	# déjà affiché les valeurs par défaut avant la lecture du fichier.
	settings_changed.emit()


## Sans fichier, les valeurs par défaut ci-dessus font foi : une première partie n'est pas
## un cas d'erreur.
func _load_parameters():
	if FileAccess.file_exists(parameters_file):
		var f = FileAccess.open(parameters_file, FileAccess.READ)
		var loaded_parameters = JSON.parse_string(f.get_as_text())
		# ⚠️ Un fichier illisible ne doit PAS court-circuiter la suite : sans le
		# `_resoudre_livre_courant()` d'en bas, `current_book` resterait vide et l'app
		# démarrerait sans aucun livre.
		if loaded_parameters is Dictionary:
			# Clé par clé et non un remplacement en bloc : un fichier écrit par une version
			# plus ancienne ne connaît pas les réglages ajoutés depuis, qui gardent alors
			# leur valeur par défaut au lieu de disparaître.
			for k in loaded_parameters:
				parameters[k] = loaded_parameters[k]
		else:
			print('PARAM: fichier de réglages illisible, valeurs par défaut')

	# Après la lecture du fichier, pas avant : c'est la valeur relue qu'il faut valider.
	# Si on a dû la corriger, on réécrit tout de suite, sinon la correction serait
	# refaite à chaque lancement.
	if _resoudre_livre_courant():
		_save_parameters()


## Garantit que `current_book` nomme un livre du registre. Trois cas à rattraper :
##
##   - **un nombre** : les sauvegardes d'avant 2026 rangeaient le livre sous forme de
##     numéro (1, 2). On le convertit par son **rang dans le registre** — d'où la règle
##     « un nouveau livre s'ajoute à la fin de `books/books.json` » ;
##   - **vide** : première partie, personne n'a encore choisi ;
##   - **un nom inconnu** : le livre a été retiré du dépôt depuis la dernière partie.
##
## Renvoie true si la valeur a changé (donc s'il faut réécrire le fichier).
func _resoudre_livre_courant() -> bool:
	var courant = parameters['current_book']

	if typeof(courant) != TYPE_STRING:
		var rang = int(courant) - 1
		var livres = BookData.get_books()
		var nom = livres[rang].get('nom', '') if rang >= 0 and rang < livres.size() else ''
		parameters['current_book'] = nom if nom != '' else BookData.get_default_book_name()
		print('PARAM: conversion current_book %s => %s' % [courant, parameters['current_book']])
		return true

	if BookData.book_exists(courant):
		return false

	parameters['current_book'] = BookData.get_default_book_name()
	if courant != '':
		push_warning("AppParameters: livre inconnu '%s', repli sur '%s'" % [courant, parameters['current_book']])
	return true


func _save_parameters():
	var f = FileAccess.open(parameters_file, FileAccess.WRITE)
	if f == null:
		push_error("AppParameters: impossible d'écrire %s" % parameters_file)
		return
	f.store_string(JSON.stringify(parameters))
	settings_changed.emit()


# Applique les paramètres aux autres systèmes. Séparé par domaine : recharger
# tout le livre parce que le joueur a coupé le son serait absurde.
func _apply_sound():
	Sounder.set_enabled(parameters['sound'])


func _apply_book():
	BookData.do_load_book(parameters['current_book'])


## Écrit un paramètre, le persiste, et renvoie **s'il a changé**.
##
## Les quatre setters recopiaient ces cinq lignes. Ils renvoient tous un booléen maintenant :
## avant, `set_book_name` renvoyait `false` en cas de non-changement et les trois autres ne
## renvoyaient rien, ce qui rendait leur contrat illisible.
##
## ⚠️ **Sortir tôt quand la valeur est identique n'est pas une micro-optimisation.** Chaque
## écriture appelle `_save_parameters()`, qui **émet `settings_changed`**. Sans ce garde-fou,
## une interface qui repeint sur ce signal — donc qui réécrit la valeur qu'elle affiche déjà —
## relancerait le cycle.
##
## ⚠️ Ne PAS appeler ce helper `_set` : `Object._set()` est une méthode virtuelle de Godot,
## la surcharger casserait toute affectation de propriété sur cet autoload.
func _ecrire_parametre(cle: String, valeur) -> bool:
	if parameters[cle] == valeur:
		return false
	parameters[cle] = valeur
	_save_parameters()
	return true


func are_spoils_ok():
	return parameters['spoils']


func set_spoils(b) -> bool:
	return _ecrire_parametre('spoils', b)


func is_sound_ok():
	return parameters['sound']


func set_sound(b) -> bool:
	if not _ecrire_parametre('sound', b):
		return false
	_apply_sound()
	return true


func get_billy_type():
	return parameters['billy']


func set_billy_type(billy_type) -> bool:
	return _ecrire_parametre('billy', billy_type)


func set_book_name(book_name) -> bool:
	if not _ecrire_parametre('current_book', book_name):
		return false
	# L'ordre compte : BookData doit contenir le nouveau livre avant que Player
	# ne recharge la sauvegarde correspondante.
	_apply_book()
	book_changed.emit(book_name)
	return true


func get_book_name():
	return parameters['current_book']
