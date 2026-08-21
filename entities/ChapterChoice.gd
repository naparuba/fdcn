extends Panel
## Une ligne de chapitre : 6 rubans obliques à gauche, le titre, le numéro, le bouton.
##
## Servie par DEUX écrans, et c'est la clé pour comprendre le reste du fichier :
##   - `screens/aventure_menu/ChoiceNextChapiter.tscn` → `update_from_son_node()`, sur des
##     instances **neuves** à chaque changement de chapitre ;
##   - `screens/chapitres_menu.gd` → `update_when_in_all_chapters()`, sur une quinzaine de
##     lignes **recyclées** qui servent tour à tour à des centaines de chapitres.
##
## MISE EN PAGE — les rubans sont des `Polygon2D` aux points écrits en dur. Politique
## tranchée le 2026-08-12 (review §6.3) : **atome de taille fixe**. Ils vivent donc tous
## les six dans `Row/Rubans`, un `Control` de 158×75 que le conteneur place comme un bloc
## indéformable ; à l'intérieur, aucun point n'a bougé. Étirer un polygone biaiserait
## l'angle et l'échelle se transmettrait aux `Label` enfants.
##
## Les chemins de nœuds sont rassemblés ci-dessous : la scène a déjà été réorganisée une
## fois, et les retrouver dispersés dans quinze fonctions coûtait cher.

@onready var _deja_vu: Polygon2D = $Row/Rubans/AlreadySeenPolygon
@onready var _ce_billy: Polygon2D = $Row/Rubans/SessionSeenPolygon
@onready var _combat: Polygon2D = $Row/Rubans/CombatPolygon
@onready var _fin: Polygon2D = $Row/Rubans/EndPolygon
@onready var _succes: Polygon2D = $Row/Rubans/SuccessPolygon
@onready var _secret: Polygon2D = $Row/Rubans/SecretPolygon
@onready var _titre: Label = $Row/Textes/Label
@onready var _special: Label = $Row/Textes/special
@onready var _numero: Label = $Row/NBChapitre
@onready var _click_special: Panel = $Row/click/special
@onready var _click_special_wrong: Panel = $Row/click/special_wrong

var COLOR_NOT_SET = Color('e0e2e5')  # very light grey

var chap_number
var spoil_enabled = false
var main


func set_main(main):
	self.main = main


## Les 4 marqueurs de contenu et le titre sont des spoils ; « Déjà Vu » et « Ce Billy »
## n'en sont pas — ils parlent du joueur, pas du livre — donc ils restent toujours visibles.
func set_spoil_enabled(b):
	self.spoil_enabled = b
	_combat.visible = self.spoil_enabled
	_fin.visible = self.spoil_enabled
	_succes.visible = self.spoil_enabled
	_secret.visible = self.spoil_enabled
	_titre.visible = self.spoil_enabled


func get_chapter_id():
	return self.chap_number


func set_chapitre(chapitre):
	# int() : le JSON rend les identifiants en float (voir Player.did_all_times_seen).
	self.chap_number = int(chapitre)
	_numero.text = '%3d' % self.chap_number


func set_label(label):
	_titre.text = label


func set_already_seen():
	_deja_vu.color = Color('00c2aa')

func set_not_already_seen():
	_deja_vu.color = COLOR_NOT_SET

func set_session_seen():
	_ce_billy.color = Color('00c2aa')

func set_session_not_seen():
	_ce_billy.color = COLOR_NOT_SET

func set_combat():
	_combat.color = Color('ff6f04')

func set_not_combat():
	_combat.color = COLOR_NOT_SET

func set_ending():
	_fin.color = Color('00c2aa')

func set_not_ending():
	_fin.color = COLOR_NOT_SET

func set_success():
	_succes.color = Color('00c2aa')

func set_not_success():
	_succes.color = COLOR_NOT_SET

func set_secret():
	_secret.color = Color('00c2aa')

func set_not_secret():
	_secret.color = COLOR_NOT_SET


func set_condition_txt(condition_txt):
	_special.text = condition_txt


func enable_special_jump():
	_special.visible = true
	_special.set("theme_override_colors/font_color", Color('00c2aa'))
	_click_special.visible = true
	_click_special_wrong.visible = false


