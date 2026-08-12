extends Panel
## Page Lore : les 4 types de Billy et les 14 dieux, chacun avec son portrait et sa voix.
##
## **Ce script ne fait presque rien, et c'est le but.** Chaque `LoreEntry` est autonome : elle
## connecte son bouton de lecture dans sa propre scène, charge son portrait dans son
## `_ready()`, et son `@tool` affiche son titre jusque dans l'éditeur. Composer la page, c'est
## déposer une instance et renseigner ses trois propriétés exportées — `type_entry`,
## `entry_name`, `titre`. Aucune boucle d'instanciation ici, donc rien à maintenir en double
## entre la scène et le code.
##
## Ne restaient à brancher que les **deux liens externes**, qui n'appartiennent à aucune
## entrée. Ils étaient dans la scène depuis le portage mais morts, faute de script. Les URL
## viennent de l'archive (`_on_morelore_button_pressed`, `_on_image_author_button_pressed`).

const _URL_WIKI := "https://saga-de-billy.fandom.com/fr/wiki/Wiki_Saga_de_Billy"
const _URL_AUTEUR_IMAGES := "https://twitter.com/DrazielUnicorn"


func _ready() -> void:
	$VBox/Header/HeaderRow/LinkButton.pressed.connect(func(): OS.shell_open(_URL_WIKI))
	$VBox/LoreAuthor/AuthorRow/LinkButton.pressed.connect(func(): OS.shell_open(_URL_AUTEUR_IMAGES))
