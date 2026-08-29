extends "res://test/test_case.gd"
## Le registre `books/books.json` et les fichiers **facultatifs** d'un livre.
##
## Ces tests sont surtout là pour le **jour où on ajoute un livre**. Une entrée de registre
## qui ne correspond à aucun dossier, une couverture oubliée, un son mal rangé : rien de
## tout ça ne se voit avant d'ouvrir l'écran concerné, livre chargé.
##
## Le lanceur impose fdcn — les assertions nommées portent donc sur lui.


func test_le_registre_declare_des_livres() -> void:
	var livres = BookData.get_books()
	assert_true(livres.size() >= 2, "le registre déclare au moins les deux livres (%d)" % livres.size())
	for livre in livres:
		assert_ne(livre.get("nom", ""), "", "chaque entrée a un `nom`")
		assert_ne(livre.get("titre", ""), "", "chaque entrée a un `titre`")


func test_chaque_livre_declare_a_ses_donnees_sur_le_disque() -> void:
	for livre in BookData.get_books():
		var nom = livre.get("nom", "")
		var chemin = "res://books/%s/data/%s-compilated.json" % [nom, nom]
		assert_true(Utils.is_file_exists(chemin), "%s : le fichier compilé est là" % nom)
		var compiled = Utils.load_json_file(chemin)
		for cle in ["chapters", "nodes_by_chapter", "nodes_by_sub_arc", "objects", "success"]:
			assert_true(compiled.has(cle), "%s : la clé %s est là" % [nom, cle])


## Les images d'un livre sont trouvées par convention de nommage, jamais déclarées : rien
## ne les vérifie au chargement, et une couverture manquante retire son bouton illustré du
## sélecteur.
func test_chaque_livre_a_ses_images() -> void:
	for livre in BookData.get_books():
		var nom = livre.get("nom", "")
		var img = "res://books/%s/img" % nom
		assert_true(Utils.is_file_exists(img + "/logo.png"), "%s : logo" % nom)
		assert_true(Utils.is_file_exists(img + "/title.png"), "%s : titre" % nom)
		assert_true(Utils.is_file_exists(img + "/cover.jpg"), "%s : couverture" % nom)


func test_le_livre_par_defaut_est_le_premier_du_registre() -> void:
	# C'est ce que voit une première partie, et le repli quand la sauvegarde nomme un livre
	# qui n'existe plus.
	assert_eq(BookData.get_default_book_name(), BookData.get_books()[0]["nom"],
		"le défaut est le premier livre déclaré")


func test_un_livre_inconnu_ne_fait_pas_planter() -> void:
	# Tous les appelants enchaînent sur `.get(...)` : un livre absent doit se comporter
	# comme un livre sans option, pas faire tomber l'app.
	assert_false(BookData.book_exists("livre-qui-nexiste-pas"), "le livre n'existe pas")
	assert_true(BookData.get_book("livre-qui-nexiste-pas").is_empty(), "et son entrée est vide")


#
#    Les fichiers facultatifs du livre
#

func test_les_compteurs_viennent_du_fichier_du_livre() -> void:
	# `books/fdcn/data/compteurs.json` — pas une table en dur, pas le registre.
	var cles := []
	for compteur in BookData.get_counters():
		cles.append(compteur["cle"])
	assert_true("gloire" in cles, "fdcn compte la gloire")
	assert_true("info" in cles, "fdcn compte les infos")
	assert_false("rancune" in cles, "et ignore les compteurs de cdsi")
	assert_true(BookData.is_counter("gloire"), "is_counter suit le fichier du livre")


func test_les_clefs_ignorees_viennent_aussi_du_fichier_du_livre() -> void:
	# Meme fichier que les compteurs, meme test de nature : todo 3.5.
	assert_true(BookData.is_ignored("arc_et_couteau"), "fdcn ignore arc_et_couteau (ch284)")
	assert_false(BookData.is_ignored("gloire"), "un compteur n'est pas une clef ignoree")
	assert_false(BookData.is_ignored("critique"), "une clef inconnue n'est pas ignoree pour autant")


## La narration d'un chapitre est **un fichier, pas une déclaration** :
## `books/<nom>/audio/<chapitre>.mp3`. Le test vérifie la convention de bout en bout.
func test_une_narration_est_un_fichier_du_livre() -> void:
	assert_true(Narrator.has_narration(27), "fdcn 27 a sa narration")
	assert_false(Narrator.has_narration(26), "fdcn 26 n'en a pas")
	# Les identifiants arrivent parfois en float depuis les données du livre.
	assert_true(Narrator.has_narration(27.0), "un identifiant flottant marche aussi")


func test_l_intro_du_livre_est_dans_son_dossier() -> void:
	# Non-régression du rangement : les sons du livre ont quitté `sounds/`.
	assert_true(Utils.is_file_exists("res://books/fdcn/audio/intro.mp3"), "fdcn a son intro")
	assert_false(Utils.is_file_exists("res://sounds/intro-fdcn.mp3"), "et plus rien dans sounds/")


