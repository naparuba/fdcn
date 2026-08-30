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
##
## TESTS D'INTERFACE — un test peut `await`. Le lanceur détecte une méthode asynchrone et
## l'attend, y compris les crochets. Ça débloque tout ce qui a besoin d'un arbre vivant :
##
##     func test_la_ligne_ne_deborde_pas():
##         var page = await afficher(preload("res://ui/MenuPage.tscn").instantiate())
##         assert_true(page.size.x <= 540, "la page tient dans l'écran")
##
## `afficher()` ajoute le nœud à l'arbre et laisse passer deux images : la première
## déclenche son `_ready()`, la seconde laisse les conteneurs poser leur mise en page. Sans
## cette seconde image, **toutes les tailles valent zéro** et un test de mise en page
## passerait pour de mauvaises raisons.

## Résultats accumulés par les assertions : [{ok: bool, label: String}]
var _assertions := []

## Les nœuds ajoutés à l'arbre par `afficher()`, libérés après chaque test.
var _noeuds_affiches := []


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
#    Arbre vivant (tests d'interface)
#

## Ajoute `noeud` à l'arbre, attend qu'il soit prêt ET mesuré, puis le renvoie.
## Le lanceur le libère après le test, il n'y a rien à ranger soi-même.
func afficher(noeud: Node) -> Node:
	_arbre().root.add_child(noeud)
	_noeuds_affiches.append(noeud)
	await attendre_une_frame()
	await attendre_une_frame()
	return noeud


func attendre_une_frame() -> void:
	await _arbre().process_frame


## L'arbre de la scène. `test_case.gd` est un `RefCounted` : il n'a pas de `get_tree()`,
## d'où le passage par la boucle principale.
func _arbre() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Appelé par le lanceur après chaque test. On libère **tout de suite** (`free()` et non
## `queue_free()`) : un nœud seulement mis en file survivrait à la fin de la suite et
## serait compté comme une fuite à la sortie.
func _liberer_les_noeuds() -> void:
	if _noeuds_affiches.is_empty():
		return
	for noeud in _noeuds_affiches:
		if is_instance_valid(noeud):
			noeud.free()
	_noeuds_affiches = []
	await attendre_une_frame()


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
