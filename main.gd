extends Node2D

var current_node_id = 1
var all_nodes = {}
var chapters_by_arc = {}
var chapters_by_sub_arc = {}

var secret_node_ids = []

var all_success = []

var session_visited_nodes = []

var visited_nodes_all_times = []

var current_lines = []

var parameters = {
	'billy': 'guerrier',
	'spoils': true,
}

onready var Bread = preload('res://bread.tscn')
onready var Choice = preload('res://ChapterChoice.tscn')
onready var Success = preload('res://Success.tscn')

onready var gauge = $Background/GlobalCompletion/Gauge

onready var camera = $Camera

var current_page = 'main'

# The 4 top menus
var top_menus = []


# Give something like C:\Users\j.gabes\AppData\Roaming\Godot\app_userdata\fdcn for windows
var all_times_already_visited_file = "user://all_times_already_visited.save"
var current_node_id_file = "user://current_node_id.save"
var session_visited_nodes_file  = "user://session_visited_nodes.save"
var parameters_file  = "user://parameters.save"


func load_all_times_already_visited():
	var f = File.new()
	if f.file_exists(all_times_already_visited_file):
		f.open(all_times_already_visited_file, File.READ)
		visited_nodes_all_times = f.get_var()
		f.close()
	else:
		visited_nodes_all_times = []

func save_all_times_already_visited():
	var f = File.new()
	f.open(all_times_already_visited_file, File.WRITE)
	print('SAVING in file: %s' % f)
	f.store_var(visited_nodes_all_times)
	f.close()


func load_current_node_id():
	var f = File.new()
	if f.file_exists(current_node_id_file):
		f.open(current_node_id_file, File.READ)
		current_node_id = f.get_var()
		f.close()
	else:
		current_node_id = 1

func save_current_node_id():
	var f = File.new()
	f.open(current_node_id_file, File.WRITE)
	print('SAVING in file: %s' % f)
	f.store_var(current_node_id)
	f.close()


func load_session_visited_nodes():
	var f = File.new()
	if f.file_exists(session_visited_nodes_file):
		f.open(session_visited_nodes_file, File.READ)
		session_visited_nodes = f.get_var()
		f.close()
	else:
		session_visited_nodes = []

func save_session_visited_nodes():
	var f = File.new()
	f.open(session_visited_nodes_file, File.WRITE)
	print('SAVING in file: %s' % f)
	f.store_var(session_visited_nodes)
	f.close()
	

func load_parameters():
	var f = File.new()
	if f.file_exists(parameters_file):
		f.open(parameters_file, File.READ)
		var loaded_parameters = f.get_var()
		f.close()
		# NOTE: so we can manage code with new parameters
		for k in loaded_parameters.keys():
			var v = loaded_parameters[k]
			print('PARAM: %s=>' % k, v)
			parameters[k] = v
	else:
		# already created in globals
		pass

func save_parameters():
	var f = File.new()
	f.open(parameters_file, File.WRITE)
	f.store_var(parameters)
	f.close()


func load_json_file(path):
	"""Loads a JSON file from the given res path and return the loaded JSON object."""
	var file = File.new()
	file.open(path, file.READ)
	var text = file.get_as_text()
	var result_json = JSON.parse(text)
	if result_json.error != OK:
		print("[load_json_file] Error loading JSON file '" + str(path) + "'.")
		print("\tError: ", result_json.error)
		print("\tError Line: ", result_json.error_line)
		print("\tError String: ", result_json.error_string)
		return null
	var obj = result_json.result
	return obj


func go_to_node(node_id):
	self.current_node_id = node_id
	self.save_current_node_id()
	
	# Update session, but maybe it's just a app reload
	if len(self.session_visited_nodes) == 0 or self.session_visited_nodes[len(self.session_visited_nodes) -1] != node_id:
		self.session_visited_nodes.append(self.current_node_id)
		self.save_session_visited_nodes()
	else:
		print('Already on the visited session update: %s' % str(self.session_visited_nodes))
	print('Visited session: %s' % str(self.session_visited_nodes))
	
	# Update id if not already visited
	if !(self.current_node_id in visited_nodes_all_times):
		self.visited_nodes_all_times.append(self.current_node_id)
		self.save_all_times_already_visited()
		
	print('SESSION visited nodes: %s' % str(self.session_visited_nodes))
	print('ALL TIMES visited nodes: %s' % str(self.visited_nodes_all_times))
	
	self.refresh()
	# We did change node, so important to see it
	self.focus_to_main()
	
	# If we are in a special node, play sound
	self._play_node_sound()


