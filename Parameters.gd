extends Node

var parameters_file  = "user://parameters.save"
var parameters = {
	'billy': 'guerrier',
	'spoils': true,
	'sound': true,
	'current_book': 1,  # which book did the user select
}

func _init():
	print('Parameters: init')
	self._load_parameters()
	self._apply_parameters()



func _load_parameters():
	var f = File.new()
	if f.file_exists(parameters_file):
		f.open(parameters_file, File.READ)
		var loaded_parameters = f.get_var()
		f.close()
		# NOTE: so we can manage code with new parameters
		for k in loaded_parameters.keys():
			var v = loaded_parameters[k]
			print('PARAM: %s=>' % k, v)
			parameters[k] = v
	else:
		# already created in globals
		pass


func _save_parameters():
	var f = File.new()
	f.open(parameters_file, File.WRITE)
	f.store_var(parameters)
	f.close()


# We warn others about the params, if changed or load
func _apply_parameters():
	Sounder.set_enabled(self.parameters['sound'])
	print('PARAMETERS: _apply_parameters')
	BookData.do_load_book(self.parameters['current_book'])
	

func are_spoils_ok():
	return self.parameters['spoils']


func set_spoils(b):
	var current = self.parameters['spoils']
	if b == current:
		return
	print('PARAMETERS: spoils => %s' % b)
	self.parameters['spoils'] = b
	self._save_parameters()


func is_sound_ok():
	return self.parameters['sound']


func set_sound(b):
	var current = self.parameters['sound']
	if b == current:
		return
	print('PARAMETERS: sound => %s' % b)
	self.parameters['sound'] = b
	self._save_parameters()
	self._apply_parameters()
	
	
func get_billy_type():
	return self.parameters['billy']


func set_billy_type(billy_type):
	var current = self.parameters['billy']
	if current == billy_type:
		return
	print('PARAMETERS: billy_type => %s' % billy_type)
	self.parameters['billy'] = billy_type
	self._save_parameters()


func set_book_number(book_number):
	var current = self.parameters['current_book']
	if current == book_number:
		return false
	print('PARAMETERS: book_number => %s' % book_number)
	self.parameters['current_book'] = book_number
	self._save_parameters()
	self._apply_parameters()
	return true
 

func get_book_number():
	return self.parameters['current_book']
	
	
