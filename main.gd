extends Node2D


var current_lines = []


onready var Bread = preload('res://bread.tscn')
onready var Choice = preload('res://ChapterChoice.tscn')
onready var EndingChoice = preload('res://EndingChoice.tscn')
onready var Success = preload('res://Success.tscn')
onready var LoreEntry = preload('res://LoreEntry.tscn')
onready var Item = preload('res://Item.tscn')
onready var ItemPopup = preload('res://ItemPopup.tscn')

onready var gauge = $Background/GlobalCompletion/Gauge

onready var camera = $Camera

var current_page = 'main'

# The 4 top menus
var top_menus = []



func _ready():
	# Register to Swiper for page move
	Swiper.register_main(self)
	Player.register_main(self)

	# Register top_menus so they can call us back
	self._register_top_menus()
	
	# Load the nodes ids we did already visited in the past
	self._reload_all_player()
	
	self._do_load_book_context()
	

func _reload_all_player():
	# Load the nodes ids we did already visited in the past
	var need_show_options_at_startup = Player.do_load()
	if need_show_options_at_startup:
		print('_reload_all_player:: need_show_options_at_startup is forced')
		self.show_options()


func _do_load_book_context():
	print('_do_load_book_context')
	# Create all chapters in the 2nd screen
	self.insert_all_chapters()
	# And success to the 3th
	self.insert_all_success()
	# Also lore as book have differents gods ^^
	self.insert_all_lore()
	
	print('_do_load_book_context:: Player.insert_all_objects')
	Player.insert_all_objects()
	print('_do_load_book_context:: Player.do_load')
	Player.do_load()  # TEST
	print('_do_load_book_context:: Player.compute_my_billy')
	Player.compute_my_billy()
	
	# Jump to node, and will show main page
	self.go_to_node(Player.get_current_node_id())
	
	# Play intro
	# NOTE: if the current node id have a sound, intro will supress it
	self._play_intro()


func go_to_node(node_id):
	
	var go_to_node_return = Player.go_to_node(node_id)
	# =>  is_new_node, aquires, removes
	var is_new_node = go_to_node_return[0]
	var new_aquires = go_to_node_return[1]
	var new_removes = go_to_node_return[2]
	print('JUMP TO:  is_new=%s' % is_new_node, ' aquires=%s' % str(new_aquires), ' new removes=%s' % str(new_removes))
		
	self.refresh()
	# We did change node, so important to see it
	Swiper.focus_to_main()
	
	# If we are in a special node, play sound
	self._play_node_sound()

	if is_new_node:
		self._check_new_success(Player.get_current_node_id())
	
	# Show popups about new/remove items ^^
	# NOTE: auto disapears after 3s
	for item_name in new_aquires:
		self.popup_new_item(item_name)
	for item_name in new_removes:
		self.popup_remove_item(item_name)
	
	# If it's a combat, show it
	var node = BookData.get_node(node_id)
	if node.is_combat():
		$Combat/Nom.text = node.get_combat_name()
		$Combat/EnnemiPvValue.text = '%s' % node.get_combat_pv()
		$Combat/EnnemiArmValue.text = '%s' % node.get_combat_armure()
		$Combat/EnnemiHabValue.text = '%s' % node.get_combat_hab()
		$Combat/EnnemiDegValue.text = '%s' % node.get_combat_degat()
		# We display the Pyro only if he help us
		var hab_pyro = node.get_combat_pyro()
		if hab_pyro != 0:
			$Combat/SpritePyro.visible = true
			$Combat/PyroHab.visible = true
			$Combat/PyroHab.text = '+%s' % hab_pyro
		else:  # he is not helping us
			$Combat/SpritePyro.visible = false
			$Combat/PyroHab.visible = false
		# Update the billy stats
		self._update_billy_in_combat()
		# Display the whole combat panel
		$Combat.visible = true
	else:
		$Combat.visible = false


func _update_billy_in_combat():
	$Combat/PlayerPvValue.text = '%s' % Player.get_pv()
	$Combat/PlayerHabValue.text = '%s' % Player.get_hab()
	$Combat/PlayerArmValue.text = '%s' % Player.get_arm()
	$Combat/PlayerDegValue.text = '%s' % Player.get_deg()


