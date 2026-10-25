extends "res://addons/gut/test.gd"

# Items reels du livre 1 (fdcn-1.all_objects.json), utilises comme fixtures
# stables pour verrouiller la logique de determination du type de Billy.
# ARME: EPEE, MORGENSTERN, LANCE
# EQUIPEMENT: MARMITE, COTTE DE MAILLES
# OUTIL: COUTEAU, KIT D'ESCALADE

func before_all():
	# Construit le catalogue d'objets une seule fois pour tout le fichier
	# (evite de creer/laisser fuiter des dizaines de noeuds Item par test).
	Player.insert_all_objects()


func before_each():
	Player.launch_new_billy()
	AppParameters.set_billy_type('pegu')
	Player._recompute_stats()


func _assert_billy(type):
	assert_eq(type, AppParameters.get_billy_type(), 'we want a %s' % type)


func test_less_than_3_items_is_always_pegu():
	Player.add_item_from_options('EPEE')
	_assert_billy('pegu')
	Player.add_item_from_options('MARMITE')
	_assert_billy('pegu')


func test_two_weapons_makes_guerrier():
	Player.add_item_from_options('EPEE')
	Player.add_item_from_options('MORGENSTERN')
	Player.add_item_from_options('KIT DE SOIN')  # EQUIPEMENT, complete a 3 total
	_assert_billy('guerrier')


func test_two_equipements_makes_prudent():
	Player.add_item_from_options('MARMITE')
	Player.add_item_from_options('COTTE DE MAILLES')
	Player.add_item_from_options("KIT D'ESCALADE")  # OUTIL, complete a 3 total
	_assert_billy('prudent')


func test_two_outils_makes_paysan():
	Player.add_item_from_options('COUTEAU')
	Player.add_item_from_options("KIT D'ESCALADE")
	Player.add_item_from_options('EPEE')  # ARME, complete a 3 total
	_assert_billy('paysan')


func test_one_of_each_category_makes_debrouillard():
	Player.add_item_from_options('EPEE')       # ARME
	Player.add_item_from_options('MARMITE')    # EQUIPEMENT
	Player.add_item_from_options('COUTEAU')    # OUTIL
	_assert_billy('debrouillard')


func test_removing_an_item_recomputes_billy_type():
	Player.add_item_from_options('EPEE')
	Player.add_item_from_options('MORGENSTERN')
	Player.add_item_from_options('KIT DE SOIN')
	_assert_billy('guerrier')
	Player.remove_item_from_options('MORGENSTERN')
	# Il ne reste qu'1 arme + 1 equipement = 2 objets < 3 => pegu
	_assert_billy('pegu')


func test_overload_never_removes_the_item_just_added():
	# 3 armes = pas d'overload (limite = 3 objets)
	Player.add_item_from_options('EPEE')
	Player.add_item_from_options('MORGENSTERN')
	Player.add_item_from_options('LANCE')
	assert_eq(Player.billy_overload_size(), 0)
	assert_true(Player.have_item('EPEE'))
	assert_true(Player.have_item('MORGENSTERN'))
	assert_true(Player.have_item('LANCE'))

	# Un 4e objet declenche l'overload (clean_billy_overload), mais l'objet
	# qu'on vient d'ajouter ne doit JAMAIS etre celui qui est retire
	# (cf player.gd: "if item_name != new_option").
	Player.add_item_from_options('MARMITE')
	assert_true(Player.have_item('MARMITE'), "l'objet juste ajoute ne doit pas etre celui retire par l'overload")
	var nb_possessed = 0
	for item_name in ['EPEE', 'MORGENSTERN', 'LANCE', 'MARMITE']:
		if Player.have_item(item_name):
			nb_possessed += 1
	assert_eq(nb_possessed, 3, "au plus 3 objets doivent rester possedes apres un overload")
