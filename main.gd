extends Node2D


var current_lines = []


onready var Bread = preload('res://bread.tscn')
onready var Choice = preload('res://ChapterChoice.tscn')
onready var EndingChoice = preload('res://EndingChoice.tscn')
onready var Success = preload('res://Success.tscn')

onready var gauge = $Background/GlobalCompletion/Gauge

onready var camera = $Camera

var current_page = 'main'

# The 4 top menus
var top_menus = []


	



func go_to_node(node_id):
	
	var is_new_node = Player.go_to_node(node_id)
		
	
	self.refresh()
	# We did change node, so important to see it
	Swiper.focus_to_main()
	
	# If we are in a special node, play sound
	self._play_node_sound()

	if is_new_node:
		self._check_new_success(Player.get_current_node_id())


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




# We can show a Choice if:
# * we are ok with spoils
# * we are NOT spoils but the node is NOT a secret, and not a secret jump
# * we are NOT spoils, the node IS a secret but we ALREADY see it
func is_node_id_freely_showable(node_id, secret_jumps):
	if AppParameters.are_spoils_ok():
		return true
	
	# spoils are not known
	var node = BookData.get_node(node_id)
	
	var is_in_secret_jump = node_id in secret_jumps
	
	# NOT a secret node, we can show without problem, but only
	# if it's not a secret jump
	if !node['computed']['secret'] and !is_in_secret_jump:
		return true
		
	# node is a secret (or in secret jumps), last hope is if we already see it in the past (not a spoil if already see ^^)
	if Player.did_all_times_seen(node_id):
		print('SPOILS: %s is a secret (or a secret jump) but already see it' % node_id)
		return true
	# ok, no hope for this one, hide it
	#print('SPOILS: %s is a secret and CANNOT see it' % node_id)
	return false





static func delete_children(node):
	for n in node.get_children():
		node.remove_child(n)
		n.queue_free()
		

func print_debug(s):
	$DEBUG.text = s


func _ready():
	#Load the main font file
	var dynamic_font = DynamicFont.new()
	dynamic_font.font_data = load('res://fonts/amon_font.tres')

	
	# Register to Swiper
	Swiper.register_main(self)

	# Register top_menus
	self.top_menus.append($Background/top_menu)
	self.top_menus.append($Chapitres/top_menu)
	self.top_menus.append($Succes/top_menu)
	self.top_menus.append($Lore/top_menu)
	self.top_menus.append($About/top_menu)
	
	for top_menu in self.top_menus:
		top_menu.register_main(self)
	
	
	# Load the nodes ids we did already visited in the past
	Player.do_load()
	
	# Create all chapters in the 2nd screen
	self.insert_all_chapters()
	# And success to the 3th
	self.insert_all_success()
	
	# Jump to node, and will show main page
	self.go_to_node(Player.get_current_node_id())
	
	# Play intro
	# NOTE: if the current node id have a sound, intro will supress it
	self._play_intro()
	



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
	delete_children(all_choices)
	
	var chapter_ids = BookData.get_all_nodes().keys()
	chapter_ids.sort_custom(self, '_sort_all_chapters')
	
	for chapter_id in chapter_ids:
		var chapter_data = BookData.get_node(chapter_id)
		
		var choice = Choice.instance()
		choice.set_main(self)
		choice.set_chapitre(chapter_data['computed']['id'])
		all_choices.add_child(choice)


func _update_all_chapters():
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	for choice in all_choices.get_children():
		var chapter_id = choice.get_chapter_id()
		var chapter_data = BookData.get_node(chapter_id)
		
		# Update if spoils need to be shown (or not), can depend if we already seen this node
		if BookData.is_node_id_freely_full_on_all_chapters(chapter_id):
			choice.set_spoil_enabled(true)
		else:  # only follow the parameter
			choice.set_spoil_enabled(false)
		# Session seen
		if Player.did_billy_seen(chapter_id):
			choice.set_session_seen()
		else:
			choice.set_session_not_seen()
		# All time seen
		if Player.did_all_times_seen(chapter_id):
			choice.set_already_seen()
		else:
			choice.set_not_already_seen()
		# Ending or not
		if chapter_data['computed']['ending']:
			choice.set_ending()
		else:
			choice.set_not_ending()
		# Success or not
		if chapter_data['computed']['success']:
			choice.set_success()
		else:
			choice.set_not_success()
		# label if any
		var _label = chapter_data['computed']['label']
		if _label != null:
			choice.set_label(_label)
		# secret
		if chapter_data['computed']['secret']:
			choice.set_secret()
			


		

func insert_all_success():
	var all_success = $Succes/Success/VScrollBar/Success
	delete_children(all_success)
	
	
	for success in BookData.get_all_success():
		var s = Success.instance()
		s.set_main(self)
		print('SUCCESS: %s' % str(success))
		s.set_chapitre(success['chapter'])
		s.set_label(success['label'])
		s.set_txt(success['txt'])
		s.set_success_id(success['id'])
		all_success.add_child(s)


