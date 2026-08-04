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
#   wait_seconds  {n}            attend n secondes REELLES (cf AnimationPlayer trop long pour
#                                 wait_frames sous Xvfb, ex: SuccessPopup)
#   go_to_node    {id}           equivalent d'un clic sur un ChapterChoice
#   combat_play_turn {attack_die, esquive_die}  force les des (deterministe) et joue un tour
#                                 reel via Combat._play_turn() -- null = de reel/aleatoire
#   combat_manual_win {}         equivalent du bouton "J'ai gagne" (Combat._on_manual_win_pressed)
#   combat_continue {}           equivalent du bouton "CONTINUER L'AVENTURE" de l'overlay de
#                                 resolution (Combat._on_continue_pressed) -- ferme tout le
#                                 panneau, pas seulement la carte de resolution
#   heal_billy_full {}           Player.pv = Player.pv_max (un Billy neuf a 0 PV courants tant
#                                 qu'aucun chapitre ne les a fixes -- sinon tout combat le
#                                 traite comme deja mort avant le 1er tour)
#   add_item      {name}         equivalent de cocher un objet dans Options
#   remove_item   {name}
#   launch_new_billy  {}         equivalent du bouton "Nouvelle partie" (reset direct, sans popup)
#   show_options  {}             bascule vers l'ecran Options
#   set_billy_type {type}         AppParameters.set_billy_type -- pour des scenarios deterministes
#   show_options_stats {}        bascule vers l'ecran Options, onglet "Stats"
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
#   assert_combat_visible {visible}  echoue si $Combat.visible != visible (visible par defaut true)
#   combat_undo   {}             equivalent du bouton ↺ (Combat._on_undo_pressed)
#   combat_rewind_to_turn {turn} equivalent d'un tap sur une pastille de tour (Combat._on_turn_chip_pressed)
#   assert_combat_next_turn {turn}  echoue si Combat._controller.prochain_tour() != turn
#   stats_step_chapitres_autre {stat,delta}  +/- sur "Chapitres & Autre" d'une stat (fiche de perso)
#   stats_step_pv_max_bonus {delta}  +/- sur le bonus de PV max (fiche de perso)
#   stats_step_pv {delta}        +/- sur les PV courants (fiche de perso)
#   stats_step_cha {delta}       +/- sur la Chance courante (fiche de perso)
#   stats_fill_pv {}             bouton "Plein" sur les PV (fiche de perso)
#   stats_fill_cha {}            bouton "Plein" sur la Chance (fiche de perso)
#   assert_player_stat {key,value}  echoue si Player.get_<key>() (ou Player.<key>) != value
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
		await get_tree().process_frame
	_run_next_step()


func _parse_args():
	# En Godot 4, OS.get_cmdline_args() ne renvoie plus les arguments après
	# le "--" (contrairement à Godot 3) : il faut la nouvelle méthode dédiée
	# OS.get_cmdline_user_args() pour ça.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--e2e-script="):
			_scenario_path = arg.substr(len("--e2e-script="))
		elif arg.begins_with("--e2e-out="):
			_out_dir = arg.substr(len("--e2e-out="))