# We are in a new node, check if it's a success.
# if it is one, display a cool success highlight ^^
func _check_new_success(node_id):
	if BookData.is_success_chapter(node_id):
		var success = BookData.get_success_from_chapter(node_id)
		# Update the success data
		var popup = $SuccessPopup
		popup.update_and_show(success)
	

func _play_intro():
	var intro_sound = {
		1: 'intro-fdcn.mp3',
		2: 'intro-cdsi.mp3',
	}
	var book_number = AppParameters.get_book_number()
	Sounder.play(intro_sound.get(book_number))


func _play_node_sound():
	var player = $AudioPlayer
	# In all cases, stop the player
	player.stop()
	var book_number = AppParameters.get_book_number()
	
	var node_sound_fnames = {
		# FDCN
		1 : {
			27: '27-kakaka.mp3',
			193: '193-la-cathedrale.mp3',
			216: '216-tour-des-mages.mp3',
			338: '338-virilus-backstory.mp3'
		},
		# CDSI
		2 : {
			
		},
	}
	var fname = node_sound_fnames[book_number].get(int(Player.get_current_node_id()))
	if fname == null:  # no sound this node
		return
	
	Sounder.play(fname)




func print_debug(s):
	$DEBUG.text = s


func _register_top_menus():
	self.top_menus.append($Background/top_menu)
	self.top_menus.append($Chapitres/top_menu)
	self.top_menus.append($Succes/top_menu)
	self.top_menus.append($Lore/top_menu)
	self.top_menus.append($About/top_menu)
	
	for top_menu in self.top_menus:
		top_menu.register_main(self)


func display_all_objects():
	var item_stack = $Options/Equipement/ItemsCont/Items
	Utils.delete_children(item_stack)
	print('Insert all objects')
	for item in Player.all_items:
		item_stack.add_child(item)
	

func refresh_all_objects():
	var item_stack = $Options/Equipement/ItemsCont/Items
	for item in item_stack.get_children():
		item.refresh()
		

func jump_to_chapter_100aine(centaine):
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	var scroll_bar = $Chapitres/AllChapters/VScrollBar
	# Get chapter until we find the good one
	for choice in all_choices.get_children():
		var chapter_id = choice.get_chapter_id()
		# We are not sure the choice is visible, so take the first one that match "at least
		if chapter_id >= centaine:
			print('found chapter: %s ' % chapter_id, '%s' % choice)
			print('Jump to :%s' % choice.rect_position.y)
			scroll_bar.scroll_vertical = choice.rect_position.y
			return


# We need to compare integer, not strings
static func _sort_all_chapters(nb1, nb2):
		if int(nb1) < int(nb2):
			return true
		return false


func insert_all_chapters():
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	Utils.delete_children(all_choices)
	
	var chapter_ids = BookData.get_all_nodes().keys()
	chapter_ids.sort_custom(self, '_sort_all_chapters')
	
	for chapter_id in chapter_ids:
		var chapter_data = BookData.get_node(chapter_id)
		
		var choice = Choice.instance()
		choice.set_main(self)
		choice.set_chapitre(chapter_data.get_id())
		all_choices.add_child(choice)


func _update_all_chapters():
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	for choice in all_choices.get_children():
		choice.update_when_in_all_chapters()
		


func insert_all_success():
	var all_success = $Succes/Success/VScrollBar/Success
	Utils.delete_children(all_success)
	
	for success in BookData.get_all_success():
		var s = Success.instance()
		s.set_main(self)
		s.set_from_success_object(success)
		all_success.add_child(s)

