extends "res://addons/gut/test.gd"

# Test d'intégration P0 : automatise la comparaison golden/actual des
# scénarios E2E (jusqu'ici une revue humaine manuelle, cf TEST_PLAN.md §5
# et le plan de migration Phase 7 "Revue humaine côte-à-côte"). Chaque
# scénario est rejoué dans un VRAI sous-processus Godot (rendu réel --
# --headless ne produit aucune texture lisible, cf commentaire de
# _run_scenario ci-dessous), puis l'image produite est comparée pixel par
# pixel à sa référence golden.
#
# TOLÉRANCE, PAS ÉGALITÉ STRICTE : mesuré empiriquement (2026-07-15) que
# deux rendus du MÊME code, à des instants différents, diffèrent déjà de
# quelques % de pixels (anti-aliasing/police, bruit de rendu logiciel --
# pas une vraie régression). Un seuil de MAX_PERCENT_DIFF est donc
# nécessaire pour éviter un test "flaky" qui échouerait au hasard. Ce
# seuil pourra être resserré avec plus de recul, mais ne doit jamais
# redescendre à 0% sous peine de faux positifs permanents.
#
# 8% et non 3% (2026-07-15, apres plusieurs runs locaux) : sous charge
# machine variable, le bruit de rendu seul est monte jusqu'a ~6% sur
# certaines captures (nombreuses icones/scrollbar), avec un pic ponctuel
# a bug reel toujours >= 45%. Large marge de securite entre bruit et vraie
# regression -- 8% reste tres loin des vrais bugs deja observes.
#
# LENT PAR NATURE : chaque test lance un VRAI process Godot (boot complet
# du moteur + import des ressources + rendu). Attendu et accepté (cf
# demande explicite d'intégrer ceci aux tests "normaux" plutôt qu'un
# script à part) -- c'est le prix d'une vraie vérification visuelle
# automatisée, pas juste "le script ne plante pas".
#
# Ce fichier écrit dans test/e2e/screenshots/actual/ (fichiers déjà suivis
# par git, volontairement laissés en l'état après chaque run -- pas
# nettoyés en fin de test -- pour rester inspectables manuellement).
#
# ISOLATION user:// (2026-07-15) : chaque scenario tourne dans son propre
# XDG_DATA_HOME temporaire, cree et detruit autour du sous-processus. Sans
# ça, tous les scenarios partagent le meme user:// par defaut de la machine
# -- l'etat laisse sur disque par un run precedent (items possedes, livre
# selectionne, historique de chapitres...) pollue le suivant. Detecte
# empiriquement : le meme scenario, sans aucun changement de code, passait
# ou echouait selon ce qui tournait juste avant lui -- un flaky par design,
# pas une vraie regression. Seul le test de persistance multi-processus
# partage volontairement un XDG_DATA_HOME entre ses 2 sous-process (c'est
# exactement ce qu'il doit verifier), via le parametre
# shared_xdg_data_home de _run_scenario.

const GOLDEN_DIR = "res://test/e2e/screenshots/golden/"
const ACTUAL_DIR = "res://test/e2e/screenshots/actual/"
const SCENARIOS_DIR = "res://test/e2e/scenarios/"
const MAX_PERCENT_DIFF = 8.0
const PER_CHANNEL_THRESHOLD = 24  # tolère l'anti-aliasing/le bruit de police, pas un vrai changement visuel


# --- Infra : lance un vrai process Godot pour un scénario E2E -----------

static func _godot_binary() -> String:
	var from_env = OS.get_environment("GODOT_BIN")
	if from_env != "":
		return from_env
	# Par défaut, le MÊME binaire que celui qui fait tourner ce test --
	# évite de coder en dur un chemin d'install specifique a une machine.
	return OS.get_executable_path()


