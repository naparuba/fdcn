extends Node

onready var Item = preload('res://Item.tscn')

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
var OLD_ALL_TIMES_ALREADY_VISITED_FILE = "user://all_times_already_visited.save"
var OLD_CURRENT_NODE_ID_FILE = "user://current_node_id.save"
var OLD_SESSION_VISITED_NODES_FILE  = "user://session_visited_nodes.save"
var OLD_POSSESSED_ITEM_FILE  = "user://possessed_item.save"

# Our stats, based on items or chapters
var end = 0
var adr = 0
var hab = 0
var chamax = 0
var deg = 0
var arm = 0
var crit = 0


# Set by items
var end_items = 0
var adr_items = 0
var hab_items = 0
var chamax_items = 0
var deg_items = 0
var arm_items = 0
var crit_items = 0


# Set by chapters recompute at startup
var end_chapters = 0
var adr_chapters = 0
var hab_chapters = 0
var chamax_chapters = 0
var deg_chapters = 0
var arm_chapters = 0
var crit_chapters = 0
var pv_max_bonus = 0
var nb_infos = 0

# Set by user for debug or cheat, save on change
var end_user = 0
var adr_user = 0
var hab_user = 0
var cha_user = 0
var deg_user = 0
var arm_user = 0
var crit_user = 0


# Winable on levels
var gloire = 0
var richesse = 0

# Dynamic
var pv_max = 0
var pv = 0
var cha = 0


# Be sure to migrate old files from before managing numerous books
func _assert_migrate_file(old_path, new_path):
	var directory = Directory.new()
	var f = File.new()
	if !f.file_exists(old_path):
		return
	# Oups, migration needed!
	print('Migrating ', old_path, 'to', new_path)
	directory.rename(old_path, new_path)
		

func _get_all_times_already_visited_file():
	var book_number = AppParameters.get_book_number()
	var pth = "user://all_times_already_visited-%s.save" % book_number
	return pth


func load_all_times_already_visited():
	var pth = self._get_all_times_already_visited_file()
	self._assert_migrate_file(OLD_ALL_TIMES_ALREADY_VISITED_FILE, pth)
	var f = File.new()
	if f.file_exists(pth):
		print('load_all_times_already_visited:: loading file %s' % pth)
		f.open(pth, File.READ)
		self.visited_nodes_all_times = f.get_var()
		f.close()
	else:
		self.visited_nodes_all_times = []
	# Seems that the chapter 1 is not stack at the beging of the play, so add it
	# to be sure we have it
	if !(1 in self.visited_nodes_all_times):
		self.visited_nodes_all_times.append(1)


func save_all_times_already_visited():
	var pth = self._get_all_times_already_visited_file()
	var f = File.new()
	f.open(pth, File.WRITE)
	f.store_var(visited_nodes_all_times)
	f.close()


############### CURRENT NODE ID
func _get_current_node_id_file():
	var book_number = AppParameters.get_book_number()
	var pth = "user://current_node_id-%s.save" % book_number
	return pth

func load_current_node_id():
	var f = File.new()
	var pth = self._get_current_node_id_file()
	self._assert_migrate_file(OLD_CURRENT_NODE_ID_FILE, pth)
	if f.file_exists(pth):
		f.open(pth, File.READ)
		current_node_id = f.get_var()
		f.close()
	else:
		current_node_id = 1


func save_current_node_id():
	var pth = self._get_current_node_id_file()
	var f = File.new()
	f.open(pth, File.WRITE)
	f.store_var(current_node_id)
	f.close()


############### SESSION_VISITED_NODES
func _get_session_visited_nodes_file():
	var book_number = AppParameters.get_book_number()
	var pth = "user://session_visited_nodes-%s.save" % book_number
	return pth
	
func load_session_visited_nodes():
	var pth = self._get_session_visited_nodes_file()
	self._assert_migrate_file(OLD_SESSION_VISITED_NODES_FILE, pth)
	var f = File.new()
	if f.file_exists(pth):
		f.open(pth, File.READ)
		session_visited_nodes = f.get_var()
		f.close()
	else:
		session_visited_nodes = []


func save_session_visited_nodes():
	var pth = self._get_session_visited_nodes_file()
	var f = File.new()
	f.open(pth, File.WRITE)
	f.store_var(session_visited_nodes)
	f.close()


############### POSSESSED_ITEM_FILE
func _get_possessed_items_file():
	var book_number = AppParameters.get_book_number()
	var pth = "user://possessed_item-%s.save" % book_number
	return pth
	
	