func insert_all_lore():
	var all_lore = $Lore/Lore/VScrollBar/persos
	Utils.delete_children(all_lore)
	
	var book_number = AppParameters.get_book_number()
	
	var refs = {
		1: [
			{'type': 'billys', 'name': 'guerrier', 'title':'Billy Guerrier'},
			{'type': 'billys', 'name': 'paysan', 'title':'Billy Paysan'},
			{'type': 'billys', 'name': 'prudent', 'title':'Billy Prudent'},
			{'type': 'billys', 'name': 'debrouillard', 'title':'Billy Debrouillard'},
			# Dieux
			{'type': 'dieux', 'name': 'atella', 'title':'Atella'},
			{'type': 'dieux', 'name': 'blathnat', 'title':'Blathnat'},
			{'type': 'dieux', 'name': 'edire', 'title':'Edire'},
			{'type': 'dieux', 'name': 'mutra', 'title':'Mutra'},
			{'type': 'dieux', 'name': 'melene', 'title':'Melene'},
			{'type': 'dieux', 'name': 'neit', 'title':'Neit'},
			{'type': 'dieux', 'name': 'nyses', 'title':'Nyses'},
			{'type': 'dieux', 'name': 'parodikos', 'title':'Parodikos'},
			{'type': 'dieux', 'name': 'phumtar', 'title':'Phumtar'},
			{'type': 'dieux', 'name': 'runir', 'title':'Runir'},
			{'type': 'dieux', 'name': 'vetherr', 'title':'Vetherr'},
			{'type': 'dieux', 'name': 'virilus', 'title':'Virilus'},
			{'type': 'dieux', 'name': 'ytia', 'title':'Ytia'},
			{'type': 'dieux', 'name': 'zarkan', 'title':'Zarkan'},
		],
		2: [
			{'type': 'billys', 'name': 'guerrier', 'title':'Billy Guerrier'},
			{'type': 'billys', 'name': 'paysan', 'title':'Billy Paysan'},
			{'type': 'billys', 'name': 'prudent', 'title':'Billy Prudent'},
			{'type': 'billys', 'name': 'debrouillard', 'title':'Billy Debrouillard'},
			# Dieux
			{'type': 'dieux', 'name': 'blathnat', 'title':'Blathnat'},
			{'type': 'dieux', 'name': 'iotos', 'title':'Iotos'},
			{'type': 'dieux', 'name': 'khalassa_et_ohassa', 'title':'khalassa et o\'hassa'},
			{'type': 'dieux', 'name': 'nehdira', 'title':'Neh\'Dira'},
			{'type': 'dieux', 'name': 'phumta', 'title':'Phumta'},
			{'type': 'dieux', 'name': 'vetherr', 'title':'Vetherr'},
			{'type': 'dieux', 'name': 'zarhkhan', 'title':'Zarhkhan'},
			
		],
	}
	var lst = refs.get(book_number)
	
	for _def in lst:
		var s = LoreEntry.instance()
		s.type_entry = _def['type']
		s.entry_name = _def['name']
		s.titre = _def['title']
		s.book_number = book_number
		
		all_lore.add_child(s)



func _update_all_success():
	var all_success = $Succes/Success/VScrollBar/Success
	for success in all_success.get_children():
		success.update()


func _refresh_options():
	self.refresh_all_objects()
	
	var type_billy_param = AppParameters.get_billy_type()
	var sprite_by_billy = {
		'guerrier':    $Options/Equipement/BlockGuerrier/sprite,
		'paysan':      $Options/Equipement/BlockPaysan/sprite,
		'prudent':     $Options/Equipement/BlockPrudent/sprite,
		'debrouillard':$Options/Equipement/BlockDebrouillard/sprite
	}
	
	# Gray ALL .material.set_shader_param("param_name", value)
	for billy in sprite_by_billy.keys():
		var sprite = sprite_by_billy[billy]
		self.__set_sprite_to_grey(sprite)
		#sprite.material.set_shader_param("grayscale", true)
	# Colorize the selected one
	if type_billy_param != 'pegu':
		#sprite_by_billy[type_billy_param].material.set_shader_param("grayscale", false)
		self.__set_sprite_to_not_grey(sprite_by_billy[type_billy_param])

	self._refresh_options_stats()
	
	# TODO : refresh book display with grayscale
	self._refresh_options_book_select_display()
	


func __set_sprite_to_grey(sprite):
	sprite.material.set_shader_param("grayscale", true)
	
	
func __set_sprite_to_not_grey(sprite):
	sprite.material.set_shader_param("grayscale", false)


