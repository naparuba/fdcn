extends "res://test/test_case.gd"
## `ui/menu_page.gd` — le conteneur de pages, et la règle qui l'accompagne : **une popup
## ouverte neutralise toute la navigation**.
##
## Premier test d'interface du dépôt. Il a fallu que le lanceur sache `await` pour
## l'écrire : `instantiate()` seul n'appelle pas `_ready()`, donc ni les branchements de
## signaux ni la première peinture n'existent. Ici la page est réellement dans l'arbre.

var _page: Node = null


func before_each() -> void:
	_page = await afficher(preload("res://ui/MenuPage.tscn").instantiate())


#
#    Navigation
#

func test_la_page_demarre_sur_laventure() -> void:
	assert_eq(_page.current_index, 0, "on démarre sur la première page")
	assert_not_null(_page.current_scene_instance, "et son écran est instancié")


func test_aller_a_une_page_par_son_nom() -> void:
	_page.go_to_page("succes")
	assert_eq(_page.current_index, _page.page_names.find("succes"), "on est sur les succès")


func test_une_page_inconnue_ne_bouge_rien() -> void:
	var depart = _page.current_index
	_page.go_to_page("page-qui-nexiste-pas")
	assert_eq(_page.current_index, depart, "on n'a pas bougé")


func test_les_pages_tournent_en_boucle() -> void:
	var nb = _page.scenes.size()
	_page._change_page(-1)
	assert_eq(_page.current_index, nb - 1, "reculer depuis la première mène à la dernière")
	_page._change_page(1)
	assert_eq(_page.current_index, 0, "et avancer y revient")


#
#    La règle : une popup bloque tout
#

func test_une_popup_bloque_la_navigation() -> void:
	_page.go_to_page("chapitres")
	var depart = _page.current_index

	_page.confirm("Question ?", func(): pass)
	await attendre_une_frame()
	assert_true(_page.is_popup_open(), "la popup est là")

	_page.go_to_page("succes")
	assert_eq(_page.current_index, depart, "`go_to_page` ne fait rien")
	_page._change_page(1)
	assert_eq(_page.current_index, depart, "les flèches non plus")


## Les flèches ne doivent pas seulement être inertes : elles doivent le **montrer**, sinon
## le joueur croit l'app figée.
func test_une_popup_grise_les_fleches() -> void:
	_page.confirm("Question ?", func(): pass)
	await attendre_une_frame()
	assert_true(_page._nav_left.is_disabled, "flèche gauche grisée")
	assert_true(_page._nav_right.is_disabled, "flèche droite grisée")


## ⚠️ Non-régression : un nœud en cours de suppression reste enfant pendant une image. S'il
## comptait encore comme popup ouverte, la navigation resterait bloquée **définitivement**
## après la première confirmation.
func test_la_navigation_revient_quand_la_popup_se_ferme() -> void:
	_page.confirm("Question ?", func(): pass)
	await attendre_une_frame()

	for enfant in _page.popup_container.get_children():
		enfant.queue_free()
	await attendre_une_frame()
	await attendre_une_frame()

	assert_false(_page.is_popup_open(), "plus aucune popup")
	var depart = _page.current_index
	_page._change_page(1)
	assert_ne(_page.current_index, depart, "la navigation est revenue")


## Un toast n'est pas une popup : il vit dans sa propre couche, sinon un message qui
## s'efface au bout de 3 s figerait les pages pendant 3 s.
func test_un_toast_ne_bloque_pas_la_navigation() -> void:
	var toast := Label.new()
	_page.toast_layer.add_child(toast)
	await attendre_une_frame()

	assert_false(_page.is_popup_open(), "un toast n'ouvre pas de popup")
	var depart = _page.current_index
	_page._change_page(1)
	assert_ne(_page.current_index, depart, "et ne bloque pas la navigation")
