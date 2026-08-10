extends Node

var parameters_file  = "user://parameters.json"
var parameters = {
	'billy': 'guerrier',
	'spoils': true,
	'sound': true,
	'current_book': 'fdcn',  # which book did the user select (matches books/{name}/)
}

signal settings_changed
signal settings_loaded

func _ready():
	print('Parameters: ready')
	self._load_parameters()
	self._apply_parameters()


func _load_parameters():
	if FileAccess.file_exists(parameters_file):
		var f = FileAccess.open(parameters_file, FileAccess.READ)
		var loaded_parameters = JSON.parse_string(f.get_as_text())
		if not loaded_parameters is Dictionary:
			print('PARAM: fichier de sauvegarde invalide, réinitialisation')
			return
		# NOTE: so we can manage code with new parameters
		for k in loaded_parameters.keys():
			var v = loaded_parameters[k]
			print('PARAM: %s=>' % k, v)
			parameters[k] = v
		self._migrate_legacy_book_number()
	else:
		# already created in globals
		pass


# Old saves stored current_book as a number (1/2). Migrate it to the book
# name used by the books/{name}/ folder layout.
func _migrate_legacy_book_number():
	var current = self.parameters['current_book']
	if typeof(current) == TYPE_STRING:
		return
	var legacy_names = {1: 'fdcn', 2: 'cdsi'}
	self.parameters['current_book'] = legacy_names.get(int(current), 'fdcn')


func _save_parameters():
	var f = FileAccess.open(parameters_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(parameters))
	settings_changed.emit()


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


func set_book_name(book_name):
	var current = self.parameters['current_book']
	if current == book_name:
		return false
	print('PARAMETERS: book_name => %s' % book_name)
	self.parameters['current_book'] = book_name
	self._save_parameters()
	self._apply_parameters()
	return true


func get_book_name():
	return self.parameters['current_book']
