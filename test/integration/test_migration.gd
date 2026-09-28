extends "res://addons/gut/test.gd"

# Test d'intégration P0 (cf TEST_PLAN.md §4.2): migration des anciens
# fichiers de sauvegarde (avant la gestion multi-livres) vers le nouveau
# format par livre. Écrit de vrais fichiers user:// : lancer uniquement
# avec XDG_DATA_HOME pointé vers un répertoire temporaire.

var Godot3VariantDecoder = preload('res://godot3_variant_decoder.gd')


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()


func before_each():
	Player.launch_new_billy()


func _delete_if_exists(pth):
	if FileAccess.file_exists(pth):
		DirAccess.remove_absolute(pth)
	# _load_var() lit le miroir .json en priorite (format primaire depuis
	# le 2026-07-09) : un miroir perime laisse en place ferait ignorer la
	# migration qu'on vient de tester, meme si le binaire .save fraichement
	# migre est correct -- toujours nettoyer les deux.
	var json_pth = pth.replace(".save", ".json")
	if json_pth != pth and FileAccess.file_exists(json_pth):
		DirAccess.remove_absolute(json_pth)


func _save_old_format_binary(pth, data):
	# Simule un VRAI vieux fichier de sauvegarde pre-multi-livres, au VRAI
	# format binaire Godot 3.6.2 (Godot3VariantDecoder.encode -- PAS
	# FileAccess.store_var() de Godot 4, qui numerote les types Variant
	# differemment et ne produirait donc PAS un fichier representatif d'un
	# vrai vieux fichier joueur, cf godot3_variant_decoder.gd et
	# test/fixtures/save_formats_godot3/README.md pour le detail du bug que
	# cette distinction a revele). Player._save_var() ecrit desormais en
	# JSON primaire (voir player.gd::_load_var, 2026-07-09) : l'utiliser ici
	# simulerait un fichier qui n'a jamais existe pour de vrai, et
	# _assert_migrate_file() ne trouverait jamais l'ancien fichier a migrer.
	var f = FileAccess.open(pth, FileAccess.WRITE)
	f.store_buffer(Godot3VariantDecoder.encode(data))
	f.close()


func _delete_book2_cleanup_fixtures():
	_delete_if_exists(Player.TO_CLEAN_ONE_TIME_BOOK_2_FLAG)
	_delete_if_exists(Player.TO_CLEAN_ONE_TIME_BOOK_2_FLAG.replace(".save", ".json"))
	for pth in Player.TO_CLEAN_ONE_TIME_BOOK_2:
		_delete_if_exists(pth)


func test_migrate_current_node_id_from_old_single_book_format():
	_delete_if_exists(Player.OLD_CURRENT_NODE_ID_FILE)
	_delete_if_exists(Player._get_current_node_id_file())

	_save_old_format_binary(Player.OLD_CURRENT_NODE_ID_FILE, 77)

	Player.load_current_node_id()

	assert_eq(Player.current_node_id, 77, "la valeur de l'ancien fichier doit être reprise")
	assert_false(FileAccess.file_exists(Player.OLD_CURRENT_NODE_ID_FILE), "l'ancien fichier doit être supprimé après migration")
	assert_true(FileAccess.file_exists(Player._get_current_node_id_file()), "le nouveau fichier (par livre) doit exister")


func test_migration_is_a_noop_when_no_old_file_exists():
	_delete_if_exists(Player.OLD_CURRENT_NODE_ID_FILE)
	Player.current_node_id = 5  # valeur arbitraire, Player etant un singleton partage entre tests
	Player.save_current_node_id()  # cree le nouveau fichier normalement

	Player.load_current_node_id()  # ne doit pas planter en l'absence d'ancien fichier

	assert_eq(Player.current_node_id, 5)


func test_full_do_load_migrates_all_four_old_files_at_once():
	# Scenario réel : un joueur qui avait l'app AVANT la gestion
	# multi-livres relance l'app après une mise à jour.
	_delete_if_exists(Player.OLD_ALL_TIMES_ALREADY_VISITED_FILE)
	_delete_if_exists(Player.OLD_CURRENT_NODE_ID_FILE)
	_delete_if_exists(Player.OLD_SESSION_VISITED_NODES_FILE)
	_delete_if_exists(Player.OLD_POSSESSED_ITEM_FILE)
	_delete_if_exists(Player._get_all_times_already_visited_file())
	_delete_if_exists(Player._get_current_node_id_file())
	_delete_if_exists(Player._get_session_visited_nodes_file())
	_delete_if_exists(Player._get_possessed_items_file())

	_save_old_format_binary(Player.OLD_ALL_TIMES_ALREADY_VISITED_FILE, [1, 2, 3, 42])
	_save_old_format_binary(Player.OLD_CURRENT_NODE_ID_FILE, 42)
	_save_old_format_binary(Player.OLD_SESSION_VISITED_NODES_FILE, [1, 42])
	_save_old_format_binary(Player.OLD_POSSESSED_ITEM_FILE, ['EPEE'])

	Player.do_load()

	assert_eq(Player.current_node_id, 42)
	assert_eq(Player.session_visited_nodes, [1, 42])
	assert_true(42 in Player.visited_nodes_all_times)
	assert_eq(Player.possessed_items, ['EPEE'])

	for old_pth in [Player.OLD_ALL_TIMES_ALREADY_VISITED_FILE, Player.OLD_CURRENT_NODE_ID_FILE,
			Player.OLD_SESSION_VISITED_NODES_FILE, Player.OLD_POSSESSED_ITEM_FILE]:
		assert_false(FileAccess.file_exists(old_pth), "ancien fichier encore présent: %s" % old_pth)


