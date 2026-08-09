extends Panel

@onready var items_panel = $ItemsCont/Items


@onready var Item = preload('res://entities/Item.tscn')
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	var all_objects = BookData.get_all_objects()
	for obj_name in all_objects.keys():
		var item_data = all_objects[obj_name]
		var item = Item.instantiate()
		item.load_item_data(obj_name, item_data)
		var is_ok_to_be_shown = item.is_ok_to_be_shown()
		if is_ok_to_be_shown:
			# Also let the Player know it does exists
			#print('KNOWN ITEM: %s' % item)
			Player.add_in_all_items(item)

	self.display_all_objects()
	#self.refresh_all_objects()

func display_all_objects():
	Utils.delete_children(items_panel)
	print('Insert all objects')
	for item in Player.all_items:
		items_panel.add_child(item)

func refresh_all_objects():
	for item in items_panel.get_children():
		item.refresh()

	var type_billy_param = AppParameters.get_billy_type()
	var sprite_by_billy = {
		'guerrier':    $Options/Equipement/BlockGuerrier/sprite,
		'paysan':      $Options/Equipement/BlockPaysan/sprite,
		'prudent':     $Options/Equipement/BlockPrudent/sprite,
		'debrouillard':$Options/Equipement/BlockDebrouillard/sprite
	}
	
	## Gray ALL .material.set_shader_param("param_name", value)
	for billy in sprite_by_billy.keys():
		sprite_by_billy[billy].material.set_shader_param("grayscale", true)

	## Colorize the selected one
	if type_billy_param != 'pegu':
		sprite_by_billy[type_billy_param].material.set_shader_param("grayscale", false)
