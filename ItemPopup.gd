extends Panel

var is_new = false
var _item_name = ''
var _item_data = {}


var _item_icon = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



func load_item_data(item_name, item_data):
	self._item_name = item_name
	self._item_data = item_data
	#print('Loading item data: %s' % self._item_name)
	$Nom.text = self._item_name
	var new_style = StyleBoxFlat.new()
	self.set('custom_styles/panel', new_style)
	self._item_icon = Utils.load_external_texture('res://images/items/%s.svg' % self._item_name, null)


	
func set_is_new(b):
	self.is_new = b
	self.refresh()
	

func refresh():
	var _style = self.get('custom_styles/panel')
	
	$Nom.text = self._item_name
	$sprite.texture = self._item_icon

	#print('STYLE: %s' % _style)
	if self.is_new:
		_style.set_bg_color(Color('c0ffed'))  # set to light grey
	else:
		_style.set_bg_color(Color('f45858'))  # set to light grey





func _on_Timer_timeout():
	print('GOOD BYE ITEM popup %s' % self._item_name)
	self.queue_free()
