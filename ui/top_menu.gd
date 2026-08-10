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
	if AppParameters.is_node_ready():
		_apply_settings()
	else:
		AppParameters.settings_loaded.connect(_apply_settings)

func _apply_settings() -> void:
	$HBoxContainer/Spoil/SpoilButton.button_pressed = AppParameters.are_spoils_ok()
	$HBoxContainer/Sound/SoundButton.button_pressed = AppParameters.is_sound_ok()

func _on_spoil_button_toggled(button_pressed):
	AppParameters.set_spoils(button_pressed)

func _on_sound_button_toggled(button_pressed):
	AppParameters.set_sound(button_pressed)


#
#    TODO
#

var main = null


func set_billy():
	var type_billy = AppParameters.get_billy_type()
	var billys = {'guerrier': $Billys/BlockGuerrier,
	'paysan':$Billys/BlockPaysan,
	'prudent':$Billys/BlockPrudent,
	'debrouillard':$Billys/BlockDebrouillard
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
	$Billys/BillyTypeLabel.text = billy_strings[type_billy]


func set_page(page_name):
	var pages = {'main': $Pages/BlockMain,
	'chapitres':$Pages/BlockChapitres,
	'success':$Pages/BlockSuccess,
	'lore':$Pages/BlockLore
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
	$HBoxContainer/BookSelection/logo.texture = load("res://books/%s/logo.png" % book_name)
	$HBoxContainer/BookSelection/title.texture = load("res://books/%s/title.png" % book_name)


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


func _switch_to_guerrier():
	print('guerrier')
	self.main._switch_to_guerrier()


func _switch_to_paysan():
	print('paysan')
	self.main._switch_to_paysan()


func _switch_to_prudent():
	print('prudent')
	self.main._switch_to_prudent()


func _switch_to_debrouillard():
	print('debrouillard')
	self.main._switch_to_debrouillard()
