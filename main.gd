extends Node2D

var current_node_id = 1
var all_nodes = {}

var secret_node_ids = []

var session_visited_nodes = []

var visited_nodes_all_times = []

var current_lines = []

var parameters = {
	'billy': 'guerrier',
	'spoils': true,
}

onready var Bread = preload('res://bread.tscn')
onready var Choice = preload('res://ChapterChoice.tscn')

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
	print('SPOILS: %s is a secret and CANNOT see it' % node_id)
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
	
	self.secret_node_ids = load_json_file("res://fdcn-1-compilated-secrets.json")
	
	# Load the nodes ids we did already visited in the past
	self.load_all_times_already_visited()
	self.load_current_node_id()
	self.load_session_visited_nodes()
	self.load_parameters()
	
	# Create all chapters in the 2nd screen
	self.insert_all_chapters()
	
	# Jump to node, and will show main page
	self.go_to_node(self.current_node_id)
	

func jump_to_chapter_100aine(centaine):
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	var scroll_bar = $Chapitres/AllChapters/VScrollBar
	print('Searching chapter: %s' % centaine)
	# Get chapter until we find the good one
	for choice in all_choices.get_children():
		var chapter_id = choice.get_chapter_id()
		if chapter_id == centaine:
			print('found chapter: %s ' % chapter_id, '%s' % choice)
			print('Jump to :%s' % choice.rect_position.y)
			scroll_bar.scroll_vertical = choice.rect_position.y


func insert_all_chapters():
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	delete_children(all_choices)
	for chapter_id in self.all_nodes:
		print('Creating chapter: %s' % chapter_id)
		
		var chapter_data = self._get_node(chapter_id)
		
		var choice = Choice.instance()
		choice.set_main(self)
		choice.set_chapitre(chapter_data['computed']['id'])
		#choice.set_spoil_enabled(self.parameters['spoils'])
		#if chapter_data['computed']['is_combat']:
		#	choice.set_combat()
		#if chapter_id in self.session_visited_nodes:
		#	choice.set_session_seen()
		#if chapter_id in self.visited_nodes_all_times:
		#	choice.set_already_seen()
		#if chapter_data['computed']['ending']:
		#	choice.set_ending()
		#if chapter_data['computed']['success']:
		#	choice.set_success()
		all_choices.add_child(choice)


func _update_all_chapters():
	var all_choices = $Chapitres/AllChapters/VScrollBar/Choices
	for choice in all_choices.get_children():
		var chapter_id = choice.get_chapter_id()
		var chapter_data = self._get_node(chapter_id)
		# Update if spoils need to be shown (or not)
		choice.set_spoil_enabled(self.parameters['spoils'])
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
	
	var fill_bar = $Background/Position/fill_bar
	fill_bar.value = 40  # 40% of the act is done
	
	# The number
	var _chapitre_label = $Background/Position/NumeroChapitre
	_chapitre_label.text = '%s' % my_node['computed']['id']
	
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
		
		# If the son is a secret, mayve we can show it, maybe not
		if !self.is_node_id_freely_showable(son_id):
			continue
		
		var son = self._get_node(son_id)
		
		var choice = Choice.instance()
		choice.set_main(self)
		print('NODE: %s' % son)
		choice.set_chapitre(son['computed']['id'])
		choice.set_spoil_enabled(self.parameters['spoils'])
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


func _switch_to_paysan():
	self.parameters['billy'] = 'paysan'
	self.save_parameters()
	self.refresh()

func _switch_to_prudent():
	self.parameters['billy'] = 'prudent'
	self.save_parameters()
	self.refresh()

func _switch_to_debrouillard():
	self.parameters['billy'] = 'debrouillard'
	self.save_parameters()
	self.refresh()



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
	
