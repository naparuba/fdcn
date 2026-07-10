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
	assert_eq(r.billy.pv, 15)
	assert_eq(r.adversaire.pv, 7)
	assert_eq(combat.pv_billy, 15)
	assert_eq(combat.pv_adversaire, 7)
	assert_eq(combat.tour, 1)
	assert_eq(len(combat.pile), 1)


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
	assert_true(r.attack_die_roll >= 1 and r.attack_die_roll <= 6)


# --- Armure, Esquive, Contre-Attaque Critique, plafond PAYSAN, Pyro-Barbare

func test_armure_reduces_incoming_damage_one_for_one():
	var combat = CombatScript.new(5, 5, 20, 20, {"armure_billy": 2})
	var r = combat.play_turn(1)  # diff=0, die=1 => brut 3--5, Billy a 2 Armure
	assert_eq(r.degats_adversaire, 3, "5 degats bruts - 2 Armure = 3")
	assert_eq(r.degats_billy, 3, "l'Armure de Billy ne change pas ce qu'il infligé")


func test_armure_never_makes_damage_negative():
	var combat = CombatScript.new(5, 5, 20, 20, {"armure_billy": 99})
	var r = combat.play_turn(1)
	assert_eq(r.degats_adversaire, 0)


func test_armure_adversaire_reduces_billys_outgoing_damage():
	var combat = CombatScript.new(5, 5, 20, 20, {"armure_adversaire": 2})
	var r = combat.play_turn(1)  # brut 3--5
	assert_eq(r.degats_billy, 1, "3 degats bruts - 2 Armure = 1")


func test_esquive_is_not_attempted_below_2_adresse():
	var combat = CombatScript.new(5, 5, 20, 20, {"adresse_billy": 1})
	assert_false(combat.peut_esquiver())
	var r = combat.play_turn(1, 1)  # jet d'esquive fourni par erreur, doit etre ignore
	assert_false(r.esquive)
	assert_null(r.esquive_die_roll)
	assert_eq(r.degats_adversaire, 5, "sans esquive possible, les degats bruts s'appliquent normalement")


func test_esquive_succeeds_when_the_roll_is_at_or_under_adresse():
	var combat = CombatScript.new(5, 5, 20, 20, {"adresse_billy": 3})
	var r = combat.play_turn(1, 3)  # jet d'esquive = 3 <= Adresse (3)
	assert_true(r.esquive)
	assert_eq(r.degats_adversaire, 0)
	assert_false(r.contre_attaque_critique)


func test_esquive_fails_when_the_roll_is_over_adresse():
	var combat = CombatScript.new(5, 5, 20, 20, {"adresse_billy": 2})
	var r = combat.play_turn(1, 4)  # jet d'esquive = 4 > Adresse (2)
	assert_false(r.esquive)
	assert_eq(r.degats_adversaire, 5, "brut normal, l'esquive a echoue")


func test_esquive_roll_of_1_triggers_a_critical_counter_attack():
	# diff=0 (hab 5 vs 5) : degats max (die=6) => 5--3, +2 de Critique
	var combat = CombatScript.new(5, 5, 20, 20, {"adresse_billy": 3, "critique_billy": 2})
	var r = combat.play_turn(1, 1)  # jet d'esquive = 1
	assert_true(r.esquive)
	assert_true(r.contre_attaque_critique)
	assert_eq(r.degats_adversaire, 0, "l'esquive s'applique toujours, aucun degat subi")
	assert_eq(r.degats_billy, 7, "degats max (5) + Critique (2) = 7")


func test_critical_counter_attack_ignores_the_adversaires_armure():
	var combat = CombatScript.new(5, 5, 20, 20, {
		"adresse_billy": 3, "critique_billy": 2, "armure_adversaire": 99,
	})
	var r = combat.play_turn(1, 1)
	assert_eq(r.degats_billy, 7, "l'Armure adverse (99) est ignoree par la contre-attaque critique")


func test_plafond_degats_subis_caps_incoming_damage_after_armure():
	# diff=-7, die=1 => brut 0--12. 2 Armure -> 10. Plafond PAYSAN (3) -> 3.
	var combat = CombatScript.new(1, 8, 20, 20, {"armure_billy": 2, "plafond_degats_subis_billy": 3})
	var r = combat.play_turn(1)
	assert_eq(r.degats_adversaire, 3, "le plafond s'applique APRES l'Armure (12-2=10, plafonne a 3)")


func test_plafond_degats_subis_does_not_raise_damage_below_it():
	var combat = CombatScript.new(5, 5, 20, 20, {"plafond_degats_subis_billy": 3})
	var r = combat.play_turn(3)  # diff=0, die=3 => brut 3--3
	assert_eq(r.degats_adversaire, 3, "deja sous le plafond, rien ne change")


