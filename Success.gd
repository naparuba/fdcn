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


func update():
	var chapter_id = self.get_chapter_id()
	var chapter_data = BookData.get_node(chapter_id)
		
	# Update if spoils need to be shown (or not), can depend if we already seen this node
	if BookData.is_node_id_freely_full_on_all_chapters(chapter_id):
		self.set_spoil_enabled(true)
	else:  # only follow the parameter
		self.set_spoil_enabled(false)
	# All time seen
	if Player.did_all_times_seen(chapter_id):
		self.set_already_seen()
	else:
		self.set_not_already_seen()


func get_chapter_id():
	return self.chap_number


func set_from_success_object(success_object):
	self.set_chapitre(success_object['chapter'])
	self.set_label(success_object['label'])
	self.set_txt(success_object['txt'])
	self.set_success_id(success_object['id'])
	

func set_success_id(success_id):
	var png_path = "res://images/success/%s.png" % success_id
	var svg_path ="res://images/success/%s.svg" % success_id
	var texture = null
	if Utils.is_file_exists(svg_path):
		texture = Utils.load_external_texture(svg_path, null)
	elif Utils.is_file_exists(png_path):
		texture = Utils.load_external_texture(png_path, null)
	
	$sprite.texture = texture
	#print('SPRITE LOADED: %s' % success_id)


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


func hide_chapter():
	$NBChapitre.visible = false
	$click.visible = false


func _on_Button_pressed():
	print('CLICK: on chapter: %s' % self.chap_number)
	self.main.go_to_node(self.chap_number)