## Les cinq sorties que personne ne lisait ont été supprimées le 2026-08-13 : la liste des
## combats, celle des secrets et les trois listes de fins. Tout ça se lit chapitre par
## chapitre. Et les cinq qui restaient (3 calculées + 2 tables recopiées) ont été réunies en
## un seul fichier le 2026-08-29 (todo 3.6). Si un futur passage sur le générateur les
## réécrit par erreur, c'est ce test qui doit le remarquer.
func test_les_sorties_inutiles_nexistent_plus() -> void:
	for inutile in ["combats", "secrets", "endings", "good-endings", "bad-endings",
			"success", "success-chapters", "all-objects", "data",
			"nodes-by-chapter", "nodes-by-sub-arc"]:
		assert_false(Utils.is_file_exists("res://books/fdcn/data/fdcn-compilated-%s.json" % inutile),
			"fdcn-compilated-%s.json n'a plus de raison d'être" % inutile)
	assert_false(Utils.is_file_exists("res://books/fdcn/data/fdcn.all_objects.json"),
		"fdcn.all_objects.json est maintenant dans la clé `objects` du fichier compilé")
	assert_false(Utils.is_file_exists("res://books/fdcn/data/fdcn.all_success.json"),
		"fdcn.all_success.json est maintenant dans la clé `success` du fichier compilé")


## Les données compilées ne contiennent plus que le CALCULÉ : le chapitre écrit à la main
## vit dans `<nom>.json`, à côté, et n'y est plus recopié. `chapter_data.gd` accepte encore
## l'ancienne forme, donc ce test décrit l'état des données, pas une obligation du code.
func test_les_donnees_compilees_ne_repetent_pas_la_source() -> void:
	var chapitre = BookData.get_chapter_node(1)
	assert_not_null(chapitre.get_sons(), "un chapitre a bien ses fils calculés")
	assert_eq(chapitre.get_id(), 1, "et son identifiant")


## Objets et succès sont lus dans les fichiers de l'auteur, puis **complétés** de ce que les
## chapitres en disent. C'est ce complément qu'on vérifie : sans lui, l'inventaire cacherait
## tous les objets et l'écran des succès n'afficherait aucun chapitre.
func test_les_objets_et_succes_sont_completes_au_chargement() -> void:
	var epee = BookData.get_item_data("EPEE")
	assert_true(epee.has('in_chapters'), "un objet sait où il se gagne")
	assert_true(epee.has('stats'), "et porte toujours un dictionnaire de stats")

	var succes = BookData.get_all_success()
	assert_true(succes.size() > 0, "le livre a des succès")
	for s in succes:
		assert_true(s.has('chapter'), "le succès %s sait où il se gagne" % s['id'])

	# fdcn 112 donne TROIE : le chemin complet, du chapitre au succès.
	var troie = BookData.get_success_from_chapter(112)
	assert_eq(troie['id'], "TROIE", "chapitre -> succès")
	assert_eq(troie['chapter'], 112, "et le succès sait d'où il vient")
	assert_ne(BookData.get_success_txt("TROIE"), "", "son texte est là")


## ⚠️ Un succès qui se gagne dans DEUX chapitres ne doit apparaître qu'une fois — et compter
## comme obtenu si l'un ou l'autre a été traversé. Le fichier compilé en faisait deux lignes.
func test_un_succes_gagne_deux_fois_napparait_quune_fois() -> void:
	var ids := []
	for s in BookData.get_all_success():
		assert_false(s['id'] in ids, "le succès %s n'est listé qu'une fois" % s['id'])
		ids.append(s['id'])


#
#    La grille du sélecteur
#

## La règle de mise en page du sélecteur de livre : plus il y a de livres, plus la grille
## s'élargit — mais jamais plus large que haute, l'app étant en portrait et les couvertures
## plus hautes que larges. C'est une fonction pure : elle se teste sans afficher la scène,
## donc sans attendre la moindre image.
func test_la_grille_du_selecteur_reste_en_portrait() -> void:
	var selecteur = load("res://popups/sub/book_selection.gd")
	assert_eq(selecteur.colonnes_pour(1), 1, "1 livre : une colonne")
	assert_eq(selecteur.colonnes_pour(2), 1, "2 livres : l'un au-dessus de l'autre")
	assert_eq(selecteur.colonnes_pour(3), 2, "3 livres : 2 colonnes, une case vide")
	assert_eq(selecteur.colonnes_pour(4), 2, "4 livres : 2 colonnes, 2 lignes")
	assert_eq(selecteur.colonnes_pour(6), 2, "6 livres : 2 colonnes, 3 lignes")
	assert_eq(selecteur.colonnes_pour(9), 3, "9 livres : 3 colonnes")
	assert_eq(selecteur.colonnes_pour(0), 1, "aucun livre : jamais zéro colonne")
