extends Node
## Lance tous les tests depuis l'ÉDITEUR : ouvrir `test/all.tscn` puis F6.
## Les résultats s'affichent dans la console de sortie.
##
## En ligne de commande, utiliser `test/all.gd` à la place.

func _ready() -> void:
	# On laisse une image aux autoloads pour finir leur `_ready()`.
	await get_tree().process_frame

	var runner = load("res://test/test_runner.gd").new()
	var ok = runner.run_all()
	print("\n(F6 terminé — %s)" % ("succès" if ok else "ÉCHEC"))
	get_tree().quit(0 if ok else 1)
