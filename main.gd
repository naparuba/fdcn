extends Node2D

var current_node_id = 2
var all_nodes = {}

var visited_nodes = []

var current_lines = []

onready var hbox_next_jumps = $MarginContainer/VBoxContainer/Progress

onready var Going_to_line = preload('res://going_to_line.tscn')



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
	self.visited_nodes.append(self.current_node_id)
	
	self.refresh()


func _get_node(node_id):
	return self.all_nodes['%s' % node_id]

	


func _ready():
	#Load the main font file
	var dynamic_font = DynamicFont.new()
	dynamic_font.font_data = load('res://fonts/amon_font.tres')
	
	self.all_nodes = load_json_file("res://fdcn-1-compilated-data.json")
	
	self.go_to_node(self.current_node_id)
	self.refresh()
	
	
func refresh():
	# First unload all current lines
	for line in self.current_lines:
		line.queue_free()
	self.current_lines = []
	
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
		
		self.current_lines.append(line)
		hbox_next_jumps.add_child(line)
		