func _load_scenario():
	if !FileAccess.file_exists(_scenario_path):
		printerr("E2E: cannot open scenario file: %s" % _scenario_path)
		return false
	var f = FileAccess.open(_scenario_path, FileAccess.READ)
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
			await get_tree().process_frame
		_run_next_step()
	elif action == "wait_seconds":
		# Temps REEL (Timer), pas un compte de frames -- indispensable pour
		# attendre la fin d'une animation a duree fixe (ex: AnimationPlayer
		# du SuccessPopup, 5.9s). Sous Xvfb, sans limitation vsync fiable,
		# un nombre de frames fixe peut s'ecouler en bien moins de temps reel
		# que prevu -- vu en pratique sur E4_fin_bonne (500 frames pas
		# toujours suffisantes pour laisser le popup de succes disparaitre).
		await get_tree().create_timer(step.get("n", 1.0)).timeout
		_run_next_step()
	elif action == "go_to_node":
		_main.go_to_node(int(step["id"]))
		_run_next_step()
	elif action == "combat_play_turn":
		# Force les des plutot que de cliquer le vrai bouton -- un scenario
		# E2E doit rester reproductible, jamais a la merci d'un jet aleatoire
		# (meme technique que test_combat_screen.gd::_play_turn()). Le JSON
		# ne connait que le type "float" pour les nombres -- reconverti en
		# int explicitement, combat.gd indexant SITUATION_TABLE avec ces
		# valeurs.
		var attack_die = step.get("attack_die")
		var esquive_die = step.get("esquive_die")
		await _main.get_node("Combat")._play_turn(
			int(attack_die) if attack_die != null else null,
			int(esquive_die) if esquive_die != null else null
		)
		_run_next_step()
	elif action == "heal_billy_full":
		# Un Billy tout neuf a 0 PV courants (jamais mis a jour avant qu'un
		# chapitre du livre ne le fasse) -- combat.gd le traiterait alors,
		# a raison, comme deja mort avant le 1er tour. Sans equivalent
		# "chapitre de soin" simple a rejouer ici, on fixe directement les
		# PV au max pour un scenario de combat qui a un sens.
		Player.pv = Player.pv_max
		_run_next_step()
	elif action == "combat_manual_win":
		_main.get_node("Combat")._on_manual_win_pressed()
		_run_next_step()
	elif action == "combat_continue":
		_main.get_node("Combat")._on_continue_pressed()
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
	elif action == "set_billy_type":
		# Pour des scenarios deterministes : "guerrier" (defaut reel de
		# Parameters.gd) ajoute des bonus qui compliqueraient le calcul a
		# la main des valeurs attendues par assert_player_stat.
		AppParameters.set_billy_type(step["type"])
		_run_next_step()
	elif action == "show_options_stats":
		_main.show_options()
		_main._on_button_show_stats()
		_run_next_step()
	elif action == "validate_options":
		_main._on_options_validate_button_pressed()
		_run_next_step()
	elif action == "focus_page":
		Swiper.go_to_page(step["page"])  # "main" | "chapitres" | "success" | "lore" | "about"
		_run_next_step()
	elif action == "real_swipe":
		# Position fiable seulement une fois la camera stabilisee, sinon le
		# transform gui_input change a chaque frame. En Godot 4, `await` sur
		# n'importe quel appel fonctionne correctement qu'il suspende
		# reellement ou retourne de facon synchrone -- plus besoin de
		# detecter un GDScriptFunctionState comme en Godot 3.
		await _wait_for_camera_to_settle()
		await _real_swipe(float(step["from_x"]), float(step["to_x"]), float(step.get("y", 500.0)))
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
		# _take_screenshot() attend le rendu du frame avant de retourner :
		# il faut explicitement l'attendre, sinon on avance a l'etape
		# suivante avant que le PNG soit ecrit.
		await _take_screenshot(step.get("name", "step_%s" % _step_index))
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
	elif action == "assert_combat_visible":
		# Verifie le VRAI etat runtime du VRAI panneau ($Combat sous main.tscn
		# reel), pas une relecture separee du JSON -- exactement ce que
		# is_combat() est cense declencher dans main.gd::go_to_node().
		var expected_visible = step.get("visible", true)
		var actual_visible = _main.get_node("Combat").visible
		if actual_visible != expected_visible:
			printerr("E2E ASSERT FAILED: Combat.visible is %s, expected %s (node %s)" % [actual_visible, expected_visible, Player.current_node_id])
			get_tree().quit(1)
			return
		print("E2E ASSERT OK: Combat.visible == %s (node %s)" % [expected_visible, Player.current_node_id])
		_run_next_step()
	elif action == "combat_undo":
		# Equivalent du bouton ↺ : annule le DERNIER tour joue, jamais un
		# clic reel (fragile en coordonnees) -- meme principe que
		# combat_play_turn/combat_manual_win ci-dessus.
		_main.get_node("Combat")._on_undo_pressed()
		_run_next_step()
	elif action == "combat_rewind_to_turn":
		# Equivalent d'un tap sur une pastille de tour : revient avant le
		# tour donne, annulant tous les tours suivants d'un coup.
		_main.get_node("Combat")._on_turn_chip_pressed(int(step["turn"]))
		_run_next_step()
	elif action == "assert_combat_next_turn":
		var expected_turn = int(step["turn"])
		var actual_turn = _main.get_node("Combat")._controller.prochain_tour()
		if actual_turn != expected_turn:
			printerr("E2E ASSERT FAILED: prochain_tour() is %s, expected %s" % [actual_turn, expected_turn])
			get_tree().quit(1)
			return
		print("E2E ASSERT OK: prochain_tour() == %s" % expected_turn)
		_run_next_step()
	elif action == "stats_step_chapitres_autre":
		# Triche sur une stat de base (Habilete, Endurance, ...) via la
		# fiche de personnage reelle -- jamais en touchant le vrai vecu
		# narratif (*_chapters), cf StatsScreen.gd::_step_chapitres_autre.
		_main.get_node("Options/Stats")._step_chapitres_autre(step["stat"], int(step["delta"]))
		_run_next_step()
	elif action == "stats_step_pv_max_bonus":
		_main.get_node("Options/Stats")._step_pv_max_bonus(int(step["delta"]))
		_run_next_step()
	elif action == "stats_step_pv":
		_main.get_node("Options/Stats")._step_pv(int(step["delta"]))
		_run_next_step()
	elif action == "stats_step_cha":
		_main.get_node("Options/Stats")._step_cha(int(step["delta"]))
		_run_next_step()
	elif action == "stats_fill_pv":
		_main.get_node("Options/Stats")._fill_pv()
		_run_next_step()
	elif action == "stats_fill_cha":
		_main.get_node("Options/Stats")._fill_cha()
		_run_next_step()
	elif action == "search_items":
		# Equivalent d'un utilisateur qui tape dans le champ de recherche de
		# l'Equipement : poser le texte ne declenche pas text_changed tout
		# seul (signal emis uniquement par une vraie saisie), donc on rappelle
		# le handler explicitement -- meme principe que stats_step_*.
		var query = step["query"]
		_main.get_node("Options/Equipement/SearchBar/Box/Field").text = query
		_main._on_item_search_text_changed(query)
		_run_next_step()
	elif action == "clear_item_search":
		_main._on_item_search_clear_pressed()
		_run_next_step()
	elif action == "assert_visible_items_count":
		var expected = int(step["count"])
		var item_stack = _main.get_node("Options/Equipement/ItemsCont/Items")
		var visible_count = 0
		for item in item_stack.get_children():
			if item.visible:
				visible_count += 1
		if visible_count != expected:
			printerr("E2E ASSERT FAILED: visible_items_count is %s, expected %s" % [visible_count, expected])
			get_tree().quit(1)
			return
		print("E2E ASSERT OK: visible_items_count == %s" % expected)
		_run_next_step()
	elif action == "assert_player_stat":
		# key: nom de stat ("hab", "pv", "pv_max", "cha", "chamax", ...) --
		# passe par le getter reel s'il existe (get_hab()...), sinon lit la
		# propriete directement (pv/pv_max/cha/chamax n'ont pas de getter).
		var key = step["key"]
		var expected = int(step["value"])
		var actual = Player.call("get_%s" % key) if Player.has_method("get_%s" % key) else Player.get(key)
		if actual != expected:
			printerr("E2E ASSERT FAILED: Player %s is %s, expected %s" % [key, actual, expected])
			get_tree().quit(1)
			return
		print("E2E ASSERT OK: Player %s == %s" % [key, expected])
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
		var center = camera.get_screen_center_position()
		if abs(center.x - camera.position.x) < 0.5 and abs(center.y - camera.position.y) < 0.5:
			break
		await get_tree().process_frame
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
		await get_tree().process_frame


