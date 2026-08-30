extends Control
## La fanfare de nouveau succès : un voile sombre, des particules, la carte du succès qui
## grandit, puis tout s'efface. Instanciée par `ui/menu_page.gd` à chaque
## `Player.chapter_discovered` sur un chapitre à succès.
##
## ⚠️ **C'était un `Popup`, et ça ne pouvait pas marcher en Godot 4.** Un `Popup` y est un
## `Window`, avec sa propre fenêtre et sa propre taille — alors que l'animation lui appelait
## `popup(Rect2(0, 0, 0, 0))`, l'API Godot 3. Elle **réduisait donc la fenêtre à 0 × 0 dès la
## première image** : ni texte, ni effet, rien. Racine passée en `Control` plein cadre, ce
## qu'elle a toujours voulu être — une surcouche par-dessus la page, pas une fenêtre.
##
## Deux autres fautes de la même conversion, indépendantes :
##
## - une piste appelait `play("\"hide\"")` — avec les guillemets **dans** la chaîne, artefact
##   de sérialisation. Elle ne trouvait aucune animation de ce nom. Retirée : le chaînage
##   show → hide se fait dans `_on_AnimationPlayer_animation_finished`, où il est lisible.
## - la carte `Success` avait `anchor_right = 0.0` avec `offset_right = -8`, soit une largeur
##   de **−16**. Le `SuccessItem` était donc écrasé sur sa taille minimale, hors du cadre.
##
## Les noms de nœuds sont inchangés : les pistes d'animation les ciblent par chemin
## (`wholebackground/PanelBorder:scale`…), les renommer les casserait en silence.


func update_and_show(success):
	var s = $wholebackground/PanelBorder/Success
	s.set_chapitre(success['chapter'])
	s.set_label(success['label'])
	s.set_txt(success['txt'])
	s.set_success_id(success['id'])
	s.set_not_already_seen()  # passera à « obtenu » à 2,4 s, pendant l'animation
	# On ne montre pas le numéro de chapitre : ce serait divulguer où trouver le succès.
	s.hide_chapter()

	# Les particules sont un `Node2D` : pas d'ancrage, donc on les recentre à la main sur la
	# surcouche. Sans ça elles restent sur le centre d'un écran de 540 × 960 et dérivent sur
	# tout écran plus allongé.
	#
	# ⚠️ Leur réglage vit dans la scène et **tout y était par défaut** : `amount = 8`,
	# `initial_velocity = 0`, `gravity = (0, 98)`, émission depuis un point. Huit particules
	# sans élan, qui ne pouvaient que tomber. Elles partent maintenant vers le haut en
	# éventail (`direction = (0, -1)`, `spread = 60`) à vitesse variable, et retombent — et la
	# `angular_velocity_curve` de la scène sert enfin à quelque chose : elle était multipliée
	# par un `angular_velocity_min/max` resté à zéro, donc rien ne tournait.
	$wholebackground/CPUParticles2D.position = size / 2.0

	# L'animation `hide` finit sur `visible = false` ; une instance neuve part visible, mais
	# on l'écrit pour ne pas dépendre de l'ordre des lectures.
	visible = true
	$AnimationPlayer.play("show")
	_new_success_play_sound()


func _new_success_play_sound():
	var player = $AudioPlayer
	player.stop()
	if !Sounder.is_enabled():
		return
	player.stream = load('res://sounds/lennon-c-beau.mp3')
	player.play()


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == 'show':  # l'entrée est finie, on enchaîne la sortie
		$AnimationPlayer.play('hide')
	elif anim_name == 'hide':
		# Elle se libère : une instance est créée par succès découvert, les garder dans
		# l'arbre en accumulerait une par succès du livre (51 pour fdcn).
		queue_free()
