extends "res://addons/gut/test.gd"

# Chapitre du livre 1 (fdcn-1.json / compilated-data) choisi car il a des
# stats INCONDITIONNELLES simples (pas de stats_cond, pas d'item a
# acquerir/retirer) : {'end': 1}. Ideal pour verrouiller l'application des
# stats de chapitre de façon deterministe.
const SIMPLE_STATS_NODE_ID = 128

func before_all():
	Player.insert_all_objects()


func before_each():
	Player.launch_new_billy()
	AppParameters.set_billy_type('pegu')
	Player._recompute_stats()


func test_billy_base_stats_pegu_is_neutral():
	AppParameters.set_billy_type('pegu')
	Player._recompute_stats()
	assert_eq(Player.get_end(), 2)
	assert_eq(Player.get_adr(), 1)
	assert_eq(Player.get_hab(), 2)
	assert_eq(Player.get_chamax(), 3)
	assert_eq(Player.get_deg(), 0)


func test_billy_base_stats_guerrier():
	AppParameters.set_billy_type('guerrier')
	Player._recompute_stats()
	# base (2,1,2,3,0) + guerrier (hab+2, chamax-1, deg+1)
	assert_eq(Player.get_hab(), 4)
	assert_eq(Player.get_chamax(), 2)
	assert_eq(Player.get_deg(), 1)


func test_billy_base_stats_prudent():
	AppParameters.set_billy_type('prudent')
	Player._recompute_stats()
	# base (hab=2, chamax=3) + prudent (hab-1, chamax+2)
	assert_eq(Player.get_hab(), 1)
	assert_eq(Player.get_chamax(), 5)


func test_billy_base_stats_paysan():
	AppParameters.set_billy_type('paysan')
	Player._recompute_stats()
	# base (adr=1, end=2) + paysan (adr-1, end+2)
	assert_eq(Player.get_adr(), 0)
	assert_eq(Player.get_end(), 4)


func test_billy_base_stats_debrouillard():
	AppParameters.set_billy_type('debrouillard')
	Player._recompute_stats()
	# base (adr=1, end=2) + debrouillard (adr+2, end-1)
	assert_eq(Player.get_adr(), 3)
	assert_eq(Player.get_end(), 1)


func test_item_stats_are_added_to_totals():
	AppParameters.set_billy_type('pegu')
	Player._recompute_stats()
	var hab_before = Player.get_hab()
	Player.add_item_from_options('EPEE')  # stats: {'hab': 4}
	assert_eq(Player.get_hab(), hab_before + 4)
	assert_eq(Player.get_hab_items(), 4)


func test_removing_item_reverts_its_stats():
	AppParameters.set_billy_type('pegu')
	Player._recompute_stats()
	var hab_before = Player.get_hab()
	Player.add_item_from_options('EPEE')
	Player.remove_item_from_options('EPEE')
	assert_eq(Player.get_hab(), hab_before)
	assert_eq(Player.get_hab_items(), 0)


func test_visiting_same_chapter_twice_in_a_session_applies_stats_only_once():
	# Regression: c'est exactement la garde-fou (is_new_node_for_this_billy)
	# qui a ete corrigee suite au bug "stats de chapitres infinies" (cf
	# commit 95ec4c3). On visite deux fois le meme chapitre dans LA MEME
	# session (sans changer de Billy), les stats de chapitre ne doivent
	# etre appliquees qu'une seule fois.
	var end_chapters_before = Player.end_chapters
	Player.go_to_node(SIMPLE_STATS_NODE_ID)
	var end_chapters_after_first_visit = Player.end_chapters
	assert_eq(end_chapters_after_first_visit, end_chapters_before + 1)

	Player.go_to_node(SIMPLE_STATS_NODE_ID)  # meme chapitre, meme session
	assert_eq(Player.end_chapters, end_chapters_after_first_visit,
		"revisiter le meme chapitre dans la meme session ne doit pas re-appliquer ses stats")


func test_launch_new_billy_resets_chapter_stats_before_revisiting():
	# Regression directe du commit 95ec4c3: "les stats de chapitres
	# n'étaient pas reset lors qu'on avait un nouveau Billy, ceci permettait
	# d'avoir des stats infinies". On visite un chapitre avec un premier
	# Billy, on relance une partie (nouveau Billy), on revisite LE MEME
	# chapitre: les stats ne doivent pas s'accumuler par rapport au premier
	# passage.
	Player.go_to_node(SIMPLE_STATS_NODE_ID)
	var end_chapters_first_billy = Player.end_chapters
	assert_eq(end_chapters_first_billy, 1)

	Player.launch_new_billy()
	assert_eq(Player.end_chapters, 0, "launch_new_billy doit remettre les stats de chapitre a zero")

	Player.go_to_node(SIMPLE_STATS_NODE_ID)
	assert_eq(Player.end_chapters, 1,
		"le nouveau Billy doit repartir de zero, pas cumuler avec l'ancien passage")


func test_chapter_stats_are_additive_and_never_subtracted_by_a_second_different_chapter():
	# Documente le comportement ACTUEL (voir TEST_PLAN.md P1): chaque
	# nouveau chapitre visite AJOUTE ses stats de chapitre, il n'existe
	# aucun mecanisme de retrait. Ce test verrouille ce choix pour qu'un
	# futur changement soit conscient plutot qu'une regression silencieuse.
	Player.go_to_node(SIMPLE_STATS_NODE_ID)  # {'end': 1}
	assert_eq(Player.end_chapters, 1)
	Player.go_to_node(112)  # {'end': 1, 'hab': 1} + aquire un objet, mais different chapitre
	assert_eq(Player.end_chapters, 2, "les stats de chapitres s'additionnent, chapitre apres chapitre")
	assert_eq(Player.hab_chapters, 1)
