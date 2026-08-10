extends "res://test/test_case.gd"
## Le moteur de combat : table, écart, dégâts, esquive, critique, fuite.
##
## Une erreur d'arithmétique de combat est invisible à l'œil nu, d'où un test par
## règle. Les dés sont forcés via `CombatEngine.dice_roller` : aucun test n'est
## soumis au hasard.
##
## Chapitre témoin : **fdcn 114** — ORC ESCLAVAGISTE, hab 10, pv 10, arm 0, deg 0,
## pyro 4. Choisi parce que ses armures et dégâts sont nuls : les cas qui les testent
## le font en trafiquant les valeurs, ce qui rend chaque test explicite.

const CH_COMBAT := 114


func before_each() -> void:
	AppParameters.set_billy_type('pegu')
	Player.launch_new_billy()
	CombatEngine.start(CH_COMBAT)


func after_each() -> void:
	CombatEngine.stop()
	CombatEngine.dice_roller = func() -> int: return Utils.roll_a_dice(1, 6)


## Force les dés à sortir la séquence donnée, puis à répéter la dernière valeur.
func _forcer_des(valeurs: Array) -> void:
	var restant = valeurs.duplicate()
	CombatEngine.dice_roller = func() -> int:
		if restant.size() > 1:
			return restant.pop_front()
		return restant[0]


#
#    Table et écart
#

func test_la_table_est_chargee_et_complete() -> void:
	# 15 écarts x 6 dés. On vérifie les deux extrêmes dictés par les règles.
	assert_eq(CombatEngine.get_max_degats(7), 12, "écart +7, dé 6 : 12 dégâts infligés")
	assert_eq(CombatEngine.get_max_degats(0), 5, "écart 0, dé 6 : 5 dégâts infligés")
	assert_eq(CombatEngine.get_max_degats(-7), 3, "écart -7, dé 6 : 3 dégâts infligés")


func test_les_situations_portent_le_cout_de_fuite() -> void:
	# hab d'un pégu neuf = 2, ennemi hab 10, pyro +4 => écart -4 => « Désavantage ».
	assert_eq(CombatEngine.get_ecart(), -4, "écart calculé avec le bonus pyro")
	assert_eq(CombatEngine.get_situation(), "Désavantage", "situation nommée")
	assert_eq(CombatEngine.get_fuite_cost(), 3, "fuir un désavantage coûte 3 chance")


func test_le_bonus_pyro_est_automatique() -> void:
	# Sans le pyro (+4) l'écart vaudrait 2 - 10 = -8.
	assert_eq(CombatEngine.get_ecart_brut(), -4, "le pyro entre sans qu'on le demande")


func test_le_modificateur_manuel_deplace_lecart() -> void:
	CombatEngine.set_hab_modifier(3)
	assert_eq(CombatEngine.get_ecart(), -1, "la règle spéciale saisie à la main s'applique")


func test_un_ecart_sous_le_plancher_est_plafonne() -> void:
	CombatEngine.set_hab_modifier(-100)
	assert_true(CombatEngine.is_ecart_plafonne(), "l'écart est signalé comme plafonné")
	assert_eq(CombatEngine.get_ecart(), -7, "on lit la ligne -7")
	assert_eq(CombatEngine.get_ecart_brut(), -104, "l'écart brut reste affichable tel quel")


func test_plus_de_sept_decart_gagne_sans_lancer_de_de() -> void:
	CombatEngine.set_hab_modifier(100)
	assert_true(CombatEngine.is_auto_win(), "victoire automatique au-delà de +7")


#
#    Dégâts
#

func test_les_degats_de_la_table_sont_appliques() -> void:
	# écart -4, dé 6 => [4, 3]. Ennemi arm 0 / deg 0, joueur deg 0 / arm 0 :
	# les chiffres de la frise passent tels quels.
	_forcer_des([6])
	var pv_depart = PlayerStats.get_pv()
	CombatEngine.roll()
	var r = CombatEngine.resolve()

	assert_eq(r["degats_infliges"], 4, "4 dégâts infligés")
	assert_eq(r["degats_recus"], 3, "3 dégâts reçus")
	assert_eq(CombatEngine.get_enemy_pv(), 10 - 4, "les pv de l'ennemi descendent")
	assert_eq(PlayerStats.get_pv(), pv_depart - 3, "les pv du joueur descendent")


