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


func test_deg_billy_adds_a_flat_bonus_to_a_normal_attack():
	var combat = CombatScript.new(5, 5, 20, 20, {"deg_billy": 2})
	var r = combat.play_turn(1)  # brut 3--5, +2 DEGATS
	assert_eq(r.degats_billy, 5)
	assert_eq(r.degats_adversaire, 5, "le DEGATS de Billy n'affecte pas ce qu'il subit")


func test_deg_adversaire_adds_a_flat_bonus_to_what_billy_receives():
	var combat = CombatScript.new(5, 5, 20, 20, {"deg_adversaire": 2})
	var r = combat.play_turn(1)  # brut 3--5, +2 DEGATS adverse
	assert_eq(r.degats_adversaire, 7)


func test_deg_billy_does_not_apply_on_top_of_a_critical_counter_attack():
	var combat = CombatScript.new(5, 5, 20, 20, {"adresse_billy": 3, "critique_billy": 2, "deg_billy": 10})
	var r = combat.play_turn(1, 1)  # esquive=1 => contre-attaque critique
	assert_eq(r.degats_billy, 7, "degats max (5) + Critique (2) seulement, DEGATS (10) ignore")


func test_deg_adversaire_does_not_apply_when_billy_dodges():
	var combat = CombatScript.new(5, 5, 20, 20, {"adresse_billy": 3, "deg_adversaire": 10})
	var r = combat.play_turn(1, 2)  # esquive reussie (2 <= 3), sans critique
	assert_true(r.esquive)
	assert_eq(r.degats_adversaire, 0, "esquive integrale, le bonus DEGATS adverse est aussi annule")


func test_deg_and_armure_combine_on_a_normal_attack():
	var combat = CombatScript.new(5, 5, 20, 20, {"deg_billy": 3, "armure_adversaire": 1})
	var r = combat.play_turn(1)  # brut 3 + 3 DEGATS = 6, - 1 Armure = 5
	assert_eq(r.degats_billy, 5)


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


# --- Combats complets, un par archetype de Billy, avec de vrais objets et
# de vrais ennemis (fdcn-1-compilated-*.json). Chaque archetype a sa propre
# particularite (cf player.gd::_apply_billy_stats et le Guide detaille) --
# ces tests la font apparaitre dans un vrai combat joue jusqu'au bout, pas
# juste verifier les stats de base. Sequences de des choisies a la main
# et rejouees via un simulateur Python independant avant d'etre transcrites
# ici, pour eviter une erreur de calcul (cf methode deja utilisee pour la
# Table des Situations).
#
# Fixtures ennemies reelles :
# - noeud 14 (livre 1) "GUERRIERS ORCS" : hab=5, pv=8, arm=0, deg=0, pyro=4
# - noeud 297 (livre 1) "2 SERGENT D'ARME" : hab=8, pv=12, arm=1, deg=1,
#   pyro=0 (pas d'aide du Pyro-Barbare sur ce combat -- plus difficile)
#
# Stats d'objets reelles (fdcn-1-compilated-all-objects.json) :
#   EPEE {hab:4} -- MORGENSTERN {deg:1,end:1,hab:1} -- MARMITE {arm:1,end:2}
#   FOURCHE {end:3,hab:1} -- SAC DE GRAINS {cha:2,end:2} -- PAMPHLET {cha:4}
#   KIT DE SOIN {cha:1} -- ARC {adr:1,crit:4,hab:3} -- KIT D'ESCALADE {adr:1}
#
# Stats de base (fiche officielle) : HABILETE=2, ADRESSE=1 (max 5),
# ENDURANCE=2, CHANCE=3 ; PV_MAX = ENDURANCE * 3.


