extends GutHookScript

# La fenetre du test-runner de GUT (panneau "Normal"/"Compact" sous
# GutRunner/GutLayer) couvre la quasi-totalite de l'ecran avec
# mouse_filter=STOP (visible meme en execution scriptee -gexit sous Xvfb).
# Elle intercepte donc toute simulation de clic/swipe reelle destinee a la
# vraie scene de jeu sous-jacente (test_real_swipe_navigation.gd,
# test_swipe.gd) avant qu'elle n'atteigne main.tscn. Ce hook (point
# d'extension officiel de GUT, cf gut_cmdln -gpre_run_script) desactive le
# filtrage souris de ce panneau sans jamais modifier addons/gut/ lui-meme.
func run():
	var root = gut.get_tree().root
	for child in root.get_children():
		if child.name == "GutRunner":
			_disable_mouse_filter_recursive(child)


func _disable_mouse_filter_recursive(node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_disable_mouse_filter_recursive(c)
