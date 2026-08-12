extends Node
## Narrator — décide *quand* jouer un son. `Sounder` sait *comment*.
##
## Trois usages, chacun branché sur son signal, aucun chef d'orchestre :
##
##   AppParameters.book_changed  -> l'intro du livre
##   Player.chapter_changed      -> la narration du chapitre, s'il en a une
##   Inventory.billy_changed     -> la réplique du type de Billy
##
## Rien à garder ici : `Sounder.play()` vérifie déjà l'interrupteur son et met les flux en
## cache, et il n'y a qu'un seul lecteur — un nouveau son coupe le précédent, ce qui est le
## comportement voulu (on ne veut pas la narration par-dessus l'intro).

## L'intro et les narrations de chapitre sont du **contenu de livre** : elles vivent dans
## `books/<nom>/audio/`, et **rien ne les déclare** — le fichier existe ou n'existe pas.
##
##   books/<nom>/audio/intro.mp3   joué en arrivant sur le livre
##   books/<nom>/audio/27.mp3      la narration du chapitre 27
##
## Une table de narrations était codée ici, livre par livre : ajouter un livre demandait
## d'ouvrir ce fichier, et ajouter une voix à un livre existant aussi. Un livre muet est un
## livre sans dossier `audio/`, pas une erreur.
const AUDIO_LIVRE := "res://books/%s/audio/%s.mp3"

## Le son joué quand le type de Billy change. Les cinq fichiers existent.
const BILLY_SOUNDS := {
	"guerrier": "billy-guerrier.mp3",
	"paysan": "billy-paysan.mp3",
	"prudent": "billy-prudent.mp3",
	"debrouillard": "billy-debrouillard.mp3",
	"pegu": "billy-pegu.mp3",
}


func _ready() -> void:
	AppParameters.book_changed.connect(_on_book_changed)
	Player.chapter_changed.connect(_on_chapter_changed)
	Inventory.billy_changed.connect(_on_billy_changed)

	# Pas d'intro au démarrage : `Player.do_load()` émet `chapter_changed` au boot, et la
	# narration éventuelle du chapitre où l'on reprend est plus pertinente qu'une intro
	# qu'on a déjà entendue. L'intro est réservée au changement de livre.


func _on_book_changed(book_name) -> void:
	_jouer(_audio_path(book_name, "intro"))


func _on_chapter_changed(node_id) -> void:
	_jouer(_narration_path(node_id))


func _on_billy_changed(billy_type) -> void:
	var fichier = BILLY_SOUNDS.get(billy_type)
	if fichier != null:
		Sounder.play(fichier)


## Vrai si le chapitre a une narration — l'interface peut ainsi proposer de la rejouer.
func has_narration(node_id) -> bool:
	return _narration_path(node_id) != ""


## ⚠️ `int()` obligatoire : les identifiants de chapitre arrivent parfois en **float**
## depuis les données du livre, et `"res://.../27.0.mp3"` ne désigne aucun fichier.
func _narration_path(node_id) -> String:
	return _audio_path(AppParameters.get_book_name(), "%d" % int(node_id))


## Le chemin d'un son du livre, ou "" s'il n'existe pas — **facultatif veut dire
## silencieux**, un livre sans `audio/` ne joue rien et ne se plaint pas.
func _audio_path(book_name: String, nom: String) -> String:
	var chemin = AUDIO_LIVRE % [book_name, nom]
	return chemin if Utils.is_file_exists(chemin) else ""


func _jouer(chemin: String) -> void:
	if chemin != "":
		Sounder.play_path(chemin)


## Rejoue la narration du chapitre courant, si elle existe.
func replay_narration() -> void:
	_on_chapter_changed(Player.get_current_node_id())
