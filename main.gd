extends Node2D


var current_lines = []


onready var Bread = preload('res://bread.tscn')
onready var Choice = preload('res://ChapterChoice.tscn')
onready var EndingChoice = preload('res://EndingChoice.tscn')
onready var Success = preload('res://Success.tscn')
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
	var need_show_options_at_startup = Player.do_load()
	if need_show_options_at_startup:
		#$Options.visible = true
		self.show_options()
	
	# Create all chapters in the 2nd screen
	self.insert_all_chapters()
	# And success to the 3th
	self.insert_all_success()
	
	self.insert_all_objects()
	
	Player.compute_my_billy()
	
	# Jump to node, and will show main page
	self.go_to_node(Player.get_current_node_id())
	
	# Play intro
	# NOTE: if the current node id have a sound, intro will supress it
	self._play_intro()
	


func go_to_node(node_id):
	
	var go_to_node_return = Player.go_to_node(node_id)
	# => is_new_node, aquires, removes
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


# We are in a new node, check if it's a success.
# if it is one, display a cool success highlight ^^
func _check_new_success(node_id):
	if BookData.is_success_chapter(node_id):
		var success = BookData.get_success_from_chapter(node_id)
		# Update the success data
		var popup = $SuccessPopup
		popup.update_and_show(success)
	

func _play_intro():
	Sounder.play('intro.mp3')


func _play_node_sound():
	var player = $AudioPlayer
	# In all cases, stop the player
	player.stop()
	
	var node_sound_fnames = {
		27: '27-kakaka.mp3',
		193: '193-la-cathedrale.mp3',
		216: '216-tour-des-mages.mp3',
		338: '338-virilus-backstory.mp3'
	}
	var fname = node_sound_fnames.get(int(Player.get_current_node_id()))
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


func insert_all_objects():
	var item_stack = $Options/ItemsCont/Items
	Utils.delete_children(item_stack)
	print('Insert all objects')
	var all_objects = BookData.get_all_objects()
	for obj_name in all_objects.keys():
		var item_data = all_objects[obj_name]
		var item = Item.instance()
		item.load_item_data(obj_name, item_data)
		var is_ok_to_be_shown = item.is_ok_to_be_shown()
		if is_ok_to_be_shown:
			item_stack.add_child(item)
			# Also let the Player know it does exists
			Player.add_in_all_items(item)


func refresh_all_objects():
	var item_stack = $Options/ItemsCont/Items
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


func _update_all_success():
	var all_success = $Succes/Success/VScrollBar/Success
	for success in all_success.get_children():
		success.update()


func _refresh_options():
	self.refresh_all_objects()
	
	var type_billy_param = AppParameters.get_billy_type()
	var sprite_by_billy = {
		'guerrier':    $Options/BlockGuerrier/sprite,
		'paysan':      $Options/BlockPaysan/sprite,
		'prudent':     $Options/BlockPrudent/sprite,
		'debrouillard':$Options/BlockDebrouillard/sprite
	}
	
	# Gray ALL .material.set_shader_param("param_name", value)
	for billy in sprite_by_billy.keys():
		var sprite = sprite_by_billy[billy]
		sprite.material.set_shader_param("grayscale", true)
	# Colorize the selected one
	if type_billy_param != 'pegu':
		sprite_by_billy[type_billy_param].material.set_shader_param("grayscale", false)

	
func refresh():	
	
	# Update all options based on params
	self._refresh_options()
	
	# Update the top menu with parameters
	for top_menu in self.top_menus:
		top_menu.set_spoils()	
		top_menu.set_billy()
		top_menu.set_sound()
		
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
		print('IS AN END')
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


func set_billy(billy_type):
	var current_billy = AppParameters.get_billy_type()
	if current_billy == billy_type:  # no need to warn
		return
	AppParameters.set_billy_type(billy_type)
	self.refresh()
	Sounder.play('billy-%s.mp3' % billy_type)
	

func _switch_to_guerrier():
	self.set_billy('guerrier')


func _switch_to_paysan():
	self.set_billy('paysan')


func _switch_to_prudent():
	self.set_billy('prudent')


func _switch_to_debrouillard():
	self.set_billy('debrouillard')


func _switch_to_pegu():
	self.set_billy('pegu')


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


func show_options():
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
