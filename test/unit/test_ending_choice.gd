extends "res://addons/gut/test.gd"

var EndingChoiceScene = preload('res://EndingChoice.tscn')


func test_set_ending_type_good_sets_the_good_color():
	var ec = EndingChoiceScene.instantiate()
	ec.set_ending_type(1)  # ENDINGS.GOOD
	assert_eq(ec.get_node('EndingType').color, Color('00c2aa'))
	ec.free()


func test_set_ending_type_bad_sets_the_bad_color():
	var ec = EndingChoiceScene.instantiate()
	ec.set_ending_type(2)  # ENDINGS.BAD
	assert_eq(ec.get_node('EndingType').color, Color('ff6f04'))
	ec.free()


func test_BUG_ending_ribbon_text_always_says_good_ending_even_when_bad():
	# Trouve visuellement via une capture E2E (test/e2e/scenarios/fin_mauvaise.json) :
	# le texte "Bonne fin" du bandeau (EndingChoice.tscn::EndingType/Label)
	# est codé en dur dans la scene et n'est JAMAIS mis a jour par
	# set_ending_type(), qui ne change que la couleur du ruban. Resultat
	# reel: une mauvaise fin affiche un ruban ORANGE qui dit quand meme
	# "Bonne fin". Ce test verrouille le comportement ACTUEL (bugue) pour
	# qu'un correctif futur soit une decision consciente, pas une
	# regression silencieuse -- voir TEST_PLAN.md pour la recommandation.
	var ec = EndingChoiceScene.instantiate()
	ec.set_ending_type(2)  # ENDINGS.BAD
	assert_eq(ec.get_node('EndingType/Label').text, 'Bonne fin',
		"BUG CONNU: le texte du ruban ne suit pas le type de fin, seule la couleur change")
	ec.free()


func test_set_label_updates_text():
	var ec = EndingChoiceScene.instantiate()
	ec.set_label('Vous avez perdu')
	assert_eq(ec.get_node('Label').text, 'Vous avez perdu')
	ec.free()


func test_set_ending_id_loads_a_real_ending_image():
	var ec = EndingChoiceScene.instantiate()
	ec.set_ending_id('TULIPES')  # cf fdcn-1-compilated-data.json, noeud 163
	assert_not_null(ec.get_node('Icone').texture)
	ec.free()


func test_set_ending_id_with_unknown_id_does_not_crash():
	var ec = EndingChoiceScene.instantiate()
	ec.set_ending_id('CECI_NEXISTE_PAS_DU_TOUT')
	assert_null(ec.get_node('Icone').texture)
	ec.free()