func _refresh_options_book_select_display():
	var book_number = AppParameters.get_book_number()
	if book_number == 1:
		self.__set_sprite_to_not_grey($Options/BookSelect/BoolSelectFcdn/sprite)
		self.__set_sprite_to_grey($Options/BookSelect/BoolSelectCdsi/sprite)
	else:
		self.__set_sprite_to_grey($Options/BookSelect/BoolSelectFcdn/sprite)
		self.__set_sprite_to_not_grey($Options/BookSelect/BoolSelectCdsi/sprite)
	

	
	
func refresh():	
	
	# Update all options based on params
	self._refresh_options()
	
	# Update the top menu with parameters
	for top_menu in self.top_menus:
		top_menu.set_spoils()	
		top_menu.set_billy()
		top_menu.set_sound()
		top_menu.set_book_context()
		
	# Note: the first left backer should be disabled if we cannot get back
	if Player.have_previous_chapters():
		$"Background/Left-Back".set_enabled()
	else:
		$"Background/Left-Back".set_disabled()
	
	
	# Page2: update all chapters
	self._update_all_chapters()
	
	# Page 3: update success with spoils
	self._update_all_success()
	
	# Update the % completion
	var _nb_all_nodes = len(BookData.get_all_nodes())
	var _nb_visited = Player.get_nb_all_time_seen()

	var completion_foot_note = $Background/GlobalCompletion/footnode
	completion_foot_note.text = (' %d /' % _nb_visited) + (' %d' % _nb_all_nodes)
	
	gauge.set_value(_nb_visited / float(_nb_all_nodes))
	
	# Now print my current node
	var my_node = BookData.get_node(Player.get_current_node_id())
	
	# The act in progress
	var _acte_label = $Background/Position/Acte
	_acte_label.text = '%s' % my_node.get_chapter()
	
	var pct100 = BookData.get_acte_completion(Player.get_current_node_id(), Player.get_visited_nodes_all_times())
	var fill_bar = $Background/Position/fill_bar
	fill_bar.value = pct100 # % of the acte	is done
	$Background/Position/fill_par_pct.text = '%3d%%' % pct100
	
	# The arc, if any
	var _arc = my_node.get_arc()
	if _arc != null:
		# Compute how much of the sub_arc we have done
		var pct100_sub_arc = BookData.get_sub_arc_completion(Player.get_current_node_id(), Player.get_visited_nodes_all_times())
		
		$Background/Position/fleche_arc.visible = true
		$Background/Position/LabelArc.visible = true
		$Background/Position/Arc.visible = true
		$Background/Position/Arc.text = _arc
		$Background/Position/fill_bar_arc.visible = true
		$Background/Position/fill_bar_arc.value = pct100_sub_arc
		$Background/Position/fill_bar_arc_pct.visible = true
		$Background/Position/fill_bar_arc_pct.text = '%3d%%' % pct100_sub_arc
		
		# The SMALL chapter display
		var _chapitre_label = $Background/Position/NumeroChapitreSmall
		_chapitre_label.text = '%s' % my_node.get_id()
		_chapitre_label.visible = true
		$Background/Position/LabelChapitreSmall.visible = true
		# Hide big one
		$Background/Position/LabelChapitreBig.visible = false
		$Background/Position/NumeroChapitreBig.visible = false
	else:
		$Background/Position/fleche_arc.visible = false
		$Background/Position/LabelArc.visible = false
		$Background/Position/Arc.visible = false
		$Background/Position/fill_bar_arc.visible = false
		$Background/Position/fill_bar_arc_pct.visible = false

		# The BIG chapter display
		var _chapitre_label = $Background/Position/NumeroChapitreBig
		_chapitre_label.text = '%s' % my_node.get_id()
		_chapitre_label.visible = true
		$Background/Position/LabelChapitreBig.visible = true
		# Hide big one
		$Background/Position/LabelChapitreSmall.visible = false
		$Background/Position/NumeroChapitreSmall.visible = false
	
	
	var breads = $Background/Dreadcumb/breads
	Utils.delete_children(breads)
	
		
	var last_previous = Player.get_last_5_previous_visited_nodes()
	#print('LAST 5: %s' % str(last_previous))
	var _nb_lasts = len(last_previous)
	var _i = 0
	for previous in last_previous:
		var bread = Bread.instance()
		bread.set_chap_number(previous)
		bread.set_main(self)
		if _i == 0:
			bread.set_first()
		# If previous
		
		if _i == _nb_lasts - 2:
			bread.set_previous()
		elif _i == _nb_lasts - 1:
			bread.set_current()
		else:
			bread.set_normal_color()
		breads.add_child(bread)
		_i = _i + 1
		
	
	# And my sons
	var sons_ids = my_node.get_sons()
	# Maybe son sons are not secret, but the jump is
	var secret_jumps = my_node.get_secret_jumps()
	
	# Clean choices
	var choices = $Background/Next/ScrollContainer/Choices
	Utils.delete_children(choices)
	for son_id in sons_ids:		
		# If the son is now ok to be shown, skip it
		if !BookData.is_node_id_freely_showable(son_id, secret_jumps):
			continue
		
		var son = BookData.get_node(son_id)
		var choice = Choice.instance()
		choice.set_main(self)
		choice.update_from_son_node(son)
		# Display it
		choices.add_child(choice)
		
				
	# Maybe we are an ending, then stack a EndingChoice with data
	if my_node.get_ending():
		var choice = EndingChoice.instance()
		choice.set_main(self)
		# Need an id for display:
		# * is a success: take it
		# * is not, take ending_id entry
		var ending_id = my_node.get_success()
		if ending_id == null:
			ending_id = my_node.get_ending_id()
		choice.set_ending_id(ending_id)
		
		# Text
		var ending_txt = BookData.get_success_txt(ending_id)
		if ending_txt == '':  # not a success
			ending_txt = my_node.get_ending_txt()
		choice.set_label(ending_txt)
		choice.set_ending_type(my_node.get_ending_type())
		
		choices.add_child(choice)


