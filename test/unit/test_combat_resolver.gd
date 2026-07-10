extends "res://addons/gut/test.gd"

# Verrouille combat.gd contre la "Table des Situations" officielle
# (cf combat.gd pour la source et sa transcription complete). Les valeurs
# ci-dessous sont un echantillon relu directement sur l'image source (pas
# copie depuis combat.gd), pour detecter une erreur de transcription.

var CombatScript = preload('res://combat.gd')


func test_resolve_round_at_egalite_die_1():
	var r = CombatScript.resolve_round(5, 5, 1)  # diff=0, die=1 => 3--5
	assert_eq(r['degats_billy'], 3)
	assert_eq(r['degats_adversaire'], 5)
	assert_eq(r['diff'], 0)


func test_resolve_round_at_egalite_die_6():
	var r = CombatScript.resolve_round(5, 5, 6)  # diff=0, die=6 => 5--3
	assert_eq(r['degats_billy'], 5)
	assert_eq(r['degats_adversaire'], 3)


func test_resolve_round_desavantage_lourd_die_1():
	var r = CombatScript.resolve_round(1, 8, 1)  # diff=-7, die=1 => 0--12
	assert_eq(r['degats_billy'], 0)
	assert_eq(r['degats_adversaire'], 12)


func test_resolve_round_avantage_lourd_die_6():
	var r = CombatScript.resolve_round(12, 5, 6)  # diff=7, die=6 => 12--0
	assert_eq(r['degats_billy'], 12)
	assert_eq(r['degats_adversaire'], 0)


func test_resolve_round_avantage_die_3():
	var r = CombatScript.resolve_round(8, 5, 3)  # diff=3, die=3 => 4--3
	assert_eq(r['degats_billy'], 4)
	assert_eq(r['degats_adversaire'], 3)


func test_resolve_round_desavantage_die_4():
	var r = CombatScript.resolve_round(5, 9, 4)  # diff=-4, die=4 => 2--4
	assert_eq(r['degats_billy'], 2)
	assert_eq(r['degats_adversaire'], 4)


func test_diff_beyond_the_table_is_clamped_to_7():
	# La table ne va que jusqu'a +-7 -- une difference plus grande retombe
	# sur la meme case que 7/-7, cf le commentaire d'en-tete de combat.gd.
	var r_extreme = CombatScript.resolve_round(50, 5, 6)  # diff brut = 45
	var r_sept = CombatScript.resolve_round(12, 5, 6)  # diff = 7
	assert_eq(r_extreme['degats_billy'], r_sept['degats_billy'])
	assert_eq(r_extreme['degats_adversaire'], r_sept['degats_adversaire'])
	assert_eq(r_extreme['diff'], 7)


func test_clamp_diff():
	assert_eq(CombatScript.clamp_diff(45), 7)
	assert_eq(CombatScript.clamp_diff(-45), -7)
	assert_eq(CombatScript.clamp_diff(3), 3)


func test_fuite_cost_matches_the_table():
	assert_eq(CombatScript.get_fuite_cost(5, 12), 5)  # diff=-7 => Desavantage Lourd
	assert_eq(CombatScript.get_fuite_cost(5, 5), 1)   # diff=0 => Egalite
	assert_eq(CombatScript.get_fuite_cost(12, 5), 0)  # diff=7 => Avantage Lourd


func test_tier_names():
	assert_eq(CombatScript.get_tier_name(5, 12), "DESAVANTAGE_LOURD")
	assert_eq(CombatScript.get_tier_name(5, 5), "EGALITE")
	assert_eq(CombatScript.get_tier_name(6, 5), "AVANTAGE_LEGER")
	assert_eq(CombatScript.get_tier_name(12, 5), "AVANTAGE_LOURD")


func test_roll_die_is_always_in_range():
	for i in range(50):
		var d = CombatScript.roll_die()
		assert_true(d >= 1 and d <= 6, "roll_die() doit toujours renvoyer 1-6, a renvoye %s" % d)


func test_play_turn_tracks_pv_on_both_sides():
	var combat = CombatScript.new(5, 5, 20, 10)  # egalite, PV Billy=20, PV Adv=10
	var r = combat.play_turn(1)  # diff=0, die=1 => 3--5
	assert_eq(r['pv_billy'], 15)
	assert_eq(r['pv_adversaire'], 7)
	assert_eq(combat.pv_billy, 15)
	assert_eq(combat.pv_adversaire, 7)
	assert_eq(combat.tour, 1)
	assert_eq(len(combat.historique), 1)


func test_pv_never_goes_below_zero():
	var combat = CombatScript.new(5, 5, 3, 3)
	combat.play_turn(1)  # 3--5 : les deux PV (3) sont depasses
	assert_eq(combat.pv_billy, 0)
	assert_eq(combat.pv_adversaire, 0)


func test_is_over_and_get_winner_when_adversaire_dies():
	var combat = CombatScript.new(12, 5, 20, 5)  # diff=7
	combat.play_turn(6)  # 12--0
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy",
		"l'adversaire (PV=5) tombe a 0 sous les 12 degats -- Billy gagne")


func test_is_over_false_before_anyone_dies():
	var combat = CombatScript.new(5, 5, 20, 20)
	combat.play_turn(1)
	assert_false(combat.is_over())
	assert_null(combat.get_winner())


func test_get_winner_returns_egalite_when_both_die_the_same_turn():
	var combat = CombatScript.new(5, 5, 3, 3)
	combat.play_turn(1)  # diff=0, die=1 => 3--5 : les deux PV (3) sont depasses
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "egalite")


func test_play_turn_after_the_end_returns_null_and_logs_an_error():
	var combat = CombatScript.new(5, 5, 1, 1)
	combat.play_turn(1)
	assert_true(combat.is_over())
	var r = combat.play_turn(1)
	assert_null(r)
	# combat.gd utilise push_error() (pas une erreur moteur native) --
	# assertion dediee, cf addons/gut/test.gd::assert_push_error_count.
	assert_push_error_count(1)


func test_play_turn_without_a_die_roll_uses_a_random_one_in_range():
	var combat = CombatScript.new(5, 5, 100, 100)
	var r = combat.play_turn()
	assert_true(r['die_roll'] >= 1 and r['die_roll'] <= 6)
