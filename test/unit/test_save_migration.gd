extends "res://test/test_case.gd"
## Migration des sauvegardes (SaveManager).
##
## Le lanceur a déjà redirigé `SaveManager.base_dir` vers un dossier jetable :
## rien ici ne touche la vraie sauvegarde du joueur.


func before_each() -> void:
	_vide_le_dossier()
	_choisis_livre("fdcn")


#
#    Utilitaires
#

func _dossier() -> String:
	return SaveManager.base_dir


func _vide_le_dossier() -> void:
	var dir = DirAccess.open(_dossier())
	if dir == null:
		DirAccess.make_dir_recursive_absolute(_dossier())
		return
	for f in dir.get_files():
		dir.remove(f)


func _choisis_livre(nom: String) -> void:
	AppParameters.parameters['current_book'] = nom


func _ecris(fichier: String, contenu: String) -> void:
	FileAccess.open(_dossier() + fichier, FileAccess.WRITE).store_string(contenu)


func _lis(fichier: String) -> String:
	var pth = _dossier() + fichier
	if not FileAccess.file_exists(pth):
		return "<absent>"
	return FileAccess.open(pth, FileAccess.READ).get_as_text().strip_edges()


func _existe(fichier: String) -> bool:
	return FileAccess.file_exists(_dossier() + fichier)


## Écrit une sauvegarde à l'ancien format (suffixée par le NUMÉRO du livre).
func _ecris_sauvegarde_v1(numero: int, chapitre: String, historique: String) -> void:
	_ecris("current_node_id-%s.json" % numero, chapitre)
	_ecris("all_times_already_visited-%s.json" % numero, historique)
	_ecris("session_visited_nodes-%s.json" % numero, "[1]")
	_ecris("possessed_item-%s.json" % numero, '["EPEE"]')


#
#    Tests
#

func test_cree_une_sauvegarde_vierge_si_aucune() -> void:
	SaveManager.prepare_save()
	assert_eq(_lis("current_node_id-fdcn.json"), "1", "démarre au chapitre 1")
	assert_eq(_lis("all_times_already_visited-fdcn.json"), "[1]", "historique = [1]")
	assert_eq(_lis("session_visited_nodes-fdcn.json"), "[]", "session vide")
	assert_eq(_lis("possessed_item-fdcn.json"), "[]", "aucun objet")
	assert_eq(_lis("save_version-fdcn.json"), str(SaveManager.CURRENT_SAVE_VERSION),
		"estampillée à la version courante")


func test_la_version_courante_est_deduite_du_tableau() -> void:
	assert_eq(SaveManager.CURRENT_SAVE_VERSION, SaveManager._migrations.size() + 1,
		"CURRENT_SAVE_VERSION == nb de migrations + 1")


func test_migration_v1_renomme_les_fichiers() -> void:
	_ecris_sauvegarde_v1(1, "95", "[1,2,95]")
	assert_true(_existe("current_node_id-1.json"), "avant : fichier numéroté présent")

	SaveManager.prepare_save()

	assert_true(_existe("current_node_id-fdcn.json"), "après : fichier nommé présent")
	assert_false(_existe("current_node_id-1.json"), "après : fichier numéroté supprimé")
	assert_true(_existe("all_times_already_visited-fdcn.json"), "historique renommé")
	assert_true(_existe("session_visited_nodes-fdcn.json"), "session renommée")
	assert_true(_existe("possessed_item-fdcn.json"), "objets renommés")
	assert_eq(_lis("save_version-fdcn.json"), str(SaveManager.CURRENT_SAVE_VERSION),
		"version estampillée")


func test_migration_v1_preserve_le_contenu() -> void:
	_ecris_sauvegarde_v1(1, "95", "[1,2,95]")
	SaveManager.prepare_save()
	assert_eq(_lis("current_node_id-fdcn.json"), "95", "chapitre courant préservé")
	assert_eq(_lis("all_times_already_visited-fdcn.json"), "[1,2,95]", "historique préservé")
	assert_eq(_lis("possessed_item-fdcn.json"), '["EPEE"]', "objets préservés")
	assert_eq(int(SaveManager.load_value(SaveManager.KEY_CURRENT_NODE_ID, 0)), 95,
		"relu correctement par l'API normale")


func test_migration_traite_les_deux_livres() -> void:
	_ecris_sauvegarde_v1(1, "95", "[1,95]")
	_ecris_sauvegarde_v1(2, "42", "[1,42]")
	SaveManager.prepare_save()  # lancée depuis fdcn
	assert_eq(_lis("current_node_id-fdcn.json"), "95", "fdcn migré")
	assert_eq(_lis("current_node_id-cdsi.json"), "42", "cdsi migré aussi")
	assert_false(_existe("current_node_id-1.json"), "plus de fichier -1")
	assert_false(_existe("current_node_id-2.json"), "plus de fichier -2")


func test_pas_de_remigration_au_second_lancement() -> void:
	_ecris_sauvegarde_v1(1, "95", "[1,95]")
	SaveManager.prepare_save()
	# On marque le fichier pour repérer une réécriture intempestive.
	_ecris("current_node_id-fdcn.json", "77")
	SaveManager.prepare_save()
	assert_eq(_lis("current_node_id-fdcn.json"), "77", "contenu non retouché")
	assert_eq(_lis("save_version-fdcn.json"), str(SaveManager.CURRENT_SAVE_VERSION),
		"toujours à la version courante")


func test_migration_idempotente() -> void:
	_ecris_sauvegarde_v1(1, "95", "[1,95]")
	SaveManager._migrate_1_to_2()
	SaveManager._migrate_1_to_2()  # relancée à vide
	assert_eq(_lis("current_node_id-fdcn.json"), "95", "contenu intact")
	assert_false(_existe("current_node_id-1.json"), "aucun fichier numéroté ressuscité")


func test_conflit_ancien_et_nouveau_fichier() -> void:
	_ecris("current_node_id-1.json", "11")     # ancien
	_ecris("current_node_id-fdcn.json", "22")  # nouveau, déjà migré
	SaveManager._migrate_1_to_2()
	assert_eq(_lis("current_node_id-fdcn.json"), "22", "le nouveau fait foi")
	assert_false(_existe("current_node_id-1.json"), "le doublon hérité est supprimé")


func test_version_future_laissee_intacte() -> void:
	_ecris("current_node_id-fdcn.json", "50")
	_ecris("save_version-fdcn.json", str(SaveManager.CURRENT_SAVE_VERSION + 1))
	SaveManager.prepare_save()
	assert_eq(_lis("current_node_id-fdcn.json"), "50", "données intactes")
	assert_eq(_lis("save_version-fdcn.json"), str(SaveManager.CURRENT_SAVE_VERSION + 1),
		"version non rétrogradée")


func test_vieille_sauvegarde_pas_prise_pour_une_absence() -> void:
	# Seulement des fichiers à l'ancien format : has_any_save() (nouveau format)
	# est faux, mais il ne faut SURTOUT pas créer une sauvegarde vierge par-dessus.
	_ecris_sauvegarde_v1(1, "95", "[1,2,3,95]")
	SaveManager.prepare_save()
	assert_eq(_lis("current_node_id-fdcn.json"), "95", "progression non écrasée")
	assert_eq(_lis("all_times_already_visited-fdcn.json"), "[1,2,3,95]",
		"historique non écrasé")
