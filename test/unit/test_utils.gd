extends "res://addons/gut/test.gd"


func test_is_file_exists_true_for_real_file():
	assert_true(Utils.is_file_exists('res://fdcn-1.json'))


func test_is_file_exists_false_for_missing_file():
	assert_false(Utils.is_file_exists('res://ceci_nexiste_pas.json'))


func test_load_external_texture_returns_a_texture_for_a_real_image():
	var tex = Utils.load_external_texture('res://images/success/POLIR-LANCE.png', null)
	assert_not_null(tex)


func test_load_external_texture_returns_null_for_a_missing_image():
	var tex = Utils.load_external_texture('res://images/success/CECI_NEXISTE_PAS.png', null)
	assert_null(tex)
	# GUT 9.x fait echouer un test qui produit une erreur moteur non
	# reconnue -- ici l'erreur "cannot load image" est le comportement
	# attendu (chemin d'erreur volontairement teste), pas une regression.
	assert_engine_error_count(1)


func test_load_json_file_parses_a_real_file():
	var data = Utils.load_json_file('res://fdcn-1-compilated-success-chapters.json')
	assert_true(data is Dictionary)
	assert_true(data.has('26'))


func test_roll_a_dice_stays_within_bounds():
	for i in range(50):
		var roll = Utils.roll_a_dice(1, 6)
		assert_true(roll >= 1 and roll <= 6, "roll=%s hors bornes" % roll)


func test_delete_children_removes_all_children():
	var parent = Node.new()
	parent.add_child(Node.new())
	parent.add_child(Node.new())
	assert_eq(parent.get_child_count(), 2)
	Utils.delete_children(parent)
	assert_eq(parent.get_child_count(), 0)
	parent.free()
