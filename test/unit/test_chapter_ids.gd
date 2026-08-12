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
	item.set_chapitre(26.0)
	assert_eq(typeof(item.chap_number), TYPE_INT, "chap_number est un entier")
	assert_eq(item.chap_number, 26, "valeur conservée")
	item.update()
	assert_true(item._get_polygon.color.is_equal_approx(Color('00c2aa')),
		"le ruban est vert pour un succès acquis")
	item.set_chapitre(999.0)
	item.update()
	assert_false(item._get_polygon.color.is_equal_approx(Color('00c2aa')),
		"le ruban reste gris pour un succès non acquis")
	# `free()` et non `queue_free()` : celui-ci diffère à la fin de la frame, or le lanceur
	# appelle `quit()` juste après le dernier test. Le nœud n'était donc jamais libéré et
	# comptait comme une fuite dans le bilan de sortie.
	item.free()


func test_chapter_choice_stocke_un_entier() -> void:
	var choice = preload("res://entities/ChapterChoice.tscn").instantiate()
	Engine.get_main_loop().root.add_child(choice)
	choice.set_chapitre(26.0)
	assert_eq(typeof(choice.chap_number), TYPE_INT, "chap_number est un entier")
	assert_eq(choice.get_chapter_id(), 26, "valeur conservée")
	choice.free()  # immédiat, pas différé : voir la note du test précédent
