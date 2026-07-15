extends "res://addons/gut/test.gd"

# Test d'integration qui simule un VRAI geste de swipe -- pas un appel
# direct a Swiper.go_to_page()/focus_to_X(), mais un vrai
# InputEventMouseButton presse+relache injecte via Input.parse_input_event(),
# exactement comme le ferait le vrai pipeline d'input de Godot pour un
# utilisateur (le projet a pointing/emulate_touch_from_mouse=true, donc
# Godot synthetise lui-meme les InputEventScreenTouch corrects a partir de
# ces evenements souris). Ca traverse tout le vrai chemin :
# input -> Viewport -> Control.gui_input -> main._on_main_background_gui_input
# -> Swiper.compute_event() -> _calculate_swipe() -> swipe_to_left/right().
#
# Pieges trouves en construisant ce test (voir TEST_PLAN.md) :
# 1. La camera de main.tscn a un smoothing (smoothing_speed=20) : tant
#    qu'elle n'est pas stabilisee, la position recue par gui_input est
#    incoherente (transform en cours de changement a chaque frame). Il
#    faut attendre qu'elle soit stable avant d'injecter l'input.
# 2. Envoyer un InputEventScreenTouch BRUT en position de relachement donne
#    une position recue completement fausse (semble lie a l'emulation
#    tactile interne de Godot qui ne gere pas bien un "release" tactile
#    brut sans "press" tactile brut correspondant). Passer par de VRAIS
#    InputEventMouseButton (presse puis relache) resout ca proprement :
#    Godot les convertit alors correctement en InputEventScreenTouch avec
#    les bonnes positions.
# 3. [Godot 3 -> 4] Ce piege n'existe plus avec `await` (contrairement a
#    `yield()` + GDScriptFunctionState en Godot 3, `await fn()` fonctionne
#    correctement que fn() suspende reellement ou retourne de facon
#    synchrone) -- garde neanmoins un yield/await inconditionnel au debut
#    de _wait_camera_settled() par habitude defensive, sans que ce soit
#    strictement necessaire desormais.

var _main = null

const MIN_DRAG_DELTA = 200.0  # nettement au-dessus du seuil minimum_drag=100 de swipe.gd
const VIEWPORT_WIDTH = 558.0  # cf project.godot, doit rester DANS l'ecran reel


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()
	# Player.need_force_display_options colle a "true" pour de bon une fois
	# declenche par guess_after_migration() (ex: un fichier de test
	# precedent qui bascule sur un livre sans sauvegarde) et n'est jamais
	# remis a false -- inoffensif en prod (un seul boot par processus reel)
	# mais force sinon l'ecran Options a se rouvrir tout seul ici, qui
	# intercepte alors tous les clics/touches destines a Background.
	Player.need_force_display_options = false

	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)
	for i in range(5):
		await get_tree().process_frame
	_main.get_node("Options").visible = false

	# Le panneau de rapport de GUT (GutRunner/GutLayer, CanvasLayer de layer
	# 128 -- donc rendu AU-DESSUS de tout, y compris _main) capte et avale
	# tous les clics/touches avant qu'ils n'atteignent Background : verifie
	# empiriquement que get_viewport().gui_get_hovered_control() resout sur
	# le TestOutput (RichTextLabel) de GUT, jamais sur Background, meme avec
	# un rect/mouse_filter/camera/focus fenetre tous corrects par ailleurs.
	# GUT n'expose pas de flag CLI pour desactiver son propre GUI (gexit ne
	# fait que fermer le process a la fin, pas le cacher pendant) -- on le
	# neutralise donc localement, uniquement pour ce fichier qui a besoin
	# d'un vrai clic/touch traversant tout le pipeline d'input.
	var gut_layer = get_tree().root.get_node_or_null("GutRunner/GutLayer")
	if gut_layer:
		gut_layer.visible = false


func after_all():
	_main.free()


func _wait_camera_settled():
	await get_tree().process_frame
	var cam = _main.camera
	for i in range(300):  # garde-fou ~5s a 60fps
		var center = cam.get_screen_center_position()
		if abs(center.x - cam.position.x) < 0.5 and abs(center.y - cam.position.y) < 0.5:
			return
		await get_tree().process_frame


func _real_swipe(from_x, to_x, y=500.0):
	# Simule un vrai glissement du doigt de from_x vers to_x (coordonnees
	# ecran, DOIVENT rester dans [0, VIEWPORT_WIDTH] -- une position hors
	# ecran reelle n'a pas de sens et produit un comportement incoherent).
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(from_x, y)
	press.global_position = Vector2(from_x, y)
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame

	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(to_x, y)
	release.global_position = Vector2(to_x, y)
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame


func test_swiping_finger_right_goes_from_chapitres_back_to_main():
	Swiper.focus_to_chapitres()
	await _wait_camera_settled()
	assert_eq(Swiper.get_current_page(), 'chapitres')

	await _real_swipe(50.0, 50.0 + MIN_DRAG_DELTA)
	await _wait_camera_settled()

	assert_eq(Swiper.get_current_page(), 'main',
		"un vrai geste de swipe (doigt vers la droite) doit ramener de chapitres a main")


func test_swiping_finger_left_goes_from_main_to_chapitres():
	Swiper.focus_to_main()
	await _wait_camera_settled()
	assert_eq(Swiper.get_current_page(), 'main')

	await _real_swipe(VIEWPORT_WIDTH - 50.0, VIEWPORT_WIDTH - 50.0 - MIN_DRAG_DELTA)
	await _wait_camera_settled()

	assert_eq(Swiper.get_current_page(), 'chapitres',
		"un vrai geste de swipe (doigt vers la gauche) doit avancer de main a chapitres")


func test_a_short_drag_below_the_threshold_does_not_change_page():
	Swiper.focus_to_chapitres()
	await _wait_camera_settled()

	await _real_swipe(50.0, 100.0)  # delta=50 < minimum_drag=100
	await _wait_camera_settled()

	assert_eq(Swiper.get_current_page(), 'chapitres',
		"un glissement trop court ne doit pas declencher de changement de page")


func test_real_swipe_actually_moves_the_camera():
	Swiper.focus_to_main()
	await _wait_camera_settled()
	var camera_before = _main.camera.position.x

	await _real_swipe(VIEWPORT_WIDTH - 50.0, VIEWPORT_WIDTH - 50.0 - MIN_DRAG_DELTA)
	await _wait_camera_settled()

	assert_ne(_main.camera.position.x, camera_before,
		"le swipe doit reellement deplacer la camera, pas juste changer une variable d'etat")
