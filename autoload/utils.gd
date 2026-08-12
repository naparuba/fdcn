extends Node


func _ready() -> void:
	# Sans ça, `randi()` repart de la même graine à chaque lancement : tous les dés
	# d'une partie sortaient dans le même ordre d'une session à l'autre (review #14).
	# Indispensable au combat automatisé, qui rejouerait sinon le même affrontement à
	# l'identique.
	randomize()


# IMPORTANT: need to have load() call to manage android and web
func load_external_texture(path, logger):
	var image_file = load(path)
	if image_file == null:
		print('ERROR: cannot load image %s' % path)
		return null
	return image_file


# Load a json file and give null if fail (TODO: kill program)
func load_json_file(path):
	# En Godot 4, les .json sont importés comme ressources JSON
	var res = load(path)
	if res != null and res is JSON:
		return res.data
	# Fallback FileAccess (ex: user://)
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("[load_json_file] Impossible d'ouvrir: " + path + " err=" + str(FileAccess.get_open_error()))
		return null
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		print("[load_json_file] Erreur JSON ligne %d: " % json.get_error_line() + json.get_error_message())
		return null
	return json.data


func delete_children(node):
	for n in node.get_children():
		node.remove_child(n)
		n.queue_free()


func roll_a_dice(minimum, maximum):
	var roll = randi() % (maximum-minimum+1) + minimum
	return roll


## Vrai si la **ressource** existe, importée comprise.
##
## 🔴 Remplace `FileAccess.file_exists()`, qui était faux pour cet usage. Les 7 appelants
## testent tous des ressources importées — `images/items/*.svg`, `images/success/*.png`,
## `sounds/dieux/*.mp3`. Or un export n'embarque **pas** les fichiers sources : seuls les
## artefacts de `.godot/imported/` partent dans le PCK, et `res://images/items/arc.svg`
## n'existe plus en tant que fichier. `FileAccess.file_exists()` renvoyait donc **false pour
## tout** dans un build, ce qui aurait donné l'icône « ? » sur chaque objet, aucune image de
## succès ni de fin, et aucune voix du Lore.
##
## Invisible depuis l'éditeur, où les sources sont encore là : c'est exactement le genre de
## bug qui ne se découvre qu'au premier export.
##
## `ResourceLoader.exists()` suit les remaps `.import`, donc il répond juste dans les deux
## cas. ⚠️ Il ne convient PAS pour un fichier de `user://` (sauvegardes) : là, c'est bien
## `FileAccess.file_exists()` qu'il faut, et `SaveManager` l'appelle directement.
func is_file_exists(path):
	return ResourceLoader.exists(path)


## Remonte l'arbre depuis `node` jusqu'au premier nœud qui expose `method_name`,
## ou null. Permet à un widget réutilisable (menu du haut, flèches...) de trouver
## son conteneur de pages sans que la scène ait à lui passer une référence.
func find_ancestor_with_method(node: Node, method_name: String) -> Node:
	var current = node
	while current != null:
		if current.has_method(method_name):
			return current
		current = current.get_parent()
	return null
