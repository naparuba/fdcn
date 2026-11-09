@tool

extends Panel


@export var type_entry = 'billys'
@export var entry_name = 'guerrier'
@export var titre = 'XXXX'
@export var book_number = 1


# Hauteur d'affichage d'une image de lore (454 px de haut x echelle 0.390438 des images
# historiques) : toute image, quelle que soit sa resolution, est ramenee a cette hauteur.
const DISPLAY_HEIGHT = 177.26

var is_playing = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$Label.text = titre

	var dir = type_entry
	var ext = 'png'  # default for billy
	if type_entry == 'dieux' or type_entry == 'pays':
		ext = 'jpg'
	var pth = 'res://images/%s/'%type_entry
	if type_entry == 'dieux':
		pth += '%s/' % self.book_number
	pth += entry_name
	pth += '.%s' % ext

	var texture = Utils.load_external_texture(pth, null)
	$Sprite2D.texture = texture
	if texture != null:
		$Sprite2D.scale = Vector2.ONE * (DISPLAY_HEIGHT / texture.get_height())



func _set_can_play():
	var sprite_play = $click/sprite_play
	var sprite_stop = $click/sprite_stop
	self.is_playing = false
	sprite_play.visible = true
	sprite_stop.visible = false


func _set_playing():
	var sprite_play = $click/sprite_play
	var sprite_stop = $click/sprite_stop
	self.is_playing = true
	sprite_play.visible = false
	sprite_stop.visible = true


func _on_play_pressed():
	if !Sounder.is_enabled():
		return
	var player = $AudioStreamPlayer

	# Play
	if ! self.is_playing:
		var pth = ''
		if type_entry == 'dieux':
			pth = 'res://sounds/%s/' % type_entry
			pth += '%s/' % self.book_number
		else:
			pth = 'res://sounds/%s/' % type_entry
		pth += entry_name
		pth += '.mp3'
		print('FULL PATH: %s' % pth)
		var sound = load(pth)
		print('%s is load '% sound, 'for ', entry_name)
		
		player.stream = sound
		player.play()
		self._set_playing()

	else:  #STOP
		#Sounder.stop()  # need a callback system
		player.stop()
		self._set_can_play()



func _on_AudioStreamPlayer_finished():
	self._set_can_play()
