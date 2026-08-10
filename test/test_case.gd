extends RefCounted
## Classe de base des tests.
##
## Pour écrire un test : créer `test/unit/test_<sujet>.gd` avec
##
##     extends "res://test/test_case.gd"
##
##     func test_quelque_chose():
##         assert_eq(2 + 2, 4, "les maths marchent")
##
## Toute méthode dont le nom commence par `test_` est exécutée par le lanceur.
## Les crochets `before_all` / `before_each` / `after_each` / `after_all` sont
## optionnels, il suffit de les redéfinir.
##
## Les autoloads (Player, Inventory, SaveManager...) sont accessibles
## directement par leur nom : le lanceur charge les tests une fois le jeu
## démarré.
##
## SÉCURITÉ : le lanceur redirige les sauvegardes vers un dossier jetable avant
## d'exécuter quoi que ce soit. Un test ne peut donc pas abîmer la partie du
## joueur, même s'il appelle `Player.launch_new_billy()`.

## Résultats accumulés par les assertions : [{ok: bool, label: String}]
var _assertions := []


#
#    Crochets optionnels
#

func before_all() -> void:
	pass

func before_each() -> void:
	pass

func after_each() -> void:
	pass

func after_all() -> void:
	pass


#
#    Assertions
#

func assert_eq(got, want, label := "") -> bool:
	return _record(got == want, label, "obtenu %s, attendu %s" % [_fmt(got), _fmt(want)])


func assert_ne(got, unwanted, label := "") -> bool:
	return _record(got != unwanted, label, "on ne voulait pas %s" % _fmt(unwanted))


func assert_true(got, label := "") -> bool:
	return _record(got == true, label, "obtenu %s, attendu true" % _fmt(got))


func assert_false(got, label := "") -> bool:
	return _record(got == false, label, "obtenu %s, attendu false" % _fmt(got))


func assert_null(got, label := "") -> bool:
	return _record(got == null, label, "obtenu %s, attendu null" % _fmt(got))


func assert_not_null(got, label := "") -> bool:
	return _record(got != null, label, "obtenu null")


## Échec explicite (utile dans une branche qu'on ne devrait jamais atteindre).
func fail(label := "") -> bool:
	return _record(false, label, "fail() appelé")


#
#    Interne
#

func _record(ok: bool, label: String, detail: String) -> bool:
	_assertions.append({
		"ok": ok,
		"label": label if label != "" else "(sans libellé)",
		"detail": "" if ok else detail,
	})
	return ok


func _fmt(v) -> String:
	if v is String:
		return '"%s"' % v
	return str(v)


## Appelé par le lanceur entre deux tests.
func _reset_assertions() -> void:
	_assertions = []
