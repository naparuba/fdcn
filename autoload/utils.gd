extends Node
## Les quelques fonctions sans propriétaire, appelées d'un peu partout.


func _ready() -> void:
	# Sans ça, `randi()` repart de la même graine à chaque lancement : tous les dés d'une
	# partie sortaient dans le même ordre d'une session à l'autre. Indispensable au combat
	# automatisé, qui rejouerait sinon le même affrontement à l'identique.
	randomize()


## Une image chargée à l'exécution, ou `null`.
##
## ⚠️ `load()` et non `FileAccess` : un export n'embarque pas les fichiers sources, seuls
## les artefacts importés partent dans le PCK. C'est le seul chemin qui marche à la fois
## dans l'éditeur, sur Android et sur le web.
func load_external_texture(path):
	var texture = load(path)
	if texture == null:
		push_warning("Utils: image introuvable: %s" % path)
	return texture


## Le contenu d'un fichier json, ou `null` s'il est absent ou illisible.
##
## Deux chemins parce qu'il y a deux sortes de fichiers : les json du dépôt sont des
## **ressources** (`res://`, servies par `load()`), ceux que l'app écrit vivent dans
## `user://` et ne passent que par `FileAccess`.
func load_json_file(path):
	var res = load(path)
	if res != null and res is JSON:
		return res.data

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("[load_json_file] impossible d'ouvrir %s (err=%s)" % [path, FileAccess.get_open_error()])
		return null
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print("[load_json_file] %s ligne %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func delete_children(node) -> void:
	for n in node.get_children():
		node.remove_child(n)
		n.queue_free()


func roll_a_dice(minimum: int, maximum: int) -> int:
	return randi_range(minimum, maximum)


## Vrai si la **ressource** existe, importée comprise.
##
## 🔴 Remplace `FileAccess.file_exists()`, qui était faux pour cet usage. Les appelants
## testent tous des ressources importées — `images/items/*.svg`, `books/*/audio/*.mp3`… Or
## un export n'embarque **pas** les fichiers sources : seuls les artefacts de
## `.godot/imported/` partent dans le PCK, et `res://images/items/arc.svg` n'y existe plus
## en tant que fichier. `FileAccess.file_exists()` renvoyait donc **false pour tout** dans
## un build : icône « ? » sur chaque objet, aucune image de succès ni de fin, aucune voix.
##
## Invisible depuis l'éditeur, où les sources sont encore là : exactement le genre de bug
## qui ne se découvre qu'au premier export.
##
## ⚠️ Ne convient PAS pour un fichier de `user://` (sauvegardes) : là c'est bien
## `FileAccess.file_exists()` qu'il faut, et `SaveManager` l'appelle directement.
func is_file_exists(path) -> bool:
	return ResourceLoader.exists(path)


## svg d'abord, png ensuite, `repli` sinon : le motif répété à l'identique par les 3
## apparences d'objet/succès (`entities/Item.gd`, `popups/ItemPopup.gd`,
## `entities/success_item.gd`) avant qu'il ne soit factorisé ici — un seul endroit à
## corriger si l'ordre de repli change un jour.
func load_icon_with_fallback(dossier: String, nom: String, repli: Texture2D = null) -> Texture2D:
	var svg_path = '%s%s.svg' % [dossier, nom]
	var png_path = '%s%s.png' % [dossier, nom]
	if is_file_exists(svg_path):
		return load_external_texture(svg_path)
	if is_file_exists(png_path):
		return load_external_texture(png_path)
	return repli


## La version de l'application, et **le seul endroit d'où la lire**.
##
## Source unique : `application/config/version` dans `project.godot` — le réglage standard de
## Godot (Projet ▸ Paramètres ▸ Application ▸ Config ▸ Version). Elle était écrite en dur
## dans `AboutMenu.tscn` (`text = "0.22"`), donc invisible de tout script et oubliée à chaque
## livraison.
##
## ⚠️ **Pas `android/.build_version`** : ce fichier n'est pas la version de l'app, c'est celle
## du **modèle de build Android** installé par l'éditeur (`4.0.0.stable` — un numéro de
## *moteur*, au format `majeur.mineur.patch.statut`). L'afficher annoncerait « 4.0.0.stable »
## au joueur. S'il est suivi par git (`/android/*` puis `!/android/.build_version`), c'est
## pour que Godot détecte un modèle périmé, pas pour nous renseigner.
##
## ⚠️ Restent **hors** de cette source : `version/name` et `version/code` de
## `export_presets.cfg` (aujourd'hui `22.0` / `22`), lus par Godot au moment de l'export et
## pas à l'exécution. Publier demande donc encore de toucher aux deux endroits.
func get_app_version() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if version == "":
		# Un projet sans version déclarée n'est pas une erreur fatale : mieux vaut une page
		# « À propos » sans numéro qu'un plantage, ou qu'un « 0.22 » qui ment.
		push_warning("Utils: application/config/version est vide dans project.godot")
	return version


## Remonte l'arbre depuis `node` jusqu'au premier nœud qui expose `method_name`, ou null.
## Permet à un widget réutilisable (menu du haut, flèches…) de trouver son conteneur de
## pages sans que la scène ait à lui passer une référence.
func find_ancestor_with_method(node: Node, method_name: String) -> Node:
	var current = node
	while current != null:
		if current.has_method(method_name):
			return current
		current = current.get_parent()
	return null
