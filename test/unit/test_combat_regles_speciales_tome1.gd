extends "res://addons/gut/test.gd"

# Tests ECRITS AVANT L'IMPLEMENTATION (TDD demande explicitement) pour les
# regles speciales du Tome 1 cataloguees dans COMBATS_REGLES_SPECIALES.md.
# combat_modificateurs.gd ne contient que des SQUELETTES (methodes
# presentes, logique pas codee) -- ces tests doivent donc ECHOUER pour
# l'instant (rouge intentionnel), pas planter a la compilation. Une fois
# combat_modificateurs.gd rempli pour de vrai, ils doivent passer sans
# qu'on ait besoin de les retoucher.
#
# Chaque test cite le numero de nœud et la regle exacte (cf
# COMBATS_REGLES_SPECIALES.md) pour qu'on puisse toujours retrouver la
# source. Les regles qui n'ont besoin d'AUCUN nouveau code (malus fixes
# -1 Adresse, plancher d'Habileté, override d'objet...) ne sont PAS
# testees ici : elles sont documentees comme "cote appelant" dans le
# catalogue, rien a verrouiller dans combat.gd/combat_modificateurs.gd.

var CombatScript = preload('res://combat.gd')
var Mods = preload('res://combat_modificateurs.gd')


# =========================================================================
# EsquiveAdverseSurDe -- nœuds 173, 175, 320 (partiel), 321, 574 (partiel)
# =========================================================================

func test_node173_bandit_esquive_sur_jet_de_1_ou_2():
	# "Sur un jet de 1 ou 2 durant la phase d'attaque, le bandit esquive
	# votre coup (aucun dégât) et esquive aussi votre contre-attaque
	# critique le cas échéant."
	var mod = Mods.EsquiveAdverseSurDe.new(func(d): return d == 1 or d == 2)
	var combat = CombatScript.new(6, 6, 20, 10, {"modificateurs": [mod]})
	var t = combat.play_turn(1)  # attaque=1 -> doit esquiver
	assert_eq(t.degats_billy, 0, "le bandit esquive, Billy n'inflige aucun degat")


func test_node173_bandit_esquive_meme_avec_une_contre_attaque_critique():
	var mod = Mods.EsquiveAdverseSurDe.new(func(d): return d == 1 or d == 2)
	var combat = CombatScript.new(6, 6, 20, 10, {"modificateurs": [mod], "adresse_billy": 3, "critique_billy": 5})
	var t = combat.play_turn(1, 1)  # attaque=1 (esquive adverse) + esquive Billy=1 (contre-attaque)
	assert_eq(t.degats_billy, 0, "l'esquive adverse annule meme la contre-attaque critique")


func test_node173_bandit_ne_esquive_pas_au_dela_de_2():
	var mod = Mods.EsquiveAdverseSurDe.new(func(d): return d == 1 or d == 2)
	var combat = CombatScript.new(6, 6, 20, 10, {"modificateurs": [mod]})
	var t = combat.play_turn(3)  # attaque=3 -> pas d'esquive adverse
	assert_gt(t.degats_billy, 0, "au-dela de 1 ou 2, le bandit ne esquive plus")


func test_node175_elfes_esquivent_sur_die_pair():
	# "si le dé de la phase d'attaque donne un résultat PAIR, elles
	# esquivent (aucun dégât, y compris contre-attaque critique)."
	var mod = Mods.EsquiveAdverseSurDe.new(func(d): return d % 2 == 0)
	var combat = CombatScript.new(11, 11, 20, 8, {"modificateurs": [mod]})
	var t_pair = combat.play_turn(4)
	assert_eq(t_pair.degats_billy, 0)


func test_node175_elfes_nesquivent_pas_sur_die_impair():
	var mod = Mods.EsquiveAdverseSurDe.new(func(d): return d % 2 == 0)
	var combat = CombatScript.new(11, 11, 20, 8, {"modificateurs": [mod]})
	var t_impair = combat.play_turn(3)
	assert_gt(t_impair.degats_billy, 0)


func test_node321_elfes_surprises_esquivent_sur_die_impair():
	# Miroir exact de 175 mais IMPAIR au lieu de PAIR (nœuds distincts,
	# meme modificateur, predicat different).
	var mod = Mods.EsquiveAdverseSurDe.new(func(d): return d % 2 == 1)
	var combat = CombatScript.new(9, 9, 20, 6, {"modificateurs": [mod]})
	var t = combat.play_turn(3)
	assert_eq(t.degats_billy, 0)


func test_node574_elfes_nues_esquivent_sur_un_6_exactement():
	# "sur un jet de 6, elle esquivent totalement votre attaque, y compris
	# sur une contre attaque critique"
	var mod = Mods.EsquiveAdverseSurDe.new(func(d): return d == 6)
	var combat = CombatScript.new(6, 6, 20, 10, {"modificateurs": [mod]})
	var t6 = combat.play_turn(6)
	assert_eq(t6.degats_billy, 0)
	var t5 = combat.play_turn(5)
	assert_gt(t5.degats_billy, 0, "seul le 6 declenche l'esquive, pas le 5")


# =========================================================================
# BonusDegatsAdversaireSurDe -- nœuds 574, 320
# =========================================================================

func test_node574_bonus_3_degats_sur_un_jet_de_1():
	# "si vous obtenez un 1 durant votre phase d'attaque, elle gagne +3
	# dégats pour ce tour"
	var mod = Mods.BonusDegatsAdversaireSurDe.new([1], 3)
	var combat = CombatScript.new(6, 6, 20, 10, {"modificateurs": [mod]})
	var sans_bonus = CombatScript.resolve_round(6, 6, 1)['degats_adversaire']
	var t = combat.play_turn(1)
	assert_eq(t.degats_adversaire, sans_bonus + 3)


func test_node574_pas_de_bonus_sur_un_autre_jet():
	var mod = Mods.BonusDegatsAdversaireSurDe.new([1], 3)
	var combat = CombatScript.new(6, 6, 20, 10, {"modificateurs": [mod]})
	var sans_bonus = CombatScript.resolve_round(6, 6, 2)['degats_adversaire']
	var t = combat.play_turn(2)
	assert_eq(t.degats_adversaire, sans_bonus, "le bonus ne s'applique que sur un jet de 1")


func test_node320_funeste_bonus_2_degats_sur_1_cumule_avec_lesquive():
	# "Si le résultat est exactement 1, en plus d'esquiver, sa propre
	# contre-attaque lui donne +2 dégâts ce tour-là." -- die=1 declenche
	# DEUX effets a la fois : esquive (via EsquiveAdverseSurDe, impair) ET
	# +2 degats (via BonusDegatsAdversaireSurDe).
	var esquive = Mods.EsquiveAdverseSurDe.new(func(d): return d % 2 == 1)
	var bonus = Mods.BonusDegatsAdversaireSurDe.new([1], 2)
	var combat = CombatScript.new(8, 8, 20, 12, {"modificateurs": [esquive, bonus]})
	var sans_bonus = CombatScript.resolve_round(8, 8, 1)['degats_adversaire']
	var t = combat.play_turn(1)
	assert_eq(t.degats_billy, 0, "die=1 est impair -> Funeste esquive aussi")
	assert_eq(t.degats_adversaire, sans_bonus + 2, "et gagne +2 degats ce tour")


