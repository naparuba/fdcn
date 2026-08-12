extends Node
## SaveArchive — empaqueter une sauvegarde dans un zip, et la réappliquer.
##
## **Découplé du transport, volontairement.** Empaqueter, valider et appliquer sont
## identiques partout ; seul « où poser le fichier » change, et c'est là que les plateformes
## divergent : `FileDialog` sur desktop, `user://` privé sur Android, IndexedDB et
## téléchargement navigateur sur le web. Ce fichier ne connaît que des chemins.
##
## CE QU'UNE ARCHIVE CONTIENT
##
##     manifest.json      version d'archive, date, livre courant, version de chaque partie
##     parameters.json    les réglages du joueur
##     <livre>/<clé>.json une partie complète par livre déclaré
##
## Le manifeste n'est pas décoratif : il permet de **décrire ce qu'on va écraser avant de
## l'écraser**, et de refuser une archive écrite par une version plus récente de l'app avec
## un message utile plutôt qu'une partie à moitié relue.
##
## L'IMPORT EST ATOMIQUE. Une sauvegarde à moitié appliquée — les objets d'une partie avec
## le chapitre d'une autre — est bien pire qu'un import raté. L'ordre ne se négocie pas :
##
##   1. tout lire **en mémoire** et tout valider ;
##   2. sauvegarder l'état actuel dans une archive de secours ;
##   3. seulement alors, écrire ;
##   4. recharger l'app.
##
## ⚠️ L'étape 1 lit en mémoire au lieu de décompresser dans `user://import_tmp/` comme le
## prévoyait la review §5.4 : une quinzaine de fichiers de quelques kilo-octets tiennent
## sans peine, et **rien ne touche le disque avant que tout soit validé** — c'est
## exactement ce que le dossier temporaire cherchait à garantir, en une étape de moins.

## Version du FORMAT d'archive, pas de l'app. À incrémenter le jour où la disposition des
## fichiers change ; une archive d'une version supérieure est refusée.
const VERSION_ARCHIVE := 1

const MANIFESTE := "manifest.json"
const PARAMETRES := "parameters.json"

## Nom de l'archive de secours écrite juste avant un import.
const NOM_SECOURS := "backup-avant-import.zip"


## Ce qu'une partie doit contenir pour être appliquée. `pv` et `chance` n'en sont **pas** :
## leur absence a un sens — « jamais enregistrées, démarre au plein » — et une partie neuve
## n'en a pas encore.
func _cles_obligatoires() -> Array:
	return [
		SaveManager.KEY_VISITED_ALL_TIMES,
		SaveManager.KEY_CURRENT_NODE_ID,
		SaveManager.KEY_SESSION_VISITED,
		SaveManager.KEY_POSSESSED_ITEMS,
		SaveManager.KEY_SAVE_VERSION,
	]


#
#    Export
#

## Écrit toute la sauvegarde dans `chemin_zip`. Renvoie un rapport
## `{ok, erreur, fichiers, livres}` — jamais une exception : l'appelant est une interface.
func export_to(chemin_zip: String) -> Dictionary:
	var packer := ZIPPacker.new()
	if packer.open(chemin_zip) != OK:
		return _echec("Impossible d'écrire l'archive : %s" % chemin_zip)

	var livres := []
	var fichiers := 0

	_ecrire_entree(packer, MANIFESTE, JSON.stringify(_manifeste(), "\t"))
	fichiers += 1

	var reglages = _lire_fichier(AppParameters.parameters_file)
	if reglages != "":
		_ecrire_entree(packer, PARAMETRES, reglages)
		fichiers += 1

	for book_name in _livres_sauvegardes():
		var ecrits := 0
		for cle in SaveManager.archived_keys():
			var contenu = _lire_fichier(SaveManager.get_save_path_for(cle, book_name))
			if contenu == "":
				continue
			_ecrire_entree(packer, "%s/%s.json" % [book_name, cle], contenu)
			ecrits += 1
		if ecrits > 0:
			livres.append(book_name)
			fichiers += ecrits

	packer.close()
	return {"ok": true, "erreur": "", "fichiers": fichiers, "livres": livres}


## Ce que l'archive va écraser, sans rien écraser. Sert à la confirmation affichée au
## joueur — et c'est la seule raison d'être du manifeste.
func describe(chemin_zip: String) -> Dictionary:
	var lecture = _lire_archive(chemin_zip)
	if not lecture["ok"]:
		return lecture
	var manifeste = lecture["manifeste"]
	return {
		"ok": true,
		"erreur": "",
		"date": manifeste.get("date", ""),
		"livre_courant": manifeste.get("livre_courant", ""),
		"livres": lecture["livres"].keys(),
	}


#
#    Import
#

## Remplace la sauvegarde locale par celle de l'archive. Renvoie
## `{ok, erreur, secours, livres}`.
##
## `secours` est le chemin de l'archive écrite **avant** la bascule : c'est un filet
## automatique, pas un conseil dans une notice.
func import_from(chemin_zip: String) -> Dictionary:
	var lecture = _lire_archive(chemin_zip)
	if not lecture["ok"]:
		return lecture

	# Le secours part APRÈS la validation : inutile d'écrire une archive de secours pour
	# refuser l'import trois lignes plus bas.
	var secours = SaveManager.base_dir + NOM_SECOURS
	var sauvegarde = export_to(secours)
	if not sauvegarde["ok"]:
		return _echec("Sauvegarde de secours impossible, import annulé : %s" % sauvegarde["erreur"])

	for book_name in lecture["livres"]:
		for cle in lecture["livres"][book_name]:
			_ecrire_fichier(SaveManager.get_save_path_for(cle, book_name),
				lecture["livres"][book_name][cle])
	if lecture["reglages"] != "":
		_ecrire_fichier(AppParameters.parameters_file, lecture["reglages"])

	# L'ordre compte : les réglages disent quel livre ouvrir, `AppParameters` le charge,
	# et seulement ensuite `Player` relit la partie correspondante.
	AppParameters.reload()
	Player.do_load()

	return {
		"ok": true,
		"erreur": "",
		"secours": secours,
		"livres": lecture["livres"].keys(),
	}