func load_possessed_items():
	var pth = self._get_possessed_items_file()
	self._assert_migrate_file(OLD_POSSESSED_ITEM_FILE, pth)
	var f = File.new()
	if f.file_exists(pth):
		f.open(pth, File.READ)
		self.possessed_items = f.get_var()
		f.close()
	else:
		self.guess_after_migration()


func save_possessed_items():
	var pth = self._get_possessed_items_file()
	var f = File.new()
	f.open(pth, File.WRITE)
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


# At startup we are redoing ALL our chapters and we grok stats from it
func _redo_all_my_chapters_stats():
	print('redo_all_my_chapters_stats:')
	# Objects
	# First time we are here, we look at all
	for chapter_id in self.session_visited_nodes:
		print('Playing chapt  stats in %s' % chapter_id)
		self.apply_one_chapter_stats(chapter_id)
	

func do_load():
	self.load_all_times_already_visited()
	self.load_current_node_id()
	self.load_session_visited_nodes()
	self.load_possessed_items()
	# at startup redo all our chapters so we can get our stats from chapter up to date, even if chapters data are updated
	self._redo_all_my_chapters_stats()
	self._recompute_matched_conditions()
	self._recompute_stats()
	return self.need_force_display_options


func insert_all_objects():
	print('Insert all objects')
	self.all_items = []  # Always reset the list
	var all_objects = BookData.get_all_objects()
	for obj_name in all_objects.keys():
		var item_data = all_objects[obj_name]
		var item = Item.instance()
		item.load_item_data(obj_name, item_data)
		var is_ok_to_be_shown = item.is_ok_to_be_shown()
		if is_ok_to_be_shown:
			# Also let the Player know it does exists
			#print('KNOWN ITEM: %s' % item)
			self.add_in_all_items(item)
	if self._main:  # not in tests
		self._main.display_all_objects()


func register_main(main):
	self._main = main


func add_in_all_items(item):
	self.all_items.append(item)
	

func have_previous_chapters():
	return len(self.session_visited_nodes) > 1


func go_to_node(node_id):
	self.current_node_id = node_id
	self.save_current_node_id()
	
	print('LOOK FOR NEW BILLY CHAPTER: %s' % self.current_node_id)
	print('LOOK FOR NEW BILLY CHAPTER: %s' % str(self.session_visited_nodes))
	var is_new_node_for_this_billy = !(self.current_node_id in self.session_visited_nodes)
	print('LOOK FOR NEW BILLY CHAPTER: %s' % is_new_node_for_this_billy)
	
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
	
	var aquires_and_removes = self.apply_chapter_items(node_id)
	var aquires = aquires_and_removes[0]
	var removes = aquires_and_removes[1]
	
	# If the billy enter here for the first time, apply the stats
	if is_new_node_for_this_billy:
		print('%s is a NEW chapter for this billy, updating its stats' % node_id)
		self.apply_one_chapter_stats(node_id)
	else:
		print('%s is a ALREADY VIEW chapter for this billy, NOT updating its stats' % node_id)
	
	return [is_new_node, aquires, removes]


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
	self.possessed_items = []
	self.save_possessed_items()



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
	var _really_aquires = []  # Mayve we already have some items
	var aquires = node.get_aquire()
	for aquire in aquires:
		var did_add = self.add_item_from_chapter(aquire, chapter_id)
		if did_add:
			_really_aquires.append(aquire)
	# Then remove items
	var _really_removes = []  # Mayve we already not have some items
	var removes = node.get_remove()
	for remove in removes:
		var did_remove = self.remove_item_from_chapter(remove, chapter_id)
		if did_remove:
			_really_removes.append(remove)
	print('ETAT: %s' % chapter_id, self.possessed_items)
	return [_really_aquires, _really_removes]


func _recompute_matched_conditions():
	self.all_matched_conditions = []
	for item_name in self.possessed_items:
		self.all_matched_conditions.append(item_name)
	self.all_matched_conditions.append(AppParameters.get_billy_type().to_upper())


# We reset stats on a raw billy one
func _reset_our_stats():
	self.end = 2
	self.adr = 1
	self.hab = 2
	self.chamax = 3
	self.deg = 0
	self.arm = 0
	self.crit = 0
	
	# Also item ones
	self.end_items = 0
	self.adr_items = 0
	self.hab_items = 0
	self.chamax_items = 0
	self.deg_items = 0
	self.arm_items = 0
	self.crit_items = 0


func get_end():
	return self.end
func get_adr():
	return self.adr
func get_hab():
	return self.hab
func get_cha():
	return self.cha
func get_chamax():
	return self.chamax
func get_deg():
	return self.deg