func enable_special_jump_wrong():
	_special.visible = true
	_special.set("theme_override_colors/font_color", Color(1, 0, 0))
	_click_special.visible = false
	_click_special_wrong.visible = true


func disable_special_jump():
	_special.visible = false
	_special.set("theme_override_colors/font_color", Color(1, 0, 0))
	_click_special.visible = false
	_click_special_wrong.visible = false


func _on_Button_pressed():
	Player.go_to_node(self.chap_number)


## Remet TOUS les marqueurs à leur état neutre — exactement les valeurs de la scène
## (`#e0e2e5` sur les 6 polygones, titre vide, saut spécial masqué).
##
## ⚠️ Indispensable parce que `screens/chapitres_menu.gd` **recycle** ses lignes : `_pool[i]`
## sert successivement à des dizaines de chapitres. Une décoration posée par un `if` sans
## `else` restait donc affichée sur le chapitre suivant, qui n'y avait pas droit — c'est
## ainsi qu'un chapitre sans titre héritait du titre du précédent, et qu'un chapitre banal
## se retrouvait marqué « Secret ».
##
## Réinitialiser d'un bloc plutôt que d'ajouter un `else` à chaque test ferme la porte pour
## de bon : un marqueur ajouté plus tard est neutralisé sans qu'on ait à y penser.
func _reset_decorations() -> void:
	_titre.text = ''
	set_not_already_seen()
	set_session_not_seen()
	set_not_combat()
	set_not_ending()
	set_not_success()
	set_not_secret()
	disable_special_jump()


## Le tronc commun aux deux écrans : les 7 marqueurs qu'un chapitre porte, plus son titre.
##
## Les deux appelants ci-dessous ne différaient que par **deux** choses — la façon d'obtenir
## la donnée du chapitre, et le saut conditionnel qui n'a de sens que depuis un parent. Tout
## le reste était recopié, et c'est comme ça qu'ils ont **divergé** : le marqueur « Combat »
## n'était posé que par l'un des deux, donc la liste « tous les chapitres » n'a jamais montré
## un seul combat.
func _poser_marqueurs(chapitre) -> void:
	var id = chapitre.get_id()
	self._reset_decorations()
	# Les spoils peuvent être ouverts pour ce chapitre seul, s'il a déjà été vu.
	self.set_spoil_enabled(BookData.is_node_id_freely_full_on_all_chapters(id))

	if Player.did_billy_seen(id):
		self.set_session_seen()
	if Player.did_all_times_seen(id):
		self.set_already_seen()
	if chapitre.is_combat():
		self.set_combat()
	if chapitre.get_ending():
		self.set_ending()
	if chapitre.get_success():
		self.set_success()
	if chapitre.get_secret():
		self.set_secret()
	var titre = chapitre.get_label()
	if titre != null and titre != '':
		self.set_label(titre)


## Le « saut spécial » : une flèche verte si la condition est remplie, rouge sinon. Il se lit
## depuis le chapitre **courant**, donc il n'a de sens que pour la liste des choix — dans la
## liste de tous les chapitres, il n'y a pas de parent d'où sauter.
func _poser_saut_conditionnel(son_id) -> void:
	var depuis = Player.get_current_node_id()
	if not BookData.have_chapter_conditions(depuis, son_id):
		return
	self.set_condition_txt(BookData.get_condition_txt(depuis, son_id))
	if BookData.match_chapter_conditions(depuis, son_id):
		self.enable_special_jump()
	else:
		self.enable_special_jump_wrong()


## Une ligne des **choix du chapitre courant**. Instances neuves à chaque changement.
func update_from_son_node(son):
	self.set_chapitre(son.get_id())
	self._poser_marqueurs(son)
	self._poser_saut_conditionnel(son.get_id())


## Une ligne de la liste **« tous les chapitres »**, sur des lignes **recyclées** — d'où le
## `_reset_decorations()` que `_poser_marqueurs` fait en premier. Le numéro de chapitre est
## déjà posé par `chapitres_menu.gd` avant l'appel.
func update_when_in_all_chapters():
	self._poser_marqueurs(BookData.get_chapter_node(self.get_chapter_id()))
