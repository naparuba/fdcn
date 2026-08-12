extends Panel
## Choix du livre — **une couverture par livre déclaré dans `books/books.json`**, posées
## dans une grille qui s'adapte à leur nombre.
##
## Rien n'est en dur ici : la scène ne porte plus deux boutons nommés `BoolSelectFcdn` /
## `BoolSelectCdsi` avec un gestionnaire chacun, sinon ajouter un livre voudrait dire
## rouvrir une scène et écrire une méthode. Les couvertures sont construites au `_ready()`
## à partir du registre.
##
## On passe par AppParameters et non par BookData directement : c'est lui qui
## persiste le choix dans parameters.json, recharge le livre, puis émet
## `book_changed` pour que Player recharge la sauvegarde de ce livre.
##
## La couverture du livre **non chargé** est grisée, avec le même shader que les
## portraits de Billy de l'inventaire (`shaders/gray.gdshader`). C'est le seul retour
## visuel qui dit lequel est en cours : sans lui, les couvertures sont identiquement
## colorées et rien ne distingue le livre actif.

var _gray_shader: Shader = preload('res://shaders/gray.gdshader')

## Où trouver la couverture d'un livre. ⚠️ Convention de nommage, pas un chemin déclaré :
## un livre sans image reste sélectionnable — son bouton porte alors son titre en texte,
## pour qu'un livre tout neuf soit jouable avant d'avoir son illustration.
const COUVERTURE := "res://books/%s/img/cover.jpg"

## Un plancher, pas une taille : les couvertures se dimensionnent sur leur case. Il évite
## seulement qu'une case devienne intouchable si la popup est écrasée.
const TAILLE_MINIMALE := Vector2(80, 80)

## Nom du livre -> son bouton de couverture.
var _covers := {}

@onready var _grille: GridContainer = $Marge/Grille


func _ready() -> void:
	var livres = BookData.get_books()
	_grille.columns = colonnes_pour(livres.size())

	for livre in livres:
		var nom = livre.get("nom", "")
		if nom == "":
			continue
		_covers[nom] = _construire_couverture(livre)

	AppParameters.book_changed.connect(_on_book_changed)
	_refresh()


## Combien de colonnes pour `n` couvertures : **la grille la plus carrée possible, jamais
## plus large que haute**.
##
##   1, 2 -> 1 colonne (l'une au-dessus de l'autre)
##   3, 4 -> 2 colonnes (3 laisse une case vide, 4 fait 2×2)
##   5, 6 -> 2 colonnes sur 3 lignes
##   7, 9 -> 3 colonnes
##
## L'app est en portrait (540 × 960) et les couvertures sont plus hautes que larges : à
## nombre de cases égal, une grille plus large que haute les rapetisse. Pour 3 livres,
## 2 colonnes sur 2 lignes donnent une image **plus grande** qu'une colonne unique — la
## hauteur est ici la ressource rare, pas la largeur.
##
## `static` pour être testable sans instancier la scène — `test_case.gd` ne sait pas encore
## `await`, donc rien d'affiché n'est vérifiable, mais la règle, elle, l'est.
static func colonnes_pour(n: int) -> int:
	var colonnes := 1
	# On élargit tant que la grille reste au moins aussi haute que large.
	while colonnes + 1 <= ceili(float(n) / (colonnes + 1)):
		colonnes += 1
	return colonnes


func _construire_couverture(livre: Dictionary) -> Control:
	var nom = livre.get("nom", "")
	var titre = livre.get("titre", nom)
	var chemin = COUVERTURE % nom

	var bouton: BaseButton
	if Utils.is_file_exists(chemin):
		var image := TextureButton.new()
		image.texture_normal = load(chemin)
		# Les deux ensemble font toute la mise à l'échelle : `ignore_texture_size` détache
		# la taille minimale du bouton de celle du fichier — sans lui, une couverture de
		# 1997 px de large imposerait sa largeur à la grille — et le `stretch_mode` la
		# redessine dans la case sans la déformer.
		image.ignore_texture_size = true
		image.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		bouton = image
	else:
		push_warning("BookSelection: pas de couverture pour %s (%s)" % [nom, chemin])
		var texte := Button.new()
		texte.text = titre
		bouton = texte

	bouton.custom_minimum_size = TAILLE_MINIMALE
	bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bouton.tooltip_text = titre
	bouton.pressed.connect(AppParameters.set_book_name.bind(nom))

	# Un matériau par couverture : `grayscale` est un paramètre du matériau, un seul
	# partagé griserait toutes les couvertures d'un coup.
	var gray_material := ShaderMaterial.new()
	gray_material.shader = _gray_shader
	bouton.material = gray_material

	_grille.add_child(bouton)
	return bouton


func _on_book_changed(_book_name) -> void:
	_refresh()


func _refresh() -> void:
	var courant = AppParameters.get_book_name()
	for nom in _covers:
		_covers[nom].material.set_shader_parameter('grayscale', nom != courant)