# =========================================================================
# LimiteDeTours -- nœuds 36, 97 (defaite si non gagne a temps), 607 (victoire si survie)
# =========================================================================

func test_node36_defaite_si_massacre_pas_vaincu_en_5_tours():
	# "Si non surpris, vous ne disposez que de 5 tours. À l'issue de cette
	# limite de temps, ses renforts vous encerclent et vous achèvent."
	var mod = Mods.LimiteDeTours.new(5, "adversaire")
	# pv_billy=200 (au lieu de 20) : avec hab_billy=1/hab_adversaire=20
	# (diff=-19, clampe a -7), die=3 -> table[-7][2] infligent 8 PV/tour a
	# Billy -- sans cette marge, Billy meurt de degats normaux avant le
	# 5eme tour, ce qui masquerait completement la limite de tours testee
	# ici (pv_adversaire=100 le rend increvable de son cote).
	var combat = CombatScript.new(1, 20, 200, 100, {"modificateurs": [mod]})
	for i in range(5):
		combat.play_turn(3)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "adversaire", "le delai de 5 tours est ecoule, les renforts achevent Billy")


func test_node36_pas_de_defaite_avant_la_limite():
	var mod = Mods.LimiteDeTours.new(5, "adversaire")
	var combat = CombatScript.new(1, 20, 200, 100, {"modificateurs": [mod]})
	for i in range(4):
		combat.play_turn(3)
	assert_false(combat.is_over(), "pas encore au 5eme tour")


func test_node36_8_tours_si_massacre_surpris():
	# "Si vous avez surpris MASSACRE avec vos INFOS, vous disposez de 8
	# tours" -- meme mecanique, parametre different (calcule cote
	# appelant selon si le joueur a assez d'INFOS).
	var mod = Mods.LimiteDeTours.new(8, "adversaire")
	var combat = CombatScript.new(1, 20, 200, 100, {"modificateurs": [mod]})
	for i in range(7):
		combat.play_turn(3)
	assert_false(combat.is_over(), "surpris, la limite est repoussee a 8 tours")
	combat.play_turn(3)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "adversaire")


func test_node607_victoire_si_billy_survit_8_tours():
	# "Survivez 8 tours ou remportez ce combat pour gagner" -- ici
	# l'inverse de 36/97 : le delai favorise BILLY, pas l'adversaire.
	var mod = Mods.LimiteDeTours.new(8, "billy")
	var combat = CombatScript.new(9, 24, 100, 20, {"modificateurs": [mod]})  # Billy increvable ici (100 PV), pour isoler la survie
	for i in range(8):
		combat.play_turn(1)  # jets faibles : Virilus ne devrait pas etre vaincu par les degats seuls
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy", "8 tours survecus, victoire meme si Virilus a encore des PV")


# =========================================================================
# HabiliteAdverseDegressiveParDegatsCumules -- nœuds 76, 155, 231, 370, 518
# =========================================================================

func test_node76_habilete_squelettes_baisse_tous_les_4_pv_infliges():
	# "Tous les 4 PV retirés à l'adversaire, l'ennemi perd 1 HABILETE."
	# PV adversaire volontairement genereux (100) pour que le combat ne se
	# termine jamais tout seul pendant qu'on verifie la mecanique.
	var mod = Mods.HabiliteAdverseDegressiveParDegatsCumules.new(4, 1)
	var combat = CombatScript.new(9, 12, 30, 100, {"modificateurs": [mod]})
	var hab_avant = combat.hab_adversaire
	# diff=-3, die=6 -> table[-3][5]=[4,3] : 4 degats infliges en un seul
	# tour, exactement le seuil (pas besoin de plusieurs tours).
	var t1 = combat.play_turn(6)
	assert_eq(t1.degats_billy, 4)
	assert_eq(combat.hab_adversaire, hab_avant, "le champ permanent ne change jamais")
	# Jet DIFFERENT choisi pour que diff=-3 et diff=-2 donnent des
	# degats_billy DIFFERENTS (3 contre 4) -- sans quoi un squelette de test
	# non implemente (qui ne fait jamais baisser l'Habileté) pourrait
	# donner par coincidence le meme chiffre que la version implementee.
	var t2 = combat.play_turn(5)  # sans baisse : table[-3][4]=[3,3]->3 ; avec 1 palier : table[-2][4]=[4,3]->4
	assert_eq(t2.degats_billy, 4,
		"apres >=4 PV cumules infliges, l'Habileté adverse effective a baisse de 1 (diff -3 -> -2)")


func test_node231_meme_mecanique_hommes_darmes():
	# Meme regle que 76/155, nœud different ("4 HOMMES D'ARMES").
	var mod = Mods.HabiliteAdverseDegressiveParDegatsCumules.new(4, 1)
	var combat = CombatScript.new(9, 11, 30, 100, {"deg_billy": 2, "modificateurs": [mod]})
	var t1 = combat.play_turn(6)  # diff=-2, die=6 -> table[-2][5]=[5,3] + 2 DEGATS = 7 (>= seuil de 4)
	assert_eq(t1.degats_billy, 7)
	# Jet=1 choisi pour distinguer sans ambiguite diff=-2 (table[-2][0]=2)
	# de diff=-1 (table[-1][0]=3), une fois le DEGATS (+2) ajoute : 4 contre 5.
	var t2 = combat.play_turn(1)
	assert_eq(t2.degats_billy, 5, "l'Habileté adverse effective a baisse d'au moins 1 apres les degats cumules")


func test_node370_habilete_baisse_tous_les_2_pv():
	# "tous les 2 PV perdus par l'ennemi lui fait perdre 1 point habileté"
	# -- meme mecanique que 76, pas different (2 au lieu de 4).
	var mod = Mods.HabiliteAdverseDegressiveParDegatsCumules.new(2, 1)
	var combat = CombatScript.new(9, 16, 30, 100, {"modificateurs": [mod]})
	var t1 = combat.play_turn(6)  # diff=-7, die=6 -> table[-7][5]=[3,4] : 3 degats infliges (>= seuil de 2)
	assert_eq(t1.degats_billy, 3)
	var t2 = combat.play_turn(1)  # sans baisse : diff=-7, table[-7][0]=[0,12]->0 ; avec 1 palier : diff=-6, table[-6][0]=[1,8]->1
	assert_eq(t2.degats_billy, 1, "apres >=2 PV cumules, l'Habileté adverse effective a baisse de 1 (diff -7 -> -6)")


# =========================================================================
# AdresseBillyProgressiveParDegatsCumules -- nœuds 370, 518
# =========================================================================