func test_full_combat_pegu_neutral_with_marmite_vs_guerriers_orcs():
	# PEGU : ni bonus ni malus (cf player.gd::_apply_billy_stats, aucune
	# branche pour 'pegu'). Equipe uniquement de la Marmite (l'objet
	# "universel" recommande par le guide pour tous les CARACTERES).
	# hab=2 (base), end=2+2(marmite)=4 => pv_max=12, arm=0+1(marmite)=1.
	var combat = CombatScript.new(2, 5, 12, 8, {"armure_billy": 1, "pyro_bonus": 4})
	assert_eq(CombatScript.clamp_diff(combat.hab_billy - combat.hab_adversaire), 1,
		"Avantage Leger, grace au seul bonus du Pyro-Barbare")

	var t1 = combat.play_turn(3)
	assert_eq(t1.degats_billy, 3)
	assert_eq(t1.degats_adversaire, 2, "3 bruts - 1 Armure (Marmite)")
	var t2 = combat.play_turn(3)
	var t3 = combat.play_turn(3)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy")
	assert_eq(combat.pv_billy, 6, "12 PV de depart - 2 - 2 - 2")
	assert_eq(combat.pv_adversaire, 0)
	assert_eq(combat.tour, 3)


func test_full_combat_guerrier_epee_morgenstern_marmite_vs_guerriers_orcs():
	# GUERRIER : +Habileté (hab base 2+2=4), -Chance (chamax 3-1=2), +1
	# Degat naturel. Avec Epee+Morgenstern+Marmite : hab=4+4(epee)+1(morg)=9,
	# deg=1+1(morg)=2, end=2+1(morg)+2(marmite)=5 => pv_max=15,
	# arm=0+1(marmite)=1. Avec le Pyro-Barbare (+4), diff=13-5=8, plafonne a
	# 7 (Avantage Lourd) -- exactement la situation de "DOMINATION" evoquee
	# par le guide pour ce CARACTERE : meme un mauvais jet (die=1) ecrase
	# l'adversaire en 2 tours sans risque reel.
	var combat = CombatScript.new(9, 5, 15, 8, {"deg_billy": 2, "armure_billy": 1, "pyro_bonus": 4})
	assert_eq(CombatScript.clamp_diff(combat.hab_billy - combat.hab_adversaire), 7)

	var t1 = combat.play_turn(1)  # le PIRE jet possible
	assert_eq(t1.degats_billy, 6, "table(diff=7,die=1)=4 + 2 DEGATS")
	assert_eq(t1.degats_adversaire, 2, "table=3 - 1 Armure")
	combat.play_turn(1)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy")
	assert_eq(combat.pv_billy, 11, "15 - 2 - 2 : quasiment intact meme avec le pire jet")
	assert_eq(combat.tour, 2)


func test_full_combat_paysan_fourche_sac_de_grains_morgenstern_vs_sergent_darme():
	# PAYSAN : -Adresse (adr base 1-1=0, jamais d'esquive), +Endurance (end
	# base 2+2=4). Avec Fourche+Sac de Grains+Morgenstern :
	# hab=2+1(fourche)+1(morg)=4, end=4+3(fourche)+2(sac)+1(morg)=10 =>
	# pv_max=30, deg=0+1(morg)=1. Contre le Sergent d'Arme (hab=8, pas
	# d'aide du Pyro-Barbare ici) : Desavantage (diff=-4). La particularite
	# du PAYSAN (plafond de 3 PV subis par tour, APRES l'Armure) tient sur
	# TOUTE la longueur du combat, meme desavantage + un ennemi qui a lui
	# meme 1 Armure et 1 DEGATS : verrouille comme invariant plutot que des
	# valeurs figees, pour rester correct quel que soit le jet.
	var combat = CombatScript.new(4, 8, 30, 12, {
		"deg_billy": 1, "armure_adversaire": 1, "deg_adversaire": 1,
		"plafond_degats_subis_billy": 3,
	})
	assert_eq(CombatScript.clamp_diff(combat.hab_billy - combat.hab_adversaire), -4)

	var dies = [1, 6, 3, 2, 5, 4]
	var i = 0
	while !combat.is_over() and i < 50:
		var t = combat.play_turn(dies[i % len(dies)])
		assert_true(t.degats_adversaire <= 3,
			"le plafond PAYSAN ne doit JAMAIS etre depasse, tour %s a inflige %s" % [t.tour, t.degats_adversaire])
		i += 1
	assert_eq(combat.get_winner(), "billy",
		"malgre le Desavantage, 30 PV et un plafond a 3/tour suffisent face a 12 PV adverses")
	assert_eq(combat.tour, 5)
	assert_eq(combat.pv_billy, 15)


