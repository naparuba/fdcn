extends "res://addons/gut/test.gd"

# Test d'intégration P0 (cf TEST_PLAN.md §4.1) : le scénario le plus
# important, car il verrouille exactement la classe de bug déjà survenue
# deux fois par le passé (stats de chapitre dupliquées / non réinitialisées,
# cf commit 95ec4c3 et le fix complémentaire apporté pendant cette session).
#
# LIMITE ASSUMÉE: GUT fait tourner tous les tests dans UN SEUL processus
# Godot. On ne peut donc pas "vraiment" relancer l'application. On simule un
# redémarrage en remettant manuellement en mémoire les valeurs qu'un
# processus neuf aurait (tout à zéro), puis en appelant Player.do_load(),
# qui relit les VRAIS fichiers sur disque. C'est le chemin de lecture réel
# qui est testé ; seule l'étape "table rase avant reload" est simulée.
#
# Ces tests écrivent de vrais fichiers user://. Pour ne jamais toucher aux
# vraies données de sauvegarde d'un développeur qui aurait joué sur cette
# machine, ils DOIVENT être lancés avec XDG_DATA_HOME pointé vers un
# répertoire temporaire (voir tests/README.md / commande dans TEST_PLAN.md).

const NODE_WITH_END_STAT = 128           # stats: {'end': 1}, pas d'item
const NODE_WITH_END_HAB_AND_ITEM = 112   # stats: {'end':1,'hab':1}, aquire un objet


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()


func before_each():
	Player.launch_new_billy()
	AppParameters.set_billy_type('pegu')
	Player._recompute_stats()


func _reset_player_memory_to_pristine_state():
	# Simule ce qu'un processus Godot neuf aurait en mémoire, SANS toucher
	# aux fichiers sur disque (contrairement à launch_new_billy()).
	Player.current_node_id = 1
	Player.session_visited_nodes = []
	Player.visited_nodes_all_times = []
	Player.possessed_items = []
	Player.need_force_display_options = false
	Player._fully_reset_our_stats()


func test_full_cycle_visit_acquire_save_reload_gives_identical_state():
	# Un vrai joueur démarre TOUJOURS au chapitre 1 (jamais atteint via un
	# go_to_node() explicite en jeu réel -- c'est le point d'entrée de
	# main.tscn). player.gd::load_all_times_already_visited() le sait et
	# force donc 1 dans visited_nodes_all_times à CHAQUE chargement, même
	# si la session en cours ne l'a jamais visité explicitement (cf le
	# commentaire "Seems that the chapter 1 is not stack at the beging of
	# the play"). Sauter cette étape ici casserait artificiellement la
	# comparaison avant/après reload sur visited_nodes_all_times.
	Player.go_to_node(1)
	Player.go_to_node(NODE_WITH_END_STAT)
	Player.go_to_node(NODE_WITH_END_HAB_AND_ITEM)
	Player.add_item_from_options('EPEE')

	var expected_current_node_id = Player.current_node_id
	var expected_session_visited_nodes = Player.session_visited_nodes.duplicate()
	var expected_visited_nodes_all_times = Player.visited_nodes_all_times.duplicate()
	var expected_possessed_items = Player.possessed_items.duplicate()
	var expected_end = Player.get_end()
	var expected_hab = Player.get_hab()
	var expected_end_chapters = Player.end_chapters
	var expected_hab_chapters = Player.hab_chapters

	_reset_player_memory_to_pristine_state()
	# Sanity: on est bien reparti de zéro avant le reload
	assert_eq(Player.current_node_id, 1)
	assert_eq(Player.possessed_items, [])

	Player.do_load()

	assert_eq(Player.current_node_id, expected_current_node_id)
	assert_eq(Player.session_visited_nodes, expected_session_visited_nodes)
	assert_eq(Player.visited_nodes_all_times, expected_visited_nodes_all_times)
	assert_eq(Player.possessed_items, expected_possessed_items)
	assert_eq(Player.end_chapters, expected_end_chapters)
	assert_eq(Player.hab_chapters, expected_hab_chapters)
	assert_eq(Player.get_end(), expected_end)
	assert_eq(Player.get_hab(), expected_hab)


func test_reload_is_idempotent_when_called_twice_from_a_pristine_state():
	# do_load() lui-meme ne doit pas dupliquer les stats de chapitre s'il
	# est appele plusieurs fois consecutives a partir du meme etat "table
	# rase + fichiers sur disque inchanges" (ce qui n'arrive normalement
	# qu'une fois par vrai demarrage, mais doit rester sans effet de bord
	# s'il etait appele deux fois par erreur juste apres un redemarrage).
	Player.go_to_node(NODE_WITH_END_STAT)
	var expected_end_chapters = Player.end_chapters

	_reset_player_memory_to_pristine_state()
	Player.do_load()
	assert_eq(Player.end_chapters, expected_end_chapters)

	_reset_player_memory_to_pristine_state()
	Player.do_load()
	assert_eq(Player.end_chapters, expected_end_chapters,
		"un second reload depuis une table rase doit redonner exactement le meme total, pas le doubler")


func _read_json_mirror(save_path):
	var json_path = save_path.replace(".save", ".json")
	var f = FileAccess.open(json_path, FileAccess.READ)
	var text = f.get_as_text()
	f.close()
	return Utils.ints_from_json(JSON.parse_string(text))


func test_json_mirror_files_match_the_real_save_content():
	# player.gd::_save_var() ecrit desormais le JSON en PRIMAIRE (depuis le
	# 2026-07-09, voir player.gd::_load_var) -- ce n'est plus un simple
	# miroir de confort jamais relu, c'est la vraie source de verite au
	# rechargement. Verrouille que son contenu reste synchronise avec
	# l'etat live, pas juste "le fichier existe".
	Player.go_to_node(NODE_WITH_END_HAB_AND_ITEM)  # aquire un objet au passage
	Player.add_item_from_options('EPEE')

	assert_eq(_read_json_mirror(Player._get_current_node_id_file()), Player.current_node_id)
	assert_eq(_read_json_mirror(Player._get_session_visited_nodes_file()), Player.session_visited_nodes)
	assert_eq(_read_json_mirror(Player._get_all_times_already_visited_file()), Player.visited_nodes_all_times)
	assert_eq(_read_json_mirror(Player._get_possessed_items_file()), Player.possessed_items)


func test_new_billy_then_reload_does_not_resurrect_previous_billy_chapter_stats():
	# Combine le fix de cette session (end_chapters resete par
	# launch_new_billy) avec le cycle de sauvegarde complet: apres une
	# "Nouvelle partie", meme en repassant par un reload depuis disque, on
	# ne doit JAMAIS revoir les stats de chapitre de l'ancien Billy.
	Player.go_to_node(NODE_WITH_END_STAT)
	Player.go_to_node(NODE_WITH_END_HAB_AND_ITEM)
	assert_eq(Player.end_chapters, 2)

	Player.launch_new_billy()
	assert_eq(Player.end_chapters, 0)

	_reset_player_memory_to_pristine_state()
	Player.do_load()
	assert_eq(Player.end_chapters, 0,
		"apres une nouvelle partie sauvegardee puis un reload, les stats de l'ancien Billy ne doivent pas revenir")
	assert_eq(Player.possessed_items, [])
	assert_eq(Player.session_visited_nodes, [])
