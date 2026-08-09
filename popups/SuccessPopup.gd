extends Popup


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func update_and_show(success):
	var s = $wholebackground/PanelBorder/Success
	s.set_chapitre(success['chapter'])
	s.set_label(success['label'])
	s.set_txt(success['txt'])
	s.set_success_id(success['id'])
	s.set_not_already_seen()  # will be set during the animation
	# For this one, we don't want to show the chapter
	s.hide_chapter()
	
	self.popup()
	$AnimationPlayer.play("show")
	self._new_success_play_sound()


func _new_success_play_sound():
	var player = $AudioPlayer
	player.stop()
	if !Sounder.is_enabled():
		return
	var full_pth = 'res://sounds/lennon-c-beau.mp3'
	var sound = load(full_pth)
	player.stream = sound
	player.play()


func _on_AnimationPlayer_animation_finished(anim_name):
	#print('SUCCESS: Animation %s is finish' % anim_name)
	if anim_name == 'show':  # show is finish, we can now launch hide
		$AnimationPlayer.play('hide')
		print('Show is done, now hide')
	elif anim_name == 'hide': # hide finish, do nothing
		pass
		