func test_pyro_bonus_is_added_to_billys_habilete_for_the_whole_combat():
	# Sans bonus, hab_billy=1 vs hab_adversaire=5 => diff=-4. Avec +4 de
	# Pyro-Barbare, hab_billy effectif=5 => diff=0.
	var combat = CombatScript.new(1, 5, 20, 20, {"pyro_bonus": 4})
	assert_eq(combat.hab_billy, 5)
	var r = combat.play_turn(1)  # diff=0, die=1 => 3--5
	assert_eq(r.degats_billy, 3)
	assert_eq(r.degats_adversaire, 5)
	assert_eq(CombatScript.clamp_diff(combat.hab_billy - combat.hab_adversaire), 0)


# --- Pile de tours : annulation, isolation des copies, deltas PV

func test_undo_last_turn_restores_the_previous_state():
	var combat = CombatScript.new(5, 5, 20, 10)
	combat.play_turn(1)  # 3--5 => pv_billy=15, pv_adversaire=7
	assert_eq(combat.pv_billy, 15)
	assert_eq(combat.pv_adversaire, 7)

	var annule = combat.undo_last_turn()
	assert_not_null(annule)
	assert_eq(combat.pv_billy, 20, "retour a l'etat initial, sans recalcul")
	assert_eq(combat.pv_adversaire, 10)
	assert_eq(combat.tour, 0)
	assert_eq(len(combat.pile), 0)


func test_undo_last_turn_can_be_called_repeatedly_to_go_back_several_turns():
	var combat = CombatScript.new(5, 5, 20, 20)
	combat.play_turn(1)  # tour 1
	combat.play_turn(2)  # tour 2
	combat.play_turn(3)  # tour 3
	assert_eq(combat.tour, 3)

	combat.undo_last_turn()
	assert_eq(combat.tour, 2)
	combat.undo_last_turn()
	assert_eq(combat.tour, 1)
	combat.undo_last_turn()
	assert_eq(combat.tour, 0)
	assert_eq(combat.pv_billy, 20, "retour complet a l'etat initial")


func test_undo_last_turn_with_no_turns_played_logs_an_error_and_returns_null():
	var combat = CombatScript.new(5, 5, 20, 20)
	assert_false(combat.peut_annuler_dernier_tour())
	var r = combat.undo_last_turn()
	assert_null(r)
	assert_push_error_count(1)


func test_undoing_then_replaying_a_turn_can_give_a_different_outcome():
	# Le joueur "pas content d'un tour l'annule et recommence" : rejouer
	# avec un jet different doit donner un resultat different, sans que
	# l'ancien tour (deja depile) n'interfere.
	var combat = CombatScript.new(5, 5, 20, 20)
	combat.play_turn(1)  # 3--5
	assert_eq(combat.pv_adversaire, 17)
	combat.undo_last_turn()
	combat.play_turn(6)  # 5--3
	assert_eq(combat.pv_adversaire, 15)
	assert_eq(combat.pv_billy, 17)
	assert_eq(len(combat.pile), 1, "le tour annule n'est pas reste dans la pile")


func test_pile_entries_are_independent_copies_not_shared_references():
	var combat = CombatScript.new(5, 5, 20, 20)
	var premier = combat.play_turn(1)
	var deuxieme = combat.play_turn(1)
	assert_ne(premier.billy, deuxieme.billy, "deux EtatCombattant distincts, jamais partages")
	assert_eq(premier.billy.pv, 15, "le premier tour reste inchange apres le second")
	assert_eq(deuxieme.billy.pv, 10)


func test_get_pv_delta_billy_is_zero_before_any_turn():
	var combat = CombatScript.new(5, 5, 20, 20)
	assert_eq(combat.get_pv_delta_billy(), 0)
	assert_eq(combat.get_pv_delta_adversaire(), 0)


func test_get_pv_delta_reflects_damage_taken_and_dealt():
	var combat = CombatScript.new(5, 5, 20, 20)
	combat.play_turn(1)  # brut 3--5 : Billy inflige 3, subit 5
	assert_eq(combat.get_pv_delta_billy(), -5)
	assert_eq(combat.get_pv_delta_adversaire(), -3)


func test_get_pv_delta_after_undo_reflects_the_reverted_state():
	var combat = CombatScript.new(5, 5, 20, 20)
	combat.play_turn(1)
	combat.undo_last_turn()
	assert_eq(combat.get_pv_delta_billy(), 0, "revenu a l'etat initial, aucune modification a integrer")
