extends "res://addons/gut/test.gd"

# Tests ECRITS AVANT L'IMPLEMENTATION (TDD demande explicitement), meme
# demarche que test_combat_regles_speciales_tome1.gd, pour les regles
# speciales du Tome 2 cataloguees dans COMBATS_REGLES_SPECIALES_TOME2.md.
#
# Ce fichier ne couvre QUE les nœuds qui ont besoin de code reel dans
# combat.gd/combat_modificateurs.gd. Les nœuds purement "cote appelant"
# (mains nues, +1 Adresse d'avantage numerique, Chance/Domination/fuite,
# valeurs deja refletees dans les colonnes Hab/PV/Arm/Deg/Pyro...) ne sont
# PAS testes ici, cf la section "Cote appelant" du catalogue.
#
# Les nouvelles classes de combat_modificateurs.gd sont pour l'instant des
# SQUELETTES (methodes presentes, logique reelle pas encore ecrite) --
# ces tests doivent donc ECHOUER pour l'instant (rouge intentionnel), pas
# planter a la compilation.

var CombatScript = preload('res://combat.gd')
var Mods = preload('res://combat_modificateurs.gd')


# =========================================================================
# AjustementSeuilPV -- nœud 11 (Sergent et Troufion)
# =========================================================================

func test_node11_malus_habilete_adverse_une_fois_lennemi_sous_6pv():
	# "Une fois l'ennemi en dessous de 6 PV, le Troufion est assommé et
	# votre adversaire perd 2 Habileté." -- die=3 choisi car diff=3 (avant
	# le seuil) et diff=5 (apres, hab_adversaire=5-2=3) donnent des
	# degats_billy DIFFERENTS (4 puis 5) via la Table des Situations,
	# prouvant que le malus est bien devenu actif et pas juste coincident.
	var mod = Mods.AjustementSeuilPV.new(6, "hab_adversaire", -2, false)
	var combat = CombatScript.new(8, 5, 20, 12, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)  # pre-tour PV=12>6 : pas encore franchi, diff=3 -> table[3][2]=[4,3]
	assert_eq(t1.degats_billy, 4, "avant le seuil (PV pre-tour=12), pas de malus")
	var t2 = combat.play_turn(3)  # pre-tour PV=8>6 : toujours pas franchi (le seuil se lit AVANT ce tour)
	assert_eq(t2.degats_billy, 4, "PV encore au-dessus du seuil au debut de ce tour")
	var t3 = combat.play_turn(3)  # pre-tour PV=4<=6 : franchi ! hab_adversaire=5-2=3, diff=5 -> table[5][2]=[5,2]
	assert_eq(t3.degats_billy, 5, "seuil franchi -- malus permanent actif (diff passe de 3 a 5)")


# =========================================================================
# DecroissanceParIntervalle -- nœuds 31/40 (hab_billy, tous les tours),
# 197 (hab_billy, tous les 2 tours), 649 (hab_adversaire, tous les 3 tours)
# =========================================================================

func test_node31_habilete_billy_baisse_de_1_a_partir_du_deuxieme_tour():
	# "Son cri réduit votre Habileté de 1 point à la fin de chaque tour,
	# cumulatif jusqu'à la fin du combat." -- die=4 choisi car diff=4 (tour1)
	# et diff=3 (tour2, apres la 1ere baisse) donnent 5 puis 4 (differents).
	var mod = Mods.DecroissanceParIntervalle.new("hab_billy", 1, 1)
	var combat = CombatScript.new(9, 5, 20, 50, {"modificateurs": [mod]})
	var t1 = combat.play_turn(4)  # tour1 : pas encore de baisse (a la FIN de ce tour seulement)
	assert_eq(t1.degats_billy, 5, "tour 1, Habileté pleine (9), diff=4")
	var t2 = combat.play_turn(4)  # tour2 : -1 Habileté (8), diff=3
	assert_eq(t2.degats_billy, 4, "tour 2, la baisse du tour 1 s'applique desormais")


func test_node197_habilete_billy_baisse_tous_les_2_tours():
	# Meme mecanique que 31, mais "tous les 2 tours" au lieu de "chaque
	# tour" -- la baisse ne doit apparaitre qu'au tour 3, pas au tour 2.
	var mod = Mods.DecroissanceParIntervalle.new("hab_billy", 1, 2)
	var combat = CombatScript.new(9, 5, 20, 50, {"modificateurs": [mod]})
	var t1 = combat.play_turn(4)
	assert_eq(t1.degats_billy, 5, "tour 1, pas de baisse")
	var t2 = combat.play_turn(4)
	assert_eq(t2.degats_billy, 5, "tour 2, toujours pas de baisse (2 tours pas encore ecoules)")
	var t3 = combat.play_turn(4)
	assert_eq(t3.degats_billy, 4, "tour 3, la baisse apparait apres 2 tours ecoules")


func test_node649_habilete_adverse_baisse_tous_les_3_tours():
	# "vous perdez 1 point d'Habileté tous les 3 tours" -- ici cote
	# ADVERSAIRE (Zarh perd de l'Habileté, pas Billy). die=1 choisi car
	# diff=4 (tours 1-3) et diff=5 (tour4, hab_adversaire=5-1=4) donnent des
	# degats_billy differents (3 puis 4).
	var mod = Mods.DecroissanceParIntervalle.new("hab_adversaire", 1, 3)
	var combat = CombatScript.new(9, 5, 20, 100, {"modificateurs": [mod]})
	var t1 = combat.play_turn(1)
	assert_eq(t1.degats_billy, 3, "tour 1, pas de baisse")
	var t2 = combat.play_turn(1)
	assert_eq(t2.degats_billy, 3, "tour 2, pas de baisse")
	var t3 = combat.play_turn(1)
	assert_eq(t3.degats_billy, 3, "tour 3, pas encore -- la baisse arrive APRES 3 tours ecoules")
	var t4 = combat.play_turn(1)
	assert_eq(t4.degats_billy, 4, "tour 4, la baisse apparait")


# =========================================================================
# SupprimeDegAdversaireApresSeuilPV / EsquiveAdverseSurDeApresSeuilPV --
# nœud 113 (Elfe-panthère)
# =========================================================================

func test_node113_elfe_panthere_arrete_son_bonus_de_degats_sous_la_moitie_de_ses_pv():
	# "Une fois tombé sous la moitié de ses PV, l'Elfe-panthère arrête
	# d'infliger son +1 PV bonus."
	var mod = Mods.SupprimeDegAdversaireApresSeuilPV.new(10)
	var combat = CombatScript.new(9, 9, 50, 15, {"deg_adversaire": 1, "modificateurs": [mod]})
	var t1 = combat.play_turn(3)  # pre-tour PV=15>10 : bonus actif -- table[0][2]=3 + deg_adversaire(1) = 4
	assert_eq(t1.degats_adversaire, 4, "au-dessus du seuil, le bonus de +1 s'applique encore")
	var t2 = combat.play_turn(3)  # pre-tour PV=12>10 : toujours au-dessus
	assert_eq(t2.degats_adversaire, 4, "toujours au-dessus du seuil au debut de ce tour")
	var t3 = combat.play_turn(3)  # pre-tour PV=9<=10 : franchi -- bonus supprime, degats_adversaire=3
	assert_eq(t3.degats_adversaire, 3, "sous le seuil, le bonus de +1 a disparu")


