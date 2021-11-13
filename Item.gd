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


func get_name():
	return self._item_name

func is_enabled():
	return self._is_enabled


#func raw_disable():
#	$button.pressed = false
#	self._is_enabled = false


func get_category():
	return self._item_data['category']


# Depends on the item category, some won't be display: the BILLY one
func is_ok_to_be_shown():
	if self.get_category() == 'BILLY':
		return false
	return true
	

# Is an item name can be shown?
# * we have it, so of course we can
# * we are spoills ok, so we can too
# * we already did see it's chapter in the past plays
func _can_item_be_shown():
	if self._is_enabled:
		return true
	if AppParameters.are_spoils_ok():
		return true
	#print('Can item: %s be shown ' % self._item_name, '%s' % self._item_data)
	for chapter_id in self._item_data['in_chapters']:
		if Player.did_all_times_seen(chapter_id):
			#print('Item %s can be seens thanks to chapter' % self._item_name, '%s' % chapter_id)
			return true
		#else:
		#	print('Item %s is not ok with chapter' % self._item_name, '%s' % chapter_id)
	return false


func refresh():
	# Maybe we don't need a refresh
	var do_have_item = Player.have_item(self._item_name)
	#if do_have_item == self._is_enabled:  # Already up to date, skip
	#	return
	self._is_enabled = do_have_item
	
	var _style = self.get('custom_styles/panel')
	
	if self._can_item_be_shown():
		$Nom.text = self._item_name
	else:
		$Nom.text = '?'
	FUCK=> remet le guess
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
