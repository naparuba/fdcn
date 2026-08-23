extends Panel
## La barre du haut : navigation entre pages, réglages, type de Billy, logo du livre.
##
## **Plusieurs exemplaires vivent en même temps** (un par `MenuPage`) : rien ici ne pousse
## une mise à jour vers « les autres », chaque instance se repeint elle-même via les
## signaux globaux (`AppParameters.settings_changed`/`book_changed`, `Inventory.billy_changed`).
##
## Réutilisable hors d'un `MenuPage` : `_go_to_page()` retrouve son conteneur en remontant
## l'arbre et ne fait rien s'il n'y en a pas (cas de l'archive), plutôt que de planter.

@export var popup_container: Container
var _opened_popup: Node

var _settings_open: bool = false
@onready var popup_settings: PackedScene = preload("res://popups/SettingsPopup.tscn")

## Bouton à bascule : ferme la popup si elle est ouverte, sinon en ouvre une neuve.
## `queue_free()` inconditionnel d'abord — rouvrir doit repartir d'une instance propre,
## pas de celle laissée par le clic précédent.
func _on_button_options():
	if _opened_popup:
		_opened_popup.queue_free()

	if not _settings_open:
		_opened_popup = popup_settings.instantiate()
		popup_container.add_child(_opened_popup)
		_settings_open = true
	else:
		_settings_open = false

# Called when the node enters the scene tree for the first time.
func _ready():
	# On se branche sans condition et on peint tout de suite, comme les écrans de
	# listes : `settings_changed` couvre le chargement initial ET les
	# modifications ultérieures, il n'y a rien à attendre.
	AppParameters.settings_changed.connect(_apply_settings)
	_apply_settings()

	# Le type de Billy est déduit de l'inventaire : le menu se réaffiche tout
	# seul quand il change, personne n'a besoin de le lui pousser.
	Inventory.billy_changed.connect(_on_billy_changed)

	# Le logo et le titre viennent de `books/<nom>/` : ils doivent suivre le livre courant.
	# `set_book_context()` existait déjà mais **personne ne l'appelait** — seule l'archive
	# le faisait. La scène montrait donc pour toujours le logo du premier livre, qu'elle
	# portait en dur comme aperçu d'éditeur, même après un changement de livre.
	#
	# L'appel immédiat compte autant que l'abonnement : au démarrage sur cdsi, aucun
	# `book_changed` ne part (le livre n'a pas *changé*), et la barre resterait sur fdcn.
	AppParameters.book_changed.connect(func(_nom): set_book_context())
	set_book_context()


func _on_billy_changed(_billy_type) -> void:
	set_billy()


# Tout ce que le menu lit dans les paramètres persistés, dont le type de Billy.
# `set_state` et non `set_pressed_no_signal` : les deux interrupteurs portent
# `ui/yes_no_switch.gd`, qui doit repeindre sa couleur et son libellé. Le silence est le
# même — `settings_changed` part souvent PARCE QUE le joueur vient de cliquer l'un des
# deux, inutile de relancer `toggled` — mais l'affichage suit.
func _apply_settings() -> void:
	$Margin/HBoxContainer/Spoil/SpoilButton.set_state(AppParameters.are_spoils_ok())
	$Margin/HBoxContainer/Sound/SoundButton.set_state(AppParameters.is_sound_ok())
	set_billy()

func _on_spoil_button_toggled(button_pressed):
	AppParameters.set_spoils(button_pressed)

func _on_sound_button_toggled(button_pressed):
	AppParameters.set_sound(button_pressed)


