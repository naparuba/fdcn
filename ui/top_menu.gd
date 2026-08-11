extends Panel

@export var popup_container: Container
var _opened_popup: Node

var _settings_open: bool = false
@onready var popup_settings: PackedScene = preload("res://popups/SettingsPopup.tscn")

func _on_button_options():
	print('SHOW OPTIONS')
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


func _on_billy_changed(_billy_type) -> void:
	set_billy()


# Tout ce que le menu lit dans les paramètres persistés, dont le type de Billy.
# `set_pressed_no_signal` : `settings_changed` part souvent PARCE QUE le joueur
# vient de cliquer un de ces deux interrupteurs, inutile de relancer `toggled`.
func _apply_settings() -> void:
	$Margin/HBoxContainer/Spoil/SpoilButton.set_pressed_no_signal(AppParameters.are_spoils_ok())
	$Margin/HBoxContainer/Sound/SoundButton.set_pressed_no_signal(AppParameters.is_sound_ok())
	set_billy()

func _on_spoil_button_toggled(button_pressed):
	AppParameters.set_spoils(button_pressed)

func _on_sound_button_toggled(button_pressed):
	AppParameters.set_sound(button_pressed)


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
		#print('STYLE: %s' % _style)
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


#
#    TODO
#

func set_page(page_name):
	var pages = {'main': $Margin/HBoxContainer/Pages/BlockMain,
	'chapitres':$Margin/HBoxContainer/Pages/BlockChapitres,
	'success':$Margin/HBoxContainer/Pages/BlockSuccess,
	'lore':$Margin/HBoxContainer/Pages/BlockLore
	}
	
	for page in pages.keys():
		var panel = pages[page]
		var _style = panel.get('theme_override_styles/panel')
		#print('STYLE: %s' % _style)
		_style.set_bg_color(Color('e9eaec'))  # set to light grey
	# NOTE: about is not an icon, only with swipe
	if page_name in pages:
		pages[page_name].get('theme_override_styles/panel').set_bg_color(Color('9ea8b4'))  # set to dark grey


func set_book_context():
	var book_name = AppParameters.get_book_name()
	$Margin/HBoxContainer/BookSelection/logo.texture = load("res://books/%s/logo.png" % book_name)
	$Margin/HBoxContainer/BookSelection/title.texture = load("res://books/%s/title.png" % book_name)


# Le menu du haut est réutilisable : il ne connaît pas son conteneur de pages,
# il le retrouve en remontant l'arbre. Renvoie null hors d'un MenuPage (cas de
# l'archive), auquel cas les boutons de page ne font simplement rien.
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

# NOTE: page about do NOT have a button


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
