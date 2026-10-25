extends Panel

var is_new = false
var _item_name = ''
var _item_data = {}


var _item_icon = null

const ANIM_DURATION = 0.22  # rapide, mais jamais un saut brutal
const FULL_HEIGHT = 50.0

var anim_tween: Tween = null  # expose pour l'E2E (attendre la fin avant une capture)


# Apparition en glissement (hauteur 0 -> pleine taille, cf VBoxContainer
# parent qui suit le custom_minimum_size) + fondu, plutot qu'un pop instantane.
func _ready():
	self.clip_contents = true
	self.custom_minimum_size.y = 0.0
	self.modulate.a = 0.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(self, "custom_minimum_size:y", FULL_HEIGHT, ANIM_DURATION)
	tween.tween_property(self, "modulate:a", 1.0, ANIM_DURATION)
	self.anim_tween = tween



func load_item_data(item_name, item_data):
	self._item_name = item_name
	self._item_data = item_data
	#print('Loading item data: %s' % self._item_name)
	$Nom.text = self._item_name
	var new_style = StyleBoxFlat.new()
	new_style.set_corner_radius_all(8)
	new_style.shadow_color = Color(0.05, 0.08, 0.12, 0.15)
	new_style.shadow_size = 4
	self.set('theme_override_styles/panel', new_style)
	self._item_icon = Utils.load_external_texture('res://images/items/%s.svg' % self._item_name, null)


	
func set_is_new(b):
	self.is_new = b
	self.refresh()
	

func refresh():
	var _style = self.get('theme_override_styles/panel')
	
	$Nom.text = self._item_name
	$sprite.texture = self._item_icon

	#print('STYLE: %s' % _style)
	if self.is_new:
		_style.set_bg_color(Color('c0ffed'))  # set to light grey
	else:
		_style.set_bg_color(Color('f45858'))  # set to light grey





func _on_Timer_timeout():
	print('GOOD BYE ITEM popup %s' % self._item_name)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(self, "custom_minimum_size:y", 0.0, ANIM_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, ANIM_DURATION)
	tween.chain().tween_callback(self.queue_free)
	self.anim_tween = tween
