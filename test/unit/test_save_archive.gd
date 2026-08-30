extends "res://test/test_case.gd"
## L'export / import d'une sauvegarde en zip.
##
## Tout se passe dans le dossier jetable du lanceur : `SaveManager.base_dir` et
## `AppParameters.parameters_file` y sont déjà redirigés, et `SaveArchive` ne connaît que
## ces deux-là — il n'écrit jamais `user://` en dur. C'est ce qui rend ce chantier
## entièrement testable sans interface ni appareil.

var _archive := ""


func before_each() -> void:
	_archive = SaveManager.base_dir + "test-export.zip"
	AppParameters.set_billy_type('pegu')
	# `set_billy_type()` n'écrit le fichier que s'il change de valeur : on force sa présence,
	# sinon le premier test tomberait sur une archive sans réglages.
	AppParameters._save_parameters()
	Player.launch_new_billy()
	SaveManager.prepare_save()
	# Le filet d'un import précédent ne doit pas fausser les tests qui vérifient son absence.
	DirAccess.remove_absolute(SaveManager.base_dir + SaveArchive.NOM_SECOURS)


#
#    Aller-retour
#

## LE test du chantier : ce qui sort de l'archive doit être ce qui y est entré, y compris
## après avoir abîmé la partie entre les deux.
func test_un_aller_retour_rend_la_partie_intacte() -> void:
	Player.go_to_node(111)
	Inventory.add_item_from_options("EPEE")
	PlayerStats.del_pv(2)
	var chapitre = Player.get_current_node_id()
	var pv = PlayerStats.get_pv()
	var objets = Inventory.get_possessed_items().duplicate()

	assert_true(SaveArchive.export_to(_archive)["ok"], "l'export réussit")

	# On saccage la partie : nouveau Billy, autre chapitre, plus d'objet.
	Player.launch_new_billy()
	Player.go_to_node(2)
	assert_ne(Player.get_current_node_id(), chapitre, "la partie a bien changé")

	var rapport = SaveArchive.import_from(_archive)
	assert_true(rapport["ok"], "l'import réussit : %s" % rapport["erreur"])
	assert_eq(Player.get_current_node_id(), chapitre, "le chapitre est revenu")
	assert_eq(PlayerStats.get_pv(), pv, "les pv sont revenus")
	assert_eq(Inventory.get_possessed_items().size(), objets.size(), "autant d'objets qu'avant")
	for objet in objets:
		assert_true(Inventory.have_item(objet), "l'objet %s est revenu" % objet)


func test_larchive_contient_le_manifeste_et_la_partie() -> void:
	Player.go_to_node(111)
	SaveArchive.export_to(_archive)

	var reader := ZIPReader.new()
	assert_eq(reader.open(_archive), OK, "l'archive s'ouvre")
	var entrees = reader.get_files()
	assert_true("manifest.json" in entrees, "le manifeste est là")
	assert_true("parameters.json" in entrees, "les réglages aussi")
	assert_true("fdcn/current_node_id.json" in entrees, "et la partie du livre courant")

	var manifeste = JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	reader.close()
	assert_eq(int(manifeste["version_archive"]), SaveArchive.VERSION_ARCHIVE, "la version du format")
	assert_eq(manifeste["livre_courant"], "fdcn", "le livre ouvert au moment de l'export")
	assert_ne(manifeste.get("date", ""), "", "l'archive est datée")


## `describe()` sert à annoncer au joueur ce qu'il va écraser : il ne doit rien écraser
## lui-même.
func test_describe_ne_touche_a_rien() -> void:
	Player.go_to_node(111)
	SaveArchive.export_to(_archive)
	Player.go_to_node(2)

	var description = SaveArchive.describe(_archive)
	assert_true(description["ok"], "la description réussit")
	assert_true("fdcn" in description["livres"], "elle annonce le livre")
	assert_eq(Player.get_current_node_id(), 2, "et n'a rien appliqué")


