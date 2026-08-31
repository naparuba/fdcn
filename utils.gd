@tool
extends Node


var _texture_cache = {}


# IMPORTANT: need to have load() call to manage android and web
#
# Mis en cache par chemin : toujours appele en lecture seule (assigne a une
# texture de Sprite2D/TextureRect, jamais mute ensuite -- verifie sur les 9
# appelants), donc partager la meme instance entre plusieurs noeuds est sur.
# Evite de recreer une texture GPU identique a chaque fois qu'un meme item/
# portrait est affiche (ex: LoreEntry recharge les memes ~18-29 portraits a
# chaque instanciation de main.tscn).
func load_external_texture(path, logger):
	if _texture_cache.has(path):
		return _texture_cache[path]
	var image_file = load(path);
	if image_file == null:
		print('ERROR: cannot load image %s' % path)
		return null
	image_file = image_file.get_image();
	var texture = ImageTexture.create_from_image(image_file)
	_texture_cache[path] = texture
	return texture


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


# Un ScrollContainer Godot 4 ne defile PAS au glisse-doigt/souris tout seul
# (seuls la scrollbar et la molette marchent nativement) -- bug reel
# constate a l'ecran (fiche de personnage), confirme identique partout
# ailleurs dans l'appli (aucun handler equivalent n'existait nulle part
# avant). Cette fonction ajoute ce comportement a N'IMPORTE QUEL
# ScrollContainer, pour ne jamais dupliquer cette logique ecran par ecran.
# L'etat "glisse en cours" est stocke en metadonnee sur le noeud lui-meme
# (pas une variable partagee ici) : plusieurs ScrollContainer independants
# peuvent donc appeler cette fonction sans se marcher dessus.
func enable_drag_scroll(scroll: ScrollContainer) -> void:
	scroll.set_meta("_drag_scroll_active", false)
	scroll.gui_input.connect(self._on_drag_scroll_gui_input.bind(scroll))


func _on_drag_scroll_gui_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if event is InputEventScreenTouch:
		scroll.set_meta("_drag_scroll_active", event.pressed)
	elif event is InputEventScreenDrag:
		if scroll.get_meta("_drag_scroll_active", false):
			scroll.scroll_vertical -= int(event.relative.y)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		scroll.set_meta("_drag_scroll_active", event.pressed)
	elif event is InputEventMouseMotion:
		if scroll.get_meta("_drag_scroll_active", false) and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			scroll.scroll_vertical -= int(event.relative.y)


# Tout Control a mouse_filter=STOP par defaut en Godot 4 -- sans ca, chaque
# fond de carte/label/ligne de mise en page avale le glisse-doigt avant
# qu'il n'atteigne le ScrollContainer ancetre, qui ne devient alors
# scrollable qu'a la souris/via le slider. Laisse donc tout passer SAUF les
# vrais widgets interactifs (LineEdit, et TOUT bouton -- BaseButton, pas
# seulement Button : TextureButton/CheckButton/LinkButton en sont des
# FRERES, pas des sous-classes de Button, un `is Button` les aurait laisses
# passer et rendus incliquables) et les ScrollContainer eux-memes, qui
# doivent rester la cible du glisse.
func make_non_interactive_passthrough(node: Node) -> void:
	if node is Control and not (node is BaseButton or node is LineEdit or node is ScrollContainer):
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		self.make_non_interactive_passthrough(child)

