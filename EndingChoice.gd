extends Panel



var ending_type = 0
var main

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func set_ending_id(ending_id):
	var texture = Utils.load_external_texture("res://images/endings/%s.png" % ending_id, null)
	$Icone.texture = texture
	#print('SPRITE LOADED: %s' % ending_id)


func set_main(main):
	self.main = main
	
	
func set_label(label):
	$Label.text = label


func set_ending_type(ending_type):
	print('ENDING TYPE: %s' % ending_type)
	self.ending_type = ending_type
	if self.ending_type == 1 :  # GOOD
		$EndingType.color = Color('00c2aa')
	else:  # bad one
		$EndingType.color = Color('ff6f04')

	

func _on_bouton_billy_pressed():
	self.main.launch_new_billy()


func _on_oups_pressed():
	self.main.jump_to_previous_chapter()
	
