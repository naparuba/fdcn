extends Node

signal swipe
var swipe_start = null
var minimum_drag = 100
var main = null

func _init():
	print('Create Swiper')

func register_main(_main):
	self.main = _main
	

func compute_event(event):
	#self.main.print_debug('%s' % event)
	if event is InputEventScreenDrag:
		print("Player gets dragged")
		#print("ply:", position)
		print("pos: ", event.position)
		print("rel: ", event.relative)
		print("vel: ", event.speed)
	if event is InputEventScreenTouch:
		print('TOUCH: %s' % event.is_pressed())
		#self.main.print_debug('TOUCH: %s' % event.is_pressed())
		if event.is_pressed():
			print('START')
			swipe_start = event.position
		else:
			print('STOP')
			_calculate_swipe(event.position)
	return
	print('Swipe:: EVENT: %s' % event)
	if event.is_action_pressed("click"):
		print('START CLICK: %s' % event.position)
		#swipe_start = get_global_mouse_pos()
	if event.is_action_released("click"):
		print('STOP CLICK %s' % event.position)
		#_calculate_swipe(get_global_mouse_pos())
		
func _calculate_swipe(swipe_end):
	if swipe_start == null: 
		return
	var swipe = swipe_end - swipe_start
	print(swipe)
	if abs(swipe.x) > minimum_drag:
		if swipe.x > 0:
			print('Swipe to right')
			self.main.print_debug('swap to left')
			emit_signal("swipe", "left")
			self.main.swipe_to_left()
		else:
			print('Swipe to left')
			self.main.print_debug('swap to right')
			emit_signal("swipe", "right")
			self.main.swipe_to_right()