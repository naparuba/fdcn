extends PanelContainer

signal combat_finished()

@onready var _nom = $VBoxContainer/Margin/Content/NomRow/Nom

@onready var _ennemi_pv = $VBoxContainer/Margin/Content/StatsGrid/EnnemiPvValue
@onready var _ennemi_arm = $VBoxContainer/Margin/Content/StatsGrid/EnnemiArmValue
@onready var _ennemi_hab = $VBoxContainer/Margin/Content/StatsGrid/EnnemiHabValue
@onready var _ennemi_deg = $VBoxContainer/Margin/Content/StatsGrid/EnnemiDegValue

@onready var _player_pv = $VBoxContainer/Margin/Content/StatsGrid/PlayerPvValue
@onready var _player_arm = $VBoxContainer/Margin/Content/StatsGrid/PlayerArmValue
@onready var _player_hab = $VBoxContainer/Margin/Content/StatsGrid/PlayerHabValue
@onready var _player_deg = $VBoxContainer/Margin/Content/StatsGrid/PlayerDegValue

@onready var _pyro_row = $VBoxContainer/Margin/Content/PyroRow
@onready var _pyro_hab = $VBoxContainer/Margin/Content/PyroRow/PyroHab

@onready var _dice_sprite = $VBoxContainer/Margin/Content/DiceRow/dice/sprite


func set_enemy(node) -> void:
	_nom.text = node.get_combat_name()
	_ennemi_pv.text = '%s' % node.get_combat_pv()
	_ennemi_arm.text = '%s' % node.get_combat_armure()
	_ennemi_hab.text = '%s' % node.get_combat_hab()
	_ennemi_deg.text = '%s' % node.get_combat_degat()

	var hab_pyro = node.get_combat_pyro()
	_pyro_row.visible = hab_pyro != 0
	if hab_pyro != 0:
		_pyro_hab.text = '+%s' % hab_pyro


func update_player_stats() -> void:
	_player_pv.text = '%s' % Player.get_pv()
	_player_hab.text = '%s' % Player.get_hab()
	_player_arm.text = '%s' % Player.get_arm()
	_player_deg.text = '%s' % Player.get_deg()


func _on_dice_pressed() -> void:
	var res = Utils.roll_a_dice(1, 6)
	_dice_sprite.texture = Utils.load_external_texture('res://images/dice/%s-b.svg' % res, null)


func _on_i_win_pressed() -> void:
	combat_finished.emit()
