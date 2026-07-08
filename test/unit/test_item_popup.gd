extends "res://addons/gut/test.gd"

var ItemPopupScene = preload('res://ItemPopup.tscn')


func test_load_item_data_sets_the_name():
	var popup = ItemPopupScene.instance()
	popup.load_item_data('EPEE', BookData.get_item_data('EPEE'))
	assert_eq(popup.get_node('Nom').text, 'EPEE')
	popup.free()


func test_set_is_new_true_shows_the_new_color():
	var popup = ItemPopupScene.instance()
	popup.load_item_data('EPEE', BookData.get_item_data('EPEE'))
	popup.set_is_new(true)
	assert_true(popup.is_new)
	popup.free()


func test_set_is_new_false_shows_the_removed_color():
	var popup = ItemPopupScene.instance()
	popup.load_item_data('EPEE', BookData.get_item_data('EPEE'))
	popup.set_is_new(false)
	assert_false(popup.is_new)
	popup.free()
