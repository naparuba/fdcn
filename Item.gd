extends Panel



var _is_enabled = null
var _item_name = ''
var _item_data = {}

var _unkown_icon = null
var _item_icon = null
var _sprite_scale = 0.048

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



func load_item_data(item_name, item_data):
	self._item_name = item_name
	self._item_data = item_data
	#print('Loading item data: %s' % self._item_name)
	$Nom.text = self._item_name
	self._display_stats()
	var new_style = StyleBoxFlat.new()
	self.set('custom_styles/panel', new_style)
	var svg_path = 'res://images/items/%s.svg' % self._item_name
	var png_path = 'res://images/items/%s.png' % self._item_name
	if Utils.is_file_exists(svg_path):
		self._item_icon = Utils.load_external_texture(svg_path, null)
	elif Utils.is_file_exists(png_path):
		self._item_icon = Utils.load_external_texture(png_path, null)
		self._sprite_scale = 1.0
	else:
		self._item_icon = null
	self._unkown_icon = Utils.load_external_texture('res://images/items/question.svg', null)
	self.refresh()


func _display_stats():
	var s = ''
	for k in self._item_data['stats'].keys():
		var v = self._item_data['stats'][k]
		s += ('%s=' % k.to_upper()) + str(v) + '    '
	$Stats.text = s

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
		print('ITEM:: ', self._item_name, 'SHOW :: _is_enabled' )
		return true
	if AppParameters.are_spoils_ok():
		print('ITEM:: ', self._item_name, 'SHOW :: spoils are ok' )
		return true
	#print('Can item: %s be shown ' % self._item_name, '%s' % self._item_data)
	for chapter_id in self._item_data['in_chapters']:
		if Player.did_all_times_seen(chapter_id):
			print('Item %s can be seens thanks to chapter' % self._item_name, '%s' % chapter_id)
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
	
	print('ITEM:: ', self._item_name, 'do have item? ',do_have_item )
	
	if self._can_item_be_shown():
		print('ITEM:: ', self._item_name, 'SHOW\n' )
		$Nom.text = self._item_name
		$sprite.scale[0] = self._sprite_scale
		$sprite.scale[1] = self._sprite_scale
		$sprite.texture = self._item_icon
	else:
		print('ITEM:: ', self._item_name, 'HIDE\n' )
		$Nom.text = ''  # We already have the ? icon
		$sprite.texture = self._unkown_icon
		$sprite.scale[0] = 0.048
		$sprite.scale[1] = 0.048

	#print('STYLE: %s' % _style)
	if do_have_item:
		_style.set_bg_color(Color('c0ffed'))  # set to light grey
		#print('HAVE item: %s' % self._item_name)
	else:
		_style.set_bg_color(Color('ffffff'))  # set to light grey
	# Update the button in the good state
	$button.pressed = do_have_item


func _on_button_toggled(button_pressed):
	print('ITEM: %s goes' % self._item_name, '%s' % button_pressed)
	if button_pressed:
		Player.add_item_from_options(self._item_name)
	else:  # remove it
		Player.remove_item_from_options(self._item_name)
	self.refresh()
