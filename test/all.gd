extends SceneTree
## Lance TOUS les tests, en ligne de commande.
##
##     godot --headless -s test/all.gd --path .
##
## Filtrer sur un fichier :
##     godot --headless -s test/all.gd --path . -- player
##
## Code de sortie : 0 si tout passe, 1 sinon (utilisable en CI).
##
## Depuis l'éditeur, ouvrir `test/all.tscn` et faire F6 à la place.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# On attend une image pour que les autoloads soient prêts (le jeu charge le
	# livre et la sauvegarde dans leur `_ready()`).
	await process_frame

	var filter := ""
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]

	# Le lanceur est chargé à l'exécution : contrairement à ce script `-s`, il
	# voit les autoloads par leur nom.
	var runner = load("res://test/test_runner.gd").new()
	var ok = runner.run_all(filter)
	quit(0 if ok else 1)
