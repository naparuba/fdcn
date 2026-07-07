extends Panel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self._refresh_options_stats()
	print("okok")

func _refresh_options_stats():
	$VBoxContainer/PlayerPv/PlayerPvValue.text = '%s' % Player.get_pv()
	$VBoxContainer/PlayerPv/PlayerPvValueDetail.text = ''

	$VBoxContainer/PlayerEnd/PlayerEndValue.text = '%s' % Player.get_end()
	$VBoxContainer/PlayerEnd/PlayerEndValueDetail.text = '(base:2, item/billy:%s' % Player.get_end_items() + ', chapitres:%s)' % Player.get_end_chapters()

	$VBoxContainer/PlayerHab/PlayerHabValue.text = '%s' % Player.get_hab()
	$VBoxContainer/PlayerHab/PlayerHabValueDetail.text = '(base:2, item/billy:%s' % Player.get_hab_items() + ', chapitres:%s)' % Player.get_hab_chapters()

	$VBoxContainer/PlayerAdr/PlayerAdrValue.text = '%s' % Player.get_adr()
	$VBoxContainer/PlayerAdr/PlayerAdrValueDetail.text = '(base:1, item/billy:%s' % Player.get_adr_items() + ', chapitres:%s)' % Player.get_adr_chapters()

	$VBoxContainer/PlayerCha/PlayerChaValue.text = ('%s' % Player.get_cha()) + ('/%s' % Player.get_chamax())
	$VBoxContainer/PlayerCha/PlayerChaValueDetail.text = '(base:3, item/billy:%s' % Player.get_chamax_items() + ', chapitres:%s)' % Player.get_chamax_chapters()

	$VBoxContainer/PlayerCrit/PlayerCritValue.text = '%s' % Player.get_crit()
	$VBoxContainer/PlayerCrit/PlayerCritValueDetail.text = '(item/billy:%s' % Player.get_crit_items() + ', chapitres:%s)' % Player.get_crit_chapters()

	$VBoxContainer/PlayerDeg/PlayerDegValue.text = '%s' % Player.get_deg()
	$VBoxContainer/PlayerDeg/PlayerDegValueDetail.text = '(item/billy:%s' % Player.get_deg_items() + ', chapitres:%s)' % Player.get_deg_chapters()

	$VBoxContainer/PlayerArm/PlayerArmValue.text = '%s' % Player.get_arm()
	$VBoxContainer/PlayerArm/PlayerArmValueDetail.text = '(item/billy:%s' % Player.get_arm_items() + ', chapitres:%s)' % Player.get_arm_chapters()
