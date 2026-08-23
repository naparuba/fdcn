# Review-code — pistes de refactor GDScript

État au **2026-08-23**. Lecture complète des 42 fichiers `.gd` de l'app (hors `archive/` et
`test/`, ~6 700 lignes : `entities/`, `screens/` (et sous-dossiers), `autoload/`, `popups/`
(et `sub/`), `ui/`), croisée avec `todo.md`/`review.md` pour ne pas répéter ce qui y est
déjà — catégories 1/4/5/6/7 et le point 9.1 sont réglés, 2/3/8/9.2 sont déjà au backlog.

**Ce fichier ne couvre que le code GDScript lui-même** (duplication, complexité, nommage,
couplage) — pas les données de livre, ni les tests manquants, déjà suivis ailleurs.

Rien à signaler sur `book_data.gd`, `save_archive.gd`, `sounder.gd`, `utils.gd`,
`chapter_data.gd`, `resource_gauge.gd`, `gauge_inside_circle.gd`, `yes_no_switch.gd`,
`menu_page.gd`, `lore_menu.gd`, `virtual_list_pool.gd` — lus en entier, propres.

---

## 1 — Duplication

### 1.1 Repli d'icône svg→png→placeholder, 3 copies quasi identiques

- `entities/Item.gd:46-53`, `popups/ItemPopup.gd:39-46`, `entities/success_item.gd:133-140`
- Même séquence partout : construire `<dossier>/<nom>.svg`, tester son existence, sinon
  `.png`, sinon un repli — seuls le dossier (`images/items/` vs `images/success/`) et le
  repli (`_ICONE_INCONNUE` vs `null`) changent.
- **Solution** : `Utils.load_icon_with_fallback(dossier: String, nom: String, repli:
  Texture2D = null) -> Texture2D`, qui fait le svg→png→repli une fois pour toutes. Les
  trois appelants passent de ~8 lignes à 1.
- Effort : rapide — Valeur : à faire (bug futur en un seul endroit à corriger, pas trois).

### 1.2 `ShaderMaterial` gris construit à l'identique dans 2 fichiers

- `popups/sub/inventory.gd:52-54` et `popups/sub/book_selection.gd:103-105` : `ShaderMaterial.new()` + `.shader = _gray_shader` (`shaders/gray.gdshader`) + assignation à `.material`, 3 lignes identiques.
- **Solution** : `Utils.make_gray_material() -> ShaderMaterial`.
- Effort : rapide — Valeur : accessoire.

### 1.3 « Trouver l'ancêtre avec cette méthode, avertir et sortir sinon » dupliqué 6×

- Sites : `screens/about_menu.gd:56,168,221` (avec `push_warning` si `null`),
  `screens/about_menu.gd:68,183` et `screens/aventure_menu/choice_next_chapiter.gd:86`
  (variantes proches). Tous appellent `Utils.find_ancestor_with_method(self, "confirm")`
  ou `"go_to_page"` puis testent `null`.
- **Solution** : `Utils.find_ancestor_with_method_or_warn(node: Node, methode: String,
  appelant: String) -> Node`, qui fait le `push_warning()` avec le nom de l'appelant et
  renvoie `null` — les 3 sites avec avertissement (about_menu.gd) gagnent une ligne
  chacun ; les 3 sans avertissement gardent `find_ancestor_with_method()` tel quel.
- Effort : rapide — Valeur : accessoire.

### 1.4 Résolution du numéro de livre legacy → nom, codée deux fois

- `autoload/app_parameters.gd:_resoudre_livre_courant()` (ligne ~72) et
  `autoload/save_manager.gd:_legacy_book_numbers()` (ligne 256) : les deux relisent
  `BookData.get_books()`/`get_books()` et construisent une table rang→nom pour convertir
  un ancien numéro de livre.
- **Solution** : un seul helper (`BookData.get_book_name_for_legacy_number(n)` ou
  équivalent) que les deux appellent — à vérifier d'abord que les deux tables sont
  vraiment interchangeables (l'une est indexée à partir de 1, l'autre à partir de 0 côté
  `app_parameters.gd`, à harmoniser en même temps).
- Effort : rapide — Valeur : accessoire.

### 1.5 Types de Billy en chaînes littérales, ~75 fois dans 9 fichiers

- `'guerrier'`/`'paysan'`/`'prudent'`/`'debrouillard'`/`'pegu'` tapés en dur dans
  `autoload/app_parameters.gd`, `autoload/inventory.gd`, `autoload/player_stats.gd`,
  `autoload/narrator.gd`, `autoload/combat_engine.gd`, `ui/top_menu.gd`,
  `popups/sub/inventory.gd`, `entities/LoreEntry.gd`, `screens/aventure_menu/combat.gd` —
  75 occurrences au total, aucune liste de référence partagée. Une faute de frappe dans
  l'une des chaînes compile sans erreur et casse silencieusement la comparaison.