func test_node113_elfe_panthere_esquive_sur_de_impair_une_fois_sous_la_moitie():
	# "mais esquive désormais vos attaques si vous avez un dé impair."
	var mod = Mods.EsquiveAdverseSurDeApresSeuilPV.new(10, func(d): return d % 2 == 1)
	var combat = CombatScript.new(9, 9, 50, 15, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)  # die impair, mais pre-tour PV=15>10 : pas encore actif
	assert_eq(t1.degats_billy, 3, "au-dessus du seuil, l'esquive adverse ne s'applique pas encore")
	var t2 = combat.play_turn(3)  # pre-tour PV=12>10 : toujours pas actif
	assert_eq(t2.degats_billy, 3)
	var t3 = combat.play_turn(3)  # pre-tour PV=9<=10, die impair(3) -- esquive declenchee
	assert_eq(t3.degats_billy, 0, "sous le seuil ET die impair, l'adversaire esquive totalement")
	var t4 = combat.play_turn(4)  # toujours sous le seuil, mais die PAIR -- pas d'esquive
	assert_eq(t4.degats_billy, 3, "sous le seuil mais die pair -- les DEUX conditions sont necessaires")


# =========================================================================
# AjustementSeuilPV + BonusDegatsAdversaireApresSeuilPV -- nœud 234 (Garde
# des nains)
# =========================================================================

func test_node234_adresse_restauree_une_fois_le_garde_tue():
	# "vous tuez un des gardes quand les PV passent sous la moitié, ce qui
	# vous rend votre Adresse" -- le malus initial (-1) est actif AVANT le
	# seuil et disparait APRES (avant_seuil=true).
	var mod = Mods.AjustementSeuilPV.new(5, "adresse_billy", -1, true)
	var combat = CombatScript.new(9, 9, 50, 11, {"adresse_billy": 3, "modificateurs": [mod]})
	var t1 = combat.play_turn(3, 3)  # pre-tour PV=11>5 : malus actif, Adresse eff=2, esquive(3<=2)=false
	assert_false(t1.esquive, "avant le seuil, Adresse effective = 2 (malus actif), esquive ratee")
	var t2 = combat.play_turn(3, 3)  # pre-tour PV=8>5 : toujours avant le seuil
	assert_false(t2.esquive)
	var t3 = combat.play_turn(3, 3)  # pre-tour PV=5<=5 : seuil franchi, malus retire, Adresse eff=3
	assert_true(t3.esquive, "seuil franchi, Adresse restauree a 3 -- esquive reussie")


func test_node234_garde_restant_gagne_1_degat_apres_la_mort_de_lautre():
	# "provoque la colère du garde restant, qui gagne +1 dégât pour le
	# reste du combat." Adresse a 0 (defaut) pour ne pas interferer avec
	# le mecanisme d'esquive de Billy dans ce test.
	var mod = Mods.BonusDegatsAdversaireApresSeuilPV.new(5, 1)
	var combat = CombatScript.new(9, 9, 50, 11, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)  # pre-tour PV=11>5 : pas de bonus, degats_adversaire=table[0][2]=3
	assert_eq(t1.degats_adversaire, 3)
	var t2 = combat.play_turn(3)  # pre-tour PV=8>5 : toujours pas de bonus
	assert_eq(t2.degats_adversaire, 3)
	var t3 = combat.play_turn(3)  # pre-tour PV=5<=5 : bonus actif desormais
	assert_eq(t3.degats_adversaire, 4, "seuil franchi, +1 degat permanent")


# =========================================================================
# BonusDegatsBillyDevientMalus -- nœuds 180/268 (tout le combat), 321
# (premier tour seulement)
# =========================================================================

func test_node180_les_degats_supplementaires_de_billy_deviennent_un_malus():
	# "vos dégâts supplémentaires se transforment en malus qui réduisent
	# vos dommages." play_turn ajoute deg_billy (2) AVANT ce hook, donnant
	# 3 (table) + 2 = 5 ; le hook retire ensuite 2*deg_billy pour
	# transformer le +2 en -2 net : maxi(0, 5 - 4) = 1. Discriminant par
	# rapport a un stub qui laisserait 5 (bonus normal jamais transforme).
	var mod = Mods.BonusDegatsBillyDevientMalus.new()
	var combat = CombatScript.new(9, 9, 50, 20, {"deg_billy": 2, "modificateurs": [mod]})
	var t = combat.play_turn(3)
	assert_eq(t.degats_billy, 1, "5 (3 table + 2 deg_billy) - 4 (2x deg_billy retire) = 1")