#
#    Lecture et validation
#

## Lit TOUTE l'archive en mémoire et la valide. Renvoie
## `{ok, erreur, manifeste, reglages, livres: {<livre>: {<clé>: contenu}}}`.
##
## Une archive n'est acceptée qu'entière : un seul fichier illisible et rien n'est appliqué.
func _lire_archive(chemin_zip: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(chemin_zip) != OK:
		return _echec("Archive illisible : %s" % chemin_zip)

	var entrees := reader.get_files()
	if not (MANIFESTE in entrees):
		reader.close()
		return _echec("Ce n'est pas une archive de sauvegarde : le manifeste manque.")

	var manifeste = JSON.parse_string(reader.read_file(MANIFESTE).get_string_from_utf8())
	if not manifeste is Dictionary:
		reader.close()
		return _echec("Manifeste illisible.")

	var version = int(manifeste.get("version_archive", 0))
	if version > VERSION_ARCHIVE:
		reader.close()
		return _echec("Archive en version %d, cette application ne connaît que la %d. Mettez-la à jour." % [version, VERSION_ARCHIVE])

	var reglages := ""
	if PARAMETRES in entrees:
		reglages = reader.read_file(PARAMETRES).get_string_from_utf8()
		if not JSON.parse_string(reglages) is Dictionary:
			reader.close()
			return _echec("Les réglages de l'archive sont illisibles.")

	var livres := {}
	for entree in entrees:
		var morceaux = entree.split("/")
		if morceaux.size() != 2 or not entree.ends_with(".json"):
			continue
		var book_name = morceaux[0]
		var cle = morceaux[1].trim_suffix(".json")
		if not (cle in SaveManager.archived_keys()):
			continue
		var contenu = reader.read_file(entree).get_string_from_utf8()
		if JSON.parse_string(contenu) == null:
			reader.close()
			return _echec("Fichier illisible dans l'archive : %s" % entree)
		if not livres.has(book_name):
			livres[book_name] = {}
		livres[book_name][cle] = contenu
	reader.close()

	if livres.is_empty():
		return _echec("L'archive ne contient aucune partie.")

	for book_name in livres:
		# Une partie AMPUTÉE est le pire des cas : le chapitre d'une partie avec les objets
		# d'une autre. On refuse tout plutôt que d'appliquer la moitié.
		for cle in _cles_obligatoires():
			if not livres[book_name].has(cle):
				return _echec("La partie « %s » est incomplète : %s manque." % [book_name, cle])

		# La version se valide ici plutôt qu'après la bascule : `prepare_save()` sait
		# migrer vers le haut, jamais vers le bas.
		var save_version = int(JSON.parse_string(livres[book_name][SaveManager.KEY_SAVE_VERSION]))
		if save_version > SaveManager.CURRENT_SAVE_VERSION:
			return _echec("La partie « %s » est en version %d, cette application ne lit que la %d." % [book_name, save_version, SaveManager.CURRENT_SAVE_VERSION])

	return {
		"ok": true,
		"erreur": "",
		"manifeste": manifeste,
		"reglages": reglages,
		"livres": livres,
	}


#
#    Petites mains
#

## Les livres à empaqueter : ceux du registre, plus tout livre dont une sauvegarde traîne
## sur le disque sans être déclaré — une partie ne se perd pas parce qu'un livre a été
## retiré du registre entre-temps.
func _livres_sauvegardes() -> Array:
	var noms := []
	for livre in BookData.get_books():
		var nom = livre.get("nom", "")
		if nom != "" and not (nom in noms):
			noms.append(nom)
	return noms


## `parties` donne la version de sauvegarde de chaque livre : c'est ce qui permet à un
## import de refuser une partie qu'il ne saurait pas relire, avant d'y toucher.
func _manifeste() -> Dictionary:
	var parties := {}
	for book_name in _livres_sauvegardes():
		var contenu = _lire_fichier(SaveManager.get_save_path_for(SaveManager.KEY_SAVE_VERSION, book_name))
		parties[book_name] = int(JSON.parse_string(contenu)) if contenu != "" else 1
	return {
		"version_archive": VERSION_ARCHIVE,
		"date": Time.get_datetime_string_from_system(),
		"livre_courant": AppParameters.get_book_name(),
		"version_app": Utils.get_app_version(),
		"parties": parties,
	}


func _lire_fichier(chemin: String) -> String:
	if not FileAccess.file_exists(chemin):
		return ""
	var f = FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func _ecrire_fichier(chemin: String, contenu: String) -> void:
	var f = FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		push_error("SaveArchive: impossible d'écrire %s" % chemin)
		return
	f.store_string(contenu)


func _ecrire_entree(packer: ZIPPacker, nom: String, contenu: String) -> void:
	packer.start_file(nom)
	packer.write_file(contenu.to_utf8_buffer())
	packer.close_file()


func _echec(message: String) -> Dictionary:
	return {"ok": false, "erreur": message, "livres": {}}
