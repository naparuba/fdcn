extends "res://test/test_case.gd"
## Les ressources du Billy (pv / chance) : bornage, persistance, et surtout le fait
## qu'un rejeu d'historique ne doit PAS les recréditer.
##
## Le lanceur a redirigé les sauvegardes vers un dossier jetable : les
## `launch_new_billy()` et les écritures ci-dessous ne touchent pas la vraie partie.


## Un Billy pégu part de end=2, donc pv_max=6 et chamax=3. On force le type pour
## que les plafonds ne dépendent pas du test précédent.
func before_each() -> void:
	AppParameters.set_billy_type('pegu')
	Player.launch_new_billy()


func test_un_billy_neuf_demarre_au_plein() -> void:
	# Le bug historique : `full_reset()` mettait pv à 0 et aucun chapitre ne
	# remplissait la jauge, donc une partie neuve démarrait à 0 pv.
	assert_true(PlayerStats.get_pv_max() > 0, "le plafond de pv est calculé")
	assert_eq(PlayerStats.get_pv(), PlayerStats.get_pv_max(), "pv au maximum")
	assert_eq(PlayerStats.get_cha(), PlayerStats.get_chance_max(), "chance au maximum")


func test_del_et_add_par_defaut_font_un() -> void:
	var depart = PlayerStats.get_pv()
	PlayerStats.del_pv()
	assert_eq(PlayerStats.get_pv(), depart - 1, "del_pv() retire 1 par défaut")
	PlayerStats.add_pv()
	assert_eq(PlayerStats.get_pv(), depart, "add_pv() rend 1 par défaut")

	PlayerStats.del_chance()
	assert_eq(PlayerStats.get_cha(), PlayerStats.get_chance_max() - 1, "del_chance() retire 1")


func test_les_ressources_ne_depassent_pas_leur_plafond() -> void:
	PlayerStats.add_pv(1000)
	assert_eq(PlayerStats.get_pv(), PlayerStats.get_pv_max(), "pv plafonnés à pv_max")
	PlayerStats.add_chance(1000)
	assert_eq(PlayerStats.get_cha(), PlayerStats.get_chance_max(), "chance plafonnée à chamax")


func test_les_ressources_ne_descendent_pas_sous_zero() -> void:
	PlayerStats.del_pv(1000)
	assert_eq(PlayerStats.get_pv(), 0, "pv jamais négatifs")
	PlayerStats.del_chance(1000)
	assert_eq(PlayerStats.get_cha(), 0, "chance jamais négative")


func test_une_ressource_modifiee_est_sauvegardee() -> void:
	PlayerStats.del_pv(2)
	var attendu = PlayerStats.get_pv()
	assert_eq(int(SaveManager.load_value(SaveManager.KEY_PV, -1)), attendu,
		"les pv sont sur le disque")

	# On simule un redémarrage : on abîme la valeur en mémoire, puis on relit.
	PlayerStats.add_pv(3)
	PlayerStats.load_resources()
	assert_eq(PlayerStats.get_pv(), attendu, "les pv relus sont ceux du disque")


func test_une_sauvegarde_sans_ressources_demarre_au_plein() -> void:
	# Cas de toutes les sauvegardes antérieures à cette version : le fichier
	# n'existe pas, le défaut doit être « au maximum » et non zéro.
	PlayerStats.del_pv(2)
	SaveManager.delete_save(SaveManager.KEY_PV)
	SaveManager.delete_save(SaveManager.KEY_CHANCE)

	PlayerStats.load_resources()
	assert_eq(PlayerStats.get_pv(), PlayerStats.get_pv_max(), "pv au plein par défaut")
	assert_eq(PlayerStats.get_cha(), PlayerStats.get_chance_max(), "chance au plein par défaut")


func test_le_rejeu_de_lhistorique_ne_recredite_pas_les_ressources() -> void:
	# LE test de non-régression du socle. `do_load()` rejoue les chapitres visités
	# pour reconstruire les cumuls. Le chapitre 111 de fdcn donne `pv: +5` : si le
	# rejeu l'appliquait, il écrirait des pv gonflés sur le disque (les setters
	# sauvegardent), et le `load_resources()` qui suit relirait cette valeur — donc
	# chaque démarrage effacerait les dégâts encaissés.
	Player.go_to_node(111)
	PlayerStats.del_pv(4)
	var apres_degats = PlayerStats.get_pv()

	Player.do_load()

	assert_eq(PlayerStats.get_pv(), apres_degats,
		"les pv survivent au rechargement, le rejeu ne les recrédite pas")


func test_baisser_le_plafond_rogne_les_pv() -> void:
	# `pv_max` = end x 3. Le type paysan donne +2 en endurance, donc +6 de plafond ;
	# en repassant à pégu le plafond redescend et les pv doivent suivre.
	Inventory.force_billy_type('paysan')
	PlayerStats.fill_resources()
	var plafond_haut = PlayerStats.get_pv_max()

	Inventory.force_billy_type('pegu')
	assert_true(PlayerStats.get_pv_max() < plafond_haut, "le plafond a bien baissé")
	assert_eq(PlayerStats.get_pv(), PlayerStats.get_pv_max(),
		"les pv sont rognés au nouveau plafond")
