extends Node


var type_billy = 'guerrier'

var current_node_id = 1


var session_visited_nodes = []
var visited_nodes_all_times = []


# Give something like C:\Users\j.gabes\AppData\Roaming\Godot\app_userdata\fdcn for windows
var ALL_TIMES_ALREADY_VISITED_FILE = "user://all_times_already_visited.save"
var CURRENT_NODE_ID_FILE = "user://current_node_id.save"
var SESSION_VISITED_NODES_FILE  = "user://session_visited_nodes.save"



func load_all_times_already_visited():
	var f = File.new()
	if f.file_exists(ALL_TIMES_ALREADY_VISITED_FILE):
		f.open(ALL_TIMES_ALREADY_VISITED_FILE, File.READ)
		visited_nodes_all_times = f.get_var()
		f.close()
	else:
		visited_nodes_all_times = []


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



func do_load():
	self.load_all_times_already_visited()
	self.load_current_node_id()
	self.load_session_visited_nodes()


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