func test_larmure_du_joueur_reduit_les_degats_recus() -> void:
	# écart -4, dé 6 => 3 reçus, moins 2 d'armure = 1.
	PlayerStats.apply_chapter_stat("arm", 2)
	PlayerStats.recompute()
	_forcer_des([6])
	CombatEngine.roll()
	assert_eq(CombatEngine.resolve()["degats_recus"], 1, "3 - 2 d'armure")


func test_les_degats_ne_passent_jamais_sous_zero() -> void:
	PlayerStats.apply_chapter_stat("arm", 99)
	PlayerStats.recompute()
	_forcer_des([6])
	CombatEngine.roll()
	assert_eq(CombatEngine.resolve()["degats_recus"], 0, "une grosse armure ne soigne pas")


func test_les_degats_supplementaires_sajoutent_a_la_table() -> void:
	# écart -4, dé 6 => 4 infligés, plus 2 de dégâts d'équipement = 6.
	PlayerStats.apply_chapter_stat("deg", 2)
	PlayerStats.recompute()
	_forcer_des([6])
	CombatEngine.roll()
	assert_eq(CombatEngine.resolve()["degats_infliges"], 6, "4 de la frise + 2 de deg")


#
#    Esquive et critique
#

func test_pas_desquive_sans_assez_dadresse() -> void:
	# Un pégu neuf a 1 d'adresse.
	_forcer_des([6])
	CombatEngine.roll()
	assert_false(CombatEngine.can_dodge(), "1 d'adresse ne permet pas d'esquiver")


func test_deux_dadresse_suffit_pour_esquiver() -> void:
	# Le cas litigieux : « au moins 2 », donc 2 exactement doit passer.
	PlayerStats.apply_chapter_stat("adr", 1)  # 1 + 1 = 2
	PlayerStats.recompute()
	assert_eq(PlayerStats.get_stat("adr"), 2, "adresse à 2 pile")
	_forcer_des([6, 2])
	CombatEngine.roll()
	assert_true(CombatEngine.can_dodge(), "2 d'adresse permet d'esquiver")
	CombatEngine.roll_dodge()
	assert_true(CombatEngine.resolve()["esquive_reussie"], "dé 2 <= adresse 2")


func test_une_esquive_reussie_annule_les_degats_recus() -> void:
	PlayerStats.apply_chapter_stat("adr", 4)  # adresse 5, esquive sur 2..5
	PlayerStats.recompute()
	_forcer_des([6, 2])  # dé d'assaut 6, puis dé d'esquive 2
	CombatEngine.roll()
	assert_true(CombatEngine.can_dodge(), "5 d'adresse permet d'esquiver")
	CombatEngine.roll_dodge()
	var r = CombatEngine.resolve()

	assert_true(r["esquive_reussie"], "2 <= 5 : esquive réussie")
	assert_eq(r["degats_recus"], 0, "aucun dégât encaissé")
	assert_eq(r["degats_infliges"], 4, "mais on inflige quand même les siens")


func test_une_esquive_ratee_ne_coute_rien() -> void:
	PlayerStats.apply_chapter_stat("adr", 2)  # adresse 3, esquive sur 2..3
	PlayerStats.recompute()
	_forcer_des([6, 5])  # esquive ratée (5 > 3)
	CombatEngine.roll()
	CombatEngine.roll_dodge()
	var r = CombatEngine.resolve()

	assert_false(r["esquive_reussie"], "5 > 3 : esquive ratée")
	assert_eq(r["degats_recus"], 3, "on encaisse comme si on n'avait pas tenté")


