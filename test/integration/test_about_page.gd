extends "res://addons/gut/test.gd"

# Page "A propos" du VRAI main.tscn : le Phumtar anime (AnimatedSprite2D, deux images
# anim-phumtar-1/2) doit tourner. Regression reelle : la migration Godot 3 -> 4 avait laisse
# "frames"/"playing = true" dans le .tscn ; "playing" n'existe plus en Godot 4 (il faut
# autoplay ou play()), donc l'animation restait figee sur sa premiere image.

var _main = null


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()
	_main = load("res://main.tscn").instantiate()
	add_child(_main)


func after_all():
	_main.free()


func test_phumtar_has_its_two_frames():
	var phumtar = _main.get_node("About/About/phumtar")
	assert_not_null(phumtar.sprite_frames)
	assert_eq(phumtar.sprite_frames.get_frame_count("default"), 2)


func test_phumtar_animation_is_playing():
	var phumtar = _main.get_node("About/About/phumtar")
	assert_true(phumtar.is_playing(), "l'animation de Phumtar doit tourner (autoplay)")


func test_phumtar_animation_really_changes_frame_over_time():
	var phumtar = _main.get_node("About/About/phumtar")
	var frames_seen = {}
	for i in range(40):
		frames_seen[phumtar.frame] = true
		await get_tree().process_frame
	assert_eq(len(frames_seen), 2, "les deux images doivent s'afficher tour a tour")