## Surligne le bloc du type de Billy courant, et rien de plus si c'est `pegu` — le type
## « aucune affinité déterminée » (`Inventory.compute_billy_for_option()`) n'a pas de bloc
## à lui, il n'en existe que 4 dans `billys`.
func set_billy():
	var type_billy = AppParameters.get_billy_type()
	var billys = {'guerrier': $Margin/HBoxContainer/Billys/BlockGuerrier,
	'paysan':$Margin/HBoxContainer/Billys/BlockPaysan,
	'prudent':$Margin/HBoxContainer/Billys/BlockPrudent,
	'debrouillard':$Margin/HBoxContainer/Billys/BlockDebrouillard
	}
	
	for billy in billys.keys():
		var panel = billys[billy]
		var _style = panel.get('theme_override_styles/panel')
		_style.set_bg_color(Color('e9eaec'))  # set to light grey
	if type_billy != 'pegu':
		billys[type_billy].get('theme_override_styles/panel').set_bg_color(Color('9ea8b4'))  # set to dark grey
	
	var billy_strings = {
		'guerrier': 'Guerrier',
		'paysan': 'Paysan',
		'prudent': 'Prudent',
		'debrouillard': 'Débrouillard',
		'pegu': 'Pegu!!'
	}
	$Margin/HBoxContainer/Billys/BillyTypeLabel.text = billy_strings[type_billy]


## Surligne le bloc de la page courante. La page « à propos » n'a pas d'icône dans cette
## barre (accessible seulement par swipe) : `page_name` peut donc valoir une page absente
## de `pages`, auquel cas `set_page()` désurligne tout sans rien resurligner.
func set_page(page_name):
	var pages = {'main': $Margin/HBoxContainer/Pages/BlockMain,
	'chapitres':$Margin/HBoxContainer/Pages/BlockChapitres,
	'success':$Margin/HBoxContainer/Pages/BlockSuccess,
	'lore':$Margin/HBoxContainer/Pages/BlockLore
	}

	for page in pages.keys():
		var panel = pages[page]
		var _style = panel.get('theme_override_styles/panel')
		_style.set_bg_color(Color('e9eaec'))  # set to light grey
	if page_name in pages:
		pages[page_name].get('theme_override_styles/panel').set_bg_color(Color('9ea8b4'))  # set to dark grey


## Le logo et le titre du livre courant. La scène ne porte plus ceux de fdcn en dur : elle
## en aurait fait une dépendance de `top_menu.tscn`, donc un livre impossible à retirer du
## dépôt sans casser la barre du haut. Un livre sans image laisse simplement la case vide,
## avec son avertissement — il reste jouable.
func set_book_context():
	var book_name = AppParameters.get_book_name()
	$Margin/HBoxContainer/BookSelection/logo.texture = _image_du_livre(book_name, "logo")
	$Margin/HBoxContainer/BookSelection/title.texture = _image_du_livre(book_name, "title")


func _image_du_livre(book_name: String, quoi: String) -> Texture2D:
	var chemin = "res://books/%s/img/%s.png" % [book_name, quoi]
	if not Utils.is_file_exists(chemin):
		push_warning("TopMenu: image de livre introuvable: %s" % chemin)
		return null
	return load(chemin)


## Retrouve le conteneur de pages en remontant l'arbre plutôt que de le connaître
## directement : hors d'un `MenuPage`, `menu_page` vaut `null` et les boutons de page ne
## font simplement rien, au lieu de planter.
func _go_to_page(page_name: String) -> void:
	var menu_page = Utils.find_ancestor_with_method(self, "go_to_page")
	if menu_page == null:
		return
	menu_page.go_to_page(page_name)


func focus_to_main():
	_go_to_page("aventure")


func focus_to_chapitres():
	_go_to_page("chapitres")

func focus_to_success():
	_go_to_page("succes")

func focus_to_lore():
	_go_to_page("lore")


# Les quatre boutons de type imposent le Billy directement à l'Inventory, qui
# rediffuse `billy_changed` : c'est ce signal qui rafraîchit ce menu (et tous les
# autres exemplaires), il n'y a plus de pont vers un objet « main ».
func _switch_to_guerrier():
	Inventory.force_billy_type('guerrier')


func _switch_to_paysan():
	Inventory.force_billy_type('paysan')


func _switch_to_prudent():
	Inventory.force_billy_type('prudent')


func _switch_to_debrouillard():
	Inventory.force_billy_type('debrouillard')
