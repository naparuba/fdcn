extends Node

var chapter_data_cls = preload('res://chapter_data.gd')

var all_nodes = {}
var chapters_by_arc = {}
var chapters_by_sub_arc = {}

var secret_node_ids = []

var all_success = []
var all_success_chapters = {} # chapter id -> success id
var all_endings = []
var good_endings = []
var end_endings = []
var all_objects = {}


func _init():
	# Load chapter data in chapter_data class
	var all_nodes_json = Utils.load_json_file("res://fdcn-1-compilated-data.json")
	for node_id_str in all_nodes_json.keys():
		var chapter_data = chapter_data_cls.new()
		chapter_data.create(all_nodes_json[node_id_str])
		self.all_nodes[node_id_str] = chapter_data
	
	# Just the list of int of the secret chapters
	self.secret_node_ids = Utils.load_json_file("res://fdcn-1-compilated-secrets.json")
	
	# Just a dict arc -> [ chapters ]
	self.chapters_by_arc = Utils.load_json_file("res://fdcn-1-compilated-nodes-by-chapter.json")
	
	# Just a dict sub_arc -> [ chapters ]
	self.chapters_by_sub_arc = Utils.load_json_file("res://fdcn-1-compilated-nodes-by-sub-arc.json")
	
	# All the success, in a list {id, chapter, txt}
	self.all_success = Utils.load_json_file("res://fdcn-1-compilated-success.json")
	# All the success chapters id in a list
	self.all_success_chapters = Utils.load_json_file("res://fdcn-1-compilated-success-chapters.json")
	
	# Endings: want all, good and bad
	self.all_endings = Utils.load_json_file("res://fdcn-1-compilated-endings.json")
	self.good_endings = Utils.load_json_file("res://fdcn-1-compilated-good-endings.json")
	self.end_endings = Utils.load_json_file("res://fdcn-1-compilated-bad-endings.json")

	# Objects, so we can insert them in the options
	self.all_objects = Utils.load_json_file("res://fdcn-1-compilated-all-objects.json")
	

# Called when the node enters the scene tree for the first time.
func get_all_nodes():
	return self.all_nodes


func get_all_objects():
	return self.all_objects


func get_item_data(item_name):
	return self.all_objects[item_name]

func get_all_success():
	return self.all_success

func get_node(node_id):
	return self.all_nodes['%s' % node_id]
	

func get_all_nodes_in_the_same_chapter(node_id):
	var chapter_data = self.get_node(node_id)
	var chapter = chapter_data.get_chapter()
	if chapter == null:
		return []
	var other_nodes = self.chapters_by_arc[chapter]
	return other_nodes


func get_acte_completion(node_id, visited_nodes_all_times):
	var other_nodes = self.get_all_nodes_in_the_same_chapter(node_id)
	if other_nodes == []:  # void chatper, let's say 100%
		return 100
	var nb_visited = 0
	for other_id in other_nodes:
		if other_id in visited_nodes_all_times:
			nb_visited += 1
	var pct100 = int(100 * float(nb_visited) / len(other_nodes))
	return pct100



func get_all_nodes_in_the_same_sub_arc(node_id):
	var chapter_data = self.get_node(node_id)
	var sub_arc = chapter_data.get_arc()
	if sub_arc == null:
		return []
	var other_nodes = self.chapters_by_sub_arc[sub_arc]
	return other_nodes


func get_sub_arc_completion(node_id, visited_nodes_all_times):
	var other_nodes = self.get_all_nodes_in_the_same_sub_arc(node_id)
	if other_nodes == []:  # void chatper, let's say 100%
		return 100
	var nb_visited = 0
	for other_id in other_nodes:
		if other_id in visited_nodes_all_times:
			nb_visited += 1
	var pct100 = int(100 * float(nb_visited) / len(other_nodes))
	return pct100


func is_node_id_secret(node_id):
	return node_id in self.secret_node_ids


func get_success_txt(success_id):
	for success in self.all_success:
		if success_id == success['id']:
			return success['txt']
	return ''


func is_success_chapter(node_id):
	# WARNING: the all_success_chapters is with str keys, not INT (thanks json)
	var node_id_str = '%d' % node_id
	return node_id_str in self.all_success_chapters


func get_success_from_chapter(node_id):
	# WARNING: the all_success_chapters is with str keys, not INT (thanks json)
	var node_id_str = '%d' % node_id
	var success_id = self.all_success_chapters[node_id_str]

	for success in self.get_all_success():
		if success['id'] == success_id:
			return success
	return null

func have_chapter_conditions(node_from_id, node_to_id):
	var chapter_data = self.get_node(node_from_id)
	var node_to_id_str = '%s' % node_to_id
	var all_jump_conditions = chapter_data.get_jump_conditions()
	var jump_condition = all_jump_conditions.get(node_to_id_str)
	if jump_condition == null:
		return false
	return true
	

func match_chapter_conditions(node_from_id, node_to_id):
	var chapter_data = self.get_node(node_from_id)
	var node_to_id_str = '%s' % node_to_id
	var all_jump_conditions = chapter_data.get_jump_conditions()
	var jump_condition = all_jump_conditions.get(node_to_id_str)
	if jump_condition == null:
		return false
	var r = self._check_cond_rec(jump_condition, Player.get_all_matched_conditions())#[AppParameters.get_billy_type().to_upper()])
	return r


func _check_cond_rec(jump_condition, facts):
	var r = false
	var end = jump_condition.get('$end')
	if end != null:
		#print('FIND $end= %s', end, '<=> facts=%s' % facts)
		r = end in facts
		return r
	# Ors
	var ors = jump_condition.get('$or')
	if ors != null:
		for sub_condition in ors:
			#print('OR: sub condition: %s' % sub_condition)
			r = self._check_cond_rec(sub_condition, facts)
			if r:
				#print('OR: sub condition is true STOP: %s' % sub_condition)
				return true
		return false
	
	# Ands
	var ands = jump_condition.get('$and')
	if ands != null:
		for sub_condition in ands:
			#print('AND: sub condition: %s' % sub_condition)
			r = self._check_cond_rec(sub_condition, facts)
			if !r:
				#print('AND: sub condition is wrong STOP: %s' % sub_condition)
				return false
		return true
 

func get_condition_txt(node_from_id, node_to_id):
	var chapter_data = self.get_node(node_from_id)
	var node_to_id_str = '%s' % node_to_id
	var all_txts = chapter_data.get_jump_conditions_txts()
	var txt = all_txts.get(node_to_id_str)
	if txt == null:
		return ''
	return txt
	

# on the all chapters, the "is not a secret" is not a criteria, as we don't want to see this
# and also secret jumps is not useful here (not link to a specific src jump node)
func is_node_id_freely_full_on_all_chapters(node_id):
	if AppParameters.are_spoils_ok():
			return true
	# spoils are not known
	var node = self.get_node(node_id)
	# node is a secret, last hope is if we already see it in the past (not a spoil if already see ^^)
	if Player.did_all_times_seen(node_id):
		return true
	# ok, no hope for this one, hide it
	#print('SPOILS: %s is a secret and CANNOT see it' % node_id)
	return false


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
	if !node.get_secret() and !is_in_secret_jump:
		return true
		
	# node is a secret (or in secret jumps), last hope is if we already see it in the past (not a spoil if already see ^^)
	if Player.did_all_times_seen(node_id):
		print('SPOILS: %s is a secret (or a secret jump) but already see it' % node_id)
		return true
	# ok, no hope for this one, hide it
	#print('SPOILS: %s is a secret and CANNOT see it' % node_id)
	return false



