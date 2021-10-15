extends Control





var chap_number = 1
var main_obj = null
var is_current = false

func set_main(main_obj):
	self.main_obj = main_obj

func set_chap_number(nb):
	self.chap_number = nb
	

# The current label should be wihtout the _, so people don't want to click on it
func _update_label():
	if !self.is_current:
		$ElLabel.bbcode_text = '[u]%d[/u]' % self.chap_number
	else:
		$ElLabel.bbcode_text = '%d' % self.chap_number


func _set_color(color):
	$poly_for_first.color = color
	$Polygon2D.color = color
	#print('Changed to color= %s' % color)

# Called when the node enters the scene tree for the first time.
func _ready():
	#self._set_color()
	pass


func set_first():
	$poly_for_first.visible = true
	

func set_current():
	self._set_color(Color('00c2aa'))
	self.is_current = true  # means: don't jump here ^^
	self._update_label()
	

func set_previous():
	self._set_color(Color('01bcdb'))
	self._update_label()


func set_normal_color():
	self._set_color(Color('9ea8b4'))
	self._update_label()


### NOTE: the button is invisible, normal ^^
func _on_button_pressed():
	if self.is_current:
		print('Cannot jump back to current node..')
		return
	print('BUTTON: %s pressed' % self.chap_number)
	self.main_obj.jump_back(self.chap_number)
