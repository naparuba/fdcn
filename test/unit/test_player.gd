extends "res://addons/gut/test.gd"
func before_each():
	gut.p("ran setup", 2)
	Player.insert_all_objects()
	Player.launch_new_billy()
	AppParameters.set_billy_type('pegu')
	Player._recompute_stats()
	

func after_each():
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)


func _assert_billy(type):
	self.assert_eq(type, AppParameters.get_billy_type(), 'we want a %s' % type)


func test_player_init():
	assert_eq(Player.hab, 2, "Basic hab should be 2")


# Guerrier: on ne devient guerrier que quand on a 2 armes, et 3 trucs au total
func test_player_go_guerrier():
	Player.add_item_from_options('EPEE')
	self._assert_billy('pegu')
	Player.add_item_from_options('MORGENSTERN')
	self._assert_billy('pegu')
	Player.add_item_from_options("KIT DE SOIN")
	self._assert_billy('guerrier')
	
	
	


#func test_assert_true_with_true():
#	assert_true(true, "Should pass, true is true")