func _play_intro():
	var player = $AudioPlayer
	# In all cases, stop the player
	player.stop()
	var sound = load('res://sounds/intro.mp3')
	player.stream = sound
	player.play()


func _play_node_sound():
	var player = $AudioPlayer
	# In all cases, stop the player
	player.stop()
	
	print('Trying load sound for %s' % self.current_node_id)
	var node_sound_fnames = {
		193: '193-la-cathedrale.mp3',
		216: '216-tour-des-mages.mp3',
		338: '338-virilus-backstory.mp3'
	}
	var fname = node_sound_fnames.get(int(self.current_node_id))
	if fname == null:  # no sound this node
		print('No sound for %s' % self.current_node_id)
		return

	var full_path = 'res://sounds/%s' % fname
	print('SOUND: full path=%s' % full_path)
	var sound = load(full_path)
	print('%s is load '% sound, 'for ', self.current_node_id)
	
	player.stream = sound
	player.play()

func _get_node(node_id):
	return self.all_nodes['%s' % node_id]


func is_node_id_secret(node_id):
	return node_id in self.secret_node_ids


func are_spoils_ok():
	return self.parameters['spoils']


# We can show a Choice if:
# * we are ok with spoils
# * we are NOT spoils but the node is NOT a secret
# * we are NOT spoils, the node IS a secret but we ALREADY see it
func is_node_id_freely_showable(node_id):
	if self.are_spoils_ok():
		return true
	# spoils are not known
	var node = self._get_node(node_id)
	# NOt a secret node, we can show without problem
	if !node['computed']['secret']:
		return true
	# node is a secret, last hope is if we already see it in the past (not a spoil if already see ^^)
	if node_id in self.visited_nodes_all_times:
		print('SPOILS: %s is a secret but alrady see it' % node_id)
		return true
	# ok, no hope for this one, hide it
	#print('SPOILS: %s is a secret and CANNOT see it' % node_id)
	return false


# on the all chapters, the "is not a secret" is not a criteria, as we don't want to see this
func is_node_id_freely_full_on_all_chapters(node_id):
	if self.are_spoils_ok():
			return true
	# spoils are not known
	var node = self._get_node(node_id)
	# node is a secret, last hope is if we already see it in the past (not a spoil if already see ^^)
	if node_id in self.visited_nodes_all_times:
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
	
	self.all_nodes = load_json_file("res://fdcn-1-compilated-data.json")
	
	# Just the list of int of the secret chapters
	self.secret_node_ids = load_json_file("res://fdcn-1-compilated-secrets.json")
	
	# Just a dict arc -> [ chapters ]
	self.chapters_by_arc = load_json_file("res://fdcn-1-compilated-nodes-by-chapter.json")
	
	# Just a dict sub_arc -> [ chapters ]
	self.chapters_by_sub_arc = load_json_file("res://fdcn-1-compilated-nodes-by-sub-arc.json")
	
	# All the success, in a list {id, chapter, txt}
	self.all_success = load_json_file("res://fdcn-1-compilated-success.json")
	
	# Load the nodes ids we did already visited in the past
	self.load_all_times_already_visited()
	self.load_current_node_id()
	self.load_session_visited_nodes()
	self.load_parameters()
	
	# Create all chapters in the 2nd screen
	self.insert_all_chapters()
	# And success to the 3th
	self.insert_all_success()
	
	# Jump to node, and will show main page
	self.go_to_node(self.current_node_id)
	
	# Play intro
	# NOTE: if the current node id have a sound, intro will supress it
	self._play_intro()
	