func _update_all_success():
	var all_success = $Succes/Success/VScrollBar/Success
	for success in all_success.get_children():
		var chapter_id = success.get_chapter_id()
		var chapter_data = BookData.get_node(chapter_id)
		
		# Update if spoils need to be shown (or not), can depend if we already seen this node
		if BookData.is_node_id_freely_full_on_all_chapters(chapter_id):
			success.set_spoil_enabled(true)
		else:  # only follow the parameter
			success.set_spoil_enabled(false)
		# All time seen
		if Player.did_all_times_seen(chapter_id):
			success.set_already_seen()
		else:
			success.set_not_already_seen()


func _refresh_options():
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
	sprite_by_billy[type_billy_param].material.set_shader_param("grayscale", false)

	
func refresh():	
	
	# Update all options based on params
	self._refresh_options()
	
	# Update the top menu with parameters
	for top_menu in self.top_menus:
		top_menu.set_spoils()	
		top_menu.set_billy()
		
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
	_acte_label.text = '%s' % my_node['computed']['chapter']
	
	var pct100 = BookData.get_acte_completion(Player.get_current_node_id(), Player.get_visited_nodes_all_times())
	var fill_bar = $Background/Position/fill_bar
	fill_bar.value = pct100 # % of the acte	is done
	$Background/Position/fill_par_pct.text = '%3d%%' % pct100
	
	# The arc, if any
	var _arc = my_node['computed']['arc']
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
		_chapitre_label.text = '%s' % my_node['computed']['id']
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
		_chapitre_label.text = '%s' % my_node['computed']['id']
		_chapitre_label.visible = true
		$Background/Position/LabelChapitreBig.visible = true
		# Hide big one
		$Background/Position/LabelChapitreSmall.visible = false
		$Background/Position/NumeroChapitreSmall.visible = false
	
	
	var breads = $Background/Dreadcumb/breads
	delete_children(breads)
	
		
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
	var sons_ids = my_node['computed']['sons']
	# Maybe son sons are not secret, but the jump is
	var secret_jumps = my_node['computed']['secret_jumps']
	
	# Clean choices
	var choices = $Background/Next/ScrollContainer/Choices
	delete_children(choices)
	for son_id in sons_ids:
		#print('My son: %s' % son_id)
		
		# If the son is now ok to be shown, skip it
		if !self.is_node_id_freely_showable(son_id, secret_jumps):
			continue
		
		var son = BookData.get_node(son_id)
		
		var choice = Choice.instance()
		choice.set_main(self)
		#print('NODE: %s' % son)
		choice.set_chapitre(son['computed']['id'])
		# Update if spoils need to be shown (or not), can depend if we already seen this node
		if BookData.is_node_id_freely_full_on_all_chapters(son_id):
			choice.set_spoil_enabled(true)
		else:  # only follow the parameter
			choice.set_spoil_enabled(false)
		
		if son['computed']['is_combat']:
			choice.set_combat()
		if Player.did_billy_seen(son_id):
			choice.set_session_seen()
		if Player.did_all_times_seen(son_id):
			choice.set_already_seen()
		if son['computed']['ending']:
			choice.set_ending()
		if son['computed']['success']:
			choice.set_success()
		if son['computed']['secret']:
			choice.set_secret()
		if son['computed']['label']:
			choice.set_label(son['computed']['label'])
			
		# Check special jump/conditions
		var jump_condition_txt = BookData.get_condition_txt(Player.get_current_node_id(), son_id)
		choice.set_condition_txt(jump_condition_txt)
		var is_special = BookData.match_chapter_conditions(Player.get_current_node_id(), son_id)
		if is_special:
			choice.enable_special_jump()
		else:
			choice.disable_special_jump()
		
		choices.add_child(choice)
				
	# Maybe we are an ending, then stack a EndingChoice with data
	if my_node['computed']['ending']:
		var choice = EndingChoice.instance()
		choice.set_main(self)
		print('IS AN END')
		# Need an id for display:
		# * is a success: take it
		# * is not, take ending_id entry
		var ending_id = my_node['computed']['success']
		if ending_id == null:
			ending_id = my_node['computed']['ending_id']
		choice.set_ending_id(ending_id)
		
		# Text
		var ending_txt = BookData.get_success_txt(ending_id)
		if ending_txt == '':  # not a success
			ending_txt = my_node['computed']['ending_txt']
		choice.set_label(ending_txt)
		choice.set_ending_type(my_node['computed']['ending_type'])
		
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


func set_billy(billy_type):
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
	# We did change node, so important to see it
	Swiper.focus_to_main()


func _on_button_bug():
	OS.shell_open("https://github.com/naparuba/fdcn/issues");


func _on_button_pressed_twitter():
	OS.shell_open("https://twitter.com/naparuba");


func show_options():
	# Currently options are in the main page
	Swiper.focus_to_main()
	$Options.visible = true


func _on_options_validate_button_pressed():
	print('BUTTON: validate')
	$Options.visible = false