func test_un_un_a_lesquive_declenche_la_contre_attaque_critique() -> void:
	PlayerStats.apply_chapter_stat("adr", 2)
	PlayerStats.apply_chapter_stat("crit", 2)
	PlayerStats.recompute()
	_forcer_des([1, 1])  # pire dé d'assaut possible, mais 1 à l'esquive
	CombatEngine.roll()
	CombatEngine.roll_dodge()
	var r = CombatEngine.resolve()

	assert_true(r["critique"], "un 1 à l'esquive est un critique")
	# Dégâts maximaux de l'écart -4 (dé 6 = 4) + 2 de critique.
	assert_eq(r["degats_infliges"], 6, "max de l'écart + dégâts critiques")
	assert_eq(r["degats_recus"], 0, "un critique n'encaisse rien")


func test_le_critique_ignore_larmure_de_lennemi() -> void:
	# On rejoue le critique contre un ennemi cuirassé : l'armure ne doit rien changer.
	CombatEngine.stop()
	CombatEngine.start(CH_COMBAT)
	CombatEngine.get_enemy()["arm"] = 3
	PlayerStats.apply_chapter_stat("adr", 2)
	PlayerStats.recompute()
	_forcer_des([1, 1])
	CombatEngine.roll()
	CombatEngine.roll_dodge()
	assert_eq(CombatEngine.resolve()["degats_infliges"], 4, "3 d'armure ignorés par le critique")


#
#    Pouvoirs de CARACTÈRE
#

func test_le_paysan_ne_subit_jamais_plus_de_trois_degats() -> void:
	AppParameters.set_billy_type('paysan')
	PlayerStats.recompute()
	_forcer_des([1])  # écart -4 dé 1 => 6 reçus, à plafonner à 3
	CombatEngine.roll()
	var r = CombatEngine.resolve()

	assert_eq(r["degats_recus"], 3, "plafonné à 3")
	assert_true("paysan" in r["pouvoirs"], "le rapport dit quel pouvoir a joué")


func test_tuer_lennemi_annule_ses_derniers_degats() -> void:
	# Coups simultanés : une arme énorme tue l'ennemi (10 pv) du premier coup, alors
	# que le dé 1 lui faisait encaisser 6 dégâts. Ces 6 ne doivent pas porter.
	PlayerStats.apply_chapter_stat("deg", 20)
	PlayerStats.recompute()
	_forcer_des([1])  # écart -4, dé 1 => [1, 6]
	var pv_depart = PlayerStats.get_pv()
	CombatEngine.roll()
	var r = CombatEngine.resolve()

	assert_eq(CombatEngine.get_enemy_pv(), 0, "l'ennemi tombe sur cet assaut")
	assert_true(r["coup_fatal_evite"], "le rapport signale les dégâts ignorés")
	assert_eq(r["degats_recus"], 0, "ses derniers dégâts sont ignorés")
	assert_eq(PlayerStats.get_pv(), pv_depart, "on ne perd rien sur l'assaut fatal")


func test_le_prudent_survit_a_un_coup_mortel_sur_un_bon_de() -> void:
	AppParameters.set_billy_type('prudent')
	PlayerStats.recompute()
	# Prudent : hab 1, écart -5 ; dé 1 => [1, 7], soit 7 encaissés pour 6 pv : mortel.
	# Chance courante 3, dé de survie 2 <= 3 : il survit.
	_forcer_des([1, 2])
	CombatEngine.roll()
	var r = CombatEngine.resolve()

	assert_eq(r["de_survie"], 2, "un dé de survie a été lancé")
	assert_true("prudent" in r["pouvoirs"], "le pouvoir a joué")
	assert_eq(PlayerStats.get_pv(), 1, "il tombe à 1 pv au lieu de mourir")


func test_le_prudent_meurt_quand_son_de_de_survie_est_trop_haut() -> void:
	AppParameters.set_billy_type('prudent')
	PlayerStats.recompute()
	_forcer_des([1, 6])  # 6 > chance 3 : le test échoue
	CombatEngine.roll()
	var r = CombatEngine.resolve()

	assert_eq(r["de_survie"], 6, "le dé de survie a bien été lancé")
	assert_false("prudent" in r["pouvoirs"], "le pouvoir n'a pas sauvé")
	assert_eq(PlayerStats.get_pv(), 0, "il tombe")


