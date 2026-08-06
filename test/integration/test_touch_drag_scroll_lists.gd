extends "res://addons/gut/test.gd"

# Meme bug que la fiche de personnage (cf test_options_tabs.gd ::
# test_touch_drag_scrolls_the_stats_screen_not_just_the_scrollbar) : un
# ScrollContainer Godot 4 ne defile PAS au glisse-doigt/souris tout seul
# (seuls la scrollbar et la molette marchent nativement). Verifie ici que
# le fix (Utils.enable_drag_scroll + Utils.make_non_interactive_passthrough,
# cf main.gd::_ready()/insert_all_*/display_all_objects()) marche aussi sur
# les 4 autres listes de l'appli, via de VRAIS InputEventMouseButton/
# MouseMotion (convertis en tactile par le projet, pointing/
# emulate_touch_from_mouse=true) -- pas un appel direct a scroll_vertical.

var _main = null


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()
	Player.need_force_display_options = false

	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)
	for i in range(5):
		await get_tree().process_frame

	# Le panneau de rapport de GUT (GutRunner/GutLayer, CanvasLayer 128 --
	# rendu au-dessus de tout, y compris _main) capte et avale tout clic/
	# touche avant qu'il n'atteigne _main -- meme piege deja documente dans
	# test_real_swipe_navigation.gd et test_options_tabs.gd.
	var gut_layer = get_tree().root.get_node_or_null("GutRunner/GutLayer")
	if gut_layer:
		gut_layer.visible = false


func after_all():
	_main.free()


func _wait_camera_settled():
	await get_tree().process_frame
	var cam = _main.camera
	for i in range(300):
		var center = cam.get_screen_center_position()
		if abs(center.x - cam.position.x) < 0.5 and abs(center.y - cam.position.y) < 0.5:
			return
		await get_tree().process_frame


# Chapitres/Succes/Lore sont des "pages" swipees en espace MONDE (le
# Node2D main deplace sa Camera2D pour les centrer, cf swipe.gd) --
# Control.get_global_rect() renvoie donc des coordonnees MONDE (ex: x=999
# alors que le vrai ecran ne fait que 558px de large), pas des coordonnees
# ecran/viewport valides pour Input.parse_input_event(). canvas_transform
# est exactement la conversion monde -> ecran utilisee par la camera 2D
# active, quelle que soit sa position/son zoom.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().canvas_transform * world_pos


func _drag_scroll(scroll: ScrollContainer, start_pos: Vector2, dy: float):
	scroll.scroll_vertical = 0
	await get_tree().process_frame

	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_pos
	press.global_position = start_pos
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame

	var steps = 15
	for i in range(steps):
		var motion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = start_pos + Vector2(0, -dy / steps * (i + 1))
		motion.global_position = motion.position
		motion.relative = Vector2(0, -dy / steps)
		Input.parse_input_event(motion)
		await get_tree().process_frame

	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start_pos + Vector2(0, -dy)
	release.global_position = release.position
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame


func test_touch_drag_scrolls_the_chapitres_list():
	Swiper.focus_to_chapitres()
	await _wait_camera_settled()
	var scroll = _main.get_node("Chapitres/AllChapters/VScrollBar")
	var first_row = _main.get_node("Chapitres/AllChapters/VScrollBar/Choices").get_child(0)
	var start_pos = first_row.get_node("NBChapitre").get_global_rect().get_center()
	start_pos = _world_to_screen(start_pos)

	await _drag_scroll(scroll, start_pos, 350)

	assert_gt(scroll.scroll_vertical, 0, "un glisse-doigt doit faire defiler la liste des chapitres")


func test_touch_drag_scrolls_the_succes_list():
	Swiper.focus_to_success()
	await _wait_camera_settled()
	var scroll = _main.get_node("Succes/Success/VScrollBar")
	var first_row = _main.get_node("Succes/Success/VScrollBar/Success").get_child(0)
	var start_pos = first_row.get_node("NBChapitre").get_global_rect().get_center()
	start_pos = _world_to_screen(start_pos)

	await _drag_scroll(scroll, start_pos, 350)

	assert_gt(scroll.scroll_vertical, 0, "un glisse-doigt doit faire defiler la liste des succes")


func test_touch_drag_scrolls_the_lore_list():
	Swiper.focus_to_lore()
	await _wait_camera_settled()
	var scroll = _main.get_node("Lore/Lore/VScrollBar")
	var first_row = _main.get_node("Lore/Lore/VScrollBar/persos").get_child(0)
	var start_pos = first_row.get_node("Label").get_global_rect().get_center()
	start_pos = _world_to_screen(start_pos)

	await _drag_scroll(scroll, start_pos, 350)

	assert_gt(scroll.scroll_vertical, 0, "un glisse-doigt doit faire defiler la liste du lore")


func test_touch_drag_scrolls_the_equipement_list():
	Swiper.focus_to_main()
	await _wait_camera_settled()
	_main.show_options()
	_main._options_show_equipement()
	var scroll = _main.get_node("Options/Equipement/ItemsCont")
	var first_row = _main.get_node("Options/Equipement/ItemsCont/Items").get_child(0)
	var start_pos = first_row.get_node("Nom").get_global_rect().get_center()
	start_pos = _world_to_screen(start_pos)

	await _drag_scroll(scroll, start_pos, 350)

	assert_gt(scroll.scroll_vertical, 0, "un glisse-doigt doit faire defiler la liste des objets")
