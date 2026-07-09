extends Node

# Pilote un scenario E2E scripte sur le VRAI jeu (main.tscn instancie tel
# quel, avec les vrais autoloads : Player, BookData, AppParameters, ...).
# Ne remplace ni ne mocke rien : les captures d'ecran refletent exactement
# ce qu'un joueur verrait.
#
# Usage (voir aussi TEST_PLAN.md §5):
#   Godot_v3.6.2-stable_x11.64 --path . test/e2e/e2e_runner.tscn -- \
#       --e2e-script=res://test/e2e/scenarios/nouvelle_partie.json \
#       --e2e-out=res://test/e2e/screenshots/actual
#
# Le scenario est une liste JSON d'etapes, chacune avec une cle "action":
#   wait_frames   {n}            attend n frames (laisse le rendu se stabiliser)
#   go_to_node    {id}           equivalent d'un clic sur un ChapterChoice
#   add_item      {name}         equivalent de cocher un objet dans Options
#   remove_item   {name}
#   launch_new_billy  {}         equivalent du bouton "Nouvelle partie" (reset direct, sans popup)
#   show_options  {}             bascule vers l'ecran Options
#   validate_options  {}         valide l'ecran Options (equivalent bouton "Valider" -- rend
#                                 $ItemPopups visible, comme un vrai joueur qui a choisi son equipement)
#   focus_page    {page}         bascule vers "main"|"chapitres"|"success"|"lore"|"about"
#   real_swipe    {from_x,to_x}  VRAI geste de swipe (InputEventMouseButton presse+relache,
#                                 converti par Godot en InputEventScreenTouch via
#                                 pointing/emulate_touch_from_mouse=true) -- traverse tout le
#                                 vrai pipeline d'input, pas un appel direct a Swiper
#   toggle_spoils {on}            equivalent du bouton "Spoils" du bandeau superieur
#   toggle_sound  {on}            equivalent du bouton "Son" du bandeau superieur
#   change_book   {book_number}  bascule FDCN (1) <-> CDSI (2)
#   open_new_billy_popup    {}   ouvre le popup de confirmation reset
#   accept_new_billy_popup  {}   simule le clic "Accepter" du popup reset
#   screenshot    {name}         capture d'ecran -> <out_dir>/<name>.png
#   assert_current_node_id {id}  echoue (quit non-zero) si Player.current_node_id != id
#   assert_has_item {name,has}   echoue si Player.have_item(name) != has (has par defaut true)
#
# assert_* est volontairement minimal (pas un framework d'assertions complet) :
# le but est de verrouiller un scenario multi-PROCESSUS (ex: persistance reelle
# a travers un vrai redemarrage) avec un resultat pass/fail deterministe, en
# plus (pas a la place) des captures d'ecran pour la preuve visuelle.

var _main = null
var _out_dir = "res://test/e2e/screenshots/actual"
var _scenario_path = ""
var _steps = []
var _step_index = 0


func _ready():
	_parse_args()
	if _scenario_path == "":
		printerr("E2E: no --e2e-script=<path> given on the command line, nothing to do")
		get_tree().quit(2)
		return
	if !_load_scenario():
		get_tree().quit(2)
		return

	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)

	# Laisse _ready()/la mise en page initiale se stabiliser avant de jouer
	# le scenario.
	for i in range(5):
		await get_tree().idle_frame
	_run_next_step()


func _parse_args():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--e2e-script="):
			_scenario_path = arg.substr(len("--e2e-script="))
		elif arg.begins_with("--e2e-out="):
			_out_dir = arg.substr(len("--e2e-out="))


func _load_scenario():
	var f = File.new()
	var err = f.open(_scenario_path, File.READ)
	if err != OK:
		printerr("E2E: cannot open scenario file: %s (error %s)" % [_scenario_path, err])
		return false
	var content = f.get_as_text()
	f.close()
	var test_json_conv = JSON.new()
	test_json_conv.parse(content)
	var parsed = test_json_conv.get_data()
	if typeof(parsed) != TYPE_ARRAY:
		printerr("E2E: scenario file must contain a JSON array of steps: %s" % _scenario_path)
		return false
	_steps = parsed
	return true


