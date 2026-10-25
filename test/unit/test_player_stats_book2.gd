extends "res://addons/gut/test.gd"

# Equivalent de test_player_stats.gd (application reelle des effets de
# chapitre via Player.go_to_node -- pas juste les getters bruts de
# chapter_data.gd/BookData.gd, deja couverts par test_chapter_data_book2.gd
# et test_bookdata_book2.gd), sur les vraies donnees du livre 2.
#
# Les stats de Billy de base (test_billy_base_stats_* dans
# test_player_stats.gd) ne sont PAS redupliquees ici : _apply_billy_stats()/
# _reset_our_stats() sont du code generique sans branche par livre, deja
# verrouille par le livre 1.
#
# Fixtures reelles du livre 2 :
# - noeud 51  : aquire = ['GRI-GRI'] (aucun autre effet)
# - noeud 522 : remove = ['GOURDE SCELLEE'] (aucun autre effet)
# - noeud 450 : stats inconditionnelles {'pv':3} + stats_cond {'deg':1} qui
#   ne s'applique que si le Billy est DEBROUILLARD -- choisi ICI (plutot
#   qu'un noeud avec juste 'pv') car 'deg' passe par le compteur
#   deg_chapters (remis a zero par launch_new_billy()), alors que 'pv' est
#   directement cumule sur self.pv et n'est JAMAIS remis a zero par
#   launch_new_billy()/_fully_reset_our_stats() -- une vraie difference de
#   comportement entre cles de stats, pas un bug de migration, mais un piege
#   si on choisit la mauvaise cle pour verrouiller "revisiter ne rejoue pas
#   les stats".
# - objet "ARC" : stats {'adr':1, 'crit':4, 'hab':3} (toutes des cles gerees)
# - noeud 601 : stats = {'critique': 2} -- 'critique' n'est PAS une cle
#   reconnue par player.gd::_apply_chapter_stat() (seul 'crit' l'est) ; cf
#   test_unhandled... ci-dessous.

const AQUIRE_ONLY_NODE = 51       # aquire: ['GRI-GRI']
const REMOVE_ONLY_NODE = 522      # remove: ['GOURDE SCELLEE']
const COND_STATS_NODE = 450       # stats: {'pv':3}, stats_cond DEBROUILLARD: {'deg':1}
const UNHANDLED_KEY_NODE = 601    # stats: {'critique': 2} (cle non geree)


func before_all():
	AppParameters.set_book_number(2)
	Player.insert_all_objects()


func after_all():
	AppParameters.set_book_number(1)  # ne pas polluer les fichiers suivants


func before_each():
	Player.launch_new_billy()
	AppParameters.set_billy_type('pegu')
	Player._recompute_matched_conditions()
	Player._recompute_stats()


func test_item_stats_are_added_to_totals():
	var hab_before = Player.get_hab()
	var adr_before = Player.get_adr()
	var crit_before = Player.get_crit()
	Player.add_item_from_options('ARC')  # stats: {'adr':1, 'crit':4, 'hab':3}
	assert_eq(Player.get_hab(), hab_before + 3)
	assert_eq(Player.get_adr(), adr_before + 1)
	assert_eq(Player.get_crit(), crit_before + 4)


func test_removing_item_reverts_its_stats():
	var hab_before = Player.get_hab()
	Player.add_item_from_options('ARC')
	Player.remove_item_from_options('ARC')
	assert_eq(Player.get_hab(), hab_before)
	assert_eq(Player.get_hab_items(), 0)


func test_go_to_node_applies_aquire():
	assert_false(Player.have_item('GRI-GRI'))
	Player.go_to_node(AQUIRE_ONLY_NODE)
	assert_true(Player.have_item('GRI-GRI'))


func test_go_to_node_applies_remove():
	Player.add_item_from_options('GOURDE SCELLEE')
	assert_true(Player.have_item('GOURDE SCELLEE'))
	Player.go_to_node(REMOVE_ONLY_NODE)
	assert_false(Player.have_item('GOURDE SCELLEE'))


func test_go_to_node_applies_unconditional_stats():
	var pv_before = Player.get_pv()
	Player.go_to_node(COND_STATS_NODE)
	assert_eq(Player.get_pv(), pv_before + 3)


func test_go_to_node_applies_matching_stats_cond_for_debrouillard():
	AppParameters.set_billy_type('debrouillard')
	Player._recompute_matched_conditions()
	Player._recompute_stats()
	var deg_before = Player.get_deg()
	Player.go_to_node(COND_STATS_NODE)
	assert_eq(Player.get_deg(), deg_before + 1)


func test_go_to_node_does_not_apply_stats_cond_for_pegu():
	var deg_before = Player.get_deg()
	Player.go_to_node(COND_STATS_NODE)
	assert_eq(Player.get_deg(), deg_before,
		"pegu ne matche pas la condition DEBROUILLARD, deg ne doit pas changer")


func test_visiting_same_chapter_twice_in_a_session_applies_stats_only_once():
	AppParameters.set_billy_type('debrouillard')
	Player._recompute_matched_conditions()
	Player._recompute_stats()

	Player.go_to_node(COND_STATS_NODE)
	var deg_chapters_after_first_visit = Player.deg_chapters
	assert_eq(deg_chapters_after_first_visit, 1)

	Player.go_to_node(COND_STATS_NODE)  # meme chapitre, meme session
	assert_eq(Player.deg_chapters, deg_chapters_after_first_visit,
		"revisiter le meme chapitre dans la meme session ne doit pas re-appliquer ses stats")


func test_launch_new_billy_resets_chapter_stats_before_revisiting():
	AppParameters.set_billy_type('debrouillard')
	Player._recompute_matched_conditions()
	Player._recompute_stats()

	Player.go_to_node(COND_STATS_NODE)
	assert_eq(Player.deg_chapters, 1)

	Player.launch_new_billy()
	assert_eq(Player.deg_chapters, 0, "launch_new_billy doit remettre les stats de chapitre a zero")

	AppParameters.set_billy_type('debrouillard')  # launch_new_billy() ne touche pas au type
	Player._recompute_matched_conditions()
	Player._recompute_stats()
	Player.go_to_node(COND_STATS_NODE)
	assert_eq(Player.deg_chapters, 1,
		"le nouveau Billy doit repartir de zero, pas cumuler avec l'ancien passage")


func test_unhandled_stat_key_is_currently_silently_ignored():
	# Documente un ecart REEL trouve en construisant cette suite (pas un
	# bug de migration : player.gd::_apply_chapter_stat() ne reconnait que
	# 'crit', jamais 'critique', et tombe dans le "else" generique qui
	# imprime juste un avertissement -- meme famille que le "STATS INCONNUE
	# DANS OBJET: pv_max" deja documente ailleurs pour les objets). Ce test
	# verrouille le comportement ACTUEL pour qu'un futur changement (fix ou
	# non) soit conscient plutot qu'une surprise silencieuse.
	var crit_chapters_before = Player.crit_chapters
	Player.go_to_node(UNHANDLED_KEY_NODE)
	assert_eq(Player.crit_chapters, crit_chapters_before,
		"'critique' n'est pas une cle reconnue par _apply_chapter_stat -- silencieusement ignoree")