static func _make_temp_user_dir() -> String:
	var tmp_base = OS.get_environment("TMPDIR")
	if tmp_base == "":
		tmp_base = "/tmp"
	var unique = tmp_base.path_join("fdcn_e2e_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(unique)
	return unique


static func _remove_temp_user_dir(path: String):
	OS.execute("rm", ["-rf", path])


# shared_xdg_data_home : laisser vide pour un user:// isole et jetable
# (cas normal, un par scenario). Passer un chemin pour le partager entre
# plusieurs appels -- seul le test de persistance multi-processus en a
# besoin, cf commentaire de tete de fichier.
static func _run_scenario(scenario_fname: String, shared_xdg_data_home: String = "") -> Dictionary:
	# Le rendu reel est OBLIGATOIRE ici : --headless utilise le driver
	# "dummy", get_viewport().get_texture() y renvoie null (verifie en
	# testant ce chemin sur ce projet, cf commit du nettoyage
	# top_menu/billy) -- aucune capture d'ecran n'est possible dessous.
	# On ne relance PAS xvfb-run : ce process herite du DISPLAY du process
	# parent (deja lance sous xvfb-run par la commande de test habituelle),
	# un seul serveur X virtuel suffit pour les deux.
	var project_path = ProjectSettings.globalize_path("res://")
	var scenario_path = SCENARIOS_DIR + scenario_fname
	var args = PackedStringArray([
		"--path", project_path,
		"test/e2e/e2e_runner.tscn", "--",
		"--e2e-script=" + scenario_path,
		"--e2e-out=" + ACTUAL_DIR,
	])

	var owns_dir = shared_xdg_data_home == ""
	var xdg_data_home = shared_xdg_data_home
	if owns_dir:
		xdg_data_home = _make_temp_user_dir()
	var previous_xdg = OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", xdg_data_home)

	var output = []
	var exit_code = OS.execute(_godot_binary(), args, output, true)

	OS.set_environment("XDG_DATA_HOME", previous_xdg)
	if owns_dir:
		_remove_temp_user_dir(xdg_data_home)

	return {"exit_code": exit_code, "output": "\n".join(output)}


# --- Infra : comparaison d'images avec tolerance -------------------------

static func _compare_images(golden_name: String, actual_name: String) -> Dictionary:
	# Chemins globalises (systeme de fichiers, pas res://) : Image.load() sur
	# un res:// emet un WARNING Godot 4 ("this will not work on export"), que
	# GUT compte comme une erreur inattendue et qui fait donc echouer le test
	# meme quand la comparaison elle-meme est OK.
	var golden = Image.new()
	if golden.load(ProjectSettings.globalize_path(GOLDEN_DIR + golden_name)) != OK:
		return {"ok": false, "reason": "golden introuvable: %s" % golden_name}
	var actual = Image.new()
	if actual.load(ProjectSettings.globalize_path(ACTUAL_DIR + actual_name)) != OK:
		return {"ok": false, "reason": "actual introuvable -- le scenario ne l'a pas genere: %s" % actual_name}
	if golden.get_size() != actual.get_size():
		return {"ok": false, "reason": "tailles differentes: golden=%s actual=%s" % [golden.get_size(), actual.get_size()]}

	golden.convert(Image.FORMAT_RGB8)
	actual.convert(Image.FORMAT_RGB8)
	var gd = golden.get_data()
	var ad = actual.get_data()
	var total_pixels = golden.get_width() * golden.get_height()
	var diff_pixels = 0
	var i = 0
	while i < gd.size():
		var dr = absi(gd[i] - ad[i])
		var dg = absi(gd[i + 1] - ad[i + 1])
		var db = absi(gd[i + 2] - ad[i + 2])
		if maxi(dr, maxi(dg, db)) > PER_CHANNEL_THRESHOLD:
			diff_pixels += 1
		i += 3

	var percent = 100.0 * diff_pixels / total_pixels
	return {
		"ok": percent <= MAX_PERCENT_DIFF,
		"percent_diff": percent,
		"diff_pixels": diff_pixels,
		"total_pixels": total_pixels,
	}


# Lance un scenario puis compare CHAQUE capture attendue a son golden --
# une seule assertion recapitulative (pas une par image) pour un message
# d'erreur qui liste tout ce qui a merde d'un coup, plutot que de s'arreter
# a la premiere image en cas de plusieurs captures dans le meme scenario.
func _run_and_assert(scenario_fname: String, expected_images: Array):
	var run = _run_scenario(scenario_fname)
	assert_eq(run.exit_code, 0, "%s: le sous-processus E2E a echoue (code %s)\n%s" % [scenario_fname, run.exit_code, run.output])

	var failures = []
	for image_name in expected_images:
		var fname = image_name + ".png"
		var result = _compare_images(fname, fname)
		if not result.get("ok", false):
			if result.has("percent_diff"):
				failures.append("%s: %.2f%% de pixels differents (%s/%s), seuil=%.1f%%" % [
					fname, result.percent_diff, result.diff_pixels, result.total_pixels, MAX_PERCENT_DIFF])
			else:
				failures.append("%s: %s" % [fname, result.get("reason", "echec inconnu")])
	assert_eq(failures, [], "\n".join(failures))


# --- Un test par scenario -------------------------------------------------

func test_nouvelle_partie():
	_run_and_assert("nouvelle_partie.json", ["E1_nouvelle_partie_chapitre_1"])


func test_navigation_choix_multiples():
	_run_and_assert("navigation_choix_multiples.json", ["E2_chapitre_10_choix_multiples"])


func test_acquisition_objet():
	_run_and_assert("acquisition_objet.json", ["E3_popup_acquisition_objet"])


func test_fin_bonne():
	_run_and_assert("fin_bonne.json", ["E4_fin_bonne_224"])


func test_fin_mauvaise():
	_run_and_assert("fin_mauvaise.json", ["E4_fin_mauvaise_163_tulipes"])


func test_succes_et_lore():
	_run_and_assert("succes_et_lore.json", ["E5_ecran_succes", "E5_ecran_lore"])


func test_changement_livre():
	_run_and_assert("changement_livre.json", ["E6_livre_fdcn", "E6_livre_cdsi", "E6_retour_livre_fdcn"])


func test_popup_reset():
	_run_and_assert("popup_reset.json", ["E7_popup_confirmation_reset", "E7_apres_acceptation_reset"])


func test_boutons_spoils_son():
	_run_and_assert("boutons_spoils_son.json", [
		"E8_chapitres_spoils_on", "E8_chapitres_spoils_off",
		"E8_bouton_son_off", "E8_bouton_son_on",
	])


func test_combat():
	# 3 temps du VRAI ecran interactif (des forces via combat_play_turn,
	# jamais le vrai bouton -- sinon un jet aleatoire rendrait le scenario
	# non reproductible) : etat initial, apres un tour reel joue, victoire.
	_run_and_assert("combat.json", ["E9_combat_debut", "E9_combat_apres_tour1", "E9_combat_victoire"])


func test_succes_seul():
	_run_and_assert("succes_seul.json", ["E10_succes_seul_sans_fin"])


func test_tous_les_combats_levent_lecran():
	# Audit demande explicitement ("tu peux verifier que TOUS les combats
	# levent bien l'ecran de combat ?") : visite REELLEMENT chaque noeud de
	# combat des deux livres (45 + 40, cf fdcn-N-compilated-combats.json) via
	# le vrai main.tscn, et verifie $Combat.visible == true a chaque fois --
	# c'est exactement ce que is_combat() est censee declencher dans
	# main.gd::go_to_node(). Purement assertionnel (aucune image), donc pas
	# d'entree dans expected_images -- seul le code de sortie du sous-processus
	# compte (chaque assert_combat_visible rate quitte en code 1).
	_run_and_assert("tous_les_combats.json", [])


func test_triche_combat():
	# Le joueur "triche" en revenant sur un combat : annule un mauvais tour
	# (↺), puis revient sur plusieurs tours a la fois via une pastille.
	# A deja fait remonter un vrai bug (tuile "prochain tour" perimee en
	# double, tuiles valides effacees a tort) -- cf CombatScreen.gd.
	_run_and_assert("triche_combat.json", [
		"triche_combat_1_debut", "triche_combat_2_mauvais_tour", "triche_combat_3_apres_annulation",
		"triche_combat_4_meilleur_tour", "triche_combat_5_trois_tours", "triche_combat_6_apres_retour_multiple",
	])


func test_triche_stats():
	# Le joueur "triche" sur ses stats via la fiche de personnage : +/- sur
	# Chapitres & Autre, bonus de PV max, "Plein" sur PV/Chance -- verifie
	# que les vraies regles restent respectees (jamais au-dessus du max).
	_run_and_assert("triche_stats.json", [
		"triche_stats_1_debut", "triche_stats_2_habilete_trichee", "triche_stats_3_pv_max_augmente",
		"triche_stats_4_pv_plein", "triche_stats_5_chance_baissee", "triche_stats_6_chance_pleine",
	])


func test_triche_bloquee_en_combat():
	# Un combat en cours tourne sur un instantane fige de Billy -- tricher
	# pendant un combat n'aurait aucun effet sur le combat affiche (verifie
	# a l'ecran), seulement source de confusion. Verifie via un vrai clic
	# simule (le panneau de combat ne bloque PAS l'acces a Options -- c'est
	# bien l'edition elle-meme qui doit etre bloquee, pas l'ecran) que
	# StatsScreen.gd affiche le message et refuse toute triche tant que
	# Player.in_combat est vrai.
	_run_and_assert("triche_bloquee_en_combat.json", [
		"triche_bloquee_1_stats_pendant_combat", "triche_bloquee_2_apres_tentative",
	])


func test_vrai_swipe():
	_run_and_assert("vrai_swipe.json", ["E11_avant_swipe_chapitres", "E11_apres_swipe_main"])


# --- Persistance a travers un vrai redemarrage (2 process, meme user://) -

func test_persistence_across_a_real_restart():
	# Seul cas ou les 2 sous-processus DOIVENT partager le meme user:// --
	# c'est exactement le scenario E9 signale comme priorite absolue par le
	# plan de migration ("critere pass/fail non-visuel, revalider en
	# priorite absolue"). Tous les autres tests de ce fichier isolent leur
	# user:// automatiquement (cf commentaire de tete de fichier) ; celui-ci
	# force explicitement le partage via shared_xdg_data_home.
	var shared_dir = _make_temp_user_dir()

	var run1 = _run_scenario("persistence_partie1_avant_redemarrage.json", shared_dir)
	var run2 = _run_scenario("persistence_partie2_apres_redemarrage.json", shared_dir)

	_remove_temp_user_dir(shared_dir)

	assert_eq(run1.exit_code, 0, "partie 1: le sous-processus E2E a echoue\n%s" % run1.output)
	assert_eq(run2.exit_code, 0, "partie 2 (apres redemarrage): le sous-processus E2E a echoue -- la persistance user:// a probablement casse\n%s" % run2.output)

	var failures = []
	for image_name in ["E9_persistence_avant_redemarrage", "E9_persistence_apres_redemarrage"]:
		var fname = image_name + ".png"
		var result = _compare_images(fname, fname)
		if not result.get("ok", false):
			if result.has("percent_diff"):
				failures.append("%s: %.2f%% de pixels differents, seuil=%.1f%%" % [fname, result.percent_diff, MAX_PERCENT_DIFF])
			else:
				failures.append("%s: %s" % [fname, result.get("reason", "echec inconnu")])
	assert_eq(failures, [], "\n".join(failures))
