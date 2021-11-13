extends Node

var _main = null
var need_force_display_options = false   # if we did guess, show options to show it
var type_billy = 'guerrier'

var current_node_id = 1

var all_matched_conditions = []
var session_visited_nodes = []
var visited_nodes_all_times = []

var possessed_items = []

var all_items = []

# Give something like C:\Users\j.gabes\AppData\Roaming\Godot\app_userdata\fdcn for windows
var ALL_TIMES_ALREADY_VISITED_FILE = "user://all_times_already_visited.save"
var CURRENT_NODE_ID_FILE = "user://current_node_id.save"
var SESSION_VISITED_NODES_FILE  = "user://session_visited_nodes.save"
var POSSESSED_ITEM_FILE  = "user://possessed_item.save"


func load_all_times_already_visited():
	var f = File.new()
	if f.file_exists(ALL_TIMES_ALREADY_VISITED_FILE):
		f.open(ALL_TIMES_ALREADY_VISITED_FILE, File.READ)
		self.visited_nodes_all_times = f.get_var()
		f.close()
	else:
		self.visited_nodes_all_times = []
	# Seems that the chapter 1 is not stack at the beging of the play, so add it
	# to be sure we have it
	if !(1 in self.visited_nodes_all_times):
		self.visited_nodes_all_times.append(1)


func save_all_times_already_visited():
	var f = File.new()
	f.open(ALL_TIMES_ALREADY_VISITED_FILE, File.WRITE)
	f.store_var(visited_nodes_all_times)
	f.close()


func load_current_node_id():
	var f = File.new()
	if f.file_exists(CURRENT_NODE_ID_FILE):
		f.open(CURRENT_NODE_ID_FILE, File.READ)
		current_node_id = f.get_var()
		f.close()
	else:
		current_node_id = 1


func save_current_node_id():
	var f = File.new()
	f.open(CURRENT_NODE_ID_FILE, File.WRITE)
	f.store_var(current_node_id)
	f.close()


func load_session_visited_nodes():
	var f = File.new()
	if f.file_exists(SESSION_VISITED_NODES_FILE):
		f.open(SESSION_VISITED_NODES_FILE, File.READ)
		session_visited_nodes = f.get_var()
		f.close()
	else:
		session_visited_nodes = []


func save_session_visited_nodes():
	var f = File.new()
	f.open(SESSION_VISITED_NODES_FILE, File.WRITE)
	f.store_var(session_visited_nodes)
	f.close()


func load_possessed_items():
	var f = File.new()
	if f.file_exists(POSSESSED_ITEM_FILE):
		f.open(POSSESSED_ITEM_FILE, File.READ)
		self.possessed_items = f.get_var()
		f.close()
	else:
		self.guess_after_migration()


func save_possessed_items():
	print('ON NE SAVE PAS LES OBJETS')
	return
	var f = File.new()
	f.open(POSSESSED_ITEM_FILE, File.WRITE)
	f.store_var(self.possessed_items)
	f.close()


func guess_after_migration():
	need_force_display_options = true  # force the options to be shown so we warn the user
	print('GUESS AFTER MIGRATION:')
	# Objects
	# First time we are here, we look at all
	for chapter_id in self.session_visited_nodes:
		print('Playing item chapt in %s' % chapter_id)
		self.apply_chapter_items(chapter_id)
	return
	# Then guess objects, guess what the dude did set
	var billy_type = AppParameters.get_billy_type()
	var guess = {
		'guerrier': ['EPEE', 'LANCE','MARMITE'],
		'prudent': ['KIT DE SOIN', 'COTTE DE MAILLES','MARMITE'],
		'paysan': ['COUTEAU', "KIT D'ESCALADE",'SAC DE GRAINS'],
		'debrouillard': ['EPEE', 'COTTE DE MAILLES','COUTEAU'],
	}
	for item_name in guess[billy_type]:
		print('GUESS: %s' % item_name)
		self._raw_add(item_name)


func do_load():
	self.load_all_times_already_visited()
	self.load_current_node_id()
	self.load_session_visited_nodes()
	self.load_possessed_items()
	self._recompute_matched_conditions()
	return self.need_force_display_options


func register_main(main):
	self._main = main


func add_in_all_items(item):
	self.all_items.append(item)
	

func have_previous_chapters():
	return len(self.session_visited_nodes) > 1