func _run_next_step():
	if _step_index >= len(_steps):
		print("E2E: scenario finished (%s steps)" % len(_steps))
		get_tree().quit(0)
		return
	var step = _steps[_step_index]
	_step_index += 1
	var action = step.get("action", "")
	print("E2E STEP %s/%s: %s" % [_step_index, len(_steps), step])

	if action == "wait_frames":
		var n = step.get("n", 1)
		for i in range(n):
			await get_tree().idle_frame
		_run_next_step()
	elif action == "go_to_node":
		_main.go_to_node(int(step["id"]))
		_run_next_step()
	elif action == "add_item":
		Player.add_item_from_options(step["name"])
		_run_next_step()
	elif action == "remove_item":
		Player.remove_item_from_options(step["name"])
		_run_next_step()
	elif action == "launch_new_billy":
		Player.launch_new_billy()
		_main.go_to_node(1)
		_run_next_step()
	elif action == "show_options":
		_main.show_options()
		_run_next_step()
	elif action == "validate_options":
		_main._on_options_validate_button_pressed()
		_run_next_step()
	elif action == "focus_page":
		Swiper.go_to_page(step["page"])  # "main" | "chapitres" | "success" | "lore" | "about"
		_run_next_step()
	elif action == "real_swipe":
		# _wait_for_camera_to_settle() ne yield reellement QUE si necessaire
		# (voir _take_screenshot()) : position fiable seulement une fois la
		# camera stabilisee, sinon le transform gui_input change a chaque frame.
		var settle_wait = _wait_for_camera_to_settle()
		if settle_wait is GDScriptFunctionState:
			await settle_wait.completed
		await _real_swipe(float(step["from_x"]), float(step["to_x"]), float(step.get("y", 500.0))).completed
		_run_next_step()
	elif action == "toggle_spoils":
		_main.change_spoils(bool(step["on"]))
		_run_next_step()
	elif action == "toggle_sound":
		_main.change_sound(bool(step["on"]))
		_run_next_step()
	elif action == "change_book":
		_main._change_book_number(int(step["book_number"]))
		_run_next_step()
	elif action == "open_new_billy_popup":
		_main._on_button_new_billy()
		_run_next_step()
	elif action == "accept_new_billy_popup":
		_main._on_GenericTextPopup_generic_popup_accept()
		_run_next_step()
	elif action == "screenshot":
		# _take_screenshot() yields internally (attend le rendu du frame) :
		# il faut explicitement attendre sa fin, sinon on avance a l'etape
		# suivante avant que le PNG soit ecrit.
		await _take_screenshot(step.get("name", "step_%s" % _step_index)).completed
		_run_next_step()
	elif action == "assert_current_node_id":
		var expected_id = int(step["id"])
		if Player.current_node_id != expected_id:
			printerr("E2E ASSERT FAILED: current_node_id is %s, expected %s" % [Player.current_node_id, expected_id])
			get_tree().quit(1)
			return
		print("E2E ASSERT OK: current_node_id == %s" % expected_id)
		_run_next_step()
	elif action == "assert_has_item":
		var item_name = step["name"]
		var expected_has = step.get("has", true)
		var actual_has = Player.have_item(item_name)
		if actual_has != expected_has:
			printerr("E2E ASSERT FAILED: have_item('%s') is %s, expected %s" % [item_name, actual_has, expected_has])
			get_tree().quit(1)
			return
		print("E2E ASSERT OK: have_item('%s') == %s" % [item_name, expected_has])
		_run_next_step()
	else:
		printerr("E2E: unknown action '%s', skipping" % action)
		_run_next_step()