func test_node321_malus_seulement_au_premier_tour():
	# "Vos bonus de dégât deviennent des malus de dégât lors du premier
	# tour, puis vous pouvez vous battre normalement."
	var mod = Mods.BonusDegatsBillyDevientMalus.new(1)
	var combat = CombatScript.new(9, 9, 50, 20, {"deg_billy": 2, "modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_billy, 1, "tour 1 : malus actif")
	var t2 = combat.play_turn(3)
	assert_eq(t2.degats_billy, 5, "tour 2 : normal, 3 (table) + 2 (deg_billy) = 5")


# =========================================================================
# ImmuniteHorsPlageDegats -- nœud 225 (La Poigne Filante)
# =========================================================================

func test_node225_degats_dans_la_plage_ne_sont_pas_affectes():
	var mod = Mods.ImmuniteHorsPlageDegats.new(3, 8)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(1)  # diff=0, die1 -> table[0][0]=3 : exactement la borne basse (3)
	assert_eq(t.degats_billy, 3, "3 est dans la plage [3,8] inclus -- aucun effet")


func test_node225_degats_sous_la_plage_sont_annules():
	var mod = Mods.ImmuniteHorsPlageDegats.new(3, 8)
	var combat = CombatScript.new(1, 20, 50, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(4)  # diff=-19 -> clampe a -7, die4 -> table[-7][3]=2 : sous la plage (2<3)
	assert_eq(t.degats_billy, 0, "2 PV serait inflige sans la regle -- hors de [3,8], immunite totale")


func test_node225_degats_au_dessus_de_la_plage_sont_annules():
	var mod = Mods.ImmuniteHorsPlageDegats.new(3, 8)
	var combat = CombatScript.new(20, 1, 50, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(5)  # diff=19 -> clampe a 7, die5 -> table[7][4]=9 : au-dessus de la plage (9>8)
	assert_eq(t.degats_billy, 0, "9 PV serait inflige sans la regle -- hors de [3,8], immunite totale")


func test_node225_double_attaque_meme_montant_si_la_2eme_esquive_rate():
	# "il vous attaque deux fois par tour (2 fois les mêmes dommages,
	# chacune esquivable...)" -- la 2eme esquive (die=5) est independante
	# et rate ici (5 > adresse_billy=3), le meme montant que la 1ere
	# attaque (3) est donc infligé une seconde fois.
	var mod = Mods.DoubleAttaqueAdverse.new(func(): return 5)
	var combat = CombatScript.new(9, 9, 50, 20, {"adresse_billy": 3, "modificateurs": [mod]})
	var t = combat.play_turn(3, 6)  # esquive PRINCIPALE (die=6>3) ratee aussi -- 1ere attaque : table[0][2]=3
	assert_eq(t.degats_adversaire, 3, "1ere attaque normale")
	assert_eq(t.degats_supplementaires_adversaire, 3, "2eme attaque, meme montant (3), esquive dediee ratee")
	assert_eq(combat.pv_billy, 50 - 3 - 3, "les deux attaques ont bien inflige leurs degats")


func test_node225_double_attaque_2eme_esquive_reussie_nannule_que_la_2eme():
	# La 2eme esquive est INDEPENDANTE de la 1ere -- une esquive reussie ici
	# (die=2<=3) annule la 2eme attaque SANS affecter la 1ere (deja
	# resolue, non critique puisque cette classe ne traite jamais de
	# contre-attaque critique sur la 2eme attaque).
	var mod = Mods.DoubleAttaqueAdverse.new(func(): return 2)
	var combat = CombatScript.new(9, 9, 50, 20, {"adresse_billy": 3, "modificateurs": [mod]})
	var t = combat.play_turn(3, 6)  # esquive PRINCIPALE ratee -- 1ere attaque normale : 3
	assert_eq(t.degats_adversaire, 3, "1ere attaque toujours normale")
	assert_eq(t.degats_supplementaires_adversaire, 0, "2eme attaque esquivee (jet dedie 2<=3)")
	assert_eq(combat.pv_billy, 50 - 3, "seule la 1ere attaque a inflige des degats")


# =========================================================================
# IgnoreArmureBilly -- nœuds 250 (Trois sans-visages), 532 (via
# ModificateurConditionnel, premier tour seulement)
# =========================================================================

func test_node250_larmure_de_billy_est_totalement_ignoree():
	# "vous subissez tous les dommages sans pouvoir les réduire."
	var mod = Mods.IgnoreArmureBilly.new()
	var combat = CombatScript.new(9, 9, 50, 20, {"armure_billy": 5, "modificateurs": [mod]})
	var t = combat.play_turn(3)  # table[0][2] adversaire=3 -- sans la regle, l'Armure (5) annulerait tout
	assert_eq(t.degats_adversaire, 3, "l'Armure (5) n'a aucun effet malgre son ampleur")


func test_node532_larmure_ignoree_seulement_au_premier_tour():
	var mod = Mods.ModificateurConditionnel.new(Mods.IgnoreArmureBilly.new(), func(combat, tour): return tour == 1)
	var combat = CombatScript.new(9, 9, 50, 20, {"armure_billy": 5, "modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_adversaire, 3, "tour 1 : Armure ignoree")
	var t2 = combat.play_turn(3)
	assert_eq(t2.degats_adversaire, 0, "tour 2 : Armure (5) redevient pleinement efficace contre 3 degats bruts")


# =========================================================================
# FinCombatSurParitesConsecutives -- nœud 256 (Mimine)
# =========================================================================

func test_node256_3_jets_pairs_consecutifs_arrete_le_combat():
	var mod = Mods.FinCombatSurParitesConsecutives.new(3)
	var combat = CombatScript.new(9, 9, 20, 20, {"modificateurs": [mod]})
	combat.play_turn(2)
	combat.play_turn(4)
	assert_false(combat.is_over(), "seulement 2 jets pairs consecutifs -- pas encore")
	combat.play_turn(6)
	assert_true(combat.is_over(), "3 jets pairs consecutifs -- Mimine arrete le combat")
	assert_eq(combat.get_winner(), "billy")


func test_node256_une_parite_differente_rompt_la_serie():
	var mod = Mods.FinCombatSurParitesConsecutives.new(3)
	var combat = CombatScript.new(9, 9, 20, 20, {"modificateurs": [mod]})
	combat.play_turn(2)  # pair
	combat.play_turn(4)  # pair
	combat.play_turn(3)  # impair -- rompt la serie
	combat.play_turn(5)  # impair
	assert_false(combat.is_over(), "seulement 2 impairs consecutifs apres la rupture -- pas encore 3")


func test_node256_pv_perdu_chaque_tour_apres_le_premier_esquivable():
	# "Chaque tour après le premier, Mimine vous enlève 1 PV en vous
	# picorant, esquivable mais non réductible." adresse_billy=3 fixe (pas
	# le defaut 0) pour que le jet d'esquive dedie ne soit pas annule par
	# play_turn (qui le mettrait a null si Adresse<2) -- meme piege que le
	# nœud 97 du Tome 1.
	var mod_degats = Mods.DegatsPeriodiques.new(1, 1, "billy", true, false, 2)
	var combat = CombatScript.new(9, 9, 20, 20, {"adresse_billy": 3, "modificateurs": [mod_degats]})
	var t1 = combat.play_turn(3, 5)  # premier tour : pas encore de picorage (tour_de_debut=2)
	assert_eq(t1.degats_supplementaires_adversaire, 0, "pas de picorage au premier tour")
	var t2 = combat.play_turn(3, 5)  # deuxieme tour, esquive du picorage ratee (5 > adresse_billy=3)
	assert_eq(t2.degats_supplementaires_adversaire, 1, "picorage a partir du 2eme tour, esquive ratee")
	var t3 = combat.play_turn(3, 2)  # troisieme tour, esquive du picorage reussie (2 <= adresse_billy=3)
	assert_eq(t3.degats_supplementaires_adversaire, 0, "esquive du picorage reussie -- preuve que le picorage est bien esquivable, pas juste absent")


# =========================================================================
# AdversaireNAttaquePasSiConditionParTour + PlafondDegatsInflige -- nœud
# 474 (Banc de requins des sables)
# =========================================================================

func test_node474_requin_abattu_ne_riposte_pas_et_degats_infliges_plafonnes():
	# "vous abattez un des requins dès sa sortie du sable et menez une
	# phase d'attaque sans subir de dégât en retour" (simule ici par une
	# condition externe injectee -- le vrai test de reflexes 2d6 est cote
	# appelant) + "vous ne pouvez infliger que 4 points de dégâts maximum
	# par tour."
	var mod_riposte = Mods.AdversaireNAttaquePasSiConditionParTour.new(func(tour): return tour == 2)
	var mod_plafond = Mods.PlafondDegatsInflige.new(4)
	var combat = CombatScript.new(9, 9, 50, 100, {"modificateurs": [mod_riposte, mod_plafond]})
	var t1 = combat.play_turn(6)  # diff=0, die6 -> table[0][5]=[5,3] ; degats_billy plafonne a 4
	assert_eq(t1.degats_billy, 4, "5 degats bruts, plafonnes a 4")
	assert_eq(t1.degats_adversaire, 3, "tour 1 : condition fausse, riposte normale")
	var t2 = combat.play_turn(6)
	assert_eq(t2.degats_billy, 4, "plafond toujours actif au tour 2")
	assert_eq(t2.degats_adversaire, 0, "tour 2 : requin abattu, pas de riposte")


# =========================================================================
# SansAttaqueTour (duree etendue) + EvenementAleatoireGardienSurpris --
# nœud 323 (Gardien surpris)
# =========================================================================

func test_node323_adversaire_najoute_pas_dattaque_pendant_2_tours():
	# "l'effarement de votre adversaire l'empêche d'attaquer pendant 2
	# tours."
	var mod = Mods.SansAttaqueTour.new(1, 2)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_adversaire, 0, "tour 1, pas d'attaque")
	var t2 = combat.play_turn(3)
	assert_eq(t2.degats_adversaire, 0, "tour 2, toujours pas d'attaque")
	var t3 = combat.play_turn(3)
	assert_eq(t3.degats_adversaire, 3, "tour 3, attaque normale de retour")


func test_node323_evenement_aleatoire_branche_1_perte_de_2pv_instantanee():
	# "sur 1, vous perdez 2 PV" -- die de l'evenement (independant du jet
	# d'attaque) fourni via un Callable deterministe.
	var mod = Mods.EvenementAleatoireGardienSurpris.new(func(): return 1)
	var combat = CombatScript.new(9, 9, 20, 9, {"modificateurs": [mod]})
	var t = combat.play_turn(3)
	assert_eq(t.degats_supplementaires_adversaire, 2, "perte de 2 PV instantanee, independante du combat normal")


func test_node323_evenement_aleatoire_branche_2ou3_malus_habilete_ce_tour():
	# "2 ou 3 : malus d'Habileté de 2 points pour ce tour." die=3 choisi
	# car diff=2 (avec malus) et diff=4 (sans) donnent 3 puis 4 (differents).
	var mod = Mods.EvenementAleatoireGardienSurpris.new(func(): return 2)
	var combat = CombatScript.new(9, 5, 20, 9, {"modificateurs": [mod]})
	var t = combat.play_turn(3)
	assert_eq(t.degats_billy, 3, "Habileté de Billy effective = 9-2 = 7, diff=2 (au lieu de 4 sans malus)")


func test_node323_evenement_aleatoire_branche_4ou5_bonus_habilete_ce_tour():
	# "4 ou 5 : bonus de 2 points d'Habileté." die=3 choisi car diff=0
	# (avec bonus) et diff=-2 (sans) donnent 3 puis 2 (differents).
	var mod = Mods.EvenementAleatoireGardienSurpris.new(func(): return 4)
	var combat = CombatScript.new(9, 11, 20, 9, {"modificateurs": [mod]})
	var t = combat.play_turn(3)
	assert_eq(t.degats_billy, 3, "Habileté de Billy effective = 9+2 = 11, diff=0 (au lieu de -2 sans bonus)")


func test_node323_evenement_aleatoire_branche_6_bonus_degats_et_aucun_degat_subi():
	# "6 : vous infligez +2 dégâts et ne subissez aucun dégât à ce tour."
	var mod = Mods.EvenementAleatoireGardienSurpris.new(func(): return 6)
	var combat = CombatScript.new(9, 9, 20, 9, {"modificateurs": [mod]})
	var t = combat.play_turn(3)  # normal : table[0][2]=[3,3]
	assert_eq(t.degats_billy, 5, "3 (table) + 2 (branche 6) = 5")
	assert_eq(t.degats_adversaire, 0, "aucun degat subi ce tour (branche 6)")


# =========================================================================
# AjustementTemporaireParTour -- nœud 436 (Creux vizir)
# =========================================================================

func test_node436_malus_adresse_billy_pendant_2_tours_puis_disparait():
	# "Deux gardes apportent leur soutien au Creux, réduisant votre
	# Adresse de 2 [...]. Votre lampe fera effet à la fin du 2ᵉ tour."
	var mod = Mods.AjustementTemporaireParTour.new("adresse_billy", -2, 2)
	var combat = CombatScript.new(9, 9, 20, 20, {"adresse_billy": 4, "modificateurs": [mod]})
	var t1 = combat.play_turn(3, 3)  # tour1 : Adresse eff=2, esquive(3<=2)=false
	assert_false(t1.esquive)
	var t2 = combat.play_turn(3, 3)  # tour2 : toujours actif
	assert_false(t2.esquive)
	var t3 = combat.play_turn(3, 3)  # tour3 : malus disparu, Adresse eff=4, esquive(3<=4)=true
	assert_true(t3.esquive, "apres le tour 2, le malus d'Adresse a disparu")


func test_node436_bonus_habilete_adverse_pendant_2_tours_puis_disparait():
	# "et augmentant leur Habileté de 3" -- meme fenetre de 2 tours.
	var mod = Mods.AjustementTemporaireParTour.new("hab_adversaire", 3, 2)
	var combat = CombatScript.new(9, 5, 20, 20, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)  # tour1 : hab_adversaire eff=8, diff=1 -> table[1][2]=3
	assert_eq(t1.degats_billy, 3)
	var t2 = combat.play_turn(3)  # tour2 : toujours actif
	assert_eq(t2.degats_billy, 3)
	var t3 = combat.play_turn(3)  # tour3 : bonus disparu, hab_adversaire=5, diff=4 -> table[4][2]=4
	assert_eq(t3.degats_billy, 4, "apres le tour 2, le bonus d'Habileté adverse a disparu")


# =========================================================================
# DivisionDegats -- nœuds 630 (L'Usurpatrice, conditionnel sur dé impair),
# 689 (Titan des glaces, inconditionnel)
# =========================================================================

func test_node630_degats_infliges_divises_par_deux_sur_de_impair():
	# "tous vos dommages sont divisés par deux (arrondi à l'inférieur)
	# lorsque vous obtenez un dé impair."
	var mod = Mods.DivisionDegats.new("adversaire", 2, func(d): return d % 2 == 1)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	var t1 = combat.play_turn(1)  # die impair -- table[0][0]=3, divise -> 1 (floor)
	assert_eq(t1.degats_billy, 1, "die impair, 3 divise par 2 arrondi a l'inferieur = 1")
	var t2 = combat.play_turn(2)  # die pair -- pas de division
	assert_eq(t2.degats_billy, 3, "die pair, aucune division")


func test_node689_degats_subis_divises_par_deux_inconditionnellement():
	# "ignorez la moitié de ses dommages !"
	var mod = Mods.DivisionDegats.new("billy", 2)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(3)  # table[0][2] adversaire=3, divise -> 1 (floor)
	assert_eq(t.degats_adversaire, 1, "3 divise par 2 arrondi a l'inferieur = 1")


# =========================================================================
# ModificateurConditionnel -- nœud 514 (Frère Plouf suspend une des 3
# règles du Gardien de la Nécropole, au choix, au début de chaque tour) --
# verifie ici le decorateur generique sur un Modificateur DEJA connu et
# teste au Tome 1 (MalusHabiliteAdversePremierTourSeulement), pour isoler
# le comportement du decorateur de la complexite propre au nœud 514.
# =========================================================================

func test_modificateur_conditionnel_transmet_quand_la_condition_est_vraie():
	var interieur = Mods.MalusHabiliteAdversePremierTourSeulement.new(2)
	var mod = Mods.ModificateurConditionnel.new(interieur, func(combat, tour): return true)
	var combat = CombatScript.new(6, 6, 20, 12, {"modificateurs": [mod], "pyro_bonus": 4})
	var t1 = combat.play_turn(3)
	# meme fixture que test_node575 au Tome 1 : hab_adversaire=6-2=4, hab_billy=10, diff=6
	assert_eq(t1.degats_billy, CombatScript.SITUATION_TABLE[6][2][0])


func test_modificateur_conditionnel_neutre_quand_la_condition_est_fausse():
	var interieur = Mods.MalusHabiliteAdversePremierTourSeulement.new(2)
	var mod = Mods.ModificateurConditionnel.new(interieur, func(combat, tour): return false)
	var combat = CombatScript.new(6, 6, 20, 12, {"modificateurs": [mod], "pyro_bonus": 4})
	var t1 = combat.play_turn(3)
	# condition fausse -- le malus interieur n'est jamais transmis, hab_adversaire reste 6, diff=4
	assert_eq(t1.degats_billy, CombatScript.SITUATION_TABLE[4][2][0])


# =========================================================================
# Reutilisation directe de classes Tome 1 dans un contexte Tome 2 --
# nœuds 293 (Gnoll surpris), 608 (Creux de la prison)
# =========================================================================

func test_node293_victoire_immediate_apres_la_premiere_attaque():
	# "Vous gagnez dès la première attaque."
	var mod = Mods.LimiteDeTours.new(1, "billy")
	var combat = CombatScript.new(9, 9, 20, 20, {"modificateurs": [mod]})
	combat.play_turn(3)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy")


func test_node608_defaite_forcee_si_pas_vaincu_en_2_tours():
	# "Vous avez 2 tours pour vaincre les Creux, sinon [...] les renforts
	# [...] vous submergeront."
	var mod = Mods.LimiteDeTours.new(2, "adversaire")
	var combat = CombatScript.new(1, 20, 20, 100, {"modificateurs": [mod]})
	combat.play_turn(3)
	assert_false(combat.is_over(), "pas encore au 2eme tour")
	combat.play_turn(3)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "adversaire")


# =========================================================================
# HabiliteAdverseMalusDecroissantParTour -- nœud 16 (Jeune Kränelornien
# épuisé)
# =========================================================================

func test_node16_malus_habilete_adverse_se_resorbe_au_fil_des_tours():
	# "il commence le combat avec -3 Habileté, mais regagne 1 point à la
	# fin de chaque tour." die=5 choisi car diff=2 (tour1, malus plein) et
	# diff=-1 (malus resorbe, si le malus etait reste a 3) donnent 5 puis 4
	# (differents) -- et die=1 choisi pour le tour final car diff=0 (s'il
	# restait encore 1 point de malus) et diff=-1 (totalement resorbe)
	# donnent 5 puis 6 (differents) sur degats_adversaire.
	var mod = Mods.HabiliteAdverseMalusDecroissantParTour.new(3, 1)
	# hab_adversaire=10 est la valeur NORMALE (colonne Hab du nœud 16) --
	# le modificateur retire le malus PAR-DESSUS cette base (10-3=7 au tour1).
	var combat = CombatScript.new(9, 10, 20, 50, {"modificateurs": [mod]})
	var t1 = combat.play_turn(5)  # tour1 : malus plein (3), hab_adversaire eff=10-3=7, diff=2
	assert_eq(t1.degats_billy, 5, "tour1 : malus plein actif, diff=2")
	combat.play_turn(3)
	combat.play_turn(3)
	var t4 = combat.play_turn(1)  # tour4 : malus totalement resorbe (3-1*3=0)
	assert_eq(t4.degats_adversaire, 6, "tour4 : malus totalement resorbe -- s'il restait 1 point, on aurait 5")


# =========================================================================
# SansBonusPyroTour -- nœud 68 (Chasseurs de primes)
# =========================================================================

func test_node68_bonus_pyro_barbare_suspendu_un_seul_tour():
	# "Le Pyro-Barbare est absent pendant 1 tour."
	var mod = Mods.SansBonusPyroTour.new(1)
	var combat = CombatScript.new(6, 9, 50, 20, {"pyro_bonus": 4, "modificateurs": [mod]})
	var t1 = combat.play_turn(3)  # tour1 : pyro_bonus suspendu, hab_billy eff=6, diff=-3
	assert_eq(t1.degats_billy, 2, "tour1 : Pyro-Barbare absent, diff=-3")
	var t2 = combat.play_turn(3)  # tour2 : pyro_bonus revenu, hab_billy eff=10, diff=1
	assert_eq(t2.degats_billy, 3, "tour2 : Pyro-Barbare de retour, diff=1")


# =========================================================================
# AjustementTemporaireParTour (premier_tour) + DegatsPeriodiques
# (une_seule_fois, cible=adversaire) -- nœud 73 (Chasseurs de primes
# surpris)
# =========================================================================

func test_node73_pb_assomme_un_chasseur_au_tour_2_degats_et_malus_permanent():
	# "À la fin du 2ᵉ tour, le Pyro-Barbare assomme un des Chasseurs : 3 PV
	# infligés à l'ennemi et -2 Habileté adverse [permanent, pas juste ce
	# tour-là]."
	var mod_hab = Mods.AjustementTemporaireParTour.new("hab_adversaire", -2, null, 2)
	var mod_dmg = Mods.DegatsPeriodiques.new(2, 3, "adversaire", false, true)
	var combat = CombatScript.new(9, 9, 20, 50, {"modificateurs": [mod_hab, mod_dmg]})
	var t1 = combat.play_turn(4)  # tour1 : malus pas encore actif (premier_tour=2), pas de declenchement (intervalle=2)
	assert_eq(t1.degats_billy, 3, "tour1 : pas encore de malus, diff=0")
	assert_eq(t1.degats_supplementaires_billy, 0, "tour1 : pas encore d'evenement")
	var t2 = combat.play_turn(4)  # tour2 : malus actif desormais, evenement declenche
	assert_eq(t2.degats_billy, 4, "tour2 : malus actif (-2 Hab adverse), diff=2")
	assert_eq(t2.degats_supplementaires_billy, 3, "tour2 : le Pyro-Barbare assomme un chasseur, +3 degats")
	var t3 = combat.play_turn(4)  # tour3 : malus toujours actif (permanent), pas de nouveau declenchement
	assert_eq(t3.degats_billy, 4, "tour3 : malus permanent toujours actif")
	assert_eq(t3.degats_supplementaires_billy, 0, "tour3 : une seule fois, pas de second declenchement")


# =========================================================================
# BillyEsquiveAttaqueSurDe -- nœud 649 (bénédiction de Neit, Zarh du
# souffle de Zarh)
# =========================================================================

func test_node649_benediction_de_neit_esquive_totale_sur_de_impair():
	# "La bénédiction de Neit vous fait esquiver tous les dommages si vous
	# obtenez un dé impair durant votre phase d'attaque, sans même passer
	# par une phase d'esquive."
	var mod = Mods.BillyEsquiveAttaqueSurDe.new(func(d): return d % 2 == 1)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	var t1 = combat.play_turn(1)  # die impair
	assert_eq(t1.degats_adversaire, 0, "die impair -- esquive totale, sans jet d'esquive dedie")
	var t2 = combat.play_turn(2)  # die pair
	assert_eq(t2.degats_adversaire, 4, "die pair -- degats normaux (table[0][1]=4)")


# =========================================================================
# DegatsAdverseFixesSiTouche + AttaqueBonusSiConditionExterne (reuse) --
# nœud 686 (Avatar de Vetherr)
# =========================================================================

func test_node686_rayon_absolu_de_4_degats_sil_touche():
	# "il tire un unique trait d'énergie pure qui vous inflige 4 dommages
	# absolus s'il vous touche."
	var mod = Mods.DegatsAdverseFixesSiTouche.new(4)
	var combat = CombatScript.new(9, 0, 50, 30, {"modificateurs": [mod]})
	var t1 = combat.play_turn(1)  # diff=7 (clampe), die1 -> table[7][0] adversaire=3 (touche, non nul)
	assert_eq(t1.degats_adversaire, 4, "le rayon touche -- remplace par 4 degats absolus fixes (pas 3)")
	var t2 = combat.play_turn(5)  # die5 -> table[7][4] adversaire=0 (rate)
	assert_eq(t2.degats_adversaire, 0, "le rayon rate -- pas de degats fixes (0 reste 0)")


func test_node686_encaisser_volontairement_ajoute_un_bonus_de_4():
	# "Vous pouvez choisir d'encaisser volontairement son rayon [...] pour
	# un bonus de 4 dégâts." -- reutilise AttaqueBonusSiConditionExterne
	# a l'identique du nœud 387 (Tome 1).
	var mod_fixe = Mods.DegatsAdverseFixesSiTouche.new(4)
	var mod_bonus = Mods.AttaqueBonusSiConditionExterne.new(true, 4)
	var combat = CombatScript.new(9, 0, 50, 30, {"modificateurs": [mod_fixe, mod_bonus]})
	var t = combat.play_turn(1)
	assert_eq(t.degats_adversaire, 8, "rayon absolu (4) + bonus volontaire (+4) = 8")


# =========================================================================
# DegatsPeriodiques (cible="adversaire") -- nœud 514 (Khazin), nœud 630
# (djinns de terre du PAYSAN) -- branche du code JAMAIS exercee par un
# test avant cette revue (seul cible="billy" etait teste, Tome 1 et Tome 2)
# =========================================================================

func test_node514_khazin_inflige_2pv_par_tour_a_lennemi():
	# "Si Khazin vous accompagne : il inflige 2 PV de dégâts par tour à
	# l'ennemi."
	var mod = Mods.DegatsPeriodiques.new(1, 2, "adversaire", false, false)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(3)  # normal : table[0][2]=[3,3]
	assert_eq(t.degats_supplementaires_billy, 2, "Khazin inflige 2 PV/tour supplementaires, EN PLUS des degats normaux de Billy")
	assert_eq(combat.pv_adversaire, 20 - 3 - 2, "3 (attaque normale) + 2 (Khazin) = 5 PV perdus ce tour")


func test_node630_djinns_de_terre_du_paysan_renvoient_1pv_par_tour():
	# "PAYSAN → vos djinns de terre bloquent et renvoient les projectiles,
	# 1 PV/tour infligé à l'adversaire."
	var mod = Mods.DegatsPeriodiques.new(1, 1, "adversaire", false, false)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	var t = combat.play_turn(3)
	assert_eq(t.degats_supplementaires_billy, 1, "djinns de terre : 1 PV/tour supplementaire infligé a l'adversaire")


# =========================================================================
# MultiplieDegatsSiConditionExterne -- nœud 584 (PRUDENT, Armée de Creux) --
# condition externe VERIFIEE A CHAQUE TOUR (pas une seule fois pour tout
# le combat, contrairement a AttaqueBonusSiConditionExterne)
# =========================================================================

func test_node584_prudent_quadruple_ses_degats_sur_jet_de_chance_reussi_chaque_tour():
	# "PRUDENT → quadruple ses dégâts sur un jet de Chance réussi" -- verifie
	# ici que la condition est bien re-evaluee CHAQUE tour (pas figee a la
	# construction) : reussie au tour 2 seulement dans ce test.
	var mod = Mods.MultiplieDegatsSiConditionExterne.new(func(tour): return tour == 2, 4)
	var combat = CombatScript.new(9, 9, 50, 50, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)  # tour1 : jet de Chance non tente/rate ce tour
	assert_eq(t1.degats_billy, 3, "tour1 : degats normaux")
	var t2 = combat.play_turn(3)  # tour2 : jet de Chance reussi CE tour
	assert_eq(t2.degats_billy, 12, "tour2 : degats quadruples (3*4)")
	var t3 = combat.play_turn(3)  # tour3 : de nouveau rate -- la condition est re-evaluee, pas figee a 'toujours actif' depuis le tour2
	assert_eq(t3.degats_billy, 3, "tour3 : redevenu normal -- preuve que ce n'est pas 'actif pour toujours' une fois declenche")


# =========================================================================
# LimiteDeTours avec un resultat narratif arbitraire -- nœud 225 (La
# Poigne Filante s'echappe si non vaincue en 3 tours)
# =========================================================================

func test_node225_sechappe_si_pas_vaincu_en_3_tours():
	# "Si vous ne l'avez pas vaincu en 3 tours, il s'échappe vers le module
	# 206." -- LimiteDeTours accepte n'importe quelle chaine de resultat
	# (pas seulement "billy"/"adversaire") : get_winner() renvoie
	# litteralement ce qui a ete passe, a l'appelant de l'interpreter
	# (ici "fuite", pour rediriger vers le module 206 plutot qu'un vrai
	# gain/perte).
	var mod = Mods.LimiteDeTours.new(3, "fuite")
	var combat = CombatScript.new(1, 9, 200, 100, {"modificateurs": [mod]})
	combat.play_turn(3)
	combat.play_turn(3)
	assert_false(combat.is_over(), "pas encore au 3eme tour")
	combat.play_turn(3)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "fuite", "resultat narratif arbitraire, distinct de billy/adversaire/egalite")


# =========================================================================
# ModificateurConditionnel x3 -- nœud 514 (Frère Plouf suspend, au choix de
# Billy au début de chaque tour, UNE des 3 règles du Gardien) -- test avec
# les 3 VRAIES règles du nœud (pas un exemple synthetique), verifiant que
# CHACUNE peut etre suspendue independamment.
# =========================================================================

func test_node514_frere_plouf_peut_suspendre_chacune_des_3_regles_independamment():
	# Les 3 règles du Gardien : (1) -1 Adresse pour Billy, (2) immunite
	# totale a la contre-attaque critique, (3) +1 degat_adversaire fixe
	# (les "lames dentelées"). "regle_suspendue" est une boite mutable
	# (Array a 1 case) representant le choix de Billy au debut de CHAQUE
	# tour -- exactement le canal par lequel l'appelant (main.gd)
	# communiquerait ce choix au combat en jeu reel.
	var regle_suspendue = [null]
	var mod_adresse = Mods.ModificateurConditionnel.new(
		Mods.AjustementTemporaireParTour.new("adresse_billy", -1, null, null),
		func(combat, tour): return regle_suspendue[0] != "adresse")
	var mod_critique = Mods.ModificateurConditionnel.new(
		Mods.ImmuniteContreAttaqueCritique.new(),
		func(combat, tour): return regle_suspendue[0] != "critique")
	var mod_bonus = Mods.ModificateurConditionnel.new(
		Mods.BonusDegatsAdversaireFixe.new(1),
		func(combat, tour): return regle_suspendue[0] != "bonus")
	var combat = CombatScript.new(9, 9, 50, 50, {
		"adresse_billy": 3, "critique_billy": 10,
		"modificateurs": [mod_adresse, mod_critique, mod_bonus],
	})

	# Tour 1 : rien suspendu -- les 3 regles actives.
	var t1 = combat.play_turn(6, 3)  # Adresse eff=3-1=2, esquive(3<=2)=false
	assert_false(t1.esquive, "regle Adresse active (rien suspendu) -- Adresse eff=2, esquive ratee")
	assert_eq(t1.degats_adversaire, 4, "regle bonus active -- table[0][5]=3 + 1 = 4")

	# Tour 2 : Adresse suspendue -- Adresse pleine (3), esquive reussie.
	regle_suspendue[0] = "adresse"
	var t2 = combat.play_turn(6, 3)
	assert_true(t2.esquive, "regle Adresse suspendue par Plouf -- Adresse pleine (3), esquive reussie")

	# Tour 3 : critique suspendue -- la contre-attaque critique s'applique normalement.
	regle_suspendue[0] = "critique"
	var t3 = combat.play_turn(6, 1)  # Adresse eff=2 (regle 1 de nouveau active), esquive(1<=2)=true -> critique
	assert_eq(t3.degats_billy, 15, "regle critique suspendue par Plouf -- degats max (5) + bonus Critique (10) = 15")

	# Tour 4 : bonus suspendu -- pas de +1 degat_adversaire ce tour.
	regle_suspendue[0] = "bonus"
	var t4 = combat.play_turn(6, 3)  # Adresse eff=2, esquive(3<=2)=false
	assert_eq(t4.degats_adversaire, 3, "regle bonus suspendue par Plouf -- table[0][5]=3, pas de +1")


# =========================================================================
# UNDO + MODIFICATEURS -- meme exigence qu'au Tome 1 : le retour en
# arriere est une fonctionnalite de base, elle DOIT rester correcte meme
# combinee aux nouvelles regles speciales du Tome 2.
# =========================================================================

func test_undo_retire_le_malus_dhabilete_adverse_si_le_seuil_nest_plus_franchi():
	# nœud 11 : AjustementSeuilPV lit combat.pv_adversaire EN DIRECT (pas de
	# compteur interne) -- annuler les tours qui avaient fait franchir le
	# seuil doit faire disparaitre le malus.
	var mod = Mods.AjustementSeuilPV.new(6, "hab_adversaire", -2, false)
	var combat = CombatScript.new(8, 5, 20, 12, {"modificateurs": [mod]})
	combat.play_turn(3)  # tour1 : PV 12->8
	combat.play_turn(3)  # tour2 : PV 8->4 (franchit le seuil DURANT ce tour)
	var t3 = combat.play_turn(3)  # tour3 : pre-tour PV=4<=6 -- malus ACTIF, verifie avant d'annuler
	assert_eq(t3.degats_billy, 5, "malus actif avant annulation")
	combat.undo_last_turn()  # annule le tour3 (de verification)
	combat.undo_last_turn()  # annule aussi le tour2 (qui avait fait franchir le seuil)
	assert_eq(combat.pv_adversaire, 8, "revenu avant le franchissement du seuil")
	var t3_replay = combat.play_turn(3)  # rejoue -- pre-tour PV=8>6, seuil plus franchi
	assert_eq(t3_replay.degats_billy, 4, "le malus a disparu avec le tour qui avait fait franchir le seuil")


func test_undo_puis_rejoue_decroissance_par_intervalle_recompte_le_bon_tour():
	# nœud 31 : la baisse suit le NUMERO de tour (parametre direct de
	# play_turn), jamais un compteur interne -- annuler+rejouer doit rester
	# coherent avec le VRAI numero de tour.
	var mod = Mods.DecroissanceParIntervalle.new("hab_billy", 1, 1)
	var combat = CombatScript.new(9, 5, 20, 50, {"modificateurs": [mod]})
	combat.play_turn(4)  # tour1
	var t2 = combat.play_turn(4)  # tour2 : baisse active
	assert_eq(t2.degats_billy, 4, "baisse active au tour 2")
	combat.undo_last_turn()  # revient au tour 1
	var t2_replay = combat.play_turn(5)  # rejoue le tour 2 avec un autre jet
	assert_eq(t2_replay.degats_billy, 5, "tour 2 rejoue avec un autre jet -- la baisse (a partir du tour 2) est toujours correctement active")


func test_undo_annule_correctement_la_fin_de_combat_sur_parites_consecutives():
	# nœud 256 : FinCombatSurParitesConsecutives derive entierement de
	# combat.pile (aucun compteur interne) -- annuler le 3eme jet de la
	# serie doit remettre le combat en cours.
	var mod = Mods.FinCombatSurParitesConsecutives.new(3)
	var combat = CombatScript.new(9, 9, 20, 20, {"modificateurs": [mod]})
	combat.play_turn(2)
	combat.play_turn(4)
	combat.play_turn(6)
	assert_true(combat.is_over())
	combat.undo_last_turn()
	assert_false(combat.is_over(), "apres annulation du 3eme jet, la serie est rompue, le combat continue")
	assert_null(combat.get_winner())


func test_undo_puis_rejoue_malus_degats_bruts_devient_malus_recompte_le_bon_tour():
	# nœud 321 : BonusDegatsBillyDevientMalus(numero_tour=1) lit le
	# parametre "tour" fourni par play_turn -- annuler+rejouer le tour 1 ne
	# doit pas le faire glisser vers le comportement du tour 2.
	var mod = Mods.BonusDegatsBillyDevientMalus.new(1)
	var combat = CombatScript.new(9, 9, 50, 20, {"deg_billy": 2, "modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_billy, 1, "tour 1 : malus actif")
	combat.undo_last_turn()
	var t1_replay = combat.play_turn(4)  # rejoue le MEME tour 1 avec un autre jet
	assert_eq(t1_replay.degats_billy, 1, "tour 1 rejoue avec un autre jet -- le malus (numero de tour 1) est toujours actif")
	var t2 = combat.play_turn(3)  # vrai tour 2
	assert_eq(t2.degats_billy, 5, "vrai tour 2 -- le malus a disparu, degats normaux (3+2)")


func test_undo_puis_rejoue_malus_habilete_decroissant_recompte_le_bon_tour():
	# nœud 16 : le malus lit "tour" en direct (aucun compteur interne) --
	# annuler+rejouer le tour 2 doit rester coherent avec le NIVEAU de
	# malus du tour 2 (2 points resorbes), pas glisser vers celui du tour 3.
	var mod = Mods.HabiliteAdverseMalusDecroissantParTour.new(3, 1)
	var combat = CombatScript.new(9, 10, 20, 50, {"modificateurs": [mod]})
	combat.play_turn(5)  # tour1 : malus=3, hab_adversaire eff=7, diff=2
	var t2 = combat.play_turn(4)  # tour2 : malus=2, hab_adversaire eff=8, diff=1 -> table[1][3]=[4,3]
	assert_eq(t2.degats_adversaire, 3, "malus=2 actif au tour 2 (da=3, pas 2 comme si le malus etait reste a 3)")
	combat.undo_last_turn()  # revient au tour 1
	var t2_replay = combat.play_turn(6)  # rejoue le tour 2 avec un autre jet -- malus=2, diff=1 -> table[1][5]=[6,3]
	assert_eq(t2_replay.degats_billy, 6, "tour 2 rejoue avec un autre jet -- malus=2 toujours actif (pas 1, qui donnerait 5)")


func test_undo_puis_rejoue_evenement_declenche_a_tour_fixe_ne_se_declenche_pas_en_avance():
	# nœud 73 : meme piege que le nœud 97 du Tome 1 -- l'evenement (3 PV +
	# malus permanent) declenche au tour 2 doit rester au tour 2 apres
	# annulation+rejeu, ne pas glisser au tour 3 ni disparaitre.
	var mod_hab = Mods.AjustementTemporaireParTour.new("hab_adversaire", -2, null, 2)
	var mod_dmg = Mods.DegatsPeriodiques.new(2, 3, "adversaire", false, true)
	var combat = CombatScript.new(9, 9, 20, 50, {"modificateurs": [mod_hab, mod_dmg]})
	combat.play_turn(4)  # tour1
	combat.play_turn(5)  # tour2 (mauvais jet, le joueur n'est pas content)
	combat.undo_last_turn()  # annule le tour2
	var t2_rejoue = combat.play_turn(4)  # rejoue le tour2, 3eme appel a play_turn()
	assert_eq(t2_rejoue.tour, 2, "toujours le tour 2 apres annulation+rejeu")
	assert_eq(t2_rejoue.degats_supplementaires_billy, 3, "l'evenement (tour 2 exactement) se declenche bien sur ce rejeu")
	assert_eq(t2_rejoue.degats_billy, 4, "malus permanent actif au tour 2")
	# Annule aussi ce tour 2 rejoue ET le tour 1 -- retour total a l'etat initial.
	combat.undo_last_turn()
	combat.undo_last_turn()
	var t1_replay = combat.play_turn(4)
	assert_eq(t1_replay.degats_billy, 3, "de retour au tour 1 -- malus pas encore actif (premier_tour=2)")
	assert_eq(t1_replay.degats_supplementaires_billy, 0, "de retour au tour 1 -- pas encore d'evenement (intervalle=2)")


func test_undo_puis_rejoue_avec_condition_externe_changee_noeud_584():
	# nœud 584 (PRUDENT) : la condition externe (jet de Chance, controlee
	# par l'appelant/le joueur) peut changer entre la 1ere tentative d'un
	# tour et son rejeu apres annulation -- le Modificateur doit refleter
	# la valeur ACTUELLE de la condition, jamais un resultat figé de la
	# tentative annulee.
	var chance_reussie = [true]
	var mod = Mods.MultiplieDegatsSiConditionExterne.new(func(tour): return chance_reussie[0], 4)
	var combat = CombatScript.new(9, 9, 50, 50, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_billy, 12, "1ere tentative : Chance reussie, degats quadruples")
	combat.undo_last_turn()
	chance_reussie[0] = false  # le joueur retente ce tour, cette fois le jet de Chance echoue
	var t1_replay = combat.play_turn(3)
	assert_eq(t1_replay.degats_billy, 3, "rejeu du meme tour avec Chance ratee -- degats normaux, pas figes a l'ancien resultat")


func test_undo_puis_rejoue_avec_regle_suspendue_differente_noeud_514():
	# nœud 514 : le choix de Frère Plouf (quelle regle suspendre) est fait
	# par le joueur au debut de CHAQUE tour -- s'il annule et rejoue avec
	# un choix different, le combat doit refleter le NOUVEAU choix.
	var regle_suspendue = [null]
	var mod_adresse = Mods.ModificateurConditionnel.new(
		Mods.AjustementTemporaireParTour.new("adresse_billy", -1, null, null),
		func(combat, tour): return regle_suspendue[0] != "adresse")
	var mod_critique = Mods.ModificateurConditionnel.new(
		Mods.ImmuniteContreAttaqueCritique.new(),
		func(combat, tour): return regle_suspendue[0] != "critique")
	var combat = CombatScript.new(9, 9, 50, 50, {
		"adresse_billy": 3, "critique_billy": 10,
		"modificateurs": [mod_adresse, mod_critique],
	})
	regle_suspendue[0] = "adresse"
	var t1 = combat.play_turn(6, 3)  # adresse suspendue -- pleine (3), esquive(3<=3)=true
	assert_true(t1.esquive, "1ere tentative : Adresse suspendue, esquive reussie")
	combat.undo_last_turn()
	regle_suspendue[0] = "critique"  # le joueur change d'avis apres l'annulation
	var t1_replay = combat.play_turn(6, 3)  # adresse de nouveau active (2), esquive(3<=2)=false
	assert_false(t1_replay.esquive, "rejeu avec un AUTRE choix de Plouf -- Adresse de nouveau active, esquive ratee")


func test_undo_retire_les_degats_supplementaires_cible_adversaire():
	# nœud 630 (PAYSAN) : DegatsPeriodiques avec cible="adversaire" (branche
	# du code jamais testee avant cette revue) doit rester undo-safe comme
	# toute autre configuration de cette classe.
	var mod = Mods.DegatsPeriodiques.new(1, 1, "adversaire", false, false)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	combat.play_turn(3)
	assert_eq(combat.pv_adversaire, 20 - 3 - 1, "degats normaux + degats supplementaires (cible=adversaire)")
	combat.undo_last_turn()
	assert_eq(combat.pv_adversaire, 20, "annulation retire aussi les degats supplementaires cible=adversaire")


# =========================================================================
# Re-relecture (2026-07-13) : cas a la marge trouves en relisant le texte
# EXACT de chaque regle mot a mot, pas juste la liste des classes deja
# ecrites.
# =========================================================================

func test_node630_prudent_retire_aussi_le_bloc_de_marbre_sur_de_impair():
	# Relecture du texte dicte pour 630 (PRUDENT) : "vos djinns d'eau [...]
	# lui retirant SES PROJECTILES ET SA PROTECTION lors de vos lancers
	# impairs." "sa protection" = la division de degats (deja modelisee en
	# ne PAS attachant DivisionDegats pour PRUDENT, ce qui revient au meme
	# puisque DivisionDegats ne s'applique QUE sur un de impair de toute
	# facon). Mais "ses projectiles" = le bloc de marbre periodique
	# (DegatsPeriodiques) N'AVAIT PAS cette suppression conditionnelle --
	# omission trouvee en relisant le texte mot a mot. Corrige en
	# enveloppant le bloc de marbre dans un ModificateurConditionnel qui le
	# suspend precisement sur un de impair (reutilise le mecanisme
	# existant, aucune nouvelle classe necessaire).
	# La condition est aussi appelee (sans consequence) par les hooks
	# PRE-tour de ModificateurConditionnel (hab_billy_pour_ce_tour, etc.)
	# que DegatsPeriodiques n'implemente meme pas -- pile peut donc etre
	# encore vide (tour 1, avant l'empilement du nouvel EtatTour) : garde
	# defensive necessaire, le resultat de ces appels-la est ignore.
	var mod_marbre_prudent = Mods.ModificateurConditionnel.new(
		Mods.DegatsPeriodiques.new(1, 2, "billy", false, false),
		func(combat, tour): return combat.pile.size() > 0 and combat.pile[combat.pile.size() - 1].attack_die_roll % 2 == 0)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod_marbre_prudent]})
	var t1 = combat.play_turn(3)  # die impair -- projectiles retires, bloc de marbre suspendu
	assert_eq(t1.degats_supplementaires_adversaire, 0, "PRUDENT, die impair -- le bloc de marbre ne se declenche pas non plus")
	var t2 = combat.play_turn(4)  # die pair -- protection ET projectiles reviennent
	assert_eq(t2.degats_supplementaires_adversaire, 2, "die pair -- bloc de marbre normal (2 PV)")


func test_node282_boule_de_feu_tous_les_2_tours():
	# nœud 282 (Torche dardante) : "tous les 2 tours" (intervalle=2,
	# tour_de_debut=1 implicite) -- combinaison de DegatsPeriodiques jamais
	# exercee directement par un test avant cette relecture (Tome 1 et Tome
	# 2 n'avaient teste que intervalle=1 ou intervalle=3, jamais intervalle=2
	# avec tour_de_debut=1 par defaut).
	var mod = Mods.DegatsPeriodiques.new(2, 2, "billy", false, false)
	var combat = CombatScript.new(9, 9, 50, 20, {"modificateurs": [mod]})
	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_supplementaires_adversaire, 0, "tour 1 -- pas encore de boule de feu")
	var t2 = combat.play_turn(3)
	assert_eq(t2.degats_supplementaires_adversaire, 2, "tour 2 -- boule de feu (tous les 2 tours)")
	var t3 = combat.play_turn(3)
	assert_eq(t3.degats_supplementaires_adversaire, 0, "tour 3 -- pas encore le prochain declenchement")
	var t4 = combat.play_turn(3)
	assert_eq(t4.degats_supplementaires_adversaire, 2, "tour 4 -- nouveau declenchement")


func test_node630_habilete_adverse_baisse_tous_les_3pv_perdus():
	# nœud 630 : "elle perd 1 point d'Habileté tous les 3 PV perdus" --
	# reutilise HabiliteAdverseDegressiveParDegatsCumules (Tome 1) avec les
	# parametres EXACTS de ce nœud (pas=3), jamais exerces directement dans
	# un contexte Tome 2 (seul pas=4 et pas=2 avaient ete testes au Tome 1).
	var mod = Mods.HabiliteAdverseDegressiveParDegatsCumules.new(3, 1)
	var combat = CombatScript.new(9, 12, 30, 100, {"modificateurs": [mod]})
	var t1 = combat.play_turn(6)  # diff=-3, die6 -> table[-3][5]=[4,3] : 4 degats (seuil de 3 franchi -- 1 palier)
	assert_eq(t1.degats_billy, 4)
	var t2 = combat.play_turn(5)  # palier atteint -- hab_adversaire=11, diff=-2 -> table[-2][4]=[4,3]
	assert_eq(t2.degats_billy, 4, "1 palier de 3 PV perdus -- Habileté adverse a baisse de 1 (diff -3 -> -2)")


func test_node480_immunite_critique_et_limite_de_tours_combinees():
	# nœud 480 (Deux incarnations du vide) : les 2 mecanismes reutilises
	# (ImmuniteContreAttaqueCritique, LimiteDeTours) sont prouves
	# separement ailleurs, mais jamais ENSEMBLE sur ce nœud precis --
	# verifie ici que les deux fonctionnent correctement une fois combines.
	var mod_critique = Mods.ImmuniteContreAttaqueCritique.new()
	var mod_limite = Mods.LimiteDeTours.new(3, "billy")
	var combat = CombatScript.new(9, 9, 20, 8, {"adresse_billy": 3, "critique_billy": 10, "modificateurs": [mod_critique, mod_limite]})
	var t1 = combat.play_turn(3, 1)  # esquive=1 -- devrait normalement declencher une contre-attaque critique
	assert_true(t1.esquive)
	assert_eq(t1.degats_billy, 0, "immunite totale au critique -- meme le degat de base est annule")
	assert_false(combat.is_over(), "pas encore au tour 3")
	combat.play_turn(3)
	combat.play_turn(3)
	assert_true(combat.is_over(), "le Pyro-Barbare met fin au combat au tour 3")
	assert_eq(combat.get_winner(), "billy")
