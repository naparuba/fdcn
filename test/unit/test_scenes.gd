extends "res://test/test_case.gd"
## Toutes les scènes se chargent-elles et s'instancient-elles ?
##
## C'était l'angle mort le plus large de la suite : aucun test ne touchait un `.tscn`,
## donc une scène malformée — un `parent=` vers un nœud inexistant, un `SubResource`
## non déclaré, une propriété inconnue — ne se voyait qu'en lançant l'app à la main.
## Or ce dépôt édite ses scènes en texte (renommages, insertions de nœuds), c'est
## exactement le genre de faute qui arrive.
##
## Ce test ne valide PAS le comportement : `instantiate()` ne déclenche pas `_ready()`
## tant que le nœud n'est pas dans l'arbre. Il valide la structure, ce qui est déjà
## l'essentiel de ce qui casse.

const DOSSIERS := ["res://screens", "res://ui", "res://popups", "res://entities", "res://autoload"]

## `main.tscn` vit à la racine et n'est pas dans les dossiers balayés.
const EN_PLUS := ["res://main.tscn"]


func test_toutes_les_scenes_se_chargent() -> void:
	var chemins = _lister_scenes()
	assert_true(chemins.size() >= 20, "on a bien trouvé les scènes (%d)" % chemins.size())

	for chemin in chemins:
		var scene = load(chemin)
		assert_not_null(scene, "chargement de %s" % chemin)
		if scene == null:
			continue
		var noeud = scene.instantiate()
		assert_not_null(noeud, "instanciation de %s" % chemin)
		if noeud != null:
			noeud.free()


## Un `@onready var $Chemin` qui ne correspond à aucun nœud plante au premier affichage,
## pas au chargement. On vérifie donc les chemins du script à plat contre l'arbre réel.
func test_les_chemins_de_noeuds_des_scripts_existent() -> void:
	var verifies := 0
	for chemin in _lister_scenes():
		var scene = load(chemin)
		if scene == null:
			continue
		var racine = scene.instantiate()
		if racine == null:
			continue
		var script = racine.get_script()
		if script != null:
			for attendu in _chemins_dollar(script.source_code):
				verifies += 1
				assert_not_null(racine.get_node_or_null(attendu),
					"%s attend le nœud $%s" % [chemin.get_file(), attendu])
		racine.free()
	assert_true(verifies > 0, "des chemins $ ont bien été vérifiés (%d)" % verifies)


func _lister_scenes() -> Array:
	var chemins := []
	for dossier in DOSSIERS:
		_collecter(dossier, chemins)
	for extra in EN_PLUS:
		if ResourceLoader.exists(extra):
			chemins.append(extra)
	return chemins


func _collecter(dossier: String, sortie: Array) -> void:
	var dir = DirAccess.open(dossier)
	if dir == null:
		return
	dir.list_dir_begin()
	var nom = dir.get_next()
	while nom != "":
		var complet = "%s/%s" % [dossier, nom]
		if dir.current_is_dir():
			_collecter(complet, sortie)
		elif nom.ends_with(".tscn"):
			sortie.append(complet)
		nom = dir.get_next()
	dir.list_dir_end()


## Extrait les `$Un/Chemin` d'un source GDScript. On ignore les `$"..."` et les chemins
## construits dynamiquement, qui ne sont pas vérifiables statiquement.
##
## Les lignes de commentaire sont écartées : `entities/Item.gd` garde une fonction
## commentée qui référence un `$button` disparu, et la compter aurait fait échouer le
## test sur du code mort.
func _chemins_dollar(source: String) -> Array:
	var trouves := []
	var regex = RegEx.new()
	regex.compile("\\$([A-Za-z0-9_/]+)")
	for ligne in source.split("\n"):
		if ligne.strip_edges().begins_with("#"):
			continue
		for m in regex.search_all(ligne):
			var chemin = m.get_string(1)
			if not chemin in trouves:
				trouves.append(chemin)
	return trouves
