extends "res://addons/gut/test.gd"

func before_each():
	AppParameters.set_book_number(1)
	AppParameters.set_billy_type('pegu')
	AppParameters.set_spoils(true)
	AppParameters.set_sound(true)


func after_each():
	# Ces reglages sont des singletons partages entre TOUS les fichiers de
	# test: on les remet dans un etat neutre pour ne pas polluer la suite.
	AppParameters.set_book_number(1)
	AppParameters.set_spoils(true)
	AppParameters.set_sound(true)


func test_spoils_default_and_toggle():
	assert_true(AppParameters.are_spoils_ok())
	AppParameters.set_spoils(false)
	assert_false(AppParameters.are_spoils_ok())
	AppParameters.set_spoils(true)
	assert_true(AppParameters.are_spoils_ok())


func test_setting_spoils_to_same_value_is_a_noop():
	AppParameters.set_spoils(true)
	assert_true(AppParameters.are_spoils_ok())  # ne doit pas planter / changer d'etat


func test_sound_default_and_toggle():
	assert_true(AppParameters.is_sound_ok())
	AppParameters.set_sound(false)
	assert_false(AppParameters.is_sound_ok())
	assert_false(Sounder.is_enabled(),
		"set_sound doit repercuter l'etat sur Sounder via _apply_parameters")
	AppParameters.set_sound(true)
	assert_true(Sounder.is_enabled())


func test_billy_type_roundtrip():
	AppParameters.set_billy_type('guerrier')
	assert_eq(AppParameters.get_billy_type(), 'guerrier')
	AppParameters.set_billy_type('paysan')
	assert_eq(AppParameters.get_billy_type(), 'paysan')


func test_setting_billy_type_to_same_value_is_a_noop():
	AppParameters.set_billy_type('guerrier')
	AppParameters.set_billy_type('guerrier')
	assert_eq(AppParameters.get_billy_type(), 'guerrier')


func test_book_number_roundtrip_and_reloads_bookdata():
	AppParameters.set_book_number(2)
	assert_eq(AppParameters.get_book_number(), 2)
	# BookData doit avoir bascule sur les vraies donnees du livre 2
	assert_eq(BookData.get_chapter_data(1).get_id(), 1)
	AppParameters.set_book_number(1)
	assert_eq(AppParameters.get_book_number(), 1)


func test_set_book_number_returns_true_when_changed_false_when_not():
	AppParameters.set_book_number(1)  # etat de depart connu
	assert_false(AppParameters.set_book_number(1), "pas de changement => false")
	assert_true(AppParameters.set_book_number(2), "changement reel => true")
	AppParameters.set_book_number(1)  # restore


func test_parameters_are_persisted_to_disk():
	AppParameters.set_billy_type('paysan')
	var f = File.new()
	assert_true(f.file_exists(AppParameters.parameters_file))
	f.open(AppParameters.parameters_file, File.READ)
	var saved = f.get_var()
	f.close()
	assert_eq(saved['billy'], 'paysan')
	AppParameters.set_billy_type('pegu')