func get_arm():
	return self.arm
func get_crit():
	return self.crit
func get_pv():
	return self.pv
# For chapters
func get_end_chapters():
	return self.end_chapters
func get_adr_chapters():
	return self.adr_chapters
func get_hab_chapters():
	return self.hab_chapters
func get_chamax_chapters():
	return self.chamax_chapters
func get_deg_chapters():
	return self.deg_chapters
func get_arm_chapters():
	return self.arm_chapters
func get_crit_chapters():
	return self.crit_chapters
# For items
func get_end_items():
	return self.end_items
func get_adr_items():
	return self.adr_items
func get_hab_items():
	return self.hab_items
func get_chamax_items():
	return self.chamax_items
func get_deg_items():
	return self.deg_items
func get_arm_items():
	return self.arm_items
func get_crit_items():
	return self.crit_items


# Based on our billy, we have different stats changes
func _apply_billy_stats():
	var billy_type = AppParameters.get_billy_type()
	if billy_type == 'guerrier':
		self.hab += 2
		self.hab_items += 2
		self.chamax -= 1
		self.chamax_items -= 1
		self.deg += 1
		self.deg_items += 1
	elif billy_type == 'prudent':
		self.hab -= 1
		self.hab_items -= 1
		self.chamax += 2
		self.chamax_items += 2
	elif billy_type == 'paysan':
		self.adr -= 1
		self.adr_items -= 1
		self.end += 2
		self.end_items += 2
	elif billy_type == 'debrouillard':
		self.adr += 2
		self.adr_items += 2
		self.end -= 1
		self.end_items -= 1
	elif billy_type == 'pegu':
		pass
	else:
		print('ERROR: the billy type: %s is unknown' % billy_type)
		

# Compute our stats based on our objects and billy
func _recompute_stats():
	self._reset_our_stats()
	
	self._apply_billy_stats()
	
	for item_name in self.possessed_items:
		var item_data = BookData.get_item_data(item_name)
		var stats = item_data['stats']
		for k in stats.keys():
			var v = stats[k]
			if k == 'end':
				self.end += v
				self.end_items += v
			elif k == 'hab':
				self.hab += v
				self.hab_items += v
			elif k == 'adr':
				self.adr += v
				self.adr_items += v
			elif k == 'cha':
				self.chamax += v
				self.chamax_items += v
			elif k == 'deg':
				self.deg += v
				self.deg_items += v
			elif k == 'arm':
				self.arm += v
				self.arm_items += v
			elif k == 'crit':
				self.crit += v
				self.crit_items += v
			else:
				print('ERROR: STATS INCONNUE DANS OBJET: %s' % k)
				
		print('Item:%s' % item_name, 'stats: %s' % item_data)
	print('Billy stats by objects: end=%s' % self.end, ' hab=%s' % self.hab, ' adr=%s'%self.adr, ' chamax=%s' % self.chamax,
	' deg=%s' % self.deg,' arm=%s' % self.arm, ' crit=%s'%self.crit)
	
	self._apply_all_chapters_stats()
	print('Billy stats after chapter update: end=%s' % self.end, ' hab=%s' % self.hab, ' adr=%s'%self.adr, ' chamax=%s' % self.chamax,
	' deg=%s' % self.deg,' arm=%s' % self.arm, ' crit=%s'%self.crit)
	
	
func _apply_all_chapters_stats():
	# Now we have the stats from our items, we can apply the ones from the past chapters
	self.end += self.end_chapters
	self.adr += self.adr_chapters
	self.hab += self.hab_chapters
	self.chamax += self.chamax_chapters
	self.deg += self.deg_chapters
	self.arm += self.arm_chapters
	self.crit += self.crit_chapters
	# Now we can compute pv max based on end + pv_max_bonus
	self.pv_max = self.end * 3 + self.pv_max_bonus
	
	

func get_all_matched_conditions():
	return self.all_matched_conditions
	

func have_item(item_name):
	return item_name in self.possessed_items


func add_item_from_chapter(item_name, from_chapter):
	if !item_name in possessed_items:
		print('%s +' % from_chapter, '%s' % item_name)
		self._raw_add(item_name)
		self._recompute_matched_conditions()
		self._recompute_stats()
		self.save_possessed_items()
		return true
	return false


func add_item_from_options(item_name):
	if !item_name in possessed_items:
		print('OPTIONS +%s' % item_name)
		self._raw_add(item_name)
		self.compute_my_billy_for_option(item_name)
		self.save_possessed_items()
		self._recompute_matched_conditions()
		self._recompute_stats()
		if self._main:  # miss in test
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
		self._recompute_stats()
		self.save_possessed_items()
		return true
	return false


