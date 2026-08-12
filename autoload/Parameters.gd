extends Node

var parameters_file  = "user://parameters.json"
var parameters = {
	'billy': 'guerrier',
	'spoils': true,
	'sound': true,
	'current_book': 'fdcn',  # which book did the user select (matches books/{name}/)
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
	print('Parameters: ready')
	self._load_parameters()
	self._apply_sound()
	self._apply_book()
	# Les autoloads étant prêts avant la scène principale, personne n'écoute
	# encore : cette émission ne sert qu'à repeindre une interface qui aurait
	# déjà affiché les valeurs par défaut avant la lecture du fichier.
	settings_changed.emit()


func _load_parameters():
	if FileAccess.file_exists(parameters_file):
		var f = FileAccess.open(parameters_file, FileAccess.READ)
		var loaded_parameters = JSON.parse_string(f.get_as_text())
		if not loaded_parameters is Dictionary:
			print('PARAM: fichier de sauvegarde invalide, réinitialisation')
			return
		# NOTE: so we can manage code with new parameters
		for k in loaded_parameters.keys():
			var v = loaded_parameters[k]
			print('PARAM: %s=>' % k, v)
			parameters[k] = v
		# Si on a dû convertir un ancien format, on réécrit le fichier tout de
		# suite : sinon la conversion serait refaite à chaque lancement.
		if self._migrate_legacy_book_number():
			self._save_parameters()
	else:
		# already created in globals
		pass


# Les anciennes sauvegardes stockaient current_book sous forme de nombre (1/2).
# On le convertit vers le nom de livre utilisé par le rangement books/<nom>/.
# Renvoie true si une conversion a eu lieu (donc s'il faut réécrire le fichier).
func _migrate_legacy_book_number() -> bool:
	var current = self.parameters['current_book']
	if typeof(current) == TYPE_STRING:
		return false
	var legacy_names = {1: 'fdcn', 2: 'cdsi'}
	self.parameters['current_book'] = legacy_names.get(int(current), 'fdcn')
	print('PARAM: conversion current_book %s => %s' % [current, self.parameters['current_book']])
	return true


func _save_parameters():
	var f = FileAccess.open(parameters_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(parameters))
	settings_changed.emit()


# Applique les paramètres aux autres systèmes. Séparé par domaine : recharger
# tout le livre parce que le joueur a coupé le son serait absurde.
func _apply_sound():
	Sounder.set_enabled(self.parameters['sound'])


func _apply_book():
	print('PARAMETERS: chargement du livre %s' % self.parameters['current_book'])
	BookData.do_load_book(self.parameters['current_book'])


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
	if self.parameters[cle] == valeur:
		return false
	print('PARAMETERS: %s => %s' % [cle, valeur])
	self.parameters[cle] = valeur
	self._save_parameters()
	return true


func are_spoils_ok():
	return self.parameters['spoils']


func set_spoils(b) -> bool:
	return _ecrire_parametre('spoils', b)


func is_sound_ok():
	return self.parameters['sound']


func set_sound(b) -> bool:
	if not _ecrire_parametre('sound', b):
		return false
	self._apply_sound()
	return true


func get_billy_type():
	return self.parameters['billy']


func set_billy_type(billy_type) -> bool:
	return _ecrire_parametre('billy', billy_type)


func set_book_name(book_name) -> bool:
	if not _ecrire_parametre('current_book', book_name):
		return false
	# L'ordre compte : BookData doit contenir le nouveau livre avant que Player
	# ne recharge la sauvegarde correspondante.
	self._apply_book()
	book_changed.emit(book_name)
	return true


func get_book_name():
	return self.parameters['current_book']
