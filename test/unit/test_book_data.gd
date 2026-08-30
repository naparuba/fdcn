extends "res://test/test_case.gd"
## `BookData` — l'évaluateur de conditions, et les lectures qui en dépendent.
##
## 🔴 C'est `_check_cond_rec()` qui **décide quels chapitres sont accessibles**. Logique
## pure, sans interface, et elle n'avait aucun filet : une régression y ouvre ou ferme des
## chemins de l'aventure sans que rien ne le signale. Les 620 conditions des deux livres
## n'emploient que trois opérateurs, `$end` / `$or` / `$and`, tous couverts ici.
##
## Le lanceur impose fdcn : les chapitres cités sont les siens, vérifiés dans les données
## compilées.


## Le type de Billy entre dans les faits (`Inventory.get_all_matched_conditions()`), il
## faut donc partir d'un Billy connu.
func before_each() -> void:
	AppParameters.set_billy_type('pegu')
	Player.launch_new_billy()


#
#    L'évaluateur, avec des faits explicites
#

func test_end_est_une_feuille() -> void:
	assert_true(BookData._check_cond_rec({"$end": "EPEE"}, ["EPEE", "PEGU"]), "le fait est là")
	assert_false(BookData._check_cond_rec({"$end": "EPEE"}, ["LANCE"]), "le fait manque")
	assert_false(BookData._check_cond_rec({"$end": "EPEE"}, []), "aucun fait")


func test_or_suffit_dun_seul() -> void:
	var cond = {"$or": [{"$end": "MORGENSTERN"}, {"$end": "GUERRIER"}]}
	assert_true(BookData._check_cond_rec(cond, ["GUERRIER"]), "le second suffit")
	assert_true(BookData._check_cond_rec(cond, ["MORGENSTERN"]), "le premier aussi")
	assert_true(BookData._check_cond_rec(cond, ["MORGENSTERN", "GUERRIER"]), "les deux à la fois")
	assert_false(BookData._check_cond_rec(cond, ["LANCE"]), "aucun des deux")


func test_and_les_veut_tous() -> void:
	var cond = {"$and": [{"$end": "FER A CHEVAL"}, {"$end": "TRESSE DE CENTAURESSE"}]}
	assert_true(BookData._check_cond_rec(cond, ["FER A CHEVAL", "TRESSE DE CENTAURESSE"]), "les deux")
	assert_false(BookData._check_cond_rec(cond, ["FER A CHEVAL"]), "il en manque un")
	assert_false(BookData._check_cond_rec(cond, []), "il les manque tous")


## Les deux cas dégénérés, faciles à casser en réécrivant les boucles : un `$or` vide n'a
## aucune raison d'être vrai, un `$and` vide n'a aucune raison d'être faux.
func test_les_listes_vides() -> void:
	assert_false(BookData._check_cond_rec({"$or": []}, ["EPEE"]), "$or vide = faux")
	assert_true(BookData._check_cond_rec({"$and": []}, []), "$and vide = vrai")


func test_les_conditions_simbriquent() -> void:
	# « (PAYSAN ou GUERRIER) et une CORDE » : la forme que prennent les vraies conditions
	# du livre quand un type de Billy remplace un objet.
	var cond = {"$and": [
		{"$or": [{"$end": "PAYSAN"}, {"$end": "GUERRIER"}]},
		{"$end": "CORDE"},
	]}
	assert_true(BookData._check_cond_rec(cond, ["PAYSAN", "CORDE"]), "branche gauche + corde")
	assert_true(BookData._check_cond_rec(cond, ["GUERRIER", "CORDE"]), "branche droite + corde")
	assert_false(BookData._check_cond_rec(cond, ["PAYSAN"]), "sans la corde")
	assert_false(BookData._check_cond_rec(cond, ["CORDE"]), "sans le type")


## ⚠️ LE test de non-régression de la fonction : une condition qu'on ne sait pas lire doit
## renvoyer **false**, pas `null`. Sans le `return false` final, GDScript rendait `null`,
## qui se lit comme « condition non remplie » — une faute de frappe dans les données
## fermait donc un chemin de l'aventure en silence.
func test_une_condition_illisible_est_fausse_pas_nulle() -> void:
	assert_eq(BookData._check_cond_rec({"$nope": "EPEE"}, ["EPEE"]), false,
		"opérateur inconnu : faux, et pas null")
	assert_eq(BookData._check_cond_rec("EPEE", ["EPEE"]), false, "pas même un dictionnaire")
	assert_eq(BookData._check_cond_rec({}, ["EPEE"]), false, "dictionnaire vide")


#
#    Les conditions de saut du livre
#

func test_un_saut_conditionne_se_reconnait() -> void:
	# fdcn ch2 est le choix du type de Billy : ses quatre sorties sont conditionnées.
	assert_true(BookData.have_chapter_conditions(2, 11), "2 -> 11 a une condition")
	assert_false(BookData.have_chapter_conditions(2, 12), "2 -> 12 n'existe pas")


func test_un_saut_conditionne_suit_le_type_de_billy() -> void:
	Inventory.force_billy_type('guerrier')
	assert_true(BookData.match_chapter_conditions(2, 11), "le GUERRIER passe par 11")
	assert_false(BookData.match_chapter_conditions(2, 99), "mais pas par 99 (PAYSAN)")

	Inventory.force_billy_type('paysan')
	assert_false(BookData.match_chapter_conditions(2, 11), "le PAYSAN ne passe plus par 11")
	assert_true(BookData.match_chapter_conditions(2, 99), "il passe par 99")