#
#    Refus
#

## Une archive refusée ne doit RIEN laisser derrière elle : la partie locale est intacte,
## et aucune sauvegarde de secours n'a été écrite pour rien.
func test_une_archive_illisible_est_refusee_sans_degat() -> void:
	Player.go_to_node(111)
	var faux = SaveManager.base_dir + "pas-un-zip.zip"
	var f = FileAccess.open(faux, FileAccess.WRITE)
	f.store_string("ceci n'est pas une archive")
	f = null

	var rapport = SaveArchive.import_from(faux)
	assert_false(rapport["ok"], "l'import est refusé")
	assert_ne(rapport["erreur"], "", "avec un message")
	assert_eq(Player.get_current_node_id(), 111, "la partie locale est intacte")
	assert_false(FileAccess.file_exists(SaveManager.base_dir + SaveArchive.NOM_SECOURS),
		"et aucune sauvegarde de secours n'a été écrite")


func test_une_archive_sans_manifeste_est_refusee() -> void:
	var packer := ZIPPacker.new()
	packer.open(SaveManager.base_dir + "sans-manifeste.zip")
	packer.start_file("fdcn/current_node_id.json")
	packer.write_file("42".to_utf8_buffer())
	packer.close_file()
	packer.close()

	var rapport = SaveArchive.import_from(SaveManager.base_dir + "sans-manifeste.zip")
	assert_false(rapport["ok"], "sans manifeste, pas d'import")


## Une archive écrite par une version future de l'app : on refuse **avec un message utile**
## plutôt que de relire de travers.
func test_une_archive_de_version_future_est_refusee() -> void:
	_ecrire_archive("future.zip", SaveArchive.VERSION_ARCHIVE + 1, _partie(42))

	var rapport = SaveArchive.import_from(SaveManager.base_dir + "future.zip")
	assert_false(rapport["ok"], "refusée")
	assert_true(rapport["erreur"].contains("version"), "le message parle de version")


## Même chose pour la sauvegarde elle-même : `prepare_save()` sait migrer vers le haut,
## jamais vers le bas.
func test_une_partie_de_version_future_est_refusee() -> void:
	var partie = _partie(42)
	partie["fdcn/save_version.json"] = "%d" % (SaveManager.CURRENT_SAVE_VERSION + 1)
	_ecrire_archive("partie-future.zip", SaveArchive.VERSION_ARCHIVE, partie)

	var rapport = SaveArchive.import_from(SaveManager.base_dir + "partie-future.zip")
	assert_false(rapport["ok"], "refusée")


## Le pire cas de l'import : une partie à moitié appliquée, le chapitre de l'une avec les
## objets de l'autre. Mieux vaut tout refuser.
func test_une_partie_amputee_est_refusee() -> void:
	var partie = _partie(42)
	partie.erase("fdcn/possessed_item.json")
	_ecrire_archive("amputee.zip", SaveArchive.VERSION_ARCHIVE, partie)

	Player.go_to_node(111)
	var rapport = SaveArchive.import_from(SaveManager.base_dir + "amputee.zip")
	assert_false(rapport["ok"], "refusée")
	assert_eq(Player.get_current_node_id(), 111, "et la partie locale n'a pas bougé")


func test_une_archive_vide_est_refusee() -> void:
	_ecrire_archive("vide.zip", SaveArchive.VERSION_ARCHIVE, {})

	var rapport = SaveArchive.import_from(SaveManager.base_dir + "vide.zip")
	assert_false(rapport["ok"], "une archive sans partie ne sert à rien")


#
#    Le filet
#

