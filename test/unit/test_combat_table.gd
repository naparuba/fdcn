extends "res://addons/gut/test.gd"

# Verifie l'autoload CombatTable (cf PR16_RECOVERY_PLAN.md §5) -- couverture
# complete de la plage [-7, 7] et quelques cellules reperes, pour attraper
# toute erreur de transcription lors du passage des constantes GDScript
# (SITUATION_TABLE/FUITE_COST/TIER_NAMES, desormais supprimees de combat.gd)
# vers combat-table.json.


func test_couvre_toute_la_plage_moins_sept_a_sept():
	for diff in range(-7, 8):
		assert_not_null(CombatTable.get_tier_name(diff), "diff=%s doit avoir un nom de palier" % diff)
		for die_roll in range(1, 7):
			assert_eq(CombatTable.get_pair(diff, die_roll).size(), 2,
				"diff=%s, jet=%s doit donner une paire [degats_billy, degats_adversaire]" % [diff, die_roll])


func test_cellule_egalite_jet_1():
	assert_eq(CombatTable.get_pair(0, 1), [3, 5])


func test_cellule_avantage_lourd_borne_haute_jet_6():
	assert_eq(CombatTable.get_pair(7, 6), [12, 0])


func test_cellule_desavantage_lourd_borne_basse_jet_1():
	assert_eq(CombatTable.get_pair(-7, 1), [0, 12])


func test_noms_de_palier():
	assert_eq(CombatTable.get_tier_name(-7), "DESAVANTAGE_LOURD")
	assert_eq(CombatTable.get_tier_name(-4), "DESAVANTAGE")
	assert_eq(CombatTable.get_tier_name(-1), "DESAVANTAGE_LEGER")
	assert_eq(CombatTable.get_tier_name(0), "EGALITE")
	assert_eq(CombatTable.get_tier_name(1), "AVANTAGE_LEGER")
	assert_eq(CombatTable.get_tier_name(3), "AVANTAGE")
	assert_eq(CombatTable.get_tier_name(7), "AVANTAGE_LOURD")


func test_couts_de_fuite():
	assert_eq(CombatTable.get_fuite_cost(-7), 5)
	assert_eq(CombatTable.get_fuite_cost(-3), 3)
	assert_eq(CombatTable.get_fuite_cost(-1), 2)
	assert_eq(CombatTable.get_fuite_cost(0), 1)
	assert_eq(CombatTable.get_fuite_cost(4), 1)
	assert_eq(CombatTable.get_fuite_cost(5), 0)


func test_les_types_charges_depuis_le_json_sont_bien_des_int_pas_des_float():
	# JSON n'a pas de type entier distinct -- Utils.load_json_file() doit
	# reconvertir, sinon get_pair(0, ...) ne trouverait pas la cle 0.0 != 0
	# dans un Dictionary indexe par int (cf Utils.ints_from_json()).
	var pair = CombatTable.get_pair(0, 1)
	assert_eq(typeof(pair[0]), TYPE_INT)
	assert_eq(typeof(pair[1]), TYPE_INT)
	assert_eq(typeof(CombatTable.get_fuite_cost(0)), TYPE_INT)