func test_un_saut_sans_condition_ne_correspond_a_rien() -> void:
	# Pas de condition du tout : `match` renvoie false, et c'est bien ce qu'il faut —
	# l'appelant demande d'abord `have_chapter_conditions()`.
	assert_false(BookData.match_chapter_conditions(2, 12), "aucune condition = pas de match")


func test_le_libelle_de_la_condition() -> void:
	assert_eq(BookData.get_condition_txt(2, 11), "GUERRIER", "le texte affiché au joueur")
	assert_eq(BookData.get_condition_txt(2, 12), "", "pas de condition, pas de texte")


#
#    Les autres lectures
#

func test_les_stats_dun_chapitre() -> void:
	var stats = BookData.get_chapter_stats(131)
	assert_eq(stats['stats'].get('gloire'), 1, "fdcn 131 donne 1 gloire")
	assert_true(stats['stats_conds'] is Array, "les effets conditionnels sont une liste")


## La complétion d'un acte est un pourcentage, jamais une division par zéro : un chapitre
## hors de tout acte vaut 100 %, sinon la barre accuserait le joueur d'un retard imaginaire.
func test_la_completion_dun_acte() -> void:
	assert_eq(BookData.get_acte_completion(1, []), 0, "rien de visité")
	assert_true(BookData.get_acte_completion(1, [1]) > 0, "un chapitre visité compte")
	assert_eq(BookData.get_sub_arc_completion(1, []), 100,
		"le chapitre 1 n'a pas de sous-arc : 100 %, pas une division par zéro")


func test_les_succes_se_retrouvent_par_chapitre() -> void:
	assert_true(BookData.is_success_chapter(112), "fdcn 112 donne un succès")
	assert_false(BookData.is_success_chapter(2), "fdcn 2 non")
	var success = BookData.get_success_from_chapter(112)
	assert_eq(success['id'], "TROIE", "c'est le succès TROIE")
	assert_ne(BookData.get_success_txt("TROIE"), "", "et il a un texte")
	assert_eq(BookData.get_success_txt("SUCCES-QUI-NEXISTE-PAS"), "", "un succès inconnu n'a pas de texte")


## ⚠️ **Le contrat des valeurs absentes.** Une entrée compilée ne porte que ce qui n'est pas
## neutre : 61 % du fichier ne s'écrit plus. Un chapitre sans combat n'a pas de clé
## `combat`, un chapitre sans objet n'a pas d'`aquire`. Chaque accesseur doit donc rendre la
## valeur neutre — et **la même** que celle que le générateur a décidé de ne pas écrire
## (`Node.NEUTRES`, côté Python). Si les deux moitiés du contrat divergent, c'est ici que ça
## se voit.
func test_un_chapitre_depouille_rend_des_valeurs_neutres() -> void:
	# fdcn 273 ne déclare qu'un `goto` et un `stats` : tout le reste est absent du fichier.
	var nu = BookData.get_chapter_node(273)
	assert_eq(nu.get_id(), 273, "l'identifiant est toujours écrit")
	assert_eq(nu.get_sons(), [423], "et ce qui n'est pas neutre aussi")

	assert_false(nu.is_combat(), "pas de combat")
	assert_eq(nu.get_combats(), [], "donc aucun adversaire")
	assert_false(nu.get_ending(), "pas une fin")
	assert_null(nu.get_ending_type(), "donc pas de type de fin")
	assert_null(nu.get_ending_id(), "ni d'identifiant")
	assert_null(nu.get_ending_txt(), "ni de texte")
	assert_false(nu.get_secret(), "pas un secret")
	assert_eq(nu.get_secret_jumps(), [], "aucun saut secret")
	assert_null(nu.get_success(), "aucun succès")
	assert_null(nu.get_label(), "aucun libellé")
	assert_null(nu.get_arc(), "aucun sous-arc")
	assert_eq(nu.get_aquire(), [], "aucun objet gagné")
	assert_eq(nu.get_remove(), [], "aucun objet perdu")
	assert_eq(nu.get_stats_cond(), [], "aucun effet conditionnel")
	assert_eq(nu.get_jump_conditions(), {}, "aucune condition de saut")
	assert_eq(nu.get_jump_conditions_txts(), {}, "aucun libellé de condition")


## Les deux booléens dérivés : ils ne sont plus écrits du tout, l'app les recalcule.
func test_les_booleens_derives_suivent_leur_source() -> void:
	assert_true(BookData.get_chapter_node(274).is_combat(), "274 a des adversaires")
	assert_eq(BookData.get_chapter_node(274).get_combats().size(), 2, "et il en a deux, dans l'ordre")
	assert_true(BookData.get_chapter_node(559).get_ending(), "559 est une fin")
	assert_eq(BookData.get_chapter_node(559).get_ending_type(), 1, "une bonne fin")


func test_les_objets_du_livre() -> void:
	assert_true(BookData.exists_item_data("EPEE"), "fdcn connaît l'EPEE")
	assert_false(BookData.exists_item_data("SABRE LASER"), "et pas le sabre laser")
	assert_true(BookData.get_item_data("EPEE").has('category'), "un objet a une catégorie")
