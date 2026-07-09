extends "res://addons/gut/test.gd"

var FakeMain = preload('res://test/unit/fakes/fake_main_ui.gd')
var fake_main


func before_each():
	fake_main = FakeMain.new()
	Swiper.register_main(fake_main)
	Swiper.current_page = 'main'


func after_each():
	fake_main.free()


func _last_call():
	return Swiper.main.calls[-1]


func test_go_to_page_back_delegates_to_jump_to_previous_chapter():
	Swiper.go_to_page('BACK')
	assert_eq(_last_call(), ['jump_to_previous_chapter', null])


func test_go_to_page_main_sets_camera_and_current_page():
	Swiper.go_to_page('main')
	assert_eq(Swiper.get_current_page(), 'main')
	assert_has(fake_main.calls, ['set_camera_to_pos', 278])


func test_go_to_page_chapitres_sets_expected_camera_pos():
	Swiper.go_to_page('chapitres')
	assert_eq(Swiper.get_current_page(), 'chapitres')
	assert_has(fake_main.calls, ['set_camera_to_pos', 876])


func test_go_to_page_unknown_destination_does_not_change_page():
	Swiper.go_to_page('nowhere')
	assert_eq(Swiper.get_current_page(), 'main')


func test_swipe_to_left_from_main_jumps_to_previous_chapter():
	Swiper.current_page = 'main'
	Swiper.swipe_to_left()
	assert_has(fake_main.calls, ['jump_to_previous_chapter', null])


func test_swipe_to_left_from_chapitres_focuses_main():
	Swiper.current_page = 'chapitres'
	Swiper.swipe_to_left()
	assert_eq(Swiper.get_current_page(), 'main')


func test_swipe_to_right_from_main_focuses_chapitres():
	Swiper.current_page = 'main'
	Swiper.swipe_to_right()
	assert_eq(Swiper.get_current_page(), 'chapitres')


func test_swipe_to_right_from_about_does_not_change_page():
	Swiper.current_page = 'about'
	Swiper.swipe_to_right()
	assert_eq(Swiper.get_current_page(), 'about')


func test_compute_event_drag_beyond_threshold_triggers_swipe():
	Swiper.current_page = 'main'
	var start_event = InputEventScreenTouch.new()
	start_event.position = Vector2(0, 0)
	start_event.button_pressed = true
	Swiper.compute_event(start_event)

	var end_event = InputEventScreenTouch.new()
	end_event.position = Vector2(500, 0)
	end_event.button_pressed = false
	Swiper.compute_event(end_event)

	# swipe.x = 500 - 0 = 500 (>0) => branche "swipe_to_left()" (le code
	# source associe deplacement du doigt vers la droite a swipe_to_left,
	# cf commentaires inverses dans swipe.gd::_calculate_swipe) =>
	# depuis 'main', swipe_to_left() appelle jump_to_previous_chapter()
	assert_has(fake_main.calls, ['jump_to_previous_chapter', null])


func test_compute_event_drag_below_threshold_does_nothing():
	Swiper.current_page = 'main'
	var start_event = InputEventScreenTouch.new()
	start_event.position = Vector2(10, 0)
	start_event.button_pressed = true
	Swiper.compute_event(start_event)

	var end_event = InputEventScreenTouch.new()
	end_event.position = Vector2(0, 0)
	end_event.button_pressed = false
	Swiper.compute_event(end_event)

	assert_eq(fake_main.calls, [])
