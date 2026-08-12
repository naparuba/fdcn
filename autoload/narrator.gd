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

## Chapitres qui ont une narration, par livre. ⚠️ C'est du **contenu de livre** codé ici :
## sa place est dans `books/<nom>/`, comme `MIGRATION_GUESS` (review §11.8). En attendant,
## au moins la table est indexée par **nom** de livre et non par numéro, contrairement à
## l'archive.
const NARRATIONS := {
	"fdcn": {
		27: "27-kakaka.mp3",
		193: "193-la-cathedrale.mp3",
		216: "216-tour-des-mages.mp3",
		338: "338-virilus-backstory.mp3",
	},
	"cdsi": {},
}

const INTROS := {
	"fdcn": "intro-fdcn.mp3",
	"cdsi": "intro-cdsi.mp3",
}

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
	var fichier = INTROS.get(book_name)
	if fichier != null:
		Sounder.play(fichier)


## ⚠️ `int()` obligatoire : les identifiants de chapitre arrivent parfois en float depuis
## les données du livre, et une clé float ne trouve pas une clé int dans un dictionnaire.
func _on_chapter_changed(node_id) -> void:
	var fichier = NARRATIONS.get(AppParameters.get_book_name(), {}).get(int(node_id))
	if fichier != null:
		Sounder.play(fichier)


func _on_billy_changed(billy_type) -> void:
	var fichier = BILLY_SOUNDS.get(billy_type)
	if fichier != null:
		Sounder.play(fichier)


## Vrai si le chapitre a une narration — l'interface peut ainsi proposer de la rejouer.
func has_narration(node_id) -> bool:
	return NARRATIONS.get(AppParameters.get_book_name(), {}).has(int(node_id))


## Rejoue la narration du chapitre courant, si elle existe.
func replay_narration() -> void:
	_on_chapter_changed(Player.get_current_node_id())
