extends Node
## Lecteur de son unique de l'app, avec cache de chargement.
##
## `Node` et `AudioStreamPlayer`, plus `Node2D` / `AudioStreamPlayer2D` : un son d'interface
## n'a pas de position. Le lecteur 2D appliquait une atténuation et un panoramique selon la
## coordonnée du nœud — sans effet audible ici puisqu'il restait à l'origine, mais c'était
## un piège dormant : déplacer le nœud aurait déséquilibré le son.
##
## Un seul lecteur, donc **un son à la fois** : jouer coupe le précédent. C'est voulu — une
## narration de chapitre ne doit pas se superposer à l'intro d'un livre.

var _is_enabled := true

## Chemin -> flux déjà chargé. Une narration réécoutée ne relit pas le disque.
var _cache := {}

@onready var _player: AudioStreamPlayer = $Player


func set_enabled(b) -> void:
	_is_enabled = b
	if not _is_enabled:
		stop()


func is_enabled() -> bool:
	return _is_enabled


## Un son du rangement commun `sounds/` : les répliques de Billy, les voix des dieux.
func play(pth) -> void:
	play_path('res://sounds/%s' % pth)


## N'importe quelle ressource audio, par son chemin complet. Les sons d'un LIVRE vivent
## dans `books/<nom>/audio/`, pas dans `sounds/` : ils partent avec leur dossier le jour
## où le livre s'en va.
##
## Un son absent est un avertissement, jamais un plantage : tous les sons de livre sont
## facultatifs, un livre muet reste un livre jouable.
func play_path(full_pth: String) -> void:
	stop()
	if not _is_enabled:
		return
	if not full_pth in _cache:
		if not Utils.is_file_exists(full_pth):
			push_warning("Sounder: son introuvable: %s" % full_pth)
			return
		_cache[full_pth] = load(full_pth)
	_player.stream = _cache[full_pth]
	_player.play()


## Le garde n'est pas décoratif : `AppParameters` applique le réglage « son » pendant son
## propre `_ready()`, et rien ne garantit à un futur autoload qu'il passera après celui-ci.
func stop() -> void:
	if _player != null:
		_player.stop()