func test_node370_adresse_regagnee_tous_les_10_pv_infliges():
	# "regagnez 1 adresse tous les 10 PVs perdus par l'ennemi" (en plus du
	# malus -3 initial d'encerclement, cote appelant). Ici adresse_billy de
	# base = 0 (deja sous le seuil de 2 necessaire a l'esquive) : il faut
	# 2 paliers de 10 PV (20 PV cumules) pour que l'esquive redevienne
	# possible -- verifiable sans ambiguite via un jet d'esquive fourni.
	var mod = Mods.AdresseBillyProgressiveParDegatsCumules.new(10, 1)
	# pv_billy tres genereux (200) : le diff est defavorable a Billy (-7),
	# donc il encaisse aussi beaucoup en attendant d'accumuler 20 PV
	# infliges.
	var combat = CombatScript.new(9, 16, 200, 100, {"adresse_billy": 0, "modificateurs": [mod]})
	var adresse_avant = combat.adresse_billy
	for i in range(4):
		combat.play_turn(6)  # diff=-7, die=6 -> 3 degats/tour, 4 tours = 12 PV cumules (1 palier de 10 atteint)
	assert_true(-combat.get_pv_delta_adversaire() >= 10 and -combat.get_pv_delta_adversaire() < 20)
	assert_eq(combat.adresse_billy, adresse_avant, "le champ permanent ne change jamais")
	var t_pas_encore = combat.play_turn(3, 2)  # jet d'esquive=2 ; adresse effective = 0+1 = 1, encore <2
	assert_false(t_pas_encore.esquive, "un seul palier de 10 atteint (adresse effective=1), pas encore d'esquive possible")
	for i in range(3):
		combat.play_turn(6)  # 3 tours supplementaires = 9 PV de plus, total >=20 PV cumules (2 paliers)
	var t_esquive = combat.play_turn(3, 2)  # meme jet d'esquive=2 ; adresse effective = 0+2 = 2 desormais
	assert_true(t_esquive.esquive, "apres >=20 PV cumules infliges, l'Adresse effective de Billy = 2, l'esquive redevient possible")


# =========================================================================
# DegatsPeriodiques -- nœuds 97 (brasier), 286 (DoT), 576 (explosion)
# =========================================================================

func test_node97_brasier_tous_les_3_tours_apres_degats_normaux():
	# "Tous les 3 tours, Massacre invoque un trait de flamme qui vous fait
	# perdre 3 PV à la fin du tour, après application des dommages
	# normaux."
	var mod = Mods.DegatsPeriodiques.new(3, 3, "billy", false, false)
	var combat = CombatScript.new(9, 12, 30, 20, {"deg_billy": 2, "modificateurs": [mod]})
	combat.play_turn(3)
	combat.play_turn(3)
	var t3 = combat.play_turn(3)  # 3eme tour -> le brasier se declenche
	assert_eq(t3.degats_supplementaires_adversaire, 3,
		"le brasier inflige 3 PV supplementaires distincts des degats normaux du tour")


func test_node97_brasier_touche_meme_un_paysan_malgre_son_plafond():
	# "ce qui veut dire que si vous etes paysan, vous subirez quand même
	# ces dommages malgré votre résistance" -- le brasier IGNORE le
	# plafond_degats_subis_billy general (3 PV/tour du PAYSAN), contrairement
	# aux degats normaux de ce meme tour.
	var mod = Mods.DegatsPeriodiques.new(3, 3, "billy", false, false)
	var combat = CombatScript.new(4, 12, 30, 20, {"plafond_degats_subis_billy": 3, "modificateurs": [mod]})
	combat.play_turn(1)
	combat.play_turn(1)
	var t3 = combat.play_turn(1)
	assert_eq(t3.degats_supplementaires_adversaire, 3, "le brasier n'est pas plafonne par le pouvoir du PAYSAN")


func test_node97_brasier_esquive_ratee_inflige_les_degats():
	# Contrepartie indispensable du test "esquive reussie" ci-dessous :
	# sans un cas ou l'esquive du brasier RATE, impossible de distinguer
	# "le brasier est bien esquivable" de "le brasier ne s'applique jamais".
	var mod = Mods.DegatsPeriodiques.new(3, 3, "billy", true, false)
	var combat = CombatScript.new(9, 12, 30, 20, {"adresse_billy": 3, "modificateurs": [mod]})
	combat.play_turn(3, 3)
	combat.play_turn(3, 3)
	var t3 = combat.play_turn(3, 5)  # jet d'esquive du brasier = 5 > Adresse (3) -> rate
	assert_eq(t3.degats_supplementaires_adversaire, 3, "esquive du brasier ratee, les 3 PV s'appliquent")


func test_node97_brasier_esquive_reussie_annule_les_degats():
	# "Vous pouvez tenter de l'esquiver comme une attaque normale si vous
	# disposez d'assez d'adresse."
	var mod = Mods.DegatsPeriodiques.new(3, 3, "billy", true, false)
	var combat = CombatScript.new(9, 12, 30, 20, {"adresse_billy": 3, "modificateurs": [mod]})
	combat.play_turn(3, 3)
	combat.play_turn(3, 3)
	var t3 = combat.play_turn(3, 2)  # jet d'esquive du brasier = 2 <= Adresse (3) -> reussi
	assert_eq(t3.degats_supplementaires_adversaire, 0, "esquive du brasier reussie, aucun degat")


func test_node97_brasier_esquive_reussie_sur_un_1_ne_donne_jamais_de_contre_attaque_critique():
	# "SANS TOUTEFOIS pouvoir effectuer de contre attaque critique sur
	# cette esquive" -- meme un jet de 1 (qui declenche normalement une
	# contre-attaque critique sur l'esquive PRINCIPALE) ne doit rien
	# infliger de plus ici.
	var mod = Mods.DegatsPeriodiques.new(3, 3, "billy", true, false)
	var combat = CombatScript.new(9, 12, 30, 20, {"adresse_billy": 3, "modificateurs": [mod]})
	combat.play_turn(3, 3)
	combat.play_turn(3, 3)
	var t3 = combat.play_turn(3, 1)  # jet d'esquive du brasier = 1
	assert_eq(t3.degats_supplementaires_adversaire, 0, "esquive reussie")
	assert_eq(t3.degats_supplementaires_billy, 0, "jamais de contre-attaque critique sur ce jet-la, meme sur un 1")


func test_node286_1pv_perdu_automatiquement_chaque_tour():
	# "Entre chaque tour, les spores acide qui s'échappent de ses feuilles
	# vous font perdre automatiquement 1 POINT DE VIE." -- non esquivable,
	# tous les tours (intervalle=1), pas juste une fois.
	var mod = Mods.DegatsPeriodiques.new(1, 1, "billy", false, false)
	var combat = CombatScript.new(6, 13, 30, 18, {"pyro_bonus": 7, "modificateurs": [mod]})
	var t = combat.play_turn(3)
	assert_eq(t.degats_supplementaires_adversaire, 1)
	var t2 = combat.play_turn(3)
	assert_eq(t2.degats_supplementaires_adversaire, 1, "se repete chaque tour, pas juste le premier")


func test_node576_explosion_10pv_au_tour_3_non_esquivable():
	# "À la fin du 3ᵉ tour, il explose : perte de 10 PV, non esquivable et
	# non affecté par l'Armure." -- une seule fois (pas periodique).
	var mod = Mods.DegatsPeriodiques.new(3, 10, "billy", false, true)  # une_seule_fois=true
	var combat = CombatScript.new(6, 6, 30, 15, {"armure_billy": 5, "modificateurs": [mod]})
	combat.play_turn(3)
	combat.play_turn(3)
	var t3 = combat.play_turn(3)
	assert_eq(t3.degats_supplementaires_adversaire, 10, "l'Armure (5) ne reduit pas l'explosion")
	var t4 = combat.play_turn(3)
	assert_eq(t4.degats_supplementaires_adversaire, 0, "une seule fois, pas au tour 4")