func jump_to_previous_chapter():
	var previous_id = Player.jump_to_previous_chapter()
	if previous_id == -1:
		return
		
	self.jump_back(previous_id)


# We are jumping back until we found the good chapter number
func jump_back(previous_id):
	var can_jump_back = Player.jump_back(previous_id)
	self.go_to_node(previous_id)
	

func change_spoils(b):
	AppParameters.set_spoils(b)
	self.refresh()


func change_sound(b):
	AppParameters.set_sound(b)
	self.refresh()


# When billy type is change in Player, refresh display and play sound
func billy_type_is_changed():
	var current_billy = AppParameters.get_billy_type()
	self.refresh()
	Sounder.play('billy-%s.mp3' % current_billy)
	

func _change_book_number(book_number):
	var did_change = AppParameters.set_book_number(book_number)
	if !did_change:
		return
	self._do_load_book_context()
	self._reload_all_player()
	self.refresh()


func _on_main_background_gui_input(event):
	#print('GUI EVENT: %s' % event)
	#var swiper = get_node("/root/Swiper")
	Swiper.compute_event(event)


func update_page_in_top_menus(current_page):
	for top_menu in self.top_menus:
		top_menu.set_page(current_page)	


func set_camera_to_pos(x):
	self.camera.position.x = x


func jump_to_chapter_1():
	self.jump_to_chapter_100aine(1)

func jump_to_chapter_100():
	self.jump_to_chapter_100aine(100)
	
func jump_to_chapter_200():
	self.jump_to_chapter_100aine(200)
	
func jump_to_chapter_300():
	self.jump_to_chapter_100aine(300)
	
func jump_to_chapter_400():
	self.jump_to_chapter_100aine(400)
	
func jump_to_chapter_500():
	self.jump_to_chapter_100aine(500)
	
func jump_to_chapter_600():
	self.jump_to_chapter_100aine(600)	
	

func _on_button_new_billy():
	self.launch_new_billy()
	
	
func launch_new_billy():
	Player.launch_new_billy()
	self.go_to_node(1)
	self.refresh()
	self.show_options()  # So the user can choose a new billy


func _on_button_bug():
	OS.shell_open("https://github.com/naparuba/fdcn/issues");


func _on_button_pressed_twitter():
	OS.shell_open("https://twitter.com/naparuba");


# Switch between options visible or not
func _on_option_btn_pressed():
	if !$Options.visible:
		self.show_options()
	else:
		self._on_options_validate_button_pressed()