func go_to_node(node_id):
	self.current_node_id = node_id
	self.save_current_node_id()
	
	# Update session, but maybe it's just a app reload
	if len(self.session_visited_nodes) == 0 or self.session_visited_nodes[len(self.session_visited_nodes) -1] != node_id:
		self.session_visited_nodes.append(self.current_node_id)
		self.save_session_visited_nodes()
	#else:
	#	print('Already on the visited session update: %s' % str(self.session_visited_nodes))
	#print('Visited session: %s' % str(self.session_visited_nodes))
	
	# Update id if not already visited
	var is_new_node = !(self.current_node_id in visited_nodes_all_times)
	if is_new_node:
		self.visited_nodes_all_times.append(self.current_node_id)
		self.save_all_times_already_visited()
	
	return is_new_node


func jump_to_previous_chapter():
	print('Jumping to previous chapter: %s' % str(self.session_visited_nodes))
	if len(self.session_visited_nodes) <= 1:
		print('jump_back::CANNOT GO BACK')
		return -1
	var current_id = self.session_visited_nodes[-1]  # DON'T DROP IT HERE
	var previous_id = self.session_visited_nodes[-2]  # DON'T DROP IT HERE
	print('Previous chapter: %s =>' % current_id, '%s' % previous_id)
	return previous_id



# We are jumping back until we found the good chapter number
func jump_back(previous_id):
	print('jump_back::Jumping back to %s' % previous_id)
	print('jump_back::SESSION visited nodes: %s' % str(self.session_visited_nodes))
	if len(self.session_visited_nodes) == 1:
		print('jump_back::CANNOT GO BACK')
		return false
		
	while true:
		if len(self.session_visited_nodes) == 0:
			print('jump_back::CRITICAL: cannot find the jump back node %s' % previous_id)
			return false
		var ptn_id = self.session_visited_nodes.pop_back()  # drop as we did stack it
		print('jump_back::BACK: Look at %s' % ptn_id, ' asked %s' % previous_id)
		if ptn_id == previous_id:
			print('jump_back::BACK: geck back at %s' % previous_id)
			return true


func launch_new_billy():
	self.session_visited_nodes = []
	self.save_session_visited_nodes()



func did_billy_seen(chapter_id):
	return chapter_id in self.session_visited_nodes


func did_all_times_seen(chapter_id):
	return chapter_id in self.visited_nodes_all_times


func get_last_5_previous_visited_nodes():
	var nb_previous = len(self.session_visited_nodes)
	
	var last_previous = self.session_visited_nodes
	if len(self.session_visited_nodes) > 5:
		last_previous = self.session_visited_nodes.slice(nb_previous - 5, nb_previous)
	return last_previous


func get_current_node_id():
	return self.current_node_id


func get_nb_all_time_seen():
	return len(self.visited_nodes_all_times)


func get_visited_nodes_all_times():
	return self.visited_nodes_all_times


func apply_chapter_items(chapter_id):
	var node = BookData.get_node(chapter_id)
	# Apply new items
	var aquires = node.get_aquire()
	for aquire in aquires:
		self.add_item_from_chapter(aquire, chapter_id)
		#if !aquire in possessed_items:
		#	print('%s +' % chapter_id, '%s' % aquire)
		#	self.possessed_items.append(aquire)
	# Then remove items
	var removes = node.get_remove()
	for remove in removes:
		self.remove_item_from_chapter(remove, chapter_id)
	print('ETAT: %s' % chapter_id, self.possessed_items)


func _recompute_matched_conditions():
	self.all_matched_conditions = []
	for item_name in self.possessed_items:
		self.all_matched_conditions.append(item_name)
	self.all_matched_conditions.append(AppParameters.get_billy_type().to_upper())


func get_all_matched_conditions():
	return self.all_matched_conditions
	

func have_item(item_name):
	return item_name in self.possessed_items


func add_item_from_chapter(item_name, from_chapter):
	if !item_name in possessed_items:
		print('%s +' % from_chapter, '%s' % item_name)
		self._raw_add(item_name)
		self._recompute_matched_conditions()
		self.save_possessed_items()


func add_item_from_options(item_name):
	if !item_name in possessed_items:
		print('OPTIONS +%s' % item_name)
		self._raw_add(item_name)
		self.compute_my_billy_for_option(item_name)
		self.save_possessed_items()
		self._recompute_matched_conditions()
		self._main.refresh()  # we need to update all items and the billy
		

func _raw_add(item_name):
	print('** raw add BEFORE: %s' % item_name, ' => %s ' % str(self.possessed_items))
	self.possessed_items.append(item_name)
	print('** raw add AFTER: %s' % item_name, ' => %s ' % str(self.possessed_items))
	

