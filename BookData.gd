extends Node


var all_nodes = {}
var chapters_by_arc = {}
var chapters_by_sub_arc = {}

var secret_node_ids = []

var all_success = []
var all_success_chapters = {} # chapter id -> success id
var all_endings = []
var good_endings = []
var end_endings = []


func _init():
	
	self.all_nodes = Utils.load_json_file("res://fdcn-1-compilated-data.json")
	
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


# Called when the node enters the scene tree for the first time.
func get_all_nodes():
	return self.all_nodes


func get_all_success():
	return self.all_success

func get_node(node_id):
	return self.all_nodes['%s' % node_id]
	

func get_all_nodes_in_the_same_chapter(node_id):
	var chapter_data = self.get_node(node_id)
	var chapter = chapter_data["computed"]["chapter"]
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
	var sub_arc = chapter_data["computed"]["arc"]
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
