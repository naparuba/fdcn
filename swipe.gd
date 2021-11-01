extends Node

signal swipe
var swipe_start = null
var minimum_drag = 100
var main = null

var current_page = 'main'


func _init():
	pass


func register_main(_main):
	self.main = _main
	

func get_current_page():
	return self.current_page


func compute_event(event):
	if event is InputEventScreenTouch:
		#print('TOUCH: %s' % event.is_pressed())
		#self.main.print_debug('TOUCH: %s' % event.is_pressed())
		if event.is_pressed():
			#print('START')
			swipe_start = event.position
		else:
			#print('STOP')
			_calculate_swipe(event.position)
	return
	
		
func _calculate_swipe(swipe_end):
	if swipe_start == null: 
		return
	var swipe = swipe_end - swipe_start
	print(swipe)
	if abs(swipe.x) > minimum_drag:
		if swipe.x > 0:
			print('Swipe to right')
			self.main.print_debug('swap to left')
			#emit_signal("swipe", "left")
			self.swipe_to_left()
		else:
			print('Swipe to left')
			self.main.print_debug('swap to right')
			#emit_signal("swipe", "right")
			self.swipe_to_right()


func go_to_page(dest):
	if dest == 'BACK':
		self.main.jump_to_previous_chapter()
	elif dest == 'main':
		self.focus_to_main()
	elif dest == 'chapitres':
		self.focus_to_chapitres()
	elif dest == 'success':
		self.focus_to_success()
	elif dest == 'lore':
		self.focus_to_lore()
	elif dest == 'about':
		self.focus_to_about()
	else:
		print('ERROR: no such dest: %s' % dest)




func focus_to_main():
	print('=> main')
	self.main.set_camera_to_pos(278)
	self.current_page = 'main'
	self.main.update_page_in_top_menus(self.current_page)
	
	
func focus_to_chapitres():
	print('=> chapitres')
	self.main.set_camera_to_pos( 876)
	self.current_page = 'chapitres'
	self.main.update_page_in_top_menus(self.current_page)
	
	
func focus_to_success():
	print('=> success')
	self.main.set_camera_to_pos (1471)
	self.current_page = 'success'
	self.main.update_page_in_top_menus(self.current_page)


func focus_to_lore():
	print('=> lore')
	self.main.set_camera_to_pos( 2058)
	self.current_page = 'lore'
	self.main.update_page_in_top_menus(self.current_page)


func focus_to_about():
	print('=> about')
	self.main.set_camera_to_pos( 2648 )
	self.current_page = 'about'
	self.main.update_page_in_top_menus(self.current_page)
	

func swipe_to_left():
	print('Going to left, from page: %s' % self.current_page)
	if self.current_page == 'main':
		self.main.jump_to_previous_chapter()
		return
	elif self.current_page == 'chapitres':
		print('Going back to main')
		self.focus_to_main()
	elif self.current_page == 'success':
		self.focus_to_chapitres()
	elif self.current_page == 'lore':
		self.focus_to_success()
	elif self.current_page == 'about':
		self.focus_to_lore()
	else:
		print('ERROR: unknown page: %s' % self.current_page)

	
func swipe_to_right():
	print('Going to right, from page: %s' % self.current_page)
	if self.current_page == 'main':
		self.focus_to_chapitres()
	elif self.current_page == 'chapitres':
		self.focus_to_success()
	elif self.current_page == 'success':
		self.focus_to_lore()
	elif self.current_page == 'lore':
		self.focus_to_about()
	elif self.current_page == 'about':
		print('Last page')
	else:
		print('ERROR: unknown page: %s' % self.current_page)