func _get_all_nodes_in_the_same_sub_arc(node_id):
	var chapter_data = self._get_node(node_id)
	var sub_arc = chapter_data["computed"]["arc"]
	if sub_arc == null:
		return []
	var other_nodes = self.chapters_by_sub_arc[sub_arc]
	print('CHAPTER: in the same SUB ARC: %s' % str(other_nodes))
	return other_nodes


func _get_sub_arc_completion(node_id):
	var other_nodes = self._get_all_nodes_in_the_same_sub_arc(node_id)
	if other_nodes == []:  # void chatper, let's say 100%
		return 100
	var nb_visited = 0
	for other_id in other_nodes:
		if other_id in self.visited_nodes_all_times:
			nb_visited += 1
	var pct100 = int(100 * float(nb_visited) / len(other_nodes))
	print('Total visited sub arc: %s / ' % nb_visited, len(other_nodes), '=', pct100)
	return pct100


func _get_all_nodes_in_the_same_chapter(node_id):
	var chapter_data = self._get_node(node_id)
	var chapter = chapter_data["computed"]["chapter"]
	if chapter == null:
		return []
	var other_nodes = self.chapters_by_arc[chapter]
	print('CHAPTER: in the same ACTE: %s' % str(other_nodes))
	return other_nodes


func _get_acte_completion(node_id):
	var other_nodes = self._get_all_nodes_in_the_same_chapter(node_id)
	if other_nodes == []:  # void chatper, let's say 100%
		return 100
	var nb_visited = 0
	for other_id in other_nodes:
		if other_id in self.visited_nodes_all_times:
			nb_visited += 1
	var pct100 = int(100 * float(nb_visited) / len(other_nodes))
	print('Total visited: %s / ' % nb_visited, len(other_nodes), '=', pct100)
	return pct100


func jump_to_chapter_100aine(centaine):
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	var scroll_bar = $Chapitres/AllChapters/VScrollBar
	print('Searching chapter: %s' % centaine)
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
	
	var chapter_ids = self.all_nodes.keys()
	chapter_ids.sort_custom(self, '_sort_all_chapters')
	
	for chapter_id in chapter_ids:
		var chapter_data = self._get_node(chapter_id)
		
		var choice = Choice.instance()
		choice.set_main(self)
		choice.set_chapitre(chapter_data['computed']['id'])
		all_choices.add_child(choice)


func _update_all_chapters():
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	for choice in all_choices.get_children():
		var chapter_id = choice.get_chapter_id()
		var chapter_data = self._get_node(chapter_id)
		
		# Update if spoils need to be shown (or not), can depend if we already seen this node
		if self.is_node_id_freely_full_on_all_chapters(chapter_id):
			choice.set_spoil_enabled(true)
		else:  # only follow the parameter
			choice.set_spoil_enabled(false)
		# Session seen
		if chapter_id in self.session_visited_nodes:
			choice.set_session_seen()
		else:
			choice.set_session_not_seen()
		# All time seen
		if chapter_id in self.visited_nodes_all_times:
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
	
	var successes = self.all_success
	
	for success in successes:
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
		var chapter_data = self._get_node(chapter_id)
		
		# Update if spoils need to be shown (or not), can depend if we already seen this node
		if self.is_node_id_freely_full_on_all_chapters(chapter_id):
			success.set_spoil_enabled(true)
		else:  # only follow the parameter
			success.set_spoil_enabled(false)
		# All time seen
		if chapter_id in self.visited_nodes_all_times:
			success.set_already_seen()
		else:
			success.set_not_already_seen()
	
	
