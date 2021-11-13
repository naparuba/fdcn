extends Panel


var _is_enabled = null
var _item_name = ''
var _item_data = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.




func load_item_data(item_name, item_data):
	self._item_name = item_name
	self._item_data = item_data
	#print('Loading item data: %s' % self._item_name)
	$Nom.text = self._item_name
	$Stats.text = ''
	var new_style = StyleBoxFlat.new()
	self.set('custom_styles/panel', new_style)
	self.refresh()


func refresh():
	# Maybe we don't need a refresh
	var do_have_item = Player.have_item(self._item_name)
	if do_have_item == self._is_enabled:  # Already up to date, skip
		return
	
	var _style = self.get('custom_styles/panel')
	
	#print('STYLE: %s' % _style)
	if do_have_item:
		_style.set_bg_color(Color('00ff00'))  # set to light grey
		#print('HAVE item: %s' % self._item_name)
	else:
		_style.set_bg_color(Color('ff0000'))  # set to light grey
	# Update the button in the good state
	$button.pressed = do_have_item


func _on_button_toggled(button_pressed):
	print('ITEM: %s goes' % self._item_name, '%s' % button_pressed)
	if button_pressed:
		Player.add_item_from_options(self._item_name)
	else:  # remove it
		Player.remove_item_from_options(self._item_name)
	self.refresh()
