extends Node


# IMPORTANT: need to have load() call to manage android and web
func load_external_texture(path, logger):	
	var image_file = load(path);
	image_file = image_file.get_data();
	var imgtex = ImageTexture.new()
	imgtex.create_from_image(image_file)
	return imgtex
	