func test_node576_explosion_plafonnee_a_3_pour_un_paysan():
	# "Un PAYSAN ne subit que 3 PV" -- valeur calculee cote appelant
	# (selon l'archetype), PAS devinee par le modificateur lui-meme.
	var mod = Mods.DegatsPeriodiques.new(3, 3, "billy", false, true)  # degats=3 fourni par l'appelant pour un PAYSAN
	var combat = CombatScript.new(4, 6, 30, 15, {"modificateurs": [mod]})
	combat.play_turn(1)
	combat.play_turn(1)
	var t3 = combat.play_turn(1)
	assert_eq(t3.degats_supplementaires_adversaire, 3)


func test_node576_explosion_plafonnee_a_5_pour_un_prudent():
	var mod = Mods.DegatsPeriodiques.new(3, 5, "billy", false, true)  # degats=5 pour un PRUDENT
	var combat = CombatScript.new(1, 6, 30, 15, {"modificateurs": [mod]})
	combat.play_turn(1)
	combat.play_turn(1)
	var t3 = combat.play_turn(1)
	assert_eq(t3.degats_supplementaires_adversaire, 5)


# =========================================================================
# SeuilPV -- nœuds 232, 555 (double degats), 240, 350 (fin de combat)
# =========================================================================

func test_node232_ogre_double_ses_degats_a_10pv_ou_moins():
	# "lors ses PV sont à 10 ou moins, il DOUBLE ses DEGATS sur la table
	# des situations"
	var mod = Mods.SeuilPV.new(10, "double_degats_adversaire")
	var combat = CombatScript.new(9, 10, 30, 11, {"modificateurs": [mod]})
	var t1 = combat.play_turn(6)  # adversaire encore > 10 PV avant ce coup -- pas de doublement CE tour
	var normal = CombatScript.resolve_round(9, 10, 6)['degats_adversaire']
	assert_eq(t1.degats_adversaire, normal, "adversaire au-dessus du seuil avant ce tour, degats normaux")
	var t2 = combat.play_turn(3)  # desormais sous 10 PV
	var normal2 = CombatScript.resolve_round(9, 10, 3)['degats_adversaire']
	assert_eq(t2.degats_adversaire, normal2 * 2, "sous le seuil, les degats sont doubles")


func test_node555_ogre_double_ses_degats_sous_10pv_strict():
	# "Dès que les PV de votre adversaire passent sous 10 (inclus)" --
	# meme mecanique que 232, seuil legerement different dans le libelle
	# mais identique numeriquement (<=10 dans les deux cas d'apres le
	# texte du livre).
	var mod = Mods.SeuilPV.new(10, "double_degats_adversaire")
	var combat = CombatScript.new(9, 10, 30, 10, {"modificateurs": [mod]})
	var t = combat.play_turn(3)
	var normal = CombatScript.resolve_round(9, 10, 3)['degats_adversaire']
	assert_eq(t.degats_adversaire, normal * 2, "10 PV exactement -> deja sous le seuil (inclusif)")


func test_node240_guepe_fin_de_combat_a_3pv_ou_moins():
	# "Lorsque la créature atteint 3 PV ou moins, mettez fin du combat."
	var mod = Mods.SeuilPV.new(3, "fin_combat_victoire")
	var combat = CombatScript.new(9, 8, 30, 10, {"modificateurs": [mod]})
	combat.play_turn(3)  # descend a 10-3=7, pas encore sous le seuil
	assert_false(combat.is_over())
	combat.play_turn(6)  # gros degats, adversaire devrait tomber a 3 ou moins
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy", "fin de combat forcee, pas besoin d'atteindre 0 PV")


func test_node350_dragon_fin_de_combat_a_20pv_ou_moins():
	# diff=9+3(pyro)-15=-3, die=6 -> table[-3][5]=[4,3] : 4 degats/tour.
	# 5 tours = exactement 20 PV infliges sur les 40 du dragon -- SANS le
	# modificateur, il resterait 20 PV (>0, combat pas fini). Le seuil
	# doit forcer la fin ici, pas une depletion naturelle (qui prendrait
	# 10 tours) : la boucle s'arrete volontairement a 5, bien avant.
	var mod = Mods.SeuilPV.new(20, "fin_combat_victoire")
	var combat = CombatScript.new(9, 15, 40, 40, {"pyro_bonus": 3, "modificateurs": [mod]})
	for i in range(5):
		combat.play_turn(6)
	assert_eq(combat.pv_adversaire, 20, "exactement au seuil, PAS a 0 -- la fin doit venir du seuil, pas des PV")
	assert_true(combat.is_over(), "le seuil de 20 PV doit forcer la fin du combat des ce tour")
	assert_eq(combat.get_winner(), "billy")


# =========================================================================
# ImmuniteContreAttaqueCritique -- nœuds 276, 475/607 (Virilus)
# =========================================================================

func test_node276_trolesse_immunisee_contre_la_contre_attaque_critique():
	# "ne subit jamais de coup critique. Si un coup critique est obtenu
	# lors de la phase d'esquive, aucun dégât n'est infligé (esquive
	# simple, pas de contre-attaque)."
	var mod = Mods.ImmuniteContreAttaqueCritique.new()
	var combat = CombatScript.new(6, 6, 20, 8, {"adresse_billy": 3, "critique_billy": 10, "modificateurs": [mod]})
	var t = combat.play_turn(3, 1)  # esquive Billy = 1 -> devrait normalement etre critique
	assert_true(t.esquive)
	assert_eq(t.degats_billy, 0, "immunite totale : meme le degat de base du coup critique est annule")


func test_node475_virilus_insensible_aux_critiques():
	var mod = Mods.ImmuniteContreAttaqueCritique.new()
	var combat = CombatScript.new(9, 30, 20, 40, {"adresse_billy": 3, "critique_billy": 10, "modificateurs": [mod]})
	var t = combat.play_turn(3, 1)
	assert_eq(t.degats_billy, 0)


# =========================================================================
# ContreAttaqueCritiqueSansBonusCritique -- nœud 162
# =========================================================================

func test_node162_contre_attaque_critique_sans_le_bonus_de_critique():
	# "En cas de coup critique normal, votre bonus de CRITIQUE ne
	# s'applique pas. Si une contre-attaque critique est déclenchée...
	# elle n'inflige que les dégâts maximum de la situation (sans le
	# bonus Critique)."
	var mod = Mods.ContreAttaqueCritiqueSansBonusCritique.new()
	var combat = CombatScript.new(11, 11, 20, 12, {"adresse_billy": 3, "critique_billy": 10, "modificateurs": [mod]})
	var degats_max = CombatScript.resolve_round(11, 11, 6)['degats_billy']
	var t = combat.play_turn(3, 1)
	assert_true(t.contre_attaque_critique)
	assert_eq(t.degats_billy, degats_max, "degats maximum SANS le bonus de Critique (10) ajoute")


# =========================================================================
# RegenerationSurDe -- nœud 339 (vampiresse / ASMODIA)
# =========================================================================