func test_seul_un_prudent_lance_un_de_de_survie() -> void:
	# Un pégu qui prend un coup mortel ne lance rien du tout.
	_forcer_des([1])
	PlayerStats.del_pv(PlayerStats.get_pv() - 1)  # 1 pv restant
	CombatEngine.roll()
	var r = CombatEngine.resolve()

	assert_eq(r["de_survie"], 0, "aucun dé de survie pour un pégu")
	assert_eq(PlayerStats.get_pv(), 0, "il tombe")


func test_seul_le_debrouillard_peut_relancer() -> void:
	_forcer_des([2])
	CombatEngine.roll()
	assert_false(CombatEngine.can_reroll(), "un pégu ne relance pas")

	AppParameters.set_billy_type('debrouillard')
	PlayerStats.recompute()
	_forcer_des([2, 5])
	CombatEngine.roll()
	assert_true(CombatEngine.can_reroll(), "le débrouillard peut relancer")
	assert_eq(CombatEngine.reroll(), 5, "le nouveau dé remplace l'ancien")
	assert_false(CombatEngine.can_reroll(), "une seule relance par assaut")


#
#    Fuite et issues
#

func test_fuir_coute_de_la_chance_selon_la_situation() -> void:
	# Situation « Désavantage » => 3 points. Un pégu neuf a chamax 3.
	assert_eq(CombatEngine.get_fuite_cost(), 3, "coût de la situation")
	assert_true(CombatEngine.can_fuir(), "3 de chance disponibles")
	assert_true(CombatEngine.fuir(), "la fuite aboutit")
	assert_eq(PlayerStats.get_cha(), 0, "les 3 points sont dépensés")
	assert_false(CombatEngine.is_running(), "le combat est terminé")


func test_on_ne_peut_pas_fuir_sans_assez_de_chance() -> void:
	PlayerStats.del_chance(3)
	assert_false(CombatEngine.can_fuir(), "0 de chance, coût 3")
	assert_false(CombatEngine.fuir(), "la fuite est refusée")
	assert_true(CombatEngine.is_running(), "le combat continue")


func test_la_victoire_part_quand_lennemi_tombe() -> void:
	var gagne = [false]
	var recepteur := func(): gagne[0] = true
	CombatEngine.combat_won.connect(recepteur)
	# 10 pv d'ennemi, 4 dégâts par assaut au dé 6 : trois assauts suffisent.
	_forcer_des([6])
	for _i in range(3):
		CombatEngine.roll()
		CombatEngine.resolve()

	assert_eq(CombatEngine.get_enemy_pv(), 0, "les pv de l'ennemi ne passent pas sous zéro")
	assert_true(gagne[0], "combat_won a été émis")
	CombatEngine.combat_won.disconnect(recepteur)


#
#    Annulation du combat
#

func test_annuler_le_combat_ramene_au_chapitre_davant_avec_les_pv_davant() -> void:
	# On construit un vrai historique : chapitre 1, puis le chapitre de combat.
	CombatEngine.stop()
	Player.go_to_node(1)
	var pv_avant = PlayerStats.get_pv()
	var cha_avant = PlayerStats.get_cha()
	Player.go_to_node(CH_COMBAT)
	assert_true(CombatEngine.start(CH_COMBAT), "le combat démarre")

	# On se fait amocher, puis on annule tout.
	_forcer_des([1])
	CombatEngine.roll()
	CombatEngine.resolve()
	assert_true(PlayerStats.get_pv() < pv_avant, "on a bien encaissé avant d'annuler")

	assert_true(CombatEngine.can_cancel(), "il y a un chapitre où revenir")
	assert_true(CombatEngine.cancel(), "l'annulation aboutit")

	assert_eq(Player.get_current_node_id(), 1, "on est revenu au chapitre d'avant")
	assert_eq(PlayerStats.get_pv(), pv_avant, "les pv d'avant sont revenus")
	assert_eq(PlayerStats.get_cha(), cha_avant, "la chance d'avant est revenue")
	assert_false(CombatEngine.is_running(), "le combat est terminé")


