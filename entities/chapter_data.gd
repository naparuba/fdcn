extends Node

var _book_data = {}
# Exemple of book_data entry
#"computed": {
#            "aquire": [],
#            "arc": "Catacombes",
#            "chapter": "Forteresse",
#            "ending": false,
#            "ending_id": null,
#            "ending_txt": null,
#            "ending_type": null,
#            "id": 212,
#            "is_combat": false,
#            "combat": {
#                "arm": 0,
#                "deg": 0,
#                "hab": 13,
#                "nom": "PLANTE CARNITREX",
#                "pv": 18,
#                "pyro": 7
#            },
#            "jump_conditions": {},
#            "jump_conditions_txts": {},
#            "label": null,
#            "remove": [
#                "MEDAILLON D'EDIRE"
#            ],
#            "secret": false,
#            "secret_jumps": [],
#            "sons": [
#                25
#            ],
#            "success": null
#        },

func create(book_data):
	self._book_data = book_data


func get_id():
	return self._book_data['computed']['id']


func get_chapter():
	return self._book_data['computed']['chapter']

func get_arc():
	return self._book_data['computed']['arc']

func get_jump_conditions():
	return self._book_data['computed']['jump_conditions']

func get_jump_conditions_txts():
	return self._book_data['computed']['jump_conditions_txts']

func get_stats():
	return self._book_data['computed']['stats']

func get_stats_cond():
	return self._book_data['computed']['stats_cond']

func get_ending():
	return self._book_data['computed']['ending']

func get_ending_id():
	return self._book_data['computed']['ending_id']

func get_ending_txt():
	return self._book_data['computed']['ending_txt']

func get_ending_type():
	return self._book_data['computed']['ending_type']

func get_success():
	return self._book_data['computed']['success']

func get_label():
	return self._book_data['computed']['label']


func get_secret():
	return self._book_data['computed']['secret']

func get_sons():
	return self._book_data['computed']['sons']

func get_secret_jumps():
	return self._book_data['computed']['secret_jumps']

func is_combat():
	return self._book_data['computed']['is_combat']


# TODO: the 276 is a list
func _get_combat():
	var combat = self._book_data['computed']['combat']
	#print('type: %s , array=' % typeof(combat), '=%s' % TYPE_ARRAY)
	if typeof(combat) == TYPE_ARRAY:
		return combat[0]
	return combat


func get_combat_name():
	return self._get_combat()['nom']
	
func get_combat_hab():
	return self._get_combat()['hab']

func get_combat_pv():
	return self._get_combat()['pv']

func get_combat_pyro():
	return self._get_combat()['pyro']

func get_combat_armure():
	return self._get_combat()['arm']

func get_combat_degat():
	return self._get_combat()['deg']

func get_aquire():
	return self._book_data['computed']['aquire']
	
func get_remove():
	return self._book_data['computed']['remove']
