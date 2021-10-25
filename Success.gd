extends Panel



onready var already_seen_polygon = $GetPolygon


var chap_number
var spoil_enabled = false
var main

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func set_main(main):
	self.main = main


func set_spoil_enabled(b):
	self.spoil_enabled = b
	$click.visible = self.spoil_enabled
	$NBChapitre.visible = self.spoil_enabled



func get_chapter_id():
	return self.chap_number


func set_success_id(success_id):
	var texture = Utils.load_external_texture("res://images/success/%s.png" % success_id, null)
	$sprite.texture = texture
	print('SPRITE LOADED: %s' % success_id)


func set_chapitre(chapitre):
	self.chap_number = chapitre
	$NBChapitre.text = '%3d' % chapitre
	
	
func set_label(label):
	$Label.text = label


func set_txt(txt):
	$Txt.text = txt

func set_already_seen():
	$GetPolygon.color = Color('00c2aa')

func set_not_already_seen():
	$GetPolygon.color = Color('9ea8b4')


func _on_Button_pressed():
	print('CLICK: on chapter: %s' % self.chap_number)
	self.main.go_to_node(self.chap_number)