func show_options():
	# Make the options tab on equipement
	self._options_show_equipement()
	
	# Currently options are in the main page
	Swiper.focus_to_main()
	$ItemPopups.visible = false  # hide the popups for click catch
	$Options.visible = true


func _on_options_validate_button_pressed():
	print('BUTTON: validate')
	self.refresh()
	$Options.visible = false
	$ItemPopups.visible = true  # so we can show new popups
	
	
func _create_popup_item(item_name):
	var popup = ItemPopup.instance()
	var item_data = BookData.get_item_data(item_name)
	popup.load_item_data(item_name, item_data)
	return popup
	
	
func popup_new_item(item_name):
	var popup = self._create_popup_item(item_name)
	popup.set_is_new(true)  # it's a gain
	$ItemPopups/ScrollContainer/ItemPopupsCont.add_child(popup)


func popup_remove_item(item_name):
	var popup = self._create_popup_item(item_name)
	popup.set_is_new(false)  # it's a loose
	$ItemPopups/ScrollContainer/ItemPopupsCont.add_child(popup)


func _on_dice_pressed():
	var res = Utils.roll_a_dice(1, 6)
	print('Dice roll %s' % res)
	$Combat/dice/sprite.texture = Utils.load_external_texture('res://images/dice/%s-b.svg' % res, null)
	


func __set_tab_not_selected(tab):
	var _style = tab.get('custom_styles/panel')
	_style.set_bg_color(Color('999999'))  # set to dark blue
	print('__set_tab_not_selected', tab)


func __set_tab_selected(tab):
	var _style = tab.get('custom_styles/panel')
	_style.set_bg_color(Color('e0e2e5'))  # set to light
	print('__set_tab_selected', tab)

##################### Options

# Change colors of the tab, and hide/show real divs
func _options_show_equipement():
	# In the options, we are showing the equipement tab, so hide
	# the stats one
	self.__set_tab_selected($Options/Header/TabEquipement)
	self.__set_tab_not_selected($Options/Header/TabStats)
	self.__set_tab_not_selected($Options/Header/TabSelectBook)
	
	# Now all is changed, we can display them
	$Options/Equipement.visible = true
	$Options/BookSelect.visible = false
	$Options/Stats.visible = false
	

func _options_show_stats():
	# In the options, we are showing the equipement tab, so hide
	# the stats one
	
	# Change the headers part
	self.__set_tab_not_selected($Options/Header/TabEquipement)
	#var tab_equipement = $Options/Header/TabEquipement
	#var _style = tab_equipement.get('custom_styles/panel')
	#_style.set_bg_color(Color('e0e2e5'))  # set to dark blue
	
	self.__set_tab_not_selected($Options/Header/TabSelectBook)
	#var tab_select_book = $Options/Header/TabSelectBook
	#_style = tab_select_book.get('custom_styles/panel')
	#_style.set_bg_color(Color('e0e2e5'))  # set to dark blue
	#var v_label = $Options/Header/TabEquipement/v
	#v_label.visible = false
	# Switch the color of the tab label
	#$Options/Header/TabEquipement/Label.set("custom_colors/font_color",Color('000000'))
	
	self.__set_tab_selected($Options/Header/TabStats)
	# And hide the other
	#var tab_stats = $Options/Header/TabStats
	#_style = tab_stats.get('custom_styles/panel')
	#_style.set_bg_color(Color('313b47'))  # set to light
	#v_label = $Options/Header/TabStats/v
	#v_label.visible = true
	#$Options/Header/TabStats/Label.set("custom_colors/font_color",Color('ffffff'))
	
	
	# Now all is changed, we can display them
	$Options/Equipement.visible = false
	$Options/BookSelect.visible = false
	$Options/Stats.visible = true
	