func test_full_combat_prudent_pamphlet_kit_de_soin_sac_de_grains_vs_guerriers_orcs():
	# PRUDENT : -Habileté (hab base 2-1=1), +Chance (chamax base 3+2=5).
	# Avec Pamphlet+Kit de Soin+Sac de Grains : chamax=5+4+1+2=12, end=2+2
	# (sac)=4 => pv_max=12. Aucun objet ne touche Habileté/Adresse/Armure/
	# Degats/Critique -- exactement ce que decrit le guide ("n'aura jamais
	# besoin d'Armure, de Degats ou d'esquives"). Meme aide par le
	# Pyro-Barbare (+4, diff=0, Egalite), la victoire est tres juste : le
	# PRUDENT n'est pas fait pour se battre, meme a egalite.
	var combat = CombatScript.new(1, 5, 12, 8, {"pyro_bonus": 4})
	assert_eq(CombatScript.clamp_diff(combat.hab_billy - combat.hab_adversaire), 0)

	combat.play_turn(3)
	combat.play_turn(4)
	combat.play_turn(2)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy")
	assert_eq(combat.pv_billy, 2, "victoire tres chere payee, a 2 PV pres sur 12")


func test_full_combat_prudent_loses_without_the_pyro_barbare_and_should_flee_instead():
	# Meme PRUDENT, mais contre le Sergent d'Arme (hab=8, pas de
	# Pyro-Barbare cette fois, et l'ennemi a Armure+Degats) : Desavantage
	# Lourd (diff=-7). Documente numeriquement pourquoi le guide recommande
	# de FUIR plutot que de combattre avec ce CARACTERE : le combat direct
	# est perdant, alors que le cout de fuite (5 Points de Chance) est
	# trivial face a son chamax (12).
	var combat = CombatScript.new(1, 8, 12, 12, {"armure_adversaire": 1, "deg_adversaire": 1})
	assert_eq(CombatScript.clamp_diff(combat.hab_billy - combat.hab_adversaire), -7)
	assert_eq(CombatScript.get_fuite_cost(combat.hab_billy, combat.hab_adversaire), 5,
		"cout de fuite trivial compare a un chamax de 12 -- d'ou la strategie du guide")

	combat.play_turn(4)
	combat.play_turn(2)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "adversaire",
		"sans Chance ni aide, le PRUDENT perd un combat direct -- fuir aurait ete bien moins cher")
	assert_eq(combat.pv_billy, 0)


func test_full_combat_debrouillard_arc_marmite_kit_descalade_vs_sergent_darme():
	# DEBROUILLARD : +Adresse (adr base 1+2=3), -Endurance (end base 2-1=1).
	# Avec Arc+Marmite+Kit d'Escalade : hab=2+3(arc)=5,
	# adr=3+1(arc)+1(kit)=5 (le maximum autorise par la fiche officielle),
	# end=1+2(marmite)=3 => pv_max=9 (fragile), arm=0+1(marmite)=1,
	# crit=0+4(arc)=4. Contre le Sergent d'Arme (hab=8, arm=1, deg=1) :
	# Desavantage (diff=-3) malgre tout, mais l'Adresse au maximum esquive
	# quasiment tout, et le Critique perce l'Armure adverse lors de la
	# contre-attaque critique -- exactement ce que decrit le guide
	# ("excelle face aux adversaires lourds car ses Critiques peuvent
	# percer leur Armure").
	var combat = CombatScript.new(5, 8, 9, 12, {
		"adresse_billy": 5, "critique_billy": 4, "armure_billy": 1,
		"armure_adversaire": 1, "deg_adversaire": 1,
	})
	assert_eq(CombatScript.clamp_diff(combat.hab_billy - combat.hab_adversaire), -3)

	var t1 = combat.play_turn(4, 3)  # esquive (3<=5)
	assert_true(t1.esquive)
	assert_false(t1.contre_attaque_critique)
	var t2 = combat.play_turn(2, 5)  # esquive (5<=5)
	assert_true(t2.esquive)
	var t3 = combat.play_turn(5, 1)  # esquive=1 => contre-attaque critique
	assert_true(t3.contre_attaque_critique)
	assert_eq(t3.degats_billy, 8,
		"degats max (table diff=-3,die=6 => 4) + Critique (4) = 8, Armure adverse (1) ignoree")
	var t4 = combat.play_turn(1, 2)  # esquive (2<=5)
	assert_true(t4.esquive)

	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "billy")
	assert_eq(combat.pv_billy, 9, "esquive integrale sur les 4 tours -- aucun degat subi de bout en bout")
	assert_eq(combat.tour, 4)