func remove_item_from_chapter(item_name, from_chapter):
	if item_name in possessed_items:
		print('%s -' % from_chapter, '%s' % item_name)
		self._raw_remove(item_name)
		self._recompute_matched_conditions()
		self.save_possessed_items()


func remove_item_from_options(item_name):
	if item_name in possessed_items:
		print('OPTIONS -%s' % item_name)
		self._raw_remove(item_name)
		self.compute_my_billy_for_option(item_name)
		self.save_possessed_items()
		self._recompute_matched_conditions()
		self._main.refresh()  # we need to update all items and the billy


func _raw_remove(item_name):
	print('** raw remove BEFORE: %s' % item_name, ' => %s' % str(self.possessed_items))
	self.possessed_items.erase(item_name)
	print('** raw remove AFTER: %s' % item_name, ' => %s' % str(self.possessed_items))
	


func _compute_item_by_categories():
	var items_by_category = {'ARME': [], 'EQUIPEMENT':[], 'OUTIL':[]}
	for item in self.all_items:
		var item_name = item.get_name()
		if !item_name in self.possessed_items:#.is_enabled():
			continue
		var cat = item.get_category()
		if !cat in items_by_category:  # Not interesting cat
			continue
		items_by_category[cat].append(item)
	return items_by_category


func compute_my_billy():
	self.compute_my_billy_for_option('')



func billy_overload_size():
	var items_by_category = self._compute_item_by_categories()
	#print('COMPUTE MY BILLY: %s' % items_by_category)
	var nb_armes = len(items_by_category['ARME'])
	var nb_equipements = len(items_by_category['EQUIPEMENT'])
	var nb_outils = len(items_by_category['OUTIL'])
	
	# Rules:
	# * Can take 3 max
	# * if >= 2 in a cat => is this CAT
	# * if one in each: is DEBROUILLARD
	# * if match none of this: is a PEGU ^^
	var nb_objs = nb_armes + nb_equipements + nb_outils
	var nb_to_remove = nb_objs - 3
	var nb_remove = 0
	var to_remove = ''
	# Clean if too much
	return max(0, nb_objs -3)


func clean_billy_overload(new_option):
	var categories = ['ARME', 'EQUIPEMENT', 'OUTIL']
	
	var billy_overload = self.billy_overload_size()
	if billy_overload == 0:
		print('Billy is NOT overload')
		return
		
	print('BILLY IS OVERLOAD BY %s item' % billy_overload)
	var items_by_category = self._compute_item_by_categories()
	var all_billy_equip = []
	
	print('  - ITEM IN CAT: %s' % items_by_category)
	for cat in categories:
		for i in items_by_category[cat]:
			all_billy_equip.append(i.get_name())
	# Rules:
	# * Can take 3 max
	# * if >= 2 in a cat => is this CAT
	# * if one in each: is DEBROUILLARD
	# * if match none of this: is a PEGU ^^
	var nb_removed = 0
	
	while nb_removed < billy_overload:
		for item_name in all_billy_equip:
			if item_name != new_option:
				print('OVERLOAD: removing %s' % item_name)
				self._raw_remove(item_name)
				nb_removed += 1
				break


# We just did an option change, so if we need to remove one, not this one ^^
func compute_my_billy_for_option(new_option):
	print('compute_my_billy: start: %s' % str(self.possessed_items))
	var categories = ['ARME', 'EQUIPEMENT', 'OUTIL']
	
	self.clean_billy_overload(new_option)
	
	# Now find the billy
	var items_by_category = self._compute_item_by_categories()
	var nb_armes = len(items_by_category['ARME'])
	var nb_equipements = len(items_by_category['EQUIPEMENT'])
	var nb_outils = len(items_by_category['OUTIL'])
	
	if nb_armes + nb_equipements + nb_outils < 3:
		print('IS A PEGU')
		self._main._switch_to_pegu()
		return
		
	# Detect billy type
	if nb_armes >= 2:
		print('=> IS A GUERRIER')
		self._main._switch_to_guerrier()
	elif nb_equipements >= 2:
		print('=> IS A PRUDENT')
		self._main._switch_to_prudent()
	elif nb_outils >= 2:
		print('=> IS A PAYSAN')
		self._main._switch_to_paysan()
	elif nb_armes == 1 && nb_equipements == 1 && nb_outils == 1:
		print('IS DEBROUILLARD')
		self._main._switch_to_debrouillard()
	else:
		print('IS A PEGU')
		self._main._switch_to_pegu()
	print('compute_my_billy: end: %s' % str(self.possessed_items))
		
