extends Control

var father = null

var node = {'id':''}

onready var my_button = $MarginContainer/my_button

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func _init():
	print('LINE INIT')
	print('MY BUTTON: %s' % self.my_button)
	pass


func _ready():
	var my_button = $MarginContainer/my_button	
	
func set_node(node_):
	var _my_button = $MarginContainer/my_button	
	print('BUTTON: %s' % my_button)
	print('Give us a node_: %s' % node_)
	self.node = node_
	print('Creating a go to for node %s' % self.node['computed']['id'])
	_my_button.text = "=> %3d" % self.node['computed']['id']


func set_father(father_):
	self.father = father_



func _on_Button_pressed():
	print('2 CLICK onto node: %s' % self.node)
	if self.father != null:
		self.father.go_to_node(self.node['computed']['id'])

