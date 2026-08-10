extends "res://test/test_case.gd"
## Déduction du type de Billy à partir des objets portés.
##
## Migré depuis GUT (l'addon embarqué était en Godot 3, il a été supprimé).
##
## Le lanceur a redirigé les sauvegardes ET le fichier de paramètres vers un
## dossier jetable : `launch_new_billy()` et les ajouts d'objets ci-dessous
## n'écrivent donc rien dans la vraie partie du joueur.


func before_each() -> void:
	Player.launch_new_billy()
	AppParameters.set_billy_type('pegu')
	PlayerStats.recompute()


func _assert_billy(attendu: String) -> void:
	assert_eq(AppParameters.get_billy_type(), attendu, "type de Billy")


func test_stats_de_base_dun_billy_neuf() -> void:
	assert_eq(PlayerStats.get_stat('hab'), 2, "habileté de base")
	assert_eq(PlayerStats.get_stat('end'), 2, "endurance de base")
	assert_eq(PlayerStats.get_stat('adr'), 1, "adresse de base")
	assert_eq(PlayerStats.get_stat('chamax'), 3, "chance max de base")
	assert_eq(Inventory.get_possessed_items().size(), 0, "inventaire vide")


# On ne devient guerrier qu'avec 2 armes ET 3 objets au total.
func test_devient_guerrier_avec_deux_armes_et_trois_objets() -> void:
	Inventory.add_item_from_options('EPEE')
	_assert_billy('pegu')
	Inventory.add_item_from_options('MORGENSTERN')
	_assert_billy('pegu')
	Inventory.add_item_from_options('KIT DE SOIN')
	_assert_billy('guerrier')


func test_les_modificateurs_du_type_vont_dans_la_couche_items() -> void:
	Inventory.add_item_from_options('EPEE')
	Inventory.add_item_from_options('MORGENSTERN')
	Inventory.add_item_from_options('KIT DE SOIN')
	assert_eq(AppParameters.get_billy_type(), 'guerrier', "on est bien guerrier")
	# Le guerrier gagne +2 en habileté, qui doit apparaître dans la couche items.
	assert_true(PlayerStats.get_stat('hab', PlayerStats.LAYER_ITEMS) >= 2,
		"le bonus du type est dans la couche items")
	assert_true(PlayerStats.get_stat('hab') > 2, "le total dépasse la base")


func test_on_ne_porte_jamais_plus_de_trois_objets() -> void:
	for objet in ['EPEE', 'MORGENSTERN', 'KIT DE SOIN', 'LANCE']:
		Inventory.add_item_from_options(objet)
	assert_true(Inventory.get_possessed_items().size() <= Inventory.MAX_CARRIED,
		"au plus MAX_CARRIED objets portés")


# Le type imposé depuis le menu du haut passe par `force_billy_type()`, qui doit
# émettre `billy_changed` (c'est ce signal qui rafraîchit l'interface, review §2.4)
# et recalculer les stats, puisque le type donne des modificateurs.
func test_forcer_le_type_emet_le_signal_et_recalcule_les_stats() -> void:
	var recus := []
	var recepteur := func(billy_type): recus.append(billy_type)
	Inventory.billy_changed.connect(recepteur)

	Inventory.force_billy_type('guerrier')

	assert_eq(recus, ['guerrier'], "billy_changed émis une fois avec le type")
	_assert_billy('guerrier')
	assert_eq(PlayerStats.get_stat('hab', PlayerStats.LAYER_ITEMS), 2,
		"le +2 hab du guerrier est appliqué")
	assert_eq(PlayerStats.get_stat('chamax'), 2, "le -1 chamax du guerrier est appliqué")

	# Reposer le même type ne doit rien rediffuser.
	Inventory.force_billy_type('guerrier')
	assert_eq(recus.size(), 1, "pas de signal pour un type inchangé")

	Inventory.billy_changed.disconnect(recepteur)


func test_les_conditions_contiennent_objets_et_type_de_billy() -> void:
	Inventory.add_item_from_options('EPEE')
	var conditions = Inventory.get_all_matched_conditions()
	assert_true('EPEE' in conditions, "l'objet porté est une condition")
	assert_true(AppParameters.get_billy_type().to_upper() in conditions,
		"le type de Billy est une condition")
