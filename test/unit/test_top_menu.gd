extends "res://test/test_case.gd"
## `ui/top_menu.gd` — la barre du haut : logo et titre du livre courant, type de Billy,
## navigation vers une page.
##
## La barre est testée **dans sa page**, pas seule : elle retrouve son conteneur en
## remontant l'arbre (`Utils.find_ancestor_with_method`), donc l'instancier isolée ne
## prouverait rien de ce qui compte ici.

var _page: Node = null
var _menu: Node = null


func before_each() -> void:
	_page = await afficher(preload("res://ui/MenuPage.tscn").instantiate())
	_menu = _page.get_node("TopMenu")


func test_la_barre_est_dans_la_page() -> void:
	assert_not_null(_menu, "la page porte bien un TopMenu")


## Le logo et le titre viennent de `books/<nom>/img/` et **doivent suivre le livre
## courant** : la scène ne les porte plus en dur, justement pour que ce test ait un sens.
func test_le_logo_et_le_titre_viennent_du_livre_courant() -> void:
	var logo = _menu.get_node("Margin/HBoxContainer/BookSelection/logo")
	var titre = _menu.get_node("Margin/HBoxContainer/BookSelection/title")
	assert_not_null(logo.texture, "le logo est posé")
	assert_not_null(titre.texture, "le titre aussi")

	# Et c'est bien celui du livre du bac à sable, pas une image d'aperçu d'éditeur.
	assert_true(logo.texture.resource_path.contains("books/fdcn/img/logo"), "logo de fdcn")
	assert_true(titre.texture.resource_path.contains("books/fdcn/img/title"), "titre de fdcn")


## Un livre sans image ne doit pas planter la barre : elle laisse la case vide.
func test_un_livre_sans_image_laisse_la_case_vide() -> void:
	assert_null(_menu._image_du_livre("livre-qui-nexiste-pas", "logo"),
		"pas d'image, pas de texture — et pas d'erreur")


## Le type de Billy est écrit **en toutes lettres** dans la barre : c'est la seule façon de
## le connaître depuis que les icônes de type sont masquées faute de place.
func test_le_type_de_billy_saffiche_en_toutes_lettres() -> void:
	var libelle = _menu.get_node("Margin/HBoxContainer/Billys/BillyTypeLabel")

	Inventory.force_billy_type('paysan')
	_menu.set_billy()
	assert_eq(libelle.text, "Paysan", "le type est écrit dans la barre")

	Inventory.force_billy_type('debrouillard')
	_menu.set_billy()
	assert_eq(libelle.text, "Débrouillard", "et il suit les changements")


## La barre ne connaît pas son conteneur de pages : elle le retrouve en remontant l'arbre.
## C'est ce qui lui permet d'être réutilisable — et c'est aussi ce qui casse en silence si
## quelqu'un la sort de sa page.
func test_la_barre_trouve_son_conteneur_de_pages() -> void:
	var conteneur = Utils.find_ancestor_with_method(_menu, "go_to_page")
	assert_eq(conteneur, _page, "elle remonte jusqu'à la page")

	_menu._go_to_page("succes")
	assert_eq(_page.current_index, _page.page_names.find("succes"), "et sait y aller")


## Hors d'une page, `_go_to_page()` ne doit rien faire plutôt que planter : c'est le cas de
## l'archive, qui réutilise la barre sans conteneur.
func test_la_barre_hors_dune_page_ne_plante_pas() -> void:
	var seule = await afficher(preload("res://ui/top_menu.tscn").instantiate())
	seule._go_to_page("succes")
	assert_true(true, "aucun plantage sans conteneur de pages")
