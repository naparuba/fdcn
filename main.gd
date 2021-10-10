extends Node2D

var current_node_id = 1
var all_nodes = {}

var session_visited_nodes = []

var visited_nodes_all_times = []

var current_lines = []

onready var hbox_next_jumps = $MarginContainer/VBoxContainer/HBoxContainer/Progress

onready var Going_to_line = preload('res://going_to_line.tscn')


# Give something like C:\Users\j.gabes\AppData\Roaming\Godot\app_userdata\fdcn for windows
var all_times_already_visited_file = "user://all_times_already_visited.save"
var current_node_id_file = "user://current_node_id.save"
var session_visited_nodes_file  = "user://session_visited_nodes.save"


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
	self.session_visited_nodes.append(self.current_node_id)
	self.save_session_visited_nodes()
	if !(self.current_node_id in visited_nodes_all_times):
		self.visited_nodes_all_times.append(self.current_node_id)
		self.save_all_times_already_visited()
		
	print('SESSION visited nodes: %s' % str(self.session_visited_nodes))
	print('ALL TIMES visited nodes: %s' % str(self.visited_nodes_all_times))
	
	self.refresh()


func _get_node(node_id):
	return self.all_nodes['%s' % node_id]

	


func _ready():
	#Load the main font file
	var dynamic_font = DynamicFont.new()
	dynamic_font.font_data = load('res://fonts/amon_font.tres')
	
	self.all_nodes = load_json_file("res://fdcn-1-compilated-data.json")
	
	# Load the nodes ids we did already visited in the past
	self.load_all_times_already_visited()
	self.load_current_node_id()
	self.load_session_visited_nodes()
	
	self.go_to_node(self.current_node_id)
	self.refresh()
	
	
func refresh():
	# First unload all current lines
	for line in self.current_lines:
		line.queue_free()
	self.current_lines = []
	
	# Refresh the back button
	var _back = $MarginContainer/VBoxContainer/HBoxContainer/back
	if len(self.session_visited_nodes) == 1:
		_back.text = '...'
	else:
		var prev_id = self.session_visited_nodes[len(self.session_visited_nodes) - 2]  # we already stack us
		_back.text = '<= oups (%s)' % prev_id
	
	print('Loaded object:', self.all_nodes['%s' % self.current_node_id])
	var my_node = self._get_node(self.current_node_id)
	
	var sons_ids = my_node['computed']['sons']
	for son_id in sons_ids:
		print('My son: %s' % son_id)
		
		var son = self._get_node(son_id)
		
		var line = Going_to_line.instance()
		print('LINE BUTTON: %s' % line.my_button)
		line.set_father(self)
		line.set_node(son)
		
		if son_id in self.session_visited_nodes:
			line.set_session_already_visited()
		if son_id in self.visited_nodes_all_times:
			line.set_all_times_already_visited()
		
		self.current_lines.append(line)
		hbox_next_jumps.add_child(line)
		


func _on_button_back_pressed():
	print('Boutton back')
	print('SESSION visited nodes: %s' % str(self.session_visited_nodes))
	if len(self.session_visited_nodes) == 1:
		print('CANNOT GO BACK')
		return
	var current_id = self.session_visited_nodes.pop_back()  # drop as we did stack it
	var previous_id = self.session_visited_nodes.pop_back()
	print('BACK: geck back at %s' % previous_id)
	self.go_to_node(previous_id)
	self.refresh()
	
	
