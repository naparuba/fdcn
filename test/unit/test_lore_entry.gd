extends "res://addons/gut/test.gd"

var LoreEntryScene = preload('res://LoreEntry.tscn')


func _make_entry(type_entry, entry_name, titre, book_number=1):
	var entry = LoreEntryScene.instantiate()
	entry.type_entry = type_entry
	entry.entry_name = entry_name
	entry.titre = titre
	entry.book_number = book_number
	add_child_autofree(entry)  # necessaire: _ready() (qui charge le sprite) n'est appele qu'a l'entree dans l'arbre
	return entry


func test_ready_sets_the_title_label():
	var entry = _make_entry('billys', 'guerrier', 'Le Guerrier')
	assert_eq(entry.get_node('Label').text, 'Le Guerrier')


func test_ready_loads_a_real_billy_image():
	var entry = _make_entry('billys', 'guerrier', 'Le Guerrier')
	assert_not_null(entry.get_node('Sprite2D').texture)


func test_ready_loads_a_real_dieu_image_with_book_number_subdir():
	var entry = _make_entry('dieux', 'atella', 'Atella', 1)
	assert_not_null(entry.get_node('Sprite2D').texture)


func test_play_pressed_toggles_playing_state_when_sound_enabled():
	Sounder.set_enabled(true)
	var entry = _make_entry('billys', 'guerrier', 'Le Guerrier')
	assert_false(entry.is_playing)
	entry._on_play_pressed()
	assert_true(entry.is_playing)
	entry._on_play_pressed()  # stop
	assert_false(entry.is_playing)


func test_play_pressed_does_nothing_when_sound_disabled():
	Sounder.set_enabled(false)
	var entry = _make_entry('billys', 'guerrier', 'Le Guerrier')
	entry._on_play_pressed()
	assert_false(entry.is_playing, "sans son actif, l'etat ne doit pas basculer")
	Sounder.set_enabled(true)