func remove_item_from_options(item_name):
	if item_name in possessed_items:
		print('OPTIONS -%s' % item_name)
		self._raw_remove(item_name)
		self.compute_my_billy_for_option(item_name)
		self.save_possessed_items()
		self._recompute_matched_conditions()
		self._recompute_stats()
		if self._main:  # miss in test
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
	self._recompute_stats()



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


func _switch_to_billy(billy_type):
	var current_billy = AppParameters.get_billy_type()
	if current_billy == billy_type:  # no need to warn
		return
	AppParameters.set_billy_type(billy_type)
	if self._main:  # miss in test
		self._main.billy_type_is_changed()
	


#func switch_to_guerrier():
#	if self._main:  # miss in test
#		self._main._switch_to_guerrier()
	
#func switch_to_prudent():
#	if self._main:  # miss in test	
#		self._main._switch_to_prudent()

#func switch_to_paysan():
#	if self._main:  # miss in test
#		self._main._switch_to_paysan()

#func switch_to_debrouillard():
#	if self._main:  # miss in test
#		self._main._switch_to_debrouillard()

#func switch_to_pegu():
#	if self._main:  # miss in test	
#		self._main._switch_to_pegu()
	

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
		self._switch_to_billy('pegu')
		return
		
	# Detect billy type
	if nb_armes >= 2:
		print('=> IS A GUERRIER')
		self._switch_to_billy('guerrier')
	elif nb_equipements >= 2:
		print('=> IS A PRUDENT')
		self._switch_to_billy('prudent')
	elif nb_outils >= 2:
		print('=> IS A PAYSAN')
		self._switch_to_billy('paysan')
	elif nb_armes == 1 && nb_equipements == 1 && nb_outils == 1:
		print('IS DEBROUILLARD')
		self._switch_to_billy('debrouillard')
	else:
		print('IS A PEGU')
		self._switch_to_billy('pegu')
	print('compute_my_billy: end: %s' % str(self.possessed_items))
		

func _apply_chapter_stat(k, v):
	print('Apply chapter stats: %s' % k, ' => %s'%v)
	### HELP: y en a 20
	if k == '1_4_pv_max':
		print('_apply_chapter_stat:: %s IS NOT CURRENTLY MANAGED :( )' % k)
	elif k == 'adr':
		self.adr_chapters += v
	elif k == 'arc_et_couteau':
		print('_apply_chapter_stat:: %s IS NOT CURRENTLY MANAGED :( )' % k)
	elif k == 'arm':
		self.arm_chapters += v
	elif k == 'chance':
		#TODO: need to cap this
		self.cha += v
	elif k == 'chance_max':  # real integer
		self.chamax_chapters += v
	elif k == 'crit':
		self.crit_chapters += v
	elif k == 'deg':
		self.deg_chapters += v
	elif k == 'end':
		self.end_chapters += v
	elif k == 'gloire':
		self.gloire += v
	elif k == 'hab':
		self.hab_chapters += v
	elif k == 'half_pv':
		self.pv /= 2
	elif k == 'info':
		self.nb_infos += v
	elif k == 'max_chance':  # bool, means: set cha to max
		self.cha = self.chamax
	elif k == 'max_pv':  # means: set my pv to max
		self.pv = self.pv_max
	elif k == 'pv':
		# TODO: need to cap min/max this!
		self.pv += v
	elif k == 'pv_1_4_max':
		print('_apply_chapter_stat:: %s IS NOT CURRENTLY MANAGED :( )' % k)
	elif k == 'pv_max':
		self.pv_max_bonus += v
	elif k == 'pv_win_plus_1':
		print('_apply_chapter_stat:: %s IS NOT CURRENTLY MANAGED :( )' % k)
	elif k == 'richesse':
		self.richesse += v
	else:
		print('THE STATS KEY %s is NOT managed ' % k)

# A new chapter was reach, so apply the stats
func apply_one_chapter_stats(node_id):
	print('apply_one_chapter_stats:: for node: %s' % node_id)
	var all_stats = BookData.get_chapter_stats(node_id)
	var stats = all_stats['stats']
	var stats_conds = all_stats['stats_conds']
	for k in stats.keys():
		var v = stats[k]
		self._apply_chapter_stat(k, v)
	
	for stats_cond in stats_conds:
		for k in stats_cond.keys():
			var v = stats_cond[k]
			self._apply_chapter_stat(k, v)
			
	print('Now we can rcompute all our stats')
	self._recompute_stats()
	