func _options_show_book_select():
	# In the options, light up book select, hide others
	
	self.__set_tab_not_selected($Options/Header/TabEquipement)
	# Hide equipement
	#var tab_equipement = $Options/Header/TabEquipement
	#var _style = tab_equipement.get('custom_styles/panel')
	#_style.set_bg_color(Color('e0e2e5'))  # set to dark blue
	
	self.__set_tab_selected($Options/Header/TabSelectBook)
	# Show select book
	#var tab_select_book = $Options/Header/TabSelectBook
	#_style = tab_select_book.get('custom_styles/panel')
	#_style.set_bg_color(Color('313b47'))  # set to dark blue

	self.__set_tab_not_selected($Options/Header/TabStats)
	#var tab_stats = $Options/Header/TabStats
	#_style = tab_stats.get('custom_styles/panel')
	#_style.set_bg_color(Color('e0e2e5'))  # set to dark blue
	
	
	# Now all is changed, we can display them
	$Options/Equipement.visible = false
	$Options/BookSelect.visible = true
	$Options/Stats.visible = false
	


func _on_button_show_equipement():
	print('_on_button_show_equipement')
	self._options_show_equipement()


func _on_button_show_book_select():
	print('_on_button_show_book_select')
	self._options_show_book_select()


func _on_button_show_stats():
	print('_on_button_show_stats')
	self._options_show_stats()


# The user ask to close the combat dialog
func _on_combat_validate_button_pressed():
	$Combat.visible = false


func _refresh_options_stats():
	$Options/Stats/PlayerPvValue.text = '%s' % Player.get_pv()
	
	$Options/Stats/PlayerEndValue.text = '%s' % Player.get_end()
	$Options/Stats/PlayerEndValueDetail.text = '(base:2, item/billy:%s' % Player.get_end_items() + ', chapitres:%s)' % Player.get_end_chapters()
	
	$Options/Stats/PlayerHabValue.text = '%s' % Player.get_hab()
	$Options/Stats/PlayerHabValueDetail.text = '(base:2, item/billy:%s' % Player.get_hab_items() + ', chapitres:%s)' % Player.get_hab_chapters()
	
	$Options/Stats/PlayerAdrValue.text = '%s' % Player.get_adr()
	$Options/Stats/PlayerAdrValueDetail.text = '(base:1, item/billy:%s' % Player.get_adr_items() + ', chapitres:%s)' % Player.get_adr_chapters()
	
	$Options/Stats/PlayerChaValue.text = ('%s' % Player.get_cha()) + ('/%s' % Player.get_chamax())
	$Options/Stats/PlayerChaValueDetail.text = '(base:3, item/billy:%s' % Player.get_chamax_items() + ', chapitres:%s)' % Player.get_chamax_chapters()
	
	$Options/Stats/PlayerCritValue.text = '%s' % Player.get_crit()
	$Options/Stats/PlayerCritValueDetail.text = '(item/billy:%s' % Player.get_crit_items() + ', chapitres:%s)' % Player.get_crit_chapters()
	
	$Options/Stats/PlayerDegValue.text = '%s' % Player.get_deg()
	$Options/Stats/PlayerDegValueDetail.text = '(item/billy:%s' % Player.get_deg_items() + ', chapitres:%s)' % Player.get_deg_chapters()
	
	$Options/Stats/PlayerArmValue.text = '%s' % Player.get_arm()
	$Options/Stats/PlayerArmValueDetail.text = '(item/billy:%s' % Player.get_arm_items() + ', chapitres:%s)' % Player.get_arm_chapters()


func _switch_to_book_fcdn():
	print('SWITCH TO FCDN BOOK')
	var sprite1 = $Options/BookSelect/BoolSelectFcdn/sprite
	sprite1.material.set_shader_param("grayscale", false)
	var sprite2 = $Options/BookSelect/BoolSelectCdsi/sprite
	sprite2.material.set_shader_param("grayscale", true)
	self._change_book_number(1)


func _switch_to_book_cdsi():
	print('SWITCH TO CDSI BOOK ')
	var sprite1 = $Options/BookSelect/BoolSelectFcdn/sprite
	sprite1.material.set_shader_param("grayscale", true)
	var sprite2 = $Options/BookSelect/BoolSelectCdsi/sprite
	sprite2.material.set_shader_param("grayscale", false)
	self._change_book_number(2)


func _on_morelore_button_pressed():
	OS.shell_open("https://saga-de-billy.fandom.com/fr/wiki/Wiki_Saga_de_Billy");


func _on_image_author_button_pressed():
	OS.shell_open("https://twitter.com/DrazielUnicorn");
