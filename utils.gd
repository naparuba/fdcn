extends Node


# IMPORTANT: need to have load() call to manage android and web
func load_external_texture(path, logger):	
	var image_file = load(path);
	image_file = image_file.get_data();
	var imgtex = ImageTexture.new()
	imgtex.create_from_image(image_file)
	return imgtex
	

# Load a json file and give null if fail (TODO: kill program)
func load_json_file(path):
	"""Loads a JSON file from the given res path and return the loaded JSON object."""
	var file = File.new()
	file.open(path, file.READ)
	var text = file.get_as_text()
	var result_json = JSON.parse(text)
	if result_json.error != OK:
		print("[load_json_file] Error loading JSON file '" + str(path) + "'.")
		print("\tError: ", result_json.error)
		print("\tError Line: ", result_json.error_line)
		print("\tError String: ", result_json.error_string)
		return null
	var obj = result_json.result
	return obj


func delete_children(node):
	for n in node.get_children():
		node.remove_child(n)
		n.queue_free()