func refresh():
	
	# Update the parameters
	for top_menu in self.top_menus:
		top_menu.set_spoils(self.parameters['spoils'])	
		top_menu.set_billy(self.parameters['billy'])
		
	# Note: the first left backer should be disabled if we cannot get back
	if self.have_previous_chapters():
		$"Background/Left-Back".set_enabled()
	else:
		$"Background/Left-Back".set_disabled()
	
	
	# Page2: update all chapters
	self._update_all_chapters()
	
	# Page 3: update success with spoils
	self._update_all_success()
	
	# Update the % completion
	var _nb_all_nodes = len(self.all_nodes)
	var _nb_visited = len(self.visited_nodes_all_times)

	var completion_foot_note = $Background/GlobalCompletion/footnode
	completion_foot_note.text = (' %d /' % _nb_visited) + (' %d' % _nb_all_nodes)
	
	gauge.set_value(_nb_visited / float(_nb_all_nodes))
	
	# Now print my current node
	var my_node = self._get_node(self.current_node_id)
	
	# The act in progress
	var _acte_label = $Background/Position/Acte
	_acte_label.text = '%s' % my_node['computed']['chapter']
	
	var pct100 = self._get_acte_completion(self.current_node_id)
	var fill_bar = $Background/Position/fill_bar
	fill_bar.value = pct100 # % of the acte	is done
	$Background/Position/fill_par_pct.text = '%3d%%' % pct100
	
	# The arc, if any
	var _arc = my_node['computed']['arc']
	if _arc != null:
		# Compute how much of the sub_arc we have done
		var pct100_sub_arc = self._get_sub_arc_completion(self.current_node_id)
		
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
	
	
	#Breads
	var breads = $Background/Dreadcumb/breads
	delete_children(breads)
	var nb_previous = len(self.session_visited_nodes)
	#print('ORIGINAL prevs: %s' % str(self.session_visited_nodes))
	
	var last_previous = self.session_visited_nodes
	if len(self.session_visited_nodes) > 5:
		last_previous = self.session_visited_nodes.slice(nb_previous - 5, nb_previous)
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
	
	# Clean choices
	var choices = $Background/Next/Choices
	delete_children(choices)
	for son_id in sons_ids:
		print('My son: %s' % son_id)
		
		# If the son is now ok to be shown, skip it
		if !self.is_node_id_freely_showable(son_id):
			continue
		
		var son = self._get_node(son_id)
		
		var choice = Choice.instance()
		choice.set_main(self)
		print('NODE: %s' % son)
		choice.set_chapitre(son['computed']['id'])
		# Update if spoils need to be shown (or not), can depend if we already seen this node
		if self.is_node_id_freely_full_on_all_chapters(son_id):
			choice.set_spoil_enabled(true)
		else:  # only follow the parameter
			choice.set_spoil_enabled(false)
		#choice.set_spoil_enabled(self.parameters['spoils'])
		if son['computed']['is_combat']:
			choice.set_combat()
		if son_id in self.session_visited_nodes:
			choice.set_session_seen()
		if son_id in self.visited_nodes_all_times:
			choice.set_already_seen()
		if son['computed']['ending']:
			choice.set_ending()
		if son['computed']['success']:
			choice.set_success()
		if son['computed']['secret']:
			choice.set_secret()
		choices.add_child(choice)
				

func have_previous_chapters():
	return len(self.session_visited_nodes) > 1

func jump_to_previous_chapter():
	print('Jumping to previous chapter: %s' % str(self.session_visited_nodes))
	if len(self.session_visited_nodes) <= 1:
		print('jump_back::CANNOT GO BACK')
		return
	var current_id = self.session_visited_nodes[-1]  # DON'T DROP IT HERE
	var previous_id = self.session_visited_nodes[-2]  # DON'T DROP IT HERE
	print('Previous chapter: %s =>' % current_id, '%s' % previous_id)
	self.jump_back(previous_id)


# We are jumping back until we found the good chapter number
func jump_back(previous_id):
	print('jump_back::Jumping back to %s' % previous_id)
	print('jump_back::SESSION visited nodes: %s' % str(self.session_visited_nodes))
	if len(self.session_visited_nodes) == 1:
		print('jump_back::CANNOT GO BACK')
		return
		
	while true:
		if len(self.session_visited_nodes) == 0:
			print('jump_back::CRITICAL: cannot find the jump back node %s' % previous_id)
			return
		var ptn_id = self.session_visited_nodes.pop_back()  # drop as we did stack it
		print('jump_back::BACK: Look at %s' % ptn_id, ' asked %s' % previous_id)
		if ptn_id == previous_id:
			print('jump_back::BACK: geck back at %s' % previous_id)
			break
	
	self.go_to_node(previous_id)
	

