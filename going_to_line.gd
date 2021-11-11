extends Control

var father = null

var node = {'id':''}

onready var my_button = $MarginContainer/my_button

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func _init():
	#print('LINE INIT')
	#print('MY BUTTON: %s' % self.my_button)
	pass


func _ready():
	var my_button = $MarginContainer/my_button	
	
	
func set_node(node_):
	var _my_button = $MarginContainer/my_button	
	#print('BUTTON: %s' % my_button)
	#print('Give us a node_: %s' % node_)
	self.node = node_
	_my_button.text = "=> %3d" % self.node.get_id()
	
	# Look at icons now
	# Combats
	if self.node.is_combat():
		$MarginContainer/combat.visible = true
	
	# Show endings
	if self.node.get_ending() != false:
		$MarginContainer/end.visible = true
	


func set_father(father_):
	self.father = father_


func set_session_already_visited():
	print('SET LINE %s as session already visited' % self.node.get_id())

func set_all_times_already_visited():
	print('SET LINE %s as all times already visited' % self.node.get_id())
	var tick = $MarginContainer/already_visited
	tick.visible = true


func _on_Button_pressed():
	print('2 CLICK onto node: %s' % self.node)
	if self.father != null:
		self.father.go_to_node(self.node.get_id())