func test_node339_vampiresse_regenere_sur_1_ou_2():
	# "Si votre dé fait un 1 ou un 2 durant votre phase d'attaque, elle ne
	# prends aucun dégât et regnère 1 point de vie." -- hab choisis pour
	# que degats_billy soit NATURELLEMENT non-nul sur ce jet (diff=7,
	# die=1 -> table[7][0]=4), pour que "0 degat" prouve reellement que la
	# regeneration a coupe l'attaque, pas juste une coincidence de table.
	var mod = Mods.RegenerationSurDe.new([1, 2], 1, false)
	var combat = CombatScript.new(15, 5, 20, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(1)
	assert_eq(t.degats_billy, 0, "die=1 -> regeneration, alors que 4 degats seraient infliges normalement")
	assert_eq(combat.pv_adversaire, 21, "regenere 1 PV au lieu d'en perdre 4")


func test_node339_regeneration_desactivee_par_le_medaillon():
	# "si vous avez le petit medaillon d'Atella ou le medallon de RUNIR,
	# sa régénération est annulée." -- avec la desactivation, le
	# comportement doit redevenir un combat tout a fait normal (4 degats
	# infliges, pas de regen), pas juste "different de 21".
	var mod = Mods.RegenerationSurDe.new([1, 2], 1, true)  # desactivee=true (le joueur a le medaillon)
	var combat = CombatScript.new(15, 5, 20, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(1)
	assert_eq(t.degats_billy, 4, "medaillon possede : degats normaux (4), pas de regeneration")
	assert_eq(combat.pv_adversaire, 16, "PV bien reduits de 4, pas de regen malgre le jet de 1")


func test_node339_pas_de_regeneration_sur_un_autre_jet():
	var mod = Mods.RegenerationSurDe.new([1, 2], 1, false)
	var combat = CombatScript.new(15, 5, 20, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(5)
	assert_gt(t.degats_billy, 0, "jet de 5 -> degats normaux, pas de regeneration")


# =========================================================================
# SansAttaqueTour -- nœuds 321, 349
# =========================================================================

func test_node321_pas_dattaque_adverse_au_premier_tour():
	# "Entrée spectaculaire : l'ennemi n'attaque pas au premier tour."
	var mod = Mods.SansAttaqueTour.new(1)
	var combat = CombatScript.new(9, 9, 20, 6, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_adversaire, 0, "premier tour, aucune attaque adverse")


func test_node321_attaque_normale_a_partir_du_deuxieme_tour():
	var mod = Mods.SansAttaqueTour.new(1)
	var combat = CombatScript.new(9, 9, 20, 6, {"modificateurs": [mod]})
	combat.play_turn(3)
	var t2 = combat.play_turn(3)
	var normal = CombatScript.resolve_round(9, 9, 3)['degats_adversaire']
	assert_eq(t2.degats_adversaire, normal, "deuxieme tour, attaque normale")


func test_node349_massacre_squelette_lent_pas_dattaque_premier_tour():
	# "Il est LENT et n'attaque pas au premier tour." -- meme mecanique
	# que 321, nœud different (Massacre revenu en squelette).
	var mod = Mods.SansAttaqueTour.new(1)
	var combat = CombatScript.new(9, 13, 20, 18, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_adversaire, 0)


# =========================================================================
# MalusHabiliteAdversePremierTourSeulement -- nœud 575
# =========================================================================

func test_node575_gnoll_endormi_malus_2_habilete_premier_tour_seulement():
	# "L'ennemi a un malus de -2 Habileté durant le premier tour
	# uniquement (surprise, il dort)."
	var mod = Mods.MalusHabiliteAdversePremierTourSeulement.new(2)
	var combat = CombatScript.new(6, 6, 20, 12, {"modificateurs": [mod], "pyro_bonus": 4})
	var t1 = combat.play_turn(3)
	var t1_sans_malus = CombatScript.resolve_round(10, 6, 3)  # hab_billy=6+4 pyro=10, hab_adversaire=6-2=4 attendu
	# On verifie indirectement : au tour 1, la difference d'habilete
	# effective doit correspondre a hab_adversaire=6-2=4 (donc diff=10-4=6),
	# PAS hab_adversaire=6 (diff=4). Les degats infliges par Billy au tour1
	# doivent donc etre ceux d'un diff de 6, pas 4.
	assert_eq(t1.degats_billy, CombatScript.SITUATION_TABLE[6][2][0])


func test_node575_habilete_normale_a_partir_du_deuxieme_tour():
	var mod = Mods.MalusHabiliteAdversePremierTourSeulement.new(2)
	var combat = CombatScript.new(6, 6, 20, 12, {"modificateurs": [mod], "pyro_bonus": 4})
	combat.play_turn(3)
	var t2 = combat.play_turn(3)
	# diff attendu au tour 2 : hab_billy=10, hab_adversaire=6 (plus de malus) -> diff=4
	assert_eq(t2.degats_billy, CombatScript.SITUATION_TABLE[4][2][0])


# =========================================================================
# MalusHabiliteBillyParCoupRecu + Increvable -- nœud 421 (championne trolesse)
# =========================================================================

func test_node421_habilete_de_billy_baisse_a_chaque_coup_recu():
	# "chaque fois que vous recevez des dégâts, -1 Habileté pour ce combat."
	# Jet=5 choisi pour le tour 2 : table[-2][4]=[4,3] (degats_billy=4)
	# contre table[-3][4]=[3,3] (degats_billy=3) -- les deux DIFFERENT,
	# contrairement au jet=3 utilise initialement ou table[-2][2] et
	# table[-3][2] valent toutes les deux 2 (coincidence qui rendait ce
	# test vert sans que le malus soit reellement applique).
	var mod = Mods.MalusHabiliteBillyParCoupRecu.new(1)
	var combat = CombatScript.new(9, 11, 20, 20, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)  # diff=-2 (aucun malus encore), die=3 -> table[-2][2]=[2,4] : Billy subit 4 PV
	assert_gt(t1.degats_adversaire, 0, "le premier coup doit bien toucher Billy pour declencher le malus")
	var t2 = combat.play_turn(5)
	assert_eq(t2.degats_billy, 3,
		"apres avoir ete touche une fois, l'Habileté de Billy a baisse de 1 (diff -2 -> -3, table[-3][4]=3 au lieu de table[-2][4]=4)")


func test_node421_billy_ne_meurt_jamais_dans_ce_combat():
	# "si vos points de vie atteignent 0, vous ne mourrez pas."
	var mod = Mods.Increvable.new()
	var combat = CombatScript.new(1, 11, 1, 20, {"modificateurs": [mod]})
	combat.play_turn(1)  # Billy devrait tomber a 0 PV
	assert_eq(combat.pv_billy, 0)
	assert_false(combat.is_over(), "0 PV mais increvable -- le combat continue")


func test_node421_le_combat_se_termine_normalement_si_ladversaire_meurt():
	var mod = Mods.Increvable.new()
	var combat = CombatScript.new(12, 5, 20, 5, {"modificateurs": [mod]})
	combat.play_turn(6)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy", "Increvable ne bloque que LA defaite de Billy, pas sa victoire")


# =========================================================================
# AttaquePosthume -- nœud 462 (gobelin possede)
# =========================================================================

func test_node462_gobelin_possede_attaque_une_derniere_fois_apres_0_pv():
	# "quand ses PV atteignent 0, il joue un tour supplémentaire et
	# attaque une dernière fois avant de vraiment mourir." PV adversaire
	# (2, comme le vrai gobelin) choisis pour mourir en un coup quel que
	# soit le die (table[7] billy >= 4 partout), et die=1 choisi pour
	# l'attaque posthume (implementee en rejouant le meme jet) car
	# table[7][0] adversaire=3 (non nul) -- un die=5 ou 6 y donnerait 0,
	# rendant le test non-discriminant.
	var mod = Mods.AttaquePosthume.new()
	var combat = CombatScript.new(9, 2, 20, 2, {"modificateurs": [mod]})
	var t = combat.play_turn(1)  # diff=7, die=1 -> table[7][0]=[4,3] : tue le gobelin (2 PV)
	assert_eq(combat.pv_adversaire, 0)
	assert_eq(t.degats_supplementaires_adversaire, 3,
		"attaque posthume (meme jet reutilise, die=1) : table[7][0] adversaire=3")


# =========================================================================
# HabiliteAdverseAleatoire -- nœud 346 (bagarre générale)
# =========================================================================

func test_node346_habilete_adverse_suit_la_formule_1_plus_1d6_fois_2():
	# "l'Habileté adverse est déterminée par 1 + 1d6×2 (relancée à chaque
	# tour)" -- formule injectee, jet fourni en test pour rester
	# deterministe (die=4 -> hab = 1 + 4*2 = 9).
	var mod = Mods.HabiliteAdverseAleatoire.new(func(): return 1 + 4 * 2)
	var combat = CombatScript.new(5, 1, 20, 18, {"modificateurs": [mod]})
	var t = combat.play_turn(3)
	# diff attendu : hab_billy=5, hab_adversaire=9 -> diff=-4
	assert_eq(t.degats_billy, CombatScript.SITUATION_TABLE[-4][2][0])


func test_node346_habilete_adverse_baisse_de_1_a_partir_du_deuxieme_tour():
	# "à chaque tour après le premier, retirez 1 point d'Habileté à
	# l'adversaire" -- decroit par NUMERO DE TOUR, pas par degats cumules
	# (ecart identifie en ecrivant ces tests, cf COMBATS_REGLES_SPECIALES.md
	# -- HabiliteAdverseDecroissanteParTour est le modificateur dedie,
	# distinct de HabiliteAdverseDegressiveParDegatsCumules). Se cumule
	# AU-DESSUS de la formule aleatoire (mod_hab, fixee ici pour isoler
	# l'effet de decroissance).
	var mod_hab = Mods.HabiliteAdverseAleatoire.new(func(): return 9)
	var mod_decay = Mods.HabiliteAdverseDecroissanteParTour.new(1, 2)  # -1/tour a partir du tour 2
	var combat = CombatScript.new(5, 1, 20, 18, {"modificateurs": [mod_hab, mod_decay]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_billy, CombatScript.SITUATION_TABLE[-4][2][0], "tour 1 : hab adverse = 9 (formule), pas encore de decroissance, diff=-4")
	var t2 = combat.play_turn(3)
	# tour 2 : hab adverse = 9 (formule, toujours fixe ici) - 1 (decroissance) = 8 -> diff=-3
	assert_eq(t2.degats_billy, CombatScript.SITUATION_TABLE[-3][2][0],
		"tour 2 : la formule redonne 9, MAIS le -1/tour-apres-le-premier s'applique en plus")


# =========================================================================
# AttaqueBonusSiConditionExterne -- nœud 387
# =========================================================================

func test_node387_attaque_bonus_si_le_jet_de_chance_est_rate():
	# "Si le Jet de Chance est raté, les ennemis ont droit à un tour
	# d'attaque sans esquive ni riposte possible." -- condition
	# determinee par l'appelant (hors combat.gd), fournie en parametre.
	var mod = Mods.AttaqueBonusSiConditionExterne.new(true, 5)  # jet de chance rate = true
	var combat = CombatScript.new(9, 11, 20, 15, {"modificateurs": [mod]})
	var normal = CombatScript.resolve_round(9, 11, 3)['degats_adversaire']
	var t = combat.play_turn(3)
	assert_eq(t.degats_adversaire, normal + 5, "attaque bonus non esquivable ajoutee aux degats normaux")


func test_node387_pas_dattaque_bonus_si_le_jet_de_chance_est_reussi():
	var mod = Mods.AttaqueBonusSiConditionExterne.new(false, 5)  # jet de chance reussi
	var combat = CombatScript.new(9, 11, 20, 15, {"modificateurs": [mod]})
	var normal = CombatScript.resolve_round(9, 11, 3)['degats_adversaire']
	var t = combat.play_turn(3)
	assert_eq(t.degats_adversaire, normal, "jet de chance reussi, pas d'attaque bonus")


# =========================================================================
# TrancheEgaliteSurMortSimultanee -- nœuds 114, 422 (orc esclavagiste)
# =========================================================================

func test_node114_lorc_esclavagiste_gagne_en_cas_de_mort_simultanee():
	# "Lorsque vous calculez les dégâts, retirez vos PV avant les siens.
	# Si vous mourrez tous les deux le même tour, c'est lui qui reste
	# debout." -- le "retirez vos PV avant les siens" est deja le
	# comportement naturel de play_turn (pv_billy et pv_adversaire sont
	# mis a jour independamment, l'ordre de calcul n'affecte pas le
	# resultat numerique) ; seule la REGLE DE DEPARTAGE en cas d'egalite
	# necessite un modificateur.
	var mod = Mods.TrancheEgaliteSurMortSimultanee.new("adversaire")
	var combat = CombatScript.new(9, 10, 3, 3, {"modificateurs": [mod]})
	combat.play_turn(1)  # die=1 : degats mutuels suffisants pour tuer les deux (fixture choisie pour ca)
	assert_true(combat.pv_billy <= 0 and combat.pv_adversaire <= 0, "fixture : mort simultanee")
	assert_eq(combat.get_winner(), "adversaire", "l'esclavagiste triche et reste debout")


func test_node422_meme_fouet_mais_billy_perd_cette_fois():
	# "cette fois c'est vous qui perdez (inverse du nœud 114)."
	var mod = Mods.TrancheEgaliteSurMortSimultanee.new("adversaire")  # reste "l'adversaire gagne" = Billy perd, meme resultat cote joueur que 114 mais formule inverse dans le libelle du livre
	var combat = CombatScript.new(9, 10, 3, 3, {"modificateurs": [mod]})
	combat.play_turn(1)
	assert_eq(combat.get_winner(), "adversaire", "Billy perd en cas d'egalite sur ce nœud aussi")


func test_sans_modificateur_mort_simultanee_reste_une_egalite():
	# Verifie que le comportement par defaut (sans TrancheEgaliteSurMortSimultanee)
	# n'est pas casse par l'ajout de ce hook.
	var combat = CombatScript.new(5, 5, 3, 3)
	combat.play_turn(1)
	assert_eq(combat.get_winner(), "egalite")


# =========================================================================
# Intangible -- nœud 534 (panthère invoquée)
# =========================================================================

func test_node534_intangible_ignore_larmure_de_billy():
	# "Le caractère intangible de votre ennemi lui permet d'ignorer votre
	# Armure" -- ses attaques passent au travers de armure_billy.
	var mod = Mods.Intangible.new(0, 0)
	var combat = CombatScript.new(8, 8, 20, 9, {"armure_billy": 5, "modificateurs": [mod]})
	var sans_armure = CombatScript.resolve_round(8, 8, 3)['degats_adversaire']
	var t = combat.play_turn(3)
	assert_eq(t.degats_adversaire, sans_armure, "l'Armure de Billy (5) n'a aucun effet contre elle")


func test_node534_malus_degats_3_au_premier_tour_puis_decroissant():
	# "elle vous inflige -3 dégâts au premier tour, malus qui remonte de
	# +1 par tour jusqu'à atteindre 0 (dégâts pleins à partir du 4e tour)."
	# "elle vous inflige" = c'est la PANTHERE qui deale moins -- porte sur
	# degats_adversaire (ce que Billy RECOIT), pas degats_billy.
	var mod = Mods.Intangible.new(3, 1)
	# PV adversaire volontairement genereux (30, pas les 9 PV reels du
	# nœud) pour que les 4 tours s'enchainent meme si le malus n'est pas
	# encore applique (stub) -- la valeur reelle de PV n'affecte pas la
	# mecanique testee ici.
	var combat = CombatScript.new(8, 8, 20, 30, {"modificateurs": [mod]})
	var normal = CombatScript.resolve_round(8, 8, 3)['degats_adversaire']
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_adversaire, maxi(0, normal - 3), "tour 1 : malus plein (-3)")
	var t2 = combat.play_turn(3)
	assert_eq(t2.degats_adversaire, maxi(0, normal - 2), "tour 2 : malus (-2)")
	var t3 = combat.play_turn(3)
	assert_eq(t3.degats_adversaire, maxi(0, normal - 1), "tour 3 : malus (-1)")
	var t4 = combat.play_turn(3)
	assert_eq(t4.degats_adversaire, normal, "tour 4 : malus resorbe, degats pleins")


func test_node534_immunite_totale_a_la_contre_attaque_critique():
	# "et vos coup critique" -- meme immunite que ImmuniteContreAttaqueCritique.
	var mod = Mods.Intangible.new(3, 1)
	var combat = CombatScript.new(8, 8, 20, 9, {"adresse_billy": 3, "critique_billy": 10, "modificateurs": [mod]})
	var t = combat.play_turn(3, 1)
	assert_eq(t.degats_billy, 0, "immunisee, meme sur une contre-attaque critique de Billy")


# =========================================================================
# UNDO + MODIFICATEURS -- le retour en arriere est une fonctionnalite de
# base (cf combat.gd), elle DOIT rester correcte meme combinee aux regles
# speciales. Risque concret : un Modificateur qui compte les tours ou les
# degats cumules via un COMPTEUR INTERNE (plutot que de LIRE combat.tour/
# combat.get_pv_delta_adversaire() a chaque appel) se desynchronise dès
# qu'on annule un tour -- ces tests visent precisement ce bug de classe.
# =========================================================================

func test_undo_puis_rejoue_limite_de_tours_ne_compte_pas_le_tour_annule():
	# nœud 36/97 : la limite de tours ne doit se declencher qu'au vrai
	# NUMERO de tour, pas au nombre d'appels a play_turn() (annulation
	# comprise).
	var mod = Mods.LimiteDeTours.new(3, "adversaire")
	var combat = CombatScript.new(1, 20, 20, 100, {"modificateurs": [mod]})
	combat.play_turn(3)  # tour 1
	combat.play_turn(3)  # tour 2
	combat.undo_last_turn()  # retour au tour 1 -- le joueur n'est pas content du tour 2
	assert_false(combat.is_over(), "revenu au tour 1, loin de la limite de 3")
	combat.play_turn(4)  # rejoue le tour 2 differemment (3eme appel a play_turn, mais 2eme TOUR)
	assert_false(combat.is_over(), "toujours le tour 2 apres le rejeu, pas encore la limite")
	combat.play_turn(5)  # tour 3 pour de vrai
	assert_true(combat.is_over(), "le vrai 3eme tour atteint la limite")
	assert_eq(combat.get_winner(), "adversaire")


func test_undo_puis_rejoue_sans_attaque_tour_reste_correct():
	# nœud 321/349 : apres annulation+rejeu du tour 1, on est TOUJOURS au
	# tour 1 -- l'absence d'attaque doit continuer a s'appliquer, pas
	# disparaitre parce qu'on a "deja" appele play_turn() une fois avant.
	var mod = Mods.SansAttaqueTour.new(1)
	var combat = CombatScript.new(9, 9, 20, 6, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_adversaire, 0, "tour 1, pas d'attaque adverse")
	combat.undo_last_turn()
	var t1_rejoue = combat.play_turn(4)  # rejoue le MEME tour 1 avec un jet different
	assert_eq(t1_rejoue.degats_adversaire, 0, "toujours le tour 1 apres le rejeu -- toujours pas d'attaque adverse")
	var t2 = combat.play_turn(3)  # cette fois un vrai tour 2
	assert_gt(t2.degats_adversaire, 0, "vrai tour 2 -- attaque normale de retour")


func test_undo_empeche_un_brasier_premature_du_a_un_tour_rejoue():
	# nœud 97 : si le joueur annule le tour 2 et le rejoue, le brasier
	# (tous les 3 TOURS) ne doit pas se declencher sur ce tour 2 rejoue --
	# meme si c'est le 3eme APPEL a play_turn() en comptant l'annulation.
	var mod = Mods.DegatsPeriodiques.new(3, 3, "billy", false, false)
	var combat = CombatScript.new(9, 12, 30, 20, {"modificateurs": [mod]})
	combat.play_turn(3)  # tour 1
	combat.play_turn(3)  # tour 2 (mauvais jet, le joueur n'est pas content)
	combat.undo_last_turn()
	var t2_rejoue = combat.play_turn(5)  # rejoue le tour 2, 3eme appel a play_turn()
	assert_eq(t2_rejoue.tour, 2, "toujours le tour 2 apres annulation+rejeu")
	assert_eq(t2_rejoue.degats_supplementaires_adversaire, 0,
		"le brasier (tous les 3 TOURS) ne doit pas se declencher sur un tour 2, meme rejoue")
	var t3 = combat.play_turn(3)  # le vrai tour 3
	assert_eq(t3.degats_supplementaires_adversaire, 3, "le vrai tour 3 declenche bien le brasier")


func test_undo_retire_les_degats_cumules_pour_la_decroissance_dhabilete():
	# nœud 76/155/231/370/518 : annuler un tour qui avait fait franchir le
	# seuil de degats cumules doit faire disparaitre la decroissance
	# d'Habileté qui en decoulait. Structure en 3 temps : (1) franchir le
	# seuil et VERIFIER que la baisse est bien active (sinon le test ne
	# prouverait rien -- un modificateur jamais implemente donnerait le
	# meme resultat "pas de baisse" avant ET apres une annulation), puis
	# (2) annuler et verifier le retour a "pas de baisse".
	var mod = Mods.HabiliteAdverseDegressiveParDegatsCumules.new(4, 1)
	var combat = CombatScript.new(9, 12, 30, 100, {"modificateurs": [mod]})
	var t1 = combat.play_turn(6)  # diff=-3, die=6 -> table[-3][5]=[4,3] : 4 degats (seuil de 4 atteint)
	assert_eq(t1.degats_billy, 4)
	# (1) la baisse doit etre ACTIVE ici : die=5 -> diff=-3 donnerait 3,
	# diff=-2 (baisse active) donne 4.
	var t2 = combat.play_turn(5)
	assert_eq(t2.degats_billy, 4, "seuil atteint -- l'Habileté adverse effective a baisse de 1 (diff -3 -> -2)")
	combat.undo_last_turn()  # annule le tour de verification
	combat.undo_last_turn()  # annule aussi le tour qui avait fait franchir le seuil
	assert_eq(combat.get_pv_delta_adversaire(), 0, "apres double annulation, plus aucun degat cumule")
	# (2) meme jet (die=5) qu'a l'etape "active" -- doit redonner 3
	# maintenant (diff=-3, plus de baisse), pas 4.
	var t3 = combat.play_turn(5)
	assert_eq(t3.degats_billy, 3, "la baisse d'Habileté a disparu avec le tour qui l'avait declenchee")


func test_undo_retire_le_gain_dadresse_pour_la_progression_par_degats_cumules():
	# nœud 370/518 : meme logique que ci-dessus, cote gain d'Adresse de
	# Billy plutot que perte d'Habileté adverse. Choisi pour que
	# l'annulation fasse bien REDESCENDRE d'un palier (2 -> 1), pas juste
	# rester sous un seuil qui n'aurait jamais ete depasse de toute facon.
	var mod = Mods.AdresseBillyProgressiveParDegatsCumules.new(10, 1)
	var combat = CombatScript.new(9, 16, 200, 100, {"adresse_billy": 0, "modificateurs": [mod]})
	for i in range(7):
		combat.play_turn(6)  # diff=-7, die=6 -> 3 degats/tour, 7 tours = 21 PV cumules (2 paliers de 10 -> adresse effective = 2)
	var t_avec_esquive = combat.play_turn(3, 2)
	assert_true(t_avec_esquive.esquive, "21 PV cumules, 2 paliers de 10 -> adresse effective = 2, esquive possible")
	combat.undo_last_turn()  # annule ce tour de verification (qui a aussi inflige 1 PV, cf table[-7][2])
	combat.undo_last_turn()  # annule aussi le 7eme tour de degats -- redescend a 18 PV cumules (1 seul palier)
	var apres = -combat.get_pv_delta_adversaire()
	assert_true(apres >= 10 and apres < 20, "apres cette double annulation, un seul palier de 10 doit rester")
	var t_sans_esquive = combat.play_turn(3, 2)  # meme jet d'esquive=2 qu'avant
	assert_false(t_sans_esquive.esquive, "un seul palier de 10 (adresse effective=1) -- l'esquive redevient impossible")


func test_undo_retire_le_malus_dhabilete_si_le_coup_qui_lavait_declenche_est_annule():
	# nœud 421 : annuler le tour ou Billy a ete touche doit faire
	# disparaitre le malus d'Habileté qui en decoulait pour la suite.
	# Meme structure "activer puis annuler" que le test precedent, pour
	# la meme raison (sinon "pas de malus apres annulation" coinciderait
	# avec un modificateur jamais implemente).
	var mod = Mods.MalusHabiliteBillyParCoupRecu.new(1)
	var combat = CombatScript.new(9, 11, 20, 20, {"modificateurs": [mod]})
	combat.play_turn(3)  # tour 1, diff=-2, die=3 -> table[-2][2]=[2,4] : Billy touche (4 PV), le malus doit s'activer
	# (1) le malus doit etre ACTIF ici : die=5 -> diff=-2 donnerait 4,
	# diff=-3 (malus actif) donne 3.
	var t2 = combat.play_turn(5)
	assert_eq(t2.degats_billy, 3, "apres avoir ete touche, l'Habileté de Billy a baisse de 1 (diff -2 -> -3)")
	combat.undo_last_turn()  # annule le tour de verification
	combat.undo_last_turn()  # annule aussi le coup qui avait declenche le malus
	# (2) meme jet (die=5) qu'a l'etape "actif" -- doit redonner 4
	# maintenant (diff=-2, plus de malus).
	var t3 = combat.play_turn(5)
	assert_eq(t3.degats_billy, 4, "le malus a disparu avec le coup qui l'avait declenche")


func test_undo_annule_correctement_lattaque_posthume():
	# nœud 462 : annuler le tour qui a tue l'adversaire doit aussi
	# annuler l'attaque posthume qui en decoulait. Meme fixture que
	# test_node462... (pv_adversaire=2, die=1) : table[7][0] adversaire=3
	# (non nul), contrairement a die=6 qui donnerait 0 sur cette ligne et
	# rendrait ce test non-discriminant.
	var mod = Mods.AttaquePosthume.new()
	var combat = CombatScript.new(9, 2, 20, 2, {"modificateurs": [mod]})
	var t = combat.play_turn(1)  # tue le gobelin -> attaque posthume
	assert_eq(t.degats_supplementaires_adversaire, 3)
	combat.undo_last_turn()
	assert_false(combat.is_over(), "apres annulation, le gobelin n'est plus mort, le combat continue")
	assert_eq(combat.pv_billy, 20, "l'attaque posthume annulee aussi, PV de Billy restaures a l'etat initial")


func test_undo_puis_rejoue_malus_degats_progressif_intangible_recompte_le_bon_tour():
	# nœud 534 : le malus decroissant (-3/-2/-1/0) suit le NUMERO de tour,
	# pas le nombre d'appels a play_turn() -- une annulation+rejeu du
	# tour 2 doit rester au malus du tour 2 (-2), pas glisser au tour 3 (-1).
	var mod = Mods.Intangible.new(3, 1)
	var combat = CombatScript.new(8, 8, 20, 30, {"modificateurs": [mod]})
	var normal = CombatScript.resolve_round(8, 8, 3)['degats_adversaire']
	combat.play_turn(3)  # tour 1, malus -3
	combat.play_turn(3)  # tour 2, malus -2
	combat.undo_last_turn()  # revient au tour 1
	var t2_rejoue = combat.play_turn(3)  # rejoue le tour 2
	assert_eq(t2_rejoue.degats_adversaire, maxi(0, normal - 2),
		"toujours le tour 2 apres le rejeu -- malus -2, pas -1 comme si c'etait le tour 3")


func test_undo_apres_une_mort_simultanee_tranchee_annule_le_resultat():
	# nœud 114/422 : annuler le tour qui avait declenche une mort
	# simultanee doit remettre le combat en cours, pas laisser un vainqueur
	# "fantome".
	var mod = Mods.TrancheEgaliteSurMortSimultanee.new("adversaire")
	var combat = CombatScript.new(9, 10, 3, 3, {"modificateurs": [mod]})
	combat.play_turn(1)
	assert_true(combat.is_over())
	combat.undo_last_turn()
	assert_false(combat.is_over(), "apres annulation, plus personne n'est mort")
	assert_null(combat.get_winner())


func test_undo_repete_plusieurs_fois_avec_un_modificateur_a_etat():
	# Rappelable plusieurs fois de suite (deja verrouille sans
	# modificateur dans test_combat_resolver.gd) -- ici combine a une
	# regle qui depend des degats cumules, pour verifier que CHAQUE
	# annulation successive desactive bien le palier correspondant.
	var mod = Mods.HabiliteAdverseDegressiveParDegatsCumules.new(4, 1)
	var combat = CombatScript.new(9, 12, 30, 100, {"modificateurs": [mod]})
	combat.play_turn(6)  # tour 1 : 4 degats cumules (seuil atteint)
	combat.play_turn(6)  # tour 2 : 8 degats cumules (2eme palier)
	combat.undo_last_turn()  # revient a 4 PV cumules (1 palier)
	combat.undo_last_turn()  # revient a 0 PV cumules (aucun palier)
	assert_eq(combat.get_pv_delta_adversaire(), 0, "deux annulations de suite -- retour complet a l'etat initial")
	var t = combat.play_turn(5)  # diff=-3 (aucune baisse, aucun palier) -> table[-3][4]=[3,3]
	assert_eq(t.degats_billy, 3, "sans aucun palier atteint (tout annule), pas de baisse d'Habileté adverse")