func change_spoils(b):
	print('Mode SPOIL ou pas: %s' % b)
	self.parameters['spoils'] = b
	self.save_parameters()
	self.refresh()




func _switch_to_guerrier():
	self.parameters['billy'] = 'guerrier'
	self.save_parameters()
	self.refresh()
	self._play_sound('billy-guerrier.mp3')


func _switch_to_paysan():
	self.parameters['billy'] = 'paysan'
	self.save_parameters()
	self.refresh()
	self._play_sound('billy-paysan.mp3')


func _switch_to_prudent():
	self.parameters['billy'] = 'prudent'
	self.save_parameters()
	self.refresh()
	self._play_sound('billy-prudent.mp3')


func _switch_to_debrouillard():
	self.parameters['billy'] = 'debrouillard'
	self.save_parameters()
	self.refresh()
	self._play_sound('billy-debrouillard.mp3')


func _play_sound(pth):
	var player = $AudioPlayer
	player.stop()
	var full_pth = 'res://sounds/%s' % pth
	var sound = load(full_pth)
	player.stream = sound
	player.play()


func _on_main_background_gui_input(event):
	#print('GUI EVENT: %s' % event)
	#var swiper = get_node("/root/Swiper")
	Swiper.compute_event(event)


func go_to_page(dest):
	if dest == 'BACK':
		self.jump_to_previous_chapter()
	elif dest == 'main':
		self.focus_to_main()
	elif dest == 'chapitres':
		self.focus_to_chapitres()
	elif dest == 'success':
		self.focus_to_success()
	elif dest == 'lore':
		self.focus_to_lore()
	elif dest == 'about':
		self.focus_to_about()
	else:
		print('ERROR: no such dest: %s' % dest)


func _update_page_in_top_menus():
	for top_menu in self.top_menus:
		top_menu.set_page(self.current_page)	


func focus_to_main():
	print('=> main')
	self.camera.position.x = 278
	self.current_page = 'main'
	self._update_page_in_top_menus()
	
	
func focus_to_chapitres():
	print('=> chapitres')
	self.camera.position.x = 876
	self.current_page = 'chapitres'
	self._update_page_in_top_menus()
	
	
func focus_to_success():
	print('=> success')
	self.camera.position.x = 1471
	self.current_page = 'success'
	self._update_page_in_top_menus()


func focus_to_lore():
	print('=> lore')
	self.camera.position.x = 2058
	self.current_page = 'lore'
	self._update_page_in_top_menus()


func focus_to_about():
	print('=> about')
	self.camera.position.x = 2648
	self.current_page = 'about'
	self._update_page_in_top_menus()
	

func swipe_to_left():
	print('Going to left, from page: %s' % self.current_page)
	if self.current_page == 'main':
		self.jump_to_previous_chapter()
		return
	elif self.current_page == 'chapitres':
		print('Going back to main')
		self.focus_to_main()
	elif self.current_page == 'success':
		self.focus_to_chapitres()
	elif self.current_page == 'lore':
		self.focus_to_success()
	elif self.current_page == 'about':
		self.focus_to_lore()
	else:
		print('ERROR: unknown page: %s' % self.current_page)
	
func swipe_to_right():
	print('Going to right, from page: %s' % self.current_page)
	if self.current_page == 'main':
		self.focus_to_chapitres()
	elif self.current_page == 'chapitres':
		self.focus_to_success()
	elif self.current_page == 'success':
		self.focus_to_lore()
	elif self.current_page == 'lore':
		self.focus_to_about()
	elif self.current_page == 'about':
		print('Last page')
	else:
		print('ERROR: unknown page: %s' % self.current_page)


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
	self.session_visited_nodes = []
	self.save_session_visited_nodes()
	self.go_to_node(1)
	self.refresh()
	# We did change node, so important to see it
	self.focus_to_main()


func _on_button_bug():
	OS.shell_open("https://github.com/naparuba/fdcn/issues");


func _on_button_pressed_twitter():
	OS.shell_open("https://twitter.com/naparuba");
