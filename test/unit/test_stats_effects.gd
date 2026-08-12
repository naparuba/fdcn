extends "res://test/test_case.gd"
## La notation d'effet (`"pv": "= max/4"`) et les compteurs déclarés par le livre.
##
## Le lanceur impose fdcn : ses compteurs propres sont `gloire` et `info`, et le
## vocabulaire de cdsi (`rancune`, `respect`) ne doit donc RIEN donner ici.


## Un Billy pégu part de end=2, donc pv_max=6 et chamax=3.
func before_each() -> void:
	AppParameters.set_billy_type('pegu')
	Player.launch_new_billy()


#
#    Notation d'effet
#

func test_une_valeur_chiffree_reste_additive() -> void:
	# Le point entier de la notation : aucune migration des ~200 entrées chiffrées.
	PlayerStats.del_pv(3)
	var depart = PlayerStats.get_pv()
	PlayerStats.apply_chapter_stat("pv", 2)
	assert_eq(PlayerStats.get_pv(), depart + 2, "un nombre s'ajoute, comme avant")


func test_laffectation_au_plafond() -> void:
	PlayerStats.del_pv(4)
	PlayerStats.apply_chapter_stat("pv", "= max")
	assert_eq(PlayerStats.get_pv(), PlayerStats.get_pv_max(), "= max remplit")


func test_le_diviseur() -> void:
	PlayerStats.apply_chapter_stat("pv", "= max/2")
	assert_eq(PlayerStats.get_pv(), PlayerStats.get_pv_max() / 2, "= max/2 met à la moitié du plafond")


func test_moi_est_la_valeur_courante_pas_le_plafond() -> void:
	# La distinction qui justifie deux jetons plutôt qu'un seul mot-clé.
	PlayerStats.del_pv(2)
	var courant = PlayerStats.get_pv()
	PlayerStats.apply_chapter_stat("pv", "= moi/2")
	assert_eq(PlayerStats.get_pv(), courant / 2, "= moi/2 part du courant")
	assert_ne(PlayerStats.get_pv(), PlayerStats.get_pv_max() / 2, "et pas du plafond")


func test_les_operateurs_plus_et_moins() -> void:
	var plafond = PlayerStats.get_pv_max()
	PlayerStats.apply_chapter_stat("pv", "- max/2")
	assert_eq(PlayerStats.get_pv(), plafond - plafond / 2, "- max/2 retire la moitié du plafond")
	PlayerStats.apply_chapter_stat("pv", "+ max/2")
	assert_eq(PlayerStats.get_pv(), plafond, "+ max/2 la rend")


func test_la_notation_reste_bornee() -> void:
	# Elle passe par les setters bornés, donc elle hérite du plafond sans code dédié.
	PlayerStats.apply_chapter_stat("pv", "+ max")
	assert_eq(PlayerStats.get_pv(), PlayerStats.get_pv_max(), "pas de dépassement")
	PlayerStats.apply_chapter_stat("pv", "- max")
	assert_eq(PlayerStats.get_pv(), 0, "pas de pv négatifs")


func test_la_chance_accepte_la_meme_notation() -> void:
	PlayerStats.del_chance(2)
	PlayerStats.apply_chapter_stat("chance", "= max")
	assert_eq(PlayerStats.get_cha(), PlayerStats.get_chance_max(), "= max sur la chance aussi")


func test_une_expression_illisible_ne_change_rien() -> void:
	PlayerStats.del_pv(2)
	var depart = PlayerStats.get_pv()
	PlayerStats.apply_chapter_stat("pv", "* max")
	assert_eq(PlayerStats.get_pv(), depart, "opérateur inconnu : sans effet")
	PlayerStats.apply_chapter_stat("pv", "= endurance")
	assert_eq(PlayerStats.get_pv(), depart, "jeton inconnu : sans effet")
	PlayerStats.apply_chapter_stat("pv", "= max/0")
	assert_eq(PlayerStats.get_pv(), depart, "diviseur nul : sans effet")


func test_la_notation_ne_vaut_que_pour_les_ressources() -> void:
	# `end` n'a pas de plafond, donc pas de `max` : la chaîne est signalée, et surtout
	# elle n'est pas additionnée à la couche `chapters` (une chaîne + un entier).
	var depart = PlayerStats.get_stat("end")
	PlayerStats.apply_chapter_stat("end", "= max")
	assert_eq(PlayerStats.get_stat("end"), depart, "l'endurance n'est pas touchée")


func test_les_mots_cles_historiques_passent_par_la_notation() -> void:
	# Tant que la donnée des deux livres les emploie, ils doivent donner exactement le
	# même résultat qu'avant.
	PlayerStats.del_pv(1)
	var courant = PlayerStats.get_pv()
	PlayerStats.apply_chapter_stat("half_pv", true)
	assert_eq(PlayerStats.get_pv(), courant / 2, "half_pv = moitié du courant")

	PlayerStats.apply_chapter_stat("max_pv", true)
	assert_eq(PlayerStats.get_pv(), PlayerStats.get_pv_max(), "max_pv remplit les pv")

	PlayerStats.del_chance(1)
	PlayerStats.apply_chapter_stat("max_chance", true)
	assert_eq(PlayerStats.get_cha(), PlayerStats.get_chance_max(), "max_chance remplit la chance")


func test_le_rejeu_dhistorique_ignore_toujours_les_ressources() -> void:
	# La notation passe par `_set_pv`, donc elle sauvegarde : le rejeu ne doit pas plus
	# l'appliquer qu'il n'appliquait `max_pv`.
	PlayerStats.del_pv(3)
	var apres_degats = PlayerStats.get_pv()
	PlayerStats.apply_chapter_stat("pv", "= max", false)
	assert_eq(PlayerStats.get_pv(), apres_degats, "le rejeu ne recrédite pas les pv")


#
#    Compteurs déclarés par le livre
#

func test_le_livre_declare_ses_compteurs() -> void:
	var cles = []
	for compteur in BookData.get_counters():
		cles.append(compteur["cle"])
	assert_true("gloire" in cles, "fdcn compte la gloire")
	assert_true("info" in cles, "fdcn compte les infos")
	assert_false("rancune" in cles, "et ignore les compteurs de cdsi")


func test_un_compteur_declare_saccumule() -> void:
	PlayerStats.apply_chapter_stat("gloire", 1)
	PlayerStats.apply_chapter_stat("gloire", 2)
	assert_eq(PlayerStats.get_compteur("gloire"), 3, "la gloire s'additionne")
	assert_eq(PlayerStats.get_compteur("info"), 0, "un compteur jamais crédité vaut 0")


func test_un_compteur_non_declare_nest_pas_compte() -> void:
	# `critique` est une faute de saisie de cdsi, pas un compteur : elle doit rester
	# visible comme une anomalie, pas se transformer en ligne de feuille de stats.
	PlayerStats.apply_chapter_stat("critique", 2)
	assert_eq(PlayerStats.get_compteur("critique"), 0, "une clé non déclarée ne compte pas")


func test_le_rejeu_ne_double_pas_les_compteurs() -> void:
	# fdcn ch131 donne `gloire: 1` et `info: 1`. `do_load()` rejoue l'historique : sans
	# remise à zéro des compteurs, chaque rechargement les redoublerait.
	Player.go_to_node(131)
	var gloire = PlayerStats.get_compteur("gloire")
	assert_eq(gloire, 1, "le chapitre 131 donne 1 gloire")

	Player.do_load()

	assert_eq(PlayerStats.get_compteur("gloire"), gloire, "le rejeu ne double pas la gloire")