func _real_swipe(from_x, to_x, y):
	# VRAI geste de swipe : de vrais InputEventMouseButton presse+relache
	# injectes via Input.parse_input_event(), convertis par Godot lui-meme
	# en InputEventScreenTouch (pointing/emulate_touch_from_mouse=true dans
	# project.godot) puis routes par le vrai pipeline d'input jusqu'a
	# main._on_main_background_gui_input() -> Swiper.compute_event(). Les
	# positions DOIVENT rester dans l'ecran reel (0..558) : une position
	# hors ecran (ex: > largeur fenetre) donne une position recue
	# incoherente cote release, decouvert en construisant ce runner.
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(from_x, y)
	press.global_position = Vector2(from_x, y)
	press.button_pressed = true
	Input.parse_input_event(press)
	await get_tree().idle_frame
	await get_tree().idle_frame

	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(to_x, y)
	release.global_position = Vector2(to_x, y)
	release.button_pressed = false
	Input.parse_input_event(release)
	await get_tree().idle_frame
	await get_tree().idle_frame


func _wait_for_camera_to_settle():
	# main.tscn::Camera a smoothing_enabled=true (smoothing_speed=20): un
	# changement de page (set_camera_to_pos) ne deplace PAS la camera
	# instantanement, elle glisse dessus plusieurs frames. Pour les grands
	# sauts (main -> success/lore/about), un simple wait_frames fixe se
	# retrouve a capturer une image en pleine transition (ecran "decale").
	# On attend donc explicitement que le centre reellement affiche
	# (get_camera_screen_center) rejoigne la position cible, avec un
	# garde-fou en nombre de frames au cas ou elle ne convergerait jamais.
	var camera = _main.camera
	var max_frames = 300  # ~5s a 60fps
	var frames = 0
	while frames < max_frames:
		var center = camera.get_camera_screen_center()
		if abs(center.x - camera.position.x) < 0.5 and abs(center.y - camera.position.y) < 0.5:
			break
		await get_tree().idle_frame
		frames += 1
	print("E2E: camera settled after %s frame(s)" % frames)


func _wait_for_success_popup_to_settle():
	# Atteindre un chapitre qui est A LA FOIS une fin ET un succes (le cas de
	# TOUTES les bonnes fins du livre 1 : chacune a sa propre cle "success")
	# declenche $SuccessPopup, dont l'animation "show" dure 5s (fade-in sur
	# les 2 premieres secondes, plateau stable jusqu'a 5s, puis "hide"
	# s'enchaine immediatement). Sans attendre, la capture tombe en plein
	# fade-in. On attend d'etre dans le plateau stable (>= 3s dans "show"),
	# ou que l'animation soit deja terminee (rien a attendre).
	var anim_player = _main.get_node("SuccessPopup/AnimationPlayer")
	var max_wait_ms = 20000  # garde-fou large (show=5s + hide, + marge)
	var start_ms = Time.get_ticks_msec()
	while true:
		if !anim_player.is_playing():
			break
		if anim_player.current_animation == "show" and anim_player.current_animation_position >= 3.0:
			break
		if Time.get_ticks_msec() - start_ms > max_wait_ms:
			printerr("E2E: WARNING success popup animation safety cap reached")
			break
		await get_tree().idle_frame


func _take_screenshot(name):
	# Ces deux attentes ne yield reellement QUE si necessaire (sinon elles
	# retournent de façon synchrone, donc pas un GDScriptFunctionState) :
	# yield() exige un objet valide.
	var camera_wait = _wait_for_camera_to_settle()
	if camera_wait is GDScriptFunctionState:
		await camera_wait.completed
	var popup_wait = _wait_for_success_popup_to_settle()
	if popup_wait is GDScriptFunctionState:
		await popup_wait.completed
	# Laisse le frame en cours vraiment se rendre avant de lire la texture
	# du viewport (sinon on capture parfois l'etat precedent).
	await get_tree().idle_frame
	await get_tree().idle_frame
	var dir = DirAccess.new()
	if !dir.dir_exists(_out_dir):
		dir.make_dir_recursive(_out_dir)
	var img = get_viewport().get_texture().get_data()
	img.flip_y()  # Godot 3.x rend les textures de viewport inversees verticalement
	var pth = "%s/%s.png" % [_out_dir, name]
	var err = img.save_png(pth)
	if err == OK:
		print("E2E: screenshot saved: %s" % pth)
	else:
		printerr("E2E: FAILED to save screenshot %s (error %s)" % [pth, err])