func test_on_ne_peut_pas_annuler_sans_chapitre_ou_revenir() -> void:
	# Un Billy neuf au chapitre 1 n'a nulle part où reculer.
	CombatEngine.stop()
	Player.launch_new_billy()
	Player.go_to_node(CH_COMBAT)
	CombatEngine.start(CH_COMBAT)
	# `launch_new_billy` a vidé le fil d'Ariane : le combat est le seul chapitre.
	assert_false(CombatEngine.can_cancel(), "rien où revenir, le bouton doit être grisé")
	assert_false(CombatEngine.cancel(), "l'annulation est refusée")


func test_annuler_repose_les_objets_portes() -> void:
	CombatEngine.stop()
	Player.go_to_node(1)
	Inventory.add_item_from_options('EPEE')
	var items_avant = Inventory.get_possessed_items().duplicate()
	Player.go_to_node(CH_COMBAT)
	CombatEngine.start(CH_COMBAT)

	Inventory.add_item_from_options('COUTEAU')
	assert_true('COUTEAU' in Inventory.get_possessed_items(), "l'objet a bien été pris")

	CombatEngine.cancel()
	assert_eq(Inventory.get_possessed_items(), items_avant, "l'inventaire d'avant est reposé")


func test_un_marqueur_a_99_nest_pas_automatisable() -> void:
	assert_true(CombatEngine.is_sentinelle({"hab": 99, "pv": 99, "arm": 99, "deg": 99}),
		"tout à 99 = marqueur du livre")
	assert_false(CombatEngine.is_sentinelle({"hab": 10, "pv": 99, "arm": 0, "deg": 0}),
		"un seul 99 ne suffit pas")


func test_les_six_champs_de_lennemi_sont_lus() -> void:
	# « Ne pas oublier les stats ennemies » : les six champs du livre doivent arriver
	# dans le moteur, en entiers.
	var enemy = CombatEngine.read_enemy(CH_COMBAT)
	assert_eq(enemy["nom"], "ORC ESCLAVAGISTE", "nom")
	assert_eq(enemy["hab"], 10, "habileté")
	assert_eq(enemy["pv"], 10, "pv")
	assert_eq(enemy["arm"], 0, "armure")
	assert_eq(enemy["deg"], 0, "dégâts")
	assert_eq(enemy["pyro"], 4, "bonus pyro")


func test_larmure_de_lennemi_reduit_les_degats_infliges() -> void:
	# écart -4, dé 6 => 4 infligés, moins 3 d'armure ennemie = 1.
	CombatEngine.get_enemy()["arm"] = 3
	_forcer_des([6])
	CombatEngine.roll()
	assert_eq(CombatEngine.resolve()["degats_infliges"], 1, "4 - 3 d'armure ennemie")


func test_les_degats_de_lennemi_sajoutent_a_ce_quon_encaisse() -> void:
	# écart -4, dé 6 => 3 reçus, plus 2 de dégâts d'arme ennemie = 5.
	CombatEngine.get_enemy()["deg"] = 2
	_forcer_des([6])
	CombatEngine.roll()
	assert_eq(CombatEngine.resolve()["degats_recus"], 5, "3 de la frise + 2 de deg ennemi")


func test_un_combat_non_automatisable_nest_ni_gagne_ni_perdu() -> void:
	# Le moteur refuse de le mener, et surtout n'émet aucune issue : c'est à
	# l'interface de passer en mode manuel (combat.md §3.11).
	var issues = []
	var perdu := func(): issues.append("perdu")
	var gagne := func(): issues.append("gagne")
	CombatEngine.combat_lost.connect(perdu)
	CombatEngine.combat_won.connect(gagne)

	assert_false(CombatEngine.is_automatable(1), "le chapitre 1 n'a pas de combat")
	assert_false(CombatEngine.start(1), "start refuse")
	assert_eq(issues, [], "aucune issue n'a été déclarée")

	CombatEngine.combat_lost.disconnect(perdu)
	CombatEngine.combat_won.disconnect(gagne)
