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
		var base = "res://books/%s/data/%s" % [nom, nom]
		assert_true(Utils.is_file_exists(base + "-compilated-data.json"),
			"%s : les chapitres compilés sont là" % nom)
		assert_true(Utils.is_file_exists(base + "-compilated-all-objects.json"),
			"%s : les objets compilés sont là" % nom)


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


## `archive/` n'est pas un cimetière : le compilateur y écrit toujours, mais **rien ne doit
## le charger**. Si un de ces fichiers redevient utile, il remonte dans `data/`.
func test_larchive_du_livre_nest_pas_chargee() -> void:
	assert_true(Utils.is_file_exists("res://books/fdcn/archive/fdcn-compilated-combats.json"),
		"les sorties inutilisées sont conservées dans archive/")
	assert_false(Utils.is_file_exists("res://books/fdcn/data/fdcn-compilated-combats.json"),
		"et ne traînent plus dans data/")


#
#    La grille du sélecteur
#

## La règle de mise en page du sélecteur de livre : plus il y a de livres, plus la grille
## s'élargit — mais jamais plus large que haute, l'app étant en portrait et les couvertures
## plus hautes que larges. C'est une fonction pure, donc testable sans afficher la scène
## (`test_case.gd` ne sait pas encore `await`).
func test_la_grille_du_selecteur_reste_en_portrait() -> void:
	var selecteur = load("res://popups/sub/book_selection.gd")
	assert_eq(selecteur.colonnes_pour(1), 1, "1 livre : une colonne")
	assert_eq(selecteur.colonnes_pour(2), 1, "2 livres : l'un au-dessus de l'autre")
	assert_eq(selecteur.colonnes_pour(3), 2, "3 livres : 2 colonnes, une case vide")
	assert_eq(selecteur.colonnes_pour(4), 2, "4 livres : 2 colonnes, 2 lignes")
	assert_eq(selecteur.colonnes_pour(6), 2, "6 livres : 2 colonnes, 3 lignes")
	assert_eq(selecteur.colonnes_pour(9), 3, "9 livres : 3 colonnes")
	assert_eq(selecteur.colonnes_pour(0), 1, "aucun livre : jamais zéro colonne")
