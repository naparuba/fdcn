extends "res://addons/gut/test.gd"

# Chapitres reels du livre 1, sans items ni stats particuliers, utilises
# uniquement pour construire une session de navigation deterministe.
const NODE_A = 128
const NODE_B = 112

func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()


func before_each():
	Player.launch_new_billy()
	AppParameters.set_billy_type('pegu')


func test_jump_to_previous_chapter_returns_minus_one_with_a_single_node():
	Player.go_to_node(1)
	assert_eq(len(Player.session_visited_nodes), 1)
	assert_eq(Player.jump_to_previous_chapter(), -1)


func test_jump_to_previous_chapter_returns_second_to_last():
	Player.go_to_node(1)
	Player.go_to_node(NODE_A)
	assert_eq(Player.jump_to_previous_chapter(), 1)


func test_jump_back_with_a_single_node_returns_false():
	Player.go_to_node(1)
	assert_false(Player.jump_back(1))


func test_jump_back_pops_the_stack_down_to_and_including_the_target():
	Player.go_to_node(1)
	Player.go_to_node(NODE_A)
	Player.go_to_node(NODE_B)
	assert_eq(Player.session_visited_nodes, [1, NODE_A, NODE_B])

	var found = Player.jump_back(NODE_A)

	assert_true(found)
	assert_eq(Player.session_visited_nodes, [1],
		"jump_back retire aussi le noeud cible lui-meme (pop_back inclus); "
		+ "c'est main.gd::jump_back qui le re-ajoute ensuite via go_to_node")


func test_jump_back_returns_false_when_target_was_never_visited():
	Player.go_to_node(1)
	Player.go_to_node(NODE_A)
	Player.go_to_node(NODE_B)

	var found = Player.jump_back(999999)

	assert_false(found)
	assert_eq(Player.session_visited_nodes, [],
		"la pile est entierement videe en cherchant en vain la cible")


func test_guess_after_migration_sets_force_display_options():
	Player.go_to_node(1)
	Player.need_force_display_options = false
	Player.guess_after_migration()
	assert_true(Player.need_force_display_options)


func test_guess_after_migration_replays_items_from_session_chapters():
	Player.go_to_node(1)
	Player.go_to_node(112)  # aquire "PALAIS DES PLAISIRS D'YTIA"
	Player.possessed_items = []  # simule l'absence de fichier possessed_items

	Player.guess_after_migration()

	assert_true(Player.have_item("PALAIS DES PLAISIRS D'YTIA"),
		"les items acquis par les chapitres deja visites doivent etre rejoues")


func test_guess_after_migration_guesses_a_starting_kit_for_guerrier():
	AppParameters.set_billy_type('guerrier')
	Player.possessed_items = []
	Player.session_visited_nodes = []

	Player.guess_after_migration()

	# cf player.gd::guess_after_migration, livre 1, guerrier
	assert_true(Player.have_item('EPEE'))
	assert_true(Player.have_item('LANCE'))
	assert_true(Player.have_item('MARMITE'))


func test_guess_after_migration_guesses_nothing_for_pegu():
	AppParameters.set_billy_type('pegu')
	Player.possessed_items = []
	Player.session_visited_nodes = []

	Player.guess_after_migration()

	assert_eq(Player.possessed_items, [])