# --- Et quand Billy PERD : deux mecaniques differentes, deux archetypes
# differents. Le combat ne garantit jamais la victoire -- ces tests
# verrouillent que la defaite marche correctement (get_winner, PV a 0)
# tout autant que la victoire.

func test_full_combat_debrouillard_loses_to_two_failed_dodges_in_a_row():
	# Meme DEBROUILLARD que le test precedent (adresse=5, donc 5/6 de
	# chances d'esquiver chaque tour), mais desormais malchanceux : deux
	# jets d'esquive a 6 de suite (le seul echec possible) sur des jets
	# d'attaque faibles (die=1, table diff=-3 => 2--6). Documente
	# precisement ce que le guide decrit ("le vent tourne en sa
	# defaveur... une attaque finit par passer... lui arrachant la moitie
	# voire la totalite de ses PV") : sa reserve de PV (9, la plus basse
	# des 5 archetypes) ne pardonne pas deux echecs consecutifs.
	var combat = CombatScript.new(5, 8, 9, 12, {
		"adresse_billy": 5, "critique_billy": 4, "armure_billy": 1,
		"armure_adversaire": 1, "deg_adversaire": 1,
	})
	var t1 = combat.play_turn(1, 6)  # esquive ratee (6 > 5)
	assert_false(t1.esquive)
	assert_eq(t1.degats_adversaire, 6, "table(diff=-3,die=1)=6, +1 DEGATS adverse -1 Armure = 6")
	assert_eq(combat.pv_billy, 3)

	var t2 = combat.play_turn(1, 6)  # esquive ratee une seconde fois
	assert_false(t2.esquive)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "adversaire",
		"9 PV ne survivent pas a deux echecs d'esquive consecutifs, malgre 5/6 de reussite par tour")
	assert_eq(combat.pv_billy, 0)


func test_full_combat_guerrier_loses_to_virilus_without_the_pyro_barbare():
	# Meme GUERRIER equipe (Epee+Morgenstern+Marmite, hab=9) que le test de
	# victoire, mais desormais face a VIRILUS (noeud 607, le seigneur noir,
	# hab=24, pv=20, arm=1, deg=1) SANS l'aide du Pyro-Barbare sur ce
	# combat precis (pyro=0 pour ce noeud). diff=-15, plafonne a -7
	# (Desavantage Lourd) : exactement la situation inverse de la
	# DOMINATION que le GUERRIER inflige d'habitude -- ici il la subit.
	# N'ayant ni Adresse suffisante pour esquiver (1 < 2) ni de plafond de
	# degats subis (contrairement au PAYSAN), rien ne le protege.
	var combat = CombatScript.new(9, 24, 15, 20, {"deg_billy": 2, "armure_billy": 1, "armure_adversaire": 1})
	assert_eq(CombatScript.clamp_diff(combat.hab_billy - combat.hab_adversaire), -7)
	assert_false(combat.peut_esquiver(), "hab=9 mais Adresse=1 (jamais boostee sur ce build) -- aucune protection")

	combat.play_turn(3)
	combat.play_turn(5)
	combat.play_turn(2)
	assert_true(combat.is_over())
	assert_eq(combat.get_winner(), "adversaire",
		"le meme GUERRIER qui ecrasait les Orcs en 2 tours se fait ecraser a son tour sans le Pyro-Barbare")
	assert_eq(combat.pv_billy, 0)
	assert_eq(combat.pv_adversaire, 14, "Virilus finit le combat a 14/20 PV, largement invaincu")
