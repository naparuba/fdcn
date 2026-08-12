extends RefCounted
## Lanceur de tests : découvre et exécute tous les `test/unit/test_*.gd`.
##
## On ne passe pas par GUT : la version embarquée (7.2.0) était un addon Godot 3,
## incompatible avec Godot 4.7. Elle a été supprimée.
##
## Deux points d'entrée, tous deux appuyés sur cette classe :
##   - `test/all.gd`   -> ligne de commande, code de sortie 0/1
##   - `test/all.tscn` -> depuis l'éditeur (F6), résultats dans la console
##
## SÉCURITÉ : avant d'exécuter le moindre test, on redirige les sauvegardes ET
## le fichier de paramètres vers un dossier jetable, puis on remet tout en place
## à la fin. Aucun test ne peut donc écrire dans la vraie partie du joueur.

const UNIT_DIR := "res://test/unit/"
const SANDBOX_DIR := "user://test_sandbox/"

var nb_ok := 0
var nb_ko := 0
var _failures := []
var _saved_state := {}


## Exécute tout. `filter` ne garde que les fichiers dont le nom le contient.
## Renvoie true si tout est passé.
##
## ⚠️ **Coroutine** : les appelants doivent l'`await`. C'est le prix des tests d'interface,
## qui ont besoin de laisser passer des images pour qu'un nœud soit prêt et mesuré.
func run_all(filter := "") -> bool:
	var files = _find_test_files(filter)
	if files.is_empty():
		print("Aucun test trouvé dans %s" % UNIT_DIR)
		return true

	_enter_sandbox()
	for file_name in files:
		await _run_file(file_name)
	_leave_sandbox()

	_print_summary()
	return nb_ko == 0


#
#    Bac à sable
#

## Livre imposé pendant les tests. Les fichiers de tests citent des chapitres précis
## (fdcn 111, 112, 114...), ils ne peuvent donc pas hériter du livre que le développeur
## a sélectionné dans l'app.
const SANDBOX_BOOK := "fdcn"


func _enter_sandbox() -> void:
	DirAccess.make_dir_recursive_absolute(SANDBOX_DIR)
	_saved_state = {
		"base_dir": SaveManager.base_dir,
		"parameters_file": AppParameters.parameters_file,
		"parameters": AppParameters.parameters.duplicate(true),
		"book": AppParameters.get_book_name(),
	}
	SaveManager.base_dir = SANDBOX_DIR
	AppParameters.parameters_file = SANDBOX_DIR + "parameters.json"

	# `AppParameters` a déjà lu le VRAI `parameters.json` au démarrage : rediriger le
	# chemin n'annule pas ce qui en a été chargé. Sans épingler le livre ici, la suite
	# tournait sur celui que le joueur avait choisi dans l'app — 54 assertions ont
	# basculé le jour où il est passé à cdsi. On écrit le champ directement (pas de
	# `set_book_name()`, qui sauvegarderait et émettrait `book_changed`).
	AppParameters.parameters['current_book'] = SANDBOX_BOOK
	BookData.do_load_book(SANDBOX_BOOK)


func _leave_sandbox() -> void:
	SaveManager.base_dir = _saved_state["base_dir"]
	AppParameters.parameters_file = _saved_state["parameters_file"]
	AppParameters.parameters = _saved_state["parameters"]
	# Le livre du joueur est rechargé : les tests ne laissent pas le processus sur le
	# livre imposé.
	if _saved_state["book"] != SANDBOX_BOOK:
		BookData.do_load_book(_saved_state["book"])
	_clean_sandbox()


func _clean_sandbox() -> void:
	var dir = DirAccess.open(SANDBOX_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)


#
#    Découverte et exécution
#

func _find_test_files(filter := "") -> Array:
	var found := []
	var dir = DirAccess.open(UNIT_DIR)
	if dir == null:
		push_error("Lanceur: dossier introuvable: %s" % UNIT_DIR)
		return found
	for f in dir.get_files():
		if not f.begins_with("test_") or not f.ends_with(".gd"):
			continue
		if filter != "" and not f.contains(filter):
			continue
		found.append(f)
	found.sort()
	return found


func _run_file(file_name: String) -> void:
	print("\n── %s" % file_name)
	var script = load(UNIT_DIR + file_name)
	if script == null:
		_fail_file(file_name, "script illisible")
		return
	var instance = script.new()
	if instance == null:
		_fail_file(file_name, "instanciation impossible")
		return

	var test_names = _find_test_methods(instance)
	if test_names.is_empty():
		print("   (aucune méthode test_*)")
		return

	await _appeler(instance, "before_all")
	for test_name in test_names:
		instance._reset_assertions()
		await _appeler(instance, "before_each")
		await _appeler(instance, test_name)
		await _appeler(instance, "after_each")
		await _appeler(instance, "_liberer_les_noeuds")
		_collect(file_name, test_name, instance._assertions)
	await _appeler(instance, "after_all")


## Appelle une méthode du test, **qu'elle soit synchrone ou non**.
##
## En Godot 4, une fonction qui contient un `await` ne rend pas sa valeur : elle rend le
## signal de sa propre fin. Sans l'attendre, le lanceur relèverait les assertions d'un test
## encore en cours — et les tests d'interface, qui doivent laisser passer une image pour
## qu'un nœud soit prêt, seraient tous comptés vides.
func _appeler(instance, methode: String) -> void:
	var resultat = instance.call(methode)
	if resultat is Signal:
		await resultat


func _find_test_methods(instance) -> Array:
	var names := []
	for m in instance.get_method_list():
		if m.name.begins_with("test_") and not names.has(m.name):
			names.append(m.name)
	names.sort()
	return names


func _collect(file_name: String, test_name: String, assertions: Array) -> void:
	if assertions.is_empty():
		# Un test sans assertion ne prouve rien : on le signale.
		nb_ko += 1
		_failures.append("%s::%s — aucune assertion" % [file_name, test_name])
		print("   KO  %s (aucune assertion)" % test_name)
		return

	var failed = assertions.filter(func(a): return not a["ok"])
	if failed.is_empty():
		nb_ok += assertions.size()
		print("   ok  %s (%d assertions)" % [test_name, assertions.size()])
		return

	nb_ok += assertions.size() - failed.size()
	nb_ko += failed.size()
	print("   KO  %s" % test_name)
	for a in failed:
		var line = "%s::%s — %s : %s" % [file_name, test_name, a["label"], a["detail"]]
		_failures.append(line)
		print("        ✗ %s : %s" % [a["label"], a["detail"]])


func _fail_file(file_name: String, reason: String) -> void:
	nb_ko += 1
	_failures.append("%s — %s" % [file_name, reason])
	print("   KO  %s" % reason)


func _print_summary() -> void:
	print("\n" + "─".repeat(60))
	if nb_ko == 0:
		print("TOUT PASSE — %d assertions" % nb_ok)
		return
	print("ÉCHECS (%d) :" % nb_ko)
	for f in _failures:
		print("  ✗ %s" % f)
	print("%d assertions réussies, %d échouées" % [nb_ok, nb_ko])