- **Solution** : une seule source de vérité, par exemple `const BILLY_TYPES :=
  ["guerrier", "paysan", "prudent", "debrouillard", "pegu"]` dans `Inventory` (qui calcule
  déjà le type) ou dans un fichier de constantes partagé, et un `assert()`/test qui vérifie
  que chaque fichier n'utilise que des valeurs de cette liste.
- Effort : modéré (beaucoup de sites à toucher, mais chacun trivial) — Valeur : à faire,
  c'est une vraie fragilité si un 5ᵉ type de Billy est ajouté un jour.

### 1.6 `set_main(x): main = x` répété dans 4 fichiers

- `entities/ChapterChoice.gd`, `entities/EndingChoice.gd`, `entities/success_item.gd`,
  `ui/bread.gd` : même setter d'une ligne, mais les 4 classes n'ont pas de type de base
  commun (`Panel`, `Panel`, `PanelContainer`, `Control`) pour l'y accrocher sans imposer
  une hiérarchie artificielle.
- **Solution** : aucune pour l'instant — noté pour mémoire, pas une vraie duplication
  gênante (une ligne, quatre fichiers sans rien d'autre en commun).
- Effort : — — Valeur : spéculatif, ne pas faire sans un 5ᵉ cas qui change la donne.

---

## 2 — Code mort

| # | où | quoi | solution |
|---|---|---|---|
| 2.1 | `entities/Item.gd:79` | `is_ok_to_be_shown()` jamais appelée (vérifié `.gd` et `.tscn`) | supprimer |
| 2.2 | `autoload/player.gd:189` | `have_previous_chapters()` jamais appelée | supprimer |
| 2.3 | `autoload/narrator.gd:83` | `replay_narration()` jamais appelée — ressemble à un bouton « rejouer la voix » jamais câblé | trancher : câbler un bouton, ou supprimer |
| 2.4 | `ui/bread.gd:41-43` | `_ready()` ne fait que `#_set_color()` (commenté) + `pass` : ne fait rien | supprimer la fonction entière |
| 2.5 | `popups/GenericConfirmationPopup.gd:3` | `@export var content = "" # (String, MULTILINE)` : annotation Godot 3 en commentaire, jamais migrée. Le champ contient pourtant du texte multi-paragraphe en pratique (textes de confirmation) et s'édite mono-ligne dans l'inspecteur | remplacer par `@export_multiline var content := ""` |

Effort : rapide sur toute la ligne — Valeur : à faire (du bruit qui coûte rien à retirer,
sauf 2.3 qui demande une décision produit d'abord).

---

## 3 — Nommage

| # | où | quoi | solution |
|---|---|---|---|
| 3.1 | `entities/ChapterChoice.gd:31` | `var COLOR_NOT_SET = Color('e0e2e5')` : nom ALL_CAPS sur une `var` alors qu'elle n'est jamais réassignée | `const COLOR_NOT_SET := Color('e0e2e5')` |
| 3.2 | `ui/nav_buton.gd:95,107` | `setDisabled()`/`setMirror()` : seules méthodes publiques camelCase de tout le dépôt hors tests (appelées depuis `ui/menu_page.gd:209-210` et en interne lignes 35/37) | renommer en `set_disabled()`/`set_mirror()`, mettre à jour les 2 sites d'appel externes |
| 3.3 | `ui/nav_buton.gd:24` | `signal _on_nav_pressed()` : le préfixe `_on_` est réservé aux handlers privés partout ailleurs dans le dépôt, or c'est un signal connecté depuis `menu_page.gd:71-72` | renommer en `pressed_for_navigation` (ou équivalent), mettre à jour les 2 `.connect()` |
| 3.4 | `ui/nav_buton.gd:115` | `emit_signal("_on_nav_pressed")` : seul appel par chaîne de caractères de tout le dépôt, partout ailleurs c'est `.emit()` typé | `pressed_for_navigation.emit()`, à faire avec 3.3 |

Effort : rapide sur toute la ligne — Valeur : à faire, ce sont des pièges pour un futur
renommage ou refactor de `nav_buton.gd` (grep par convention ne les trouverait pas).

---

## 4 — Complexité / couplage

### 4.1 `autoload/combat_engine.gd:resolve()` — la fonction la plus complexe du dépôt

- Lignes 419-537 (~120 lignes) : calcule l'assaut, les deux formes d'esquive, le plafond du
  PAYSAN, le coup fatal évité, le jet de survie du PRUDENT, et la transition vers l'ennemi
  suivant, tout dans une seule fonction.
- Déjà très commentée et couverte par les 33 tests de `test_combat.gd` — le risque actuel
  est faible. Le coût apparaît le jour où une règle de plus s'ajoute (un 5ᵉ pouvoir de
  CARACTÈRE, une 3ᵉ forme d'esquive) : la fonction devient alors difficile à faire évoluer
  sans tout relire.
- **Solution** (à faire seulement à ce moment-là, pas maintenant) : extraire les étapes
  déjà nommées dans les commentaires (`_appliquer_esquive()`, `_appliquer_pouvoirs()`,
  `_transition_ennemi_suivant()`) en fonctions privées séparées, chacune testable seule.
- Effort : modéré à large — Valeur : accessoire pour l'instant, à revisiter à la prochaine
  règle de combat ajoutée.

### 4.2 `screens/about_menu.gd` — page « À propos » + fonctionnalité export/import complète

- Le fichier fait 225 lignes ; les lignes ~74-225 (~150 lignes) sont entièrement l'export/
  import de sauvegarde en zip (dialogues, filtre MIME, confirmation, `_on_exporter()`/
  `_on_importer()`/`_construire_boutons_sauvegarde()`...), greffées sur le contrôleur de la
  page « À propos » qui n'a par ailleurs rien à voir avec la sauvegarde.
- **Solution** : extraire en `screens/save_export_import.gd` (ou un composant dédié),
  instancié par `about_menu.gd` — un futur changement du flux d'export n'aura plus besoin
  de rouvrir un fichier nommé pour autre chose.
- Effort : modéré — Valeur : accessoire, mais s'impose si l'export/import évolue encore
  (la 2.3 du todo — test sur téléphone réel — pourrait bien faire remonter des ajustements
  ici).

---

## 5 — Références à `review.md` obsolètes dans les commentaires de code

Trouvé le 2026-08-23 en réconciliant `review.md` avec ses renumérotations successives —
même défaut que celui déjà corrigé pour `succes_menu.gd` (§5bis/§5ter, todo 6.6), mais pas
balayé sur le reste du dépôt :

| fichier:ligne | cite | pointe en réalité vers | probable vraie cible |
|---|---|---|---|
| `entities/LoreEntry.gd:9` | `review §6.1` | § disparu (6.1 était alors « le générateur Python », sans rapport) | `review.md` §1.2 (atome de taille fixe / conteneurs) |
| `entities/LoreEntry.gd:18` | `review §11.1` | aucune section `§11` n'existe dans `review.md` | aucune — fait autonome, retirer le pointeur |
| `screens/aventure_menu/global_completion.gd:6` | `review §6.1` | idem | `review.md` §1.2 |
| `entities/EndingChoice.gd:17`, `entities/ChapterChoice.gd:11`, `ui/gauge_inside_circle.gd:11`, `ui/bread.gd:4` | `review §6.3` | § disparu (6.3 était « ce qui est sain » du générateur) | `review.md` §1.2 (widgets à polygones) |
| `test/unit/test_player.gd:58` | `review §2.4` | `review.md` §2 n'a jamais eu de 2.4 | aucune section connue — vérifier dans `git log -p review.md` avant de choisir |
| `ui/nav_buton.gd:6` | `review §2.6` | idem, jamais existé | aucune section connue |
| `entities/Item.gd:44` | `review §5.5` | `review.md` §5.5 parlait d'autre chose (dépendances export/import) ; la vraie source est l'ancien `todo` 5.5 (icône générique) | retirer le pointeur, le fait est déjà autonome |

**Solution** : corriger les 9 sites en une passe (remplacer par la bonne cible ou retirer
le pointeur quand le fait tient seul), puis vérifier que `review.md` n'est plus jamais
renuméroté sans grep de `"review §"` sur tout le dépôt avant de committer.
Effort : rapide — Valeur : accessoire individuellement, mais c'est exactement le genre de
détail qui fait perdre du temps à la prochaine personne qui suit un pointeur.

---

## Résumé pour la prochaine session

À faire en priorité si on attaque ce fichier : **1.1** (repli d'icône, 3 copies, un vrai
risque de divergence), **1.5** (types de Billy non centralisés, la fragilité la plus
concrète), **2.1 à 2.5** (code mort, gratuit), **3.2 à 3.4** (nommage `nav_buton.gd`,
gratuit), **5** (références `review.md` mortes, gratuit et rapide). Le reste (1.2, 1.3,
1.4, 4.1, 4.2) est accessoire ou à ne faire qu'au moment où un changement fonctionnel
touche déjà ces zones — pas la peine d'y toucher pour eux seuls.