func test_full_do_load_combines_migration_and_guess_after_migration():
	# Scenario reel encore plus ancien que le precedent : un joueur qui
	# avait l'app AVANT MEME le suivi des objets (aucun fichier
	# possessed_item, ni ancien ni nouveau format). do_load() doit a la
	# fois migrer les 3 autres fichiers ET declencher
	# guess_after_migration() pour reconstituer un inventaire plausible --
	# les deux mecanismes s'enchainent dans le MEME appel public.
	_delete_if_exists(Player.OLD_ALL_TIMES_ALREADY_VISITED_FILE)
	_delete_if_exists(Player.OLD_CURRENT_NODE_ID_FILE)
	_delete_if_exists(Player.OLD_SESSION_VISITED_NODES_FILE)
	_delete_if_exists(Player.OLD_POSSESSED_ITEM_FILE)
	_delete_if_exists(Player._get_all_times_already_visited_file())
	_delete_if_exists(Player._get_current_node_id_file())
	_delete_if_exists(Player._get_session_visited_nodes_file())
	_delete_if_exists(Player._get_possessed_items_file())

	# noeud 112 du livre 1 : aquire "PALAIS DES PLAISIRS D'YTIA" (cf autres tests)
	_save_old_format_binary(Player.OLD_ALL_TIMES_ALREADY_VISITED_FILE, [1, 112])
	_save_old_format_binary(Player.OLD_CURRENT_NODE_ID_FILE, 112)
	_save_old_format_binary(Player.OLD_SESSION_VISITED_NODES_FILE, [1, 112])
	# PAS de OLD_POSSESSED_ITEM_FILE : c'est le coeur du scenario

	AppParameters.set_billy_type('guerrier')
	Player.need_force_display_options = false  # etat propre avant le test

	Player.do_load()

	# Migration des 3 fichiers qui existaient
	assert_eq(Player.current_node_id, 112)
	assert_eq(Player.session_visited_nodes, [1, 112])
	assert_true(112 in Player.visited_nodes_all_times)

	# guess_after_migration() : rejoue l'aquire du noeud 112 ET devine le
	# kit de depart du guerrier (livre 1)
	assert_true(Player.have_item("PALAIS DES PLAISIRS D'YTIA"),
		"l'objet acquis par le chapitre 112 doit etre rejoue")
	assert_true(Player.have_item('EPEE'))
	assert_true(Player.have_item('LANCE'))
	assert_true(Player.have_item('MARMITE'))
	assert_true(Player.need_force_display_options,
		"le joueur doit etre invite a valider l'inventaire devine")

	assert_true(FileAccess.file_exists(Player._get_possessed_items_file().replace(".save", ".json")),
		"le nouveau fichier possessed_item doit avoir ete cree par cette premiere sauvegarde")


func test_migration_twice_in_a_row_is_idempotent():
	_delete_if_exists(Player.OLD_CURRENT_NODE_ID_FILE)
	_delete_if_exists(Player._get_current_node_id_file())
	_save_old_format_binary(Player.OLD_CURRENT_NODE_ID_FILE, 99)

	Player.load_current_node_id()
	assert_eq(Player.current_node_id, 99)

	Player.load_current_node_id()  # deuxieme appel: l'ancien fichier n'existe plus
	assert_eq(Player.current_node_id, 99, "un second chargement ne doit rien changer")


func test_book2_one_time_cleanup_removes_orphan_files_and_sets_flag():
	_delete_book2_cleanup_fixtures()
	for pth in Player.TO_CLEAN_ONE_TIME_BOOK_2:
		_save_old_format_binary(pth, true)

	Player._assert_bug_book_2_preload_is_fixed()

	assert_true(FileAccess.file_exists(Player.TO_CLEAN_ONE_TIME_BOOK_2_FLAG.replace(".save", ".json")), "le flag doit être posé après le nettoyage")
	for pth in Player.TO_CLEAN_ONE_TIME_BOOK_2:
		assert_false(FileAccess.file_exists(pth), "fichier orphelin encore présent: %s" % pth)


func test_book2_one_time_cleanup_is_a_noop_on_second_call():
	_delete_book2_cleanup_fixtures()
	Player._assert_bug_book_2_preload_is_fixed()  # premier appel: pose le flag
	assert_true(FileAccess.file_exists(Player.TO_CLEAN_ONE_TIME_BOOK_2_FLAG.replace(".save", ".json")))

	# deuxieme appel: le flag existe déjà, ne doit pas planter meme si les
	# fichiers a nettoyer n'existent plus
	Player._assert_bug_book_2_preload_is_fixed()
	assert_true(FileAccess.file_exists(Player.TO_CLEAN_ONE_TIME_BOOK_2_FLAG.replace(".save", ".json")))
