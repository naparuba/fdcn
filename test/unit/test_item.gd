extends "res://addons/gut/test.gd"

var ItemScene = preload('res://Item.tscn')

# "PALAIS DES PLAISIRS D'YTIA": categorie EVENEMENT, visible aux chapitres
# 26/112/289 -- utilise pour verifier la regle des spoils par chapitre vu.
const EVENT_ITEM = "PALAIS DES PLAISIRS D'YTIA"

func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()


func before_each():
	Player.launch_new_billy()
	Player.visited_nodes_all_times = []  # launch_new_billy() ne le remet pas a zero
	AppParameters.set_billy_type('pegu')
	AppParameters.set_spoils(true)


func after_each():
	AppParameters.set_spoils(true)


func _make_item(item_name):
	var item = ItemScene.instance()
	item.load_item_data(item_name, BookData.get_item_data(item_name))
	return item


func test_is_ok_to_be_shown_false_for_billy_category():
	var item = _make_item('GUERRIER')  # categorie BILLY (pseudo-item de type)
	assert_eq(item.get_category(), 'BILLY')
	assert_false(item.is_ok_to_be_shown())
	item.free()


func test_is_ok_to_be_shown_true_for_a_normal_item():
	var item = _make_item('EPEE')
	assert_false(item.get_category() == 'BILLY')
	assert_true(item.is_ok_to_be_shown())
	item.free()


func test_refresh_shows_item_when_possessed():
	var item = _make_item('EPEE')
	Player.add_item_from_options('EPEE')
	item.refresh()
	assert_true(item.is_enabled())
	item.free()


func test_refresh_hides_item_when_not_possessed_and_spoils_off_and_never_seen():
	AppParameters.set_spoils(false)
	var item = _make_item(EVENT_ITEM)
	item.refresh()
	assert_false(item.is_enabled())
	item.free()


func test_item_can_be_shown_with_spoils_on_even_if_never_seen():
	AppParameters.set_spoils(true)
	var item = _make_item(EVENT_ITEM)
	item.refresh()
	# _can_item_be_shown() n'est pas expose publiquement, mais son effet est
	# visible via le texte du nom affiche (vide si cache, rempli si visible)
	assert_eq(item.get_node('Nom').text, EVENT_ITEM)
	item.free()


func test_item_can_be_shown_without_spoils_once_its_chapter_was_seen():
	AppParameters.set_spoils(false)
	Player.visited_nodes_all_times.append(112)  # un des in_chapters de l'item
	var item = _make_item(EVENT_ITEM)
	item.refresh()
	assert_eq(item.get_node('Nom').text, EVENT_ITEM)
	item.free()


func test_item_hidden_without_spoils_and_chapter_never_seen():
	AppParameters.set_spoils(false)
	var item = _make_item(EVENT_ITEM)
	item.refresh()
	assert_eq(item.get_node('Nom').text, '')
	item.free()