func test_limport_ecrit_une_sauvegarde_de_secours_reutilisable() -> void:
	Player.go_to_node(111)
	SaveArchive.export_to(_archive)
	Player.go_to_node(2)
	var avant_import = Player.get_current_node_id()

	var rapport = SaveArchive.import_from(_archive)
	assert_true(rapport["ok"], "l'import réussit")
	assert_true(FileAccess.file_exists(rapport["secours"]), "le secours existe")

	# Et il est réellement réimportable : c'est tout l'intérêt du filet.
	var retour = SaveArchive.import_from(rapport["secours"])
	assert_true(retour["ok"], "le secours se réimporte")
	assert_eq(Player.get_current_node_id(), avant_import, "on est revenu à l'état d'avant l'import")


## Une archive qui ne contient qu'un livre ne doit pas effacer la partie des autres.
func test_une_archive_dun_seul_livre_laisse_les_autres_tranquilles() -> void:
	var autre = SaveManager.get_save_path_for(SaveManager.KEY_CURRENT_NODE_ID, "cdsi")
	var f = FileAccess.open(autre, FileAccess.WRITE)
	f.store_string("321")
	f = null

	_ecrire_archive("un-seul.zip", SaveArchive.VERSION_ARCHIVE, _partie(111))
	var rapport = SaveArchive.import_from(SaveManager.base_dir + "un-seul.zip")

	assert_true(rapport["ok"], "l'import réussit : %s" % rapport["erreur"])
	assert_eq(Player.get_current_node_id(), 111, "fdcn a été remplacé")
	assert_eq(FileAccess.open(autre, FileAccess.READ).get_as_text(), "321",
		"la partie de cdsi n'a pas bougé")


#
#    Interne
#

## Une partie fdcn minimale mais VALIDE : l'import exige les cinq fichiers qu'une
## sauvegarde préparée contient toujours.
func _partie(chapitre: int) -> Dictionary:
	return {
		"fdcn/all_times_already_visited.json": "[1,%d]" % chapitre,
		"fdcn/current_node_id.json": "%d" % chapitre,
		"fdcn/session_visited_nodes.json": "[%d]" % chapitre,
		"fdcn/possessed_item.json": "[]",
		"fdcn/save_version.json": "%d" % SaveManager.CURRENT_SAVE_VERSION,
	}


## Fabrique une archive de toutes pièces, pour éprouver les refus sans dépendre de ce que
## l'export produit.
func _ecrire_archive(nom: String, version_archive: int, fichiers: Dictionary) -> void:
	var packer := ZIPPacker.new()
	packer.open(SaveManager.base_dir + nom)
	packer.start_file("manifest.json")
	packer.write_file(JSON.stringify({"version_archive": version_archive}).to_utf8_buffer())
	packer.close_file()
	for chemin in fichiers:
		packer.start_file(chemin)
		packer.write_file(str(fichiers[chemin]).to_utf8_buffer())
		packer.close_file()
	packer.close()


#
#    Transport : la liste locale, seul recours sans sélecteur système
#

## Sur un appareil sans sélecteur de documents, c'est la seule liste d'archives que l'app
## puisse proposer — et elle doit donner la **plus récente d'abord**, sans quoi le joueur
## se verrait offrir la plus vieille.
func test_les_archives_locales_arrivent_de_la_plus_recente() -> void:
	SaveArchive.export_to(SaveManager.base_dir + "vieille.zip")
	SaveArchive.export_to(SaveManager.base_dir + "recente.zip")

	var locales = SaveArchive.archives_locales()
	assert_true(locales.size() >= 2, "les deux archives sont listées")

	# On vérifie la PROPRIÉTÉ (la liste décroît) et non la place d'un fichier précis : deux
	# écritures dans la même seconde ont la même date, et rien ne les départagerait.
	var precedente = -1
	for chemin in locales:
		var date = FileAccess.get_modified_time(chemin)
		if precedente != -1:
			assert_true(date <= precedente, "%s n'est pas plus récente que la précédente" % chemin)
		precedente = date


func test_les_archives_locales_ignorent_le_reste_de_la_sauvegarde() -> void:
	var locales = SaveArchive.archives_locales()
	for chemin in locales:
		assert_false(chemin.ends_with(".json"), "aucun fichier de partie dans la liste")
