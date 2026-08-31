extends "res://addons/gut/test.gd"

# Verifie le registre node_id -> Array[Modificateur] (PR16_RECOVERY_PLAN.md
# §0) en isolation, sans passer par main.gd -- couverture structurelle
# (bonnes classes, dans le bon ordre) pour un echantillon representatif des
# deux tomes. Le CABLAGE REEL (main.gd -> Combat.new()) est verifie a part
# dans test/integration/test_combat_modificateurs_wiring.gd, via un vrai
# go_to_node() -- cf le rappel du plan : "ne pas se fier aux seuls tests
# unitaires comme preuve de succes".

const Registre = preload('res://combat_modificateurs_par_node.gd')
const Mods = preload('res://combat_modificateurs.gd')


func before_each():
	# Player.possessed_items/AppParameters.billy_type sont des singletons
	# partages par toute la suite -- remis a un etat neutre avant CHAQUE
	# test (meme piege que Sounder.player.stream, cf test_success_popup.gd).
	Player.possessed_items = []
	AppParameters.set_billy_type('pegu')


func test_noeud_inconnu_ne_renvoie_rien():
	assert_eq(Registre.for_node(1, 999999), [])
	assert_eq(Registre.for_node(2, 999999), [])


func test_livre_inconnu_ne_renvoie_rien():
	assert_eq(Registre.for_node(3, 76), [])


func test_noeuds_exclus_deliberement_ne_renvoient_rien():
	# 306 (jamais teste), 475/607 (Virilus -- classe DeSupplementaireParTour
	# jamais exercee par un test + chainage d'etat manquant), cf en-tete de
	# combat_modificateurs_par_node.gd.
	assert_eq(Registre.for_node(1, 306), [])
	assert_eq(Registre.for_node(1, 475), [])
	assert_eq(Registre.for_node(1, 607), [])


func test_noeud_76_squelettes_tome1():
	var mods = Registre.for_node(1, 76)
	assert_eq(mods.size(), 1)
	assert_true(mods[0] is Mods.HabiliteAdverseDegressiveParDegatsCumules)
	assert_eq(mods[0].pas, 4)
	assert_eq(mods[0].perte, 1)


func test_noeud_155_reprend_exactement_la_mecanique_du_76_sans_test_dedie():
	var mods_76 = Registre.for_node(1, 76)
	var mods_155 = Registre.for_node(1, 155)
	assert_eq(mods_155.size(), mods_76.size())
	assert_true(mods_155[0] is Mods.HabiliteAdverseDegressiveParDegatsCumules)
	assert_eq(mods_155[0].pas, mods_76[0].pas)
	assert_eq(mods_155[0].perte, mods_76[0].perte)


func test_noeud_240_esquive_desactivee_par_lance_ou_arc_vrais_items():
	Player.possessed_items = []
	var mods = Registre.for_node(1, 240)
	assert_eq(mods.size(), 2)
	assert_true(mods[0] is Mods.EsquiveAdverseSurDe)
	assert_true(mods[1] is Mods.SeuilPV)
	assert_true(mods[0].predicat.call(1), "sans LANCE/ARC, l'esquive sur 1/2/3 doit rester active")
	Player.possessed_items = ["LANCE"]
	var mods_avec_lance = Registre.for_node(1, 240)
	assert_false(mods_avec_lance[0].predicat.call(1), "avec la LANCE equipee, l'esquive du nœud 240 doit etre neutralisee")
	Player.possessed_items = []


func test_noeud_339_regeneration_desactivee_par_le_medaillon_reel():
	Player.possessed_items = []
	var mods_sans = Registre.for_node(1, 339)
	assert_eq(mods_sans.size(), 1)
	assert_true(mods_sans[0] is Mods.RegenerationSurDe)
	assert_false(mods_sans[0].desactivee, "sans medaillon, la regeneration doit rester active")
	Player.possessed_items = ["MEDAILLON DE RUNIR"]
	var mods_avec = Registre.for_node(1, 339)
	assert_true(mods_avec[0].desactivee, "avec le medaillon reellement possede, la regeneration doit etre desactivee")
	Player.possessed_items = []


func test_noeud_387_condition_externe_gelee_neutre_jamais_de_bonus():
	var mods = Registre.for_node(1, 387)
	assert_eq(mods.size(), 1)
	assert_true(mods[0] is Mods.AttaqueBonusSiConditionExterne)
	assert_false(mods[0].condition_vraie, "condition externe gelee neutre -- jamais de Jet de Chance verifiable")


func test_noeud_576_plafond_selon_larchetype_de_billy():
	AppParameters.set_billy_type('paysan')
	assert_eq(Registre.for_node(1, 576)[0].degats, 3)
	AppParameters.set_billy_type('prudent')
	assert_eq(Registre.for_node(1, 576)[0].degats, 5)
	AppParameters.set_billy_type('guerrier')
	assert_eq(Registre.for_node(1, 576)[0].degats, 10)


func test_noeud_256_mimine_tome2():
	var mods = Registre.for_node(2, 256)
	assert_eq(mods.size(), 2)
	assert_true(mods[0] is Mods.FinCombatSurParitesConsecutives)
	assert_true(mods[1] is Mods.DegatsPeriodiques)


func test_noeud_514_khazin_conditionne_par_litem_reel_les_3_regles_du_gardien_toujours_actives():
	Player.possessed_items = []
	var mods_sans_khazin = Registre.for_node(2, 514)
	assert_eq(mods_sans_khazin.size(), 3, "sans Khazin, seules les 3 regles du Gardien -- jamais suspendues (etat neutre)")
	Player.possessed_items = ["KHAZIN"]
	var mods_avec_khazin = Registre.for_node(2, 514)
	assert_eq(mods_avec_khazin.size(), 4, "avec Khazin reellement possede, sa regle de degats periodiques s'ajoute")
	Player.possessed_items = []


func test_noeud_584_condition_externe_gelee_neutre_jamais_de_multiplicateur():
	var mods = Registre.for_node(2, 584)
	assert_eq(mods.size(), 1)
	assert_false(mods[0].condition.call(1), "condition externe gelee neutre -- jamais de Jet de Chance verifiable")


func test_noeud_630_variante_selon_larchetype_de_billy():
	AppParameters.set_billy_type('paysan')
	assert_eq(Registre.for_node(2, 630).size(), 3, "PAYSAN : 2 regles de base + les djinns de terre")
	AppParameters.set_billy_type('prudent')
	assert_eq(Registre.for_node(2, 630).size(), 3, "PRUDENT : 2 regles de base + le bloc de marbre suspendable")
	AppParameters.set_billy_type('guerrier')
	assert_eq(Registre.for_node(2, 630).size(), 2, "autre archetype : seulement les 2 regles de base")
