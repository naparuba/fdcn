extends Node

const Godot3VariantDecoder = preload('res://godot3_variant_decoder.gd')

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
	# JSON primaire (depuis le 2026-07-09). Si le miroir JSON n'existe pas
	# encore -- joueur dont la derniere sauvegarde est anterieure a son
	# introduction (commit af5c081, 2026-05-03) -- on relit une derniere
	# fois l'ancien binaire puis on migre immediatement vers JSON.
	#
	# ATTENTION : FileAccess.get_var() ne peut PAS lire ce binaire Godot
	# 3.6.2 (cf player.gd::_load_var pour le detail du bug) -- passe par
	# Godot3VariantDecoder, un decodeur manuel du format d'origine.
	var json_pth = parameters_file.replace(".save", ".json")
	var loaded_parameters = null
	if FileAccess.file_exists(json_pth):
		var f = FileAccess.open(json_pth, FileAccess.READ)
		var text = f.get_as_text()
		f.close()
		loaded_parameters = Utils.ints_from_json(JSON.parse_string(text))
	elif FileAccess.file_exists(parameters_file):
		print('_load_parameters:: pas de miroir JSON, fallback lecture binaire unique puis migration')
		var f = FileAccess.open(parameters_file, FileAccess.READ)
		var bytes = f.get_buffer(f.get_length())
		f.close()
		loaded_parameters = Godot3VariantDecoder.decode(bytes)
	if loaded_parameters != null:
		# NOTE: so we can manage code with new parameters
		for k in loaded_parameters.keys():
			var v = loaded_parameters[k]
			print('PARAM: %s=>' % k, v)
			parameters[k] = v
		self._save_parameters()  # migre vers JSON si on vient de lire le binaire


func _save_parameters():
	var json_pth = parameters_file.replace(".save", ".json")
	var f = FileAccess.open(json_pth, FileAccess.WRITE)
	f.store_string(JSON.stringify(parameters))
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
	# Un objet possede dans un livre peut ne pas exister dans l'autre (ex:
	# changement FDCN<->CDSI) -- sans ce nettoyage, une stat recalculee sur
	# un item introuvable dans le nouveau catalogue plante (Nil). Fait ici
	# (pas dans _apply_parameters(), aussi appelee depuis _init() avant que
	# l'autoload Player n'existe encore -- AppParameters est initialise
	# avant Player dans l'ordre des autoloads).
	Player._clean_not_existing_items()
	Player._recompute_stats()
	return true
 

func get_book_number():
	return self.parameters['current_book']
	
	
