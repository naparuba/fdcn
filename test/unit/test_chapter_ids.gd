extends "res://test/test_case.gd"
## Identifiants de chapitre : entiers contre flottants.
##
## Le JSON du livre rend tous les nombres en **float** (`26.0`), alors que les
## listes de chapitres visités contiennent des **int**. Or en GDScript
## `26.0 in [26]` vaut **false** : sans conversion, tous les marqueurs
## « déjà vu » restent éteints — ruban « Obtenu » gris sur un succès pourtant
## acquis, choix de chapitre jamais marqués comme visités.
##
## Ces tests verrouillent la conversion, côté prédicats comme côté entités.


func before_each() -> void:
	Player.visited_nodes_all_times = [1, 26, 87]
	Player.session_visited_nodes = [1, 26]


#
#    La cause racine — si ce test casse, GDScript a changé de sémantique
#

func test_gdscript_ne_melange_pas_float_et_int_dans_un_tableau() -> void:
	assert_false(26.0 in [26], "26.0 in [26] doit rester faux")
	assert_true(26 in [26], "26 in [26] est vrai")


#
#    Les prédicats de Player acceptent les deux types
#

func test_did_all_times_seen_accepte_un_float() -> void:
	assert_true(Player.did_all_times_seen(26), "entier vu")
	assert_true(Player.did_all_times_seen(26.0), "float vu (venant du JSON)")
	assert_false(Player.did_all_times_seen(999), "entier non vu")
	assert_false(Player.did_all_times_seen(999.0), "float non vu")


func test_did_billy_seen_accepte_un_float() -> void:
	assert_true(Player.did_billy_seen(26), "entier vu par ce Billy")
	assert_true(Player.did_billy_seen(26.0), "float vu par ce Billy")
	assert_false(Player.did_billy_seen(87.0), "vu autrefois mais pas par ce Billy")


#
#    Les entités stockent un entier, quel que soit ce qu'on leur donne
#

func test_success_item_stocke_un_entier() -> void:
	var item = preload("res://entities/SuccessItem.tscn").instantiate()
	Engine.get_main_loop().root.add_child(item)
	# fdcn 26 donne POLIR-LANCE : `update()` doit le reconnaître comme déjà obtenu.
	item.set_success_id("POLIR-LANCE")
	item.set_chapitre(26.0)
	assert_eq(typeof(item.chap_number), TYPE_INT, "chap_number est un entier")
	assert_eq(item.chap_number, 26, "valeur conservée")
	item.update()
	assert_true(item._get_polygon.color.is_equal_approx(Color('00c2aa')),
		"le ruban est vert pour un succès acquis")
	# `free()` et non `queue_free()` : celui-ci diffère à la fin de la frame, or le lanceur
	# appelle `quit()` juste après le dernier test. Le nœud n'était donc jamais libéré et
	# comptait comme une fuite dans le bilan de sortie.
	# TROIE (fdcn 112) n'est pas dans les chapitres visités du before_each : gris.
	# ⚠️ Le ruban regarde `success_id`, pas `chap_number` — changer `chap_number` seul,
	# comme le faisait cette ligne avant, ne pouvait jamais faire passer le test.
	item.set_success_id("TROIE")
	item.set_chapitre(999.0)
	item.update()
	assert_false(item._get_polygon.color.is_equal_approx(Color('00c2aa')),
		"le ruban reste gris pour un succès non acquis")
	item.free()


func test_chapter_choice_stocke_un_entier() -> void:
	var choice = preload("res://entities/ChapterChoice.tscn").instantiate()
	Engine.get_main_loop().root.add_child(choice)
	choice.set_chapitre(26.0)
	assert_eq(typeof(choice.chap_number), TYPE_INT, "chap_number est un entier")
	assert_eq(choice.get_chapter_id(), 26, "valeur conservée")
	choice.free()  # immédiat, pas différé : voir la note du test précédent


## `Chapter.get_id()` (chapter_data.gd) rend un float, comme tout ce qui vient du json.
## `set_chapter_number()` ne le convertissait pas avant de le formater : `'%s' % 1.0`
## affiche "1.0", pas "1" — trouvé en vérifiant que le générateur et l'app restent
## d'accord (2026-08-29).
func test_position_affiche_un_entier() -> void:
	var position = preload("res://screens/aventure_menu/Position.tscn").instantiate()
	Engine.get_main_loop().root.add_child(position)
	position.set_chapter_number(26.0)
	assert_eq(position._numero_chapitre.text, "26", "pas de \".0\" affiché")
	position.free()


## `ChapterChoice.gd::update_from_son_node()` appelle `BookData.have_chapter_conditions()`/
## `match_chapter_conditions()`/`get_condition_txt()` avec `son.get_id()`, un float comme
## tout `chapter_data.gd::get_id()`. Sans cast côté `BookData._jump_condition()`, la clé de
## condition ("11.0") ne correspondait jamais à celle du livre compilé ("11") : le saut
## spécial ne se coloriait donc JAMAIS, ni en vert ni en rouge, sur aucun chapitre.
func test_condition_de_saut_accepte_un_float() -> void:
	Inventory.force_billy_type('guerrier')
	assert_true(BookData.have_chapter_conditions(2, 11.0), "2 -> 11.0 a une condition")
	assert_true(BookData.match_chapter_conditions(2, 11.0), "le GUERRIER passe par 11.0")
	assert_eq(BookData.get_condition_txt(2, 11.0), "GUERRIER", "texte trouvé avec un float")
