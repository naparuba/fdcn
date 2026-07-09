extends Node


# IMPORTANT: need to have load() call to manage android and web
func load_external_texture(path, logger):
	var image_file = load(path);
	if image_file == null:
		print('ERROR: cannot load image %s' % path)
		return null
	image_file = image_file.get_image();
	return ImageTexture.create_from_image(image_file)
	

# Load a json file and give null if fail (TODO: kill program)
func load_json_file(path):
	"""Loads a JSON file from the given res path and return the loaded JSON object."""
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(text)
	if error != OK:
		print("[load_json_file] Error loading JSON file '" + str(path) + "'.")
		print("\tError: ", error)
		print("\tError Line: ", test_json_conv.get_error_line())
		print("\tError String: ", test_json_conv.get_error_message())
		return null
	# Les ids/stats des données de jeu compilées (chapitres, sons, succès,
	# fins...) sont toujours des entiers, mais JSON n'a pas de type entier
	# distinct : renvoie donc TOUJOURS des float (ex: 100.0). En Godot 3.6,
	# `'%s' % 100.0` produisait silencieusement "100" (sans ".0"), masquant
	# le probleme pour les lookups par cle-chaine (ex: BookData.get_chapter_data).
	# En Godot 4, `'%s' % 100.0` produit "100.0" -- cast donc explicitement ici.
	return self.ints_from_json(test_json_conv.get_data())


# JSON n'a pas de type entier distinct : JSON.parse_string()/JSON.new().parse()
# renvoient toujours des float pour un nombre, y compris pour des ids de
# noeud. Reconvertit recursivement (tableaux et dictionnaires) vers int.
func ints_from_json(value):
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	elif typeof(value) == TYPE_ARRAY:
		var out = []
		for v in value:
			out.append(self.ints_from_json(v))
		return out
	elif typeof(value) == TYPE_DICTIONARY:
		var out = {}
		for k in value.keys():
			out[k] = self.ints_from_json(value[k])
		return out
	return value


func delete_children(node):
	for n in node.get_children():
		node.remove_child(n)
		n.queue_free()


func roll_a_dice(minimum, maximum):
	var roll = randi() % (maximum-minimum+1) + minimum
	return roll


func is_file_exists(path):
	return FileAccess.file_exists(path)
	