func _wait_for_item_popup_layout_to_settle():
	# Le bandeau "objet acquis" (et le decalage des cartes Complete/Position
	# qu'il declenche) est anime (cf main.gd::_shift_item_popups_layout,
	# ItemPopup.gd::_ready/_on_Timer_timeout) -- sans cette attente, une
	# capture peut tomber en pleine transition et paraitre "differente" du
	# golden sans aucune vraie regression (flaky).
	var max_frames = 60  # largement au-dessus de ITEM_POPUP_ANIM_DURATION (~0.22s)
	var frames = 0
	while frames < max_frames:
		var main_tween = _main.item_popups_layout_tween
		var main_busy = is_instance_valid(main_tween) and main_tween.is_running()
		var any_popup_busy = false
		for popup in _main.get_node("ItemPopups/ScrollContainer/ItemPopupsCont").get_children():
			var popup_tween = popup.anim_tween
			if is_instance_valid(popup_tween) and popup_tween.is_running():
				any_popup_busy = true
				break
		if not main_busy and not any_popup_busy:
			break
		await get_tree().process_frame
		frames += 1


func _take_screenshot(name):
	# En Godot 4, `await` fonctionne correctement que la fonction appelee
	# suspende reellement ou retourne de facon synchrone -- plus besoin de
	# detecter un GDScriptFunctionState comme en Godot 3.
	await _wait_for_camera_to_settle()
	await _wait_for_success_popup_to_settle()
	await _wait_for_item_popup_layout_to_settle()
	# Laisse le frame en cours vraiment se rendre avant de lire la texture
	# du viewport (sinon on capture parfois l'etat precedent).
	await get_tree().process_frame
	await get_tree().process_frame
	if !DirAccess.dir_exists_absolute(_out_dir):
		DirAccess.make_dir_recursive_absolute(_out_dir)
	var img = get_viewport().get_texture().get_image()
	var pth = "%s/%s.png" % [_out_dir, name]
	var err = img.save_png(pth)
	if err == OK:
		print("E2E: screenshot saved: %s" % pth)
	else:
		printerr("E2E: FAILED to save screenshot %s (error %s)" % [pth, err])
