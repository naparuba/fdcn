extends Panel


onready var already_seen_polygon = $AlreadySeenPolygon
onready var session_seen_polygon = $SessionSeenPolygon
onready var combat_polygon = $CombatPolygon


var COLOR_NOT_SET = Color('e0e2e5')  # very light grey

var chap_number
var spoil_enabled = false
var main

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func set_main(main):
	self.main = main


func set_spoil_enabled(b):
	self.spoil_enabled = b
	$CombatPolygon.visible = self.spoil_enabled
	$EndPolygon.visible = self.spoil_enabled
	$SuccessPolygon.visible = self.spoil_enabled
	$SecretPolygon.visible = self.spoil_enabled
	$Label.visible = self.spoil_enabled


func get_chapter_id():
	return self.chap_number


func set_chapitre(chapitre):
	self.chap_number = chapitre
	$NBChapitre.text = '%3d' % chapitre
	
	
func set_label(label):
	$Label.text = label


func set_already_seen():
	$AlreadySeenPolygon.color = Color('00c2aa')

func set_not_already_seen():
	$AlreadySeenPolygon.color = COLOR_NOT_SET

func set_session_seen():
	$SessionSeenPolygon.color = Color('00c2aa')

func set_session_not_seen():
	$SessionSeenPolygon.color = COLOR_NOT_SET

func set_combat():
	$CombatPolygon.color = Color('ff6f04')
	
func set_not_combat():
	$CombatPolygon.color = COLOR_NOT_SET

func set_ending():
	$EndPolygon.color = Color('00c2aa')

func set_not_ending():
	$EndPolygon.color = COLOR_NOT_SET

func set_success():
	$SuccessPolygon.color = Color('00c2aa')

func set_not_success():
	$SuccessPolygon.color = COLOR_NOT_SET

func set_secret():
	$SecretPolygon.color = Color('00c2aa')
	

func set_condition_txt(condition_txt):
	$special.text = condition_txt
	

func enable_special_jump():
	$special.visible = true
	$special.set("custom_colors/font_color",Color('00c2aa'))
	$click/special.visible = true
	$click/special_wrong.visible = false

func enable_special_jump_wrong():
	$special.visible = true
	$special.set("custom_colors/font_color",Color(1,0,0))
	$click/special.visible = false	
	$click/special_wrong.visible = true	


func disable_special_jump():
	$special.visible = false
	$special.set("custom_colors/font_color",Color(1,0,0))
	$click/special.visible = false	
	$click/special_wrong.visible = false	


func _on_Button_pressed():
	print('CLICK: on chapter: %s' % self.chap_number)
	self.main.go_to_node(self.chap_number)


func update_from_son_node(son):
	var son_id = son.get_id()
	self.set_chapitre(son.get_id())
	# Update if spoils need to be shown (or not), can depend if we already seen this node
	if BookData.is_node_id_freely_full_on_all_chapters(son_id):
		self.set_spoil_enabled(true)
	else:  # only follow the parameter
		self.set_spoil_enabled(false)
	
	if son.is_combat():
		self.set_combat()
	if Player.did_billy_seen(son_id):
		self.set_session_seen()
	if Player.did_all_times_seen(son_id):
		self.set_already_seen()
	if son.get_ending():
		self.set_ending()
	if son.get_success():
		self.set_success()
	if son.get_secret():
		self.set_secret()
	if son.get_label():
		self.set_label(son.get_label())
		
	# Check special jump/conditions
	var have_jump_conditions = BookData.have_chapter_conditions(Player.get_current_node_id(), son_id)
	if have_jump_conditions:
		var jump_condition_txt = BookData.get_condition_txt(Player.get_current_node_id(), son_id)
		self.set_condition_txt(jump_condition_txt)
		var is_special = BookData.match_chapter_conditions(Player.get_current_node_id(), son_id)
		if is_special:
			self.enable_special_jump()
		else:
			self.enable_special_jump_wrong()
	else:  # classic node
		self.disable_special_jump()

func update_when_in_all_chapters():
	var chapter_id = self.get_chapter_id()
	var chapter_data = BookData.get_node(chapter_id)
		
	# Update if spoils need to be shown (or not), can depend if we already seen this node
	if BookData.is_node_id_freely_full_on_all_chapters(chapter_id):
		self.set_spoil_enabled(true)
	else:  # only follow the parameter
		self.set_spoil_enabled(false)
	# Session seen
	if Player.did_billy_seen(chapter_id):
		self.set_session_seen()
	else:
		self.set_session_not_seen()
	# All time seen
	if Player.did_all_times_seen(chapter_id):
		self.set_already_seen()
	else:
		self.set_not_already_seen()
	# Ending or not
	if chapter_data.get_ending():
		self.set_ending()
	else:
		self.set_not_ending()
	# Success or not
	if chapter_data.get_success():
		self.set_success()
	else:
		self.set_not_success()
	# label if any
	var _label = chapter_data.get_label()
	if _label != null:
		self.set_label(_label)
	# secret
	if chapter_data.get_secret():
		self.set_secret()
