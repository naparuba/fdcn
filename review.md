# Review — fdcn v4

État au **2026-08-12**, branche `LINKLINSSE/refacto_V4`. **Ce document ne contient que ce
qui reste à faire** : tout ce qui a été réglé en a été retiré, l'historique est dans
`git log`.

Documents voisins : **`combat.md`** (spec complète du combat) et **`todo.md`** (la liste
d'actions du §12, en cases à cocher).

Mesures reproductibles :

```bash
# la suite de tests (à ne lancer que sur demande)
~/_Projects/godot/Godot_v4.7.1-stable_linux.x86_64 --headless -s test/all.gd --path .
```

---

## 1. Où en est l'app

**Ce qui tourne** : le boot, la navigation (5 pages, swipe + flèches + menu du haut),
l'écran Aventure complet (fil d'Ariane, position, choix de chapitre, **combat**), les
pages Chapitres et Succès (listes virtualisées), la popup d'options (inventaire, feuille
de stats + ressources, sélection de livre), les sauvegardes versionnées avec migration,
**le son** (intro, narration, type de Billy), **les annonces** d'objet gagné/perdu et de
nouveau succès, et **un thème global** (`themes/fdcn.tres`, palette documentée dans
`themes/README.md`).

**Ce qui ne tourne pas** : plus grand-chose. La page **Lore** affiche ses 16 entrées et
joue leurs voix — chaque `LoreEntry` est autonome — mais ses **deux liens** (wiki, Draziel)
sont morts faute de script sur `LoreMenu`. La page **À propos** est branchée et n'attend que
sa mise en page.

| | valeur |
|---|---|
| code vivant | **5 687** lignes de GDScript en 39 scripts, hors tests et hors `archive/` |
| tests | 1 419 lignes — **76 tests**, dernier passage vert **avant** les lots des 11 et 12 |
| scripts sans aucun test | **26 sur 39** — dont 24 d'interface |
| scènes vivantes | **30**, 105 Ko au total. **41** surcharges de style y restent, contre 570 au départ (§8.3) |

### 1.1 Écarté volontairement — à ne pas re-proposer

- **Persistance de l'état de combat.** Fermer l'app pendant un affrontement le perd.
  ⚠️ Conséquence connue : les pv déjà dépensés, eux, **restent** perdus (ils sont
  sauvegardés), donc reprendre un combat interrompu est désavantageux.
- **Affichage de `nb_infos`** dans la feuille de stats.
- **Encodage des règles spéciales de combat** dans les données des 85 combats : le moteur
  applique les règles générales, et le bouton « Gagner » est l'échappatoire.

---

## 2. Tests : couverture et angles morts

### 2.1 Couverture réelle

| | script | ce qui est vérifié |
|---|---|---|
| ✅ | `autoload/combat_engine.gd` | **42 tests** : table, écart, bornes, dégâts, armures, esquive à l'adresse **et à la chance**, critique, relance qui garde le meilleur, fuite réservée au prudent, annulation |
| ✅ | `autoload/player_stats.gd` | couches de stats, ressources bornées/sauvegardées, rejeu |
| ✅ | `autoload/save_manager.gd` | versionnage, migration v1→v2, idempotence |
| ✅ | `autoload/inventory.gd` | déduction du type de Billy, surcharge, conditions |
| ✅ | `autoload/player.gd` | chargement, rejeu d'historique, nouveau Billy, aller-retour |
| 🟡 | `autoload/Parameters.gd` | utilisé par les tests, mais aucun test ne le cible |
| 🟡 | toutes les scènes | se chargent et s'instancient, mais `_ready()` ne tourne pas |
| ❌ | **`autoload/BookData.gd`** (280 l.) | **rien** |
| ❌ | `entities/chapter_data.gd` | rien |
| ❌ | 24 scripts d'interface | rien |

### 2.2 Les angles morts, par ordre de risque

1. 🔴 **`BookData` n'a aucun test, et `_check_cond_rec` non plus.** C'est l'évaluateur
   d'arbres `$or`/`$and`/`$end` : **il décide quels chapitres sont accessibles**. Logique
   pure, sans interface, donc trivialement testable — et sans filet. Une régression ici
   ouvre ou ferme des chemins de l'aventure sans que rien ne le signale.
2. 🔴 **Aucun script d'interface n'est testé.** `test_scenes` valide la *structure* des
   scènes, pas leur comportement : `instantiate()` n'appelle pas `_ready()`, donc ni le
   branchement des signaux ni la peinture initiale ne sont exercés. Les ~400 lignes de
   `combat.gd` et les 160 de `top_menu.gd` ne sont couvertes par rien.
3. 🟠 **La suite est synchrone.** `test_case.gd` ne gère pas `await` : tout ce qui attend
   est hors de portée, dont l'animation de dé et la construction étalée de l'inventaire.
4. 🟠 **Rien ne teste la mise en page rendue.** La classe de bug propre à ce dépôt (lignes
   qui se chevauchent parce que `ROW_HEIGHT` est plus petit que la hauteur minimale réelle,
   débordement horizontal) est **invisible** pour la suite : mesurer une taille demande un
   arbre affiché, donc un test asynchrone.
5. 🟠 **608 objets fuités à la sortie.** Tant que ce bruit existe, une vraie fuite passera
   inaperçue.
6. 🟡 `Sounder` et `Narrator` n'ont aucun test. `Narrator` est pourtant de la donnée pure (chapitre → fichier) et se testerait sans interface.

### 2.3 Ce que la suite fait bien, à ne pas casser

- Elle **se sandboxe** : `SaveManager.base_dir`, `AppParameters.parameters_file` **et le
  livre courant** (`SANDBOX_BOOK`) sont neutralisés. Une partie réelle a déjà été perdue
  par un test, et la suite a déjà basculé de 54 assertions parce qu'elle héritait du livre
  choisi dans l'app.
- Un test **sans aucune assertion compte comme un échec**.
- Les dés du combat sont **injectables** : aucun test n'est soumis au hasard.
- `test_scenes` vérifie que chaque `$Chemin/De/Noeud` d'un script existe réellement dans sa
  scène — le filet indispensable pour des scènes éditées en texte.

---

## 3. Parité avec l'archive

`archive/main.gd` = 833 lignes, 65 fonctions.

### 3.1 Manquant pour de vrai

| | capacité | constat |
|---|---|---|
| **D** | 🟠 **Page Lore : il ne manque que 2 liens** | `screens/LoreMenu.tscn` porte **17 instances** de `LoreEntry` (4 Billys + 13 dieux), et chacune est **autonome** : son bouton de lecture est connecté dans sa propre scène, son `_ready()` charge son portrait, son `@tool` affiche le titre jusque dans l'éditeur. La page fonctionne donc déjà. Restent les deux `LinkButton` (`Header/LinkButton` → wiki, `LoreAuthor/LinkButton` → Draziel), morts faute de script sur `LoreMenu` — URL dans `archive/src/main.gd` (`_on_morelore_button_pressed`, `_on_image_author_button_pressed`). ⚠️ Et **`parodikos` manque** : son image et son son existent, aucune entrée ne le déclare |
| **E** | 🟢 **Page À propos : le branchement est complet** | Les 3 boutons (nouveau Billy, bug, Twitter) sont vivants. Il ne reste que la reconstruction en conteneurs (§6.1). *Correction du 2026-08-12 : cette ligne réclamait des liens « auteur » et « wiki » — ils appartiennent à la page **Lore**, pas ici. Vérifié dans `archive/src/main.tscn`, où les deux `LinkButton` sont sous `Lore/Lore/LoreAuthor` et `Lore/Header`.* |
| **G** | ⚪ **Icônes de page et de Billy du menu du haut** | `$Pages` et `$Billys` restent `visible = false` : **écarté le 2026-08-12** (§6.5), l'info est déjà accessible par le balayage, les flèches et `BillyTypeLabel`. Code dormant, pas mort |

### 3.2 Déjà porté ailleurs — ne pas re-porter

Grisage des portraits → `popups/sub/inventory.gd` · onglets → `popups/settings_popup.gd` ·
feuille de stats → `popups/sub/stats.gd` · liste d'objets → `popups/sub/inventory.gd` ·
succès → `screens/succes_menu.gd` · chapitres → `screens/chapitres_menu.gd` · barre de
saut → `entities/ChapterChoice.gd` (via `ChoiceNextChapiter`) · chargement → `Player.do_load()` +
`AppParameters._apply_book()` · type de Billy → signal `Inventory.billy_changed` · combat →
`screens/aventure_menu/combat.gd` · réglages → `ui/top_menu.gd` · livres →
`popups/sub/book_selection.gd`.

**Obsolètes, à ne pas porter** : `set_camera_to_pos` et `_on_main_background_gui_input`
(l'ancienne caméra/swipe, remplacée par `ui/menu_page.gd`), `print_debug`, le pont
`register_main`.

---

## 4. Ajouter un troisième livre

Constat de départ : **il n'existe aucun registre des livres**. Aucune liste, aucun scan de
`books/*/` — la popup de sélection *est* la liste.

### 4.1 Ce qui ne demande rien — à ne surtout pas « compléter »

| | pourquoi c'est déjà bon |
|---|---|
| **Les sauvegardes** | fichiers `<clé>-<nom>.json` créés à la demande par `prepare_save()` |
| **Les tables `{1: 'fdcn', 2: 'cdsi'}`** (`Parameters.gd`, `save_manager.gd`) | ⚠️ **ne rien y ajouter** : elles servent *uniquement* à la migration v1→v2 des sauvegardes suffixées par un numéro. Un livre neuf n'en a jamais eu |
| **`ui/top_menu.tscn`** qui référence `books/fdcn/logo.png` | ce n'est que l'aperçu de l'éditeur ; `set_book_context()` échange logo et titre à l'exécution |
| **La table de combat** | un seul fichier partagé — sauf si le marque-page du nouveau livre diffère, auquel cas il faut la passer par livre (`combat.md` §3.2) |

### 4.2 Les fichiers à fournir dans `books/<nom>/`

**Écrits à la main** (6) : `<nom>.json`, `<nom>.arcs.json`, `<nom>.sub_arcs.json`,
`<nom>.manual_sub_arcs.json`, `<nom>.all_objects.json`, `all-success.json` — plus
**`logo.png`** et **`title.png`**.

**Produits par le compilateur** : les 11 `<nom>-compilated-*.json`. `BookData` en lit
**10** ; `<nom>-compilated-combats.json` est généré et **relu par personne** (les données
de combat vivent dans `-compilated-data.json`).

### 4.3 Les trois endroits de code à modifier

| | fichier | quoi |
|---|---|---|
| 1 | **`scripts/fdcn.py`** | `--book` est un `int` avec `choices=[1, 2]`, et `book_names = {1: 'fdcn', 2: 'cdsi'}`. ⚠️ Contient aussi un cas particulier en dur : `if goto == 608 and book_number == 1` |
| 2 | **`popups/sub/book_selection.gd` + `BookSelection.tscn`** | 🔴 **le vrai point de friction** : une méthode et un `TextureButton` par livre, avec sa couverture en `ext_resource`. Rien n'est piloté par les données |
| 3 | **`autoload/inventory.gd`** `MIGRATION_GUESS` | table des objets de départ *devinés*, indexée par nom de livre. Sans entrée, une sauvegarde migrée du nouveau livre repart **sans aucun objet**, en silence |

### 4.4 Le piège qui coûtera le plus cher

`PlayerStats.apply_chapter_stat()` termine par un `_:` qui **imprime un avertissement et
jette la valeur**. Chaque livre invente son vocabulaire (§5). **Auditer les clés du nouveau
livre avant de le déclarer intégré** :

```bash
python3 -c "
import json,collections
b='<nom>'
d=json.load(open(f'books/{b}/{b}-compilated-data.json'))
c=collections.Counter()
for n in d.values():
    comp=n.get('computed') or {}
    for k in (comp.get('stats') or {}): c[k]+=1
    for p in (comp.get('stats_cond') or []):
        for k in (p.get('stats') or {}): c[k]+=1
print(sorted(c.items(), key=lambda x:-x[1]))"
```

### 4.5 À trancher **avant** d'intégrer

- **Les dossiers d'assets numérotés.** `images/dieux/1`, `images/dieux/2`,
  `sounds/dieux/1`, `sounds/dieux/2` existent. Dans l'app vivante **rien ne les lit
  encore** — mais la page Lore (§3.1 D) en aura besoin. Décider **maintenant** entre
  `dieux/3` et `dieux/<nom>/` : la page Lore écrite avant ce choix héritera d'une
  numérotation que le reste du dépôt a abandonnée au profit des noms.
- **`ROW_HEIGHT`** des listes virtualisées si le nouveau livre a des libellés plus longs :
  la hauteur de ligne doit rester ≥ la hauteur minimale réelle à 416 px de large, sinon les
  lignes se chevauchent.

### 4.6 Recommandation : un registre

Un `books/books.json` — ou un scan de `books/*/` — listant `{nom, titre, couverture}`
permettrait de rendre **`BookSelection` piloté par les données** (supprime le point 2) et
de déplacer `MIGRATION_GUESS` dans `books/<nom>/` (supprime le point 3). Ajouter un livre
redeviendrait : **déposer un dossier, compiler, ajouter une ligne**.

---

## 5. Vocabulaire de stats par livre

### 5.1 La mesure

| clé | fdcn | cdsi | |
|---|---|---|---|
| `richesse` | **15** | **13** | partagée |
| `gloire` | **19** | **0** | fdcn seulement |
| `info` | **20** | **0** | fdcn seulement |
| `rancune` | **0** | **18** | cdsi seulement |
| `respect` | **0** | **14** | cdsi seulement |

**Un compteur commun + deux propres à chaque livre**, aucun croisement.

⚠️ Conséquence immédiate : la ligne « Gloire » de la feuille de stats affiche **0 pour
toujours** quand cdsi est chargé, et deux compteurs cdsi sur trois sont invisibles. Le
codage en dur est structurellement faux, pas seulement incomplet.

### 5.2 Les variantes d'orthographe sont un défaut de saisie

| source écrite à la main | contenu |
|---|---|
| `books/fdcn/fdcn.json` | `"crit"` ×5, `"half_pv"` ×1 |
| `books/cdsi/cdsi.json` | `"critique"` ×5, `"pv_1_2_max"` ×1 |

Le compilateur n'invente rien (`node.py:set_stats()` recopie tel quel). 🔴 **Et il avait
déjà tout pour l'attraper** : `scripts/fdcn.py:374` collecte et **imprime** toutes les clés
de stats du livre — il lui manque la **liste de référence** et un `sys.exit(2)`. `critique`
était listé à chaque compilation de cdsi, noyé dans les traces.

### 5.3 Les « règles ponctuelles » : 3 sur 4 sont des défauts de données

| clé | où | verdict |
|---|---|---|
| `arc_et_couteau` | fdcn **ch284**, condition *« ARC et COUTEAU »* | 🔴 **trou de saisie** : l'effet déclaré est le **nom de la condition recopié dans la case de l'effet**. L'effet réel n'est écrit nulle part. ✅ Rien à faire côté condition : l'arbre `$and` sur ARC + COUTEAU s'évalue déjà, et les deux objets existent |
| `pv_win_plus_1` | fdcn **ch126**, condition PAYSAN | 🟠 **vraie règle** : « gagner 1 pv en donne 2 ». Les 3 autres types du même chapitre ont des bonus chiffrés, le PAYSAN un booléen |
| `pv_1_4_max` / `1_4_pv_max` | fdcn **ch178** et **ch448**, arc « Prison » | 🟡 **la même règle** (pv au quart du max), **deux orthographes dans le même livre** |

### 5.4 Notation d'effet plutôt qu'un mot-clé par règle

Elle **absorbe six mots-clés existants**, soit 16 occurrences : `max_pv` ×10,
`max_chance` ×2, `half_pv`, `pv_1_4_max`, `1_4_pv_max`, `pv_1_2_max`.

```json
"stats": { "pv": 5 }            // NOMBRE  -> += 5. Comportement actuel, inchangé
"stats": { "pv": "= max" }      // CHAÎNE  -> une expression
"stats": { "pv": "= max/4" }
"stats": { "pv": "= moi/2" }    // moitié de la valeur COURANTE
"stats": { "pv": "- max/2" }
"stats": { "chance": "= max" }  // remplace `max_chance`, sans code dédié
```

- une **valeur numérique** garde le sens additif actuel → **aucune migration** des ~200
  entrées chiffrées existantes ;
- une **chaîne** commence par l'opérateur (`=`, `+`, `-`) et porte une expression sur deux
  jetons : **`max`** (le plafond de la stat) et **`moi`** (sa valeur courante),
  éventuellement divisés par un entier.

⚠️ **Pourquoi `moi` et `max` doivent être explicites** : `half_pv` fait aujourd'hui
`pv /= 2`, soit la moitié du **courant**, alors que `pv_1_2_max` dit « max ». Ce ne sont
**peut-être pas la même règle**, et les unifier sous un seul mot-clé serait une régression
silencieuse. **À vérifier dans le livre avant d'unifier les orthographes**, pas après —
c'est la seule question que les données ne tranchent pas.

### 5.5 `pv_win_plus_1` est un modificateur de gain

```json
"stats": { "pv_gain": 1 }     // chaque gain de pv est majoré de 1
"stats": { "chance_gain": 1 } // même mécanique pour n'importe quelle ressource
```

- un `_gain_bonus` par ressource, **dans la couche « chapitres »** : il vient d'un
  chapitre, donc remis à zéro par `reset_chapter_layer()` et reconstruit par le rejeu,
  exactement comme `pv_max_bonus` ;
- appliqué dans `add_pv()` / `add_chance()`, **uniquement sur un delta positif** — un bonus
  de gain ne doit pas amortir les dégâts ;
- **jamais sur une affectation** (`"= max"`), sinon « pv au plein » devient « au plein + 1 »,
  donc au-dessus du plafond.

### 5.6 La forme du vocabulaire

`books/<nom>/<nom>.vocabulaire.json`, **deux listes** :

```json
{ "compteurs": [ {"cle": "richesse", "libelle": "Richesse"},
                 {"cle": "rancune",  "libelle": "Rancune"},
                 {"cle": "respect",  "libelle": "Respect"} ],
  "ignorees":  [ "arc_et_couteau" ] }
```

Pas de liste d'alias : les orthographes se corrigent à la source (§5.2), les entretenir
dans le moteur serait entretenir la faute.

Ce que ça change : `PlayerStats` perd ses trois variables en dur (`gloire`, `richesse`,
`nb_infos`) pour un dictionnaire `_compteurs` ; `apply_chapter_stat()` y range toute clé
déclarée, et son `_:` continue d'avertir sur une clé inconnue ; **la feuille de stats
génère ses lignes** depuis le livre courant. Rien à sauvegarder — les compteurs restent
dérivés des chapitres.

---

## 6. Composants non flex

Mesure : nœuds `layout_mode = 0` (positionnés à la main) et lignes `offset_*` brutes,
contre le nombre de conteneurs.

### 6.1 État — une seule scène reste vraiment à convertir

| scène | nœuds | `lm=0` | `offset_*` | cont. | nature |
|---|---|---|---|---|---|
| **`screens/AboutMenu.tscn`** | 31 | **13** | **65** | **0** | 🟡 la dernière en position absolue pure. **À reconstruire avec sa page** (action 2.2) |
| `screens/LoreMenu.tscn` | 26 | 3 | 14 | 2 | 🟢 en-tête et pied convertis ; les 3 restants sont le pied `LoreAuthor`, à reprendre avec les 2 liens (action 2.1) |
| `entities/EndingChoice.tscn` | 19 | 2 | 17 | 4 | ✅ converti — les 2 restants sont les libellés **tournés** de la pastille « Oups », donc du dessin |
| `ui/bread.tscn` | 5 | 2 | 9 | 0 | ✅ atome de taille fixe : les `offset_*` sont le chevron lui-même |
| `ui/NavButon.tscn` | 5 | 1 | 7 | 0 | ✅ atome ; sa barre et son libellé sont calculés à l'exécution |
| `entities/ChapterChoice.tscn` | 24 | **0** | 24 | 2 | ✅ converti — les `offset_*` sont les 6 rubans et leurs libellés tournés |
| `entities/SuccessItem.tscn` | 13 | **0** | 8 | 4 | ✅ converti — ruban dans un `Control` de 96×69 |
| `entities/LoreEntry.tscn` | 12 | **0** | 8 | 3 | ✅ reconstruit, et allégé de 2,7 Mo |
| `popups/SuccessPopup.tscn` | 7 | **0** | 8 | 0 | ✅ `Popup` → `Control`, animations conservées |
| `popups/ItemPopup.tscn` | 5 | **0** | 0 | 2 | ✅ converti, `Sprite2D` → `TextureRect` |

**Lire ce tableau correctement** : un `offset_*` dans un atome de taille fixe n'est pas une
dette. Les points d'un `Polygon2D` et la position d'un libellé tourné **sont** le dessin ;
c'est la politique du §6.3. Ne restent de la vraie dette que les 13 `layout_mode = 0` et
65 `offset_*` d'`AboutMenu`, seule scène de l'app avec **zéro conteneur**.

`left_backer`, `right_nexter` et `going_to_line` figuraient ici : ils sont partis dans
`archive/` (§11.3). `gauge` en est sortie **convertie** en `Control`, ce qui a supprimé le
contournement `GaugeSizer` de `GlobalCompletion.tscn`.

Mesure globale au 2026-08-12 : **20** nœuds en `layout_mode = 0` (dont 13 dans la seule
`AboutMenu`) et **184** `offset_*` bruts.

Et un effet de bord qui vaut d'être noté : le poids total des scènes du dépôt est passé de
**~2,8 Mo à 105 Ko**. `LoreEntry.tscn` embarquait une `Image` de 320×435 sérialisée dans le
`.tscn` — une copie exacte de `images/billys/guerrier.png`, qui ne servait que d'aperçu
d'éditeur puisque le script remplace la texture à l'exécution. La scène est passée de
2 744 280 à 3 636 octets.

### 6.2 Les polygones sont tous encapsulés

Les **5 scènes** qui portaient des `Polygon2D` à points figés sont traitées, chacune selon la
politique du §6.3 :

| scène | encapsulation |
|---|---|
| `ChapterChoice` | les 6 rubans dans `Row/Rubans`, un `Control` de 158×75 |
| `SuccessItem` | le ruban dans `Marker`, 96×69 |
| `EndingChoice` | le ruban dans `Ruban`, 75×260 |
| `bread` | la racine **est** l'atome — ⚠️ largeur minimale 70 pour un dessin de 91, et c'est ce débordement qui fait chevaucher les chevrons |
| `NavButon` | la racine est l'atome, et son polygone est en plus **recalculé** à l'exécution pour suivre la hauteur d'écran |

Aucun point n'a bougé. Pour `ChapterChoice`, le script ne pilote que la **couleur** des
6 polygones — la géométrie reste entièrement dans la scène.

### 6.3 La politique des widgets à polygones — tranchée : **atomes de taille fixe**

Décision du 2026-08-12. Le widget **garde ses points en dur** et un conteneur le place comme
un bloc indéformable, via un `Control` porteur d'un `custom_minimum_size`. L'option écartée
était de recalculer les points depuis `size` dans `_draw()`.

Le patron, tel qu'appliqué à `ChapterChoice` : les 6 `Polygon2D` sont passés sous
`Row/Rubans`, un `Control` de **158×75** — la largeur exacte de leur emprise, mesurée depuis
leurs points. Aucune coordonnée n'a bougé.

Deux pièges déjà payés ici, et c'est ce qui a motivé la décision : **ne jamais *étirer* un
polygone** (ça biaise l'angle et l'échelle se transmet aux `Label` enfants), et **une pente
doit être un décalage en pixels, pas un ratio** (sinon une ligne plus haute penche plus loin
et le ruban écrit par-dessus le texte).

`ui/gauge` fait mieux que le contrat et c'est voulu : son dessin était déjà paramétrique, il
déduit donc son rayon de `size`. Elle garde une taille minimale de 100×100 pour ne pas être
écrasée par un conteneur trop serré.

### 6.4 Plus aucune scène au format Godot 3

Les sept sont converties. Mais le format n'était que la partie visible : **ce sont les
propriétés Godot 3 survivantes qui font des dégâts**, et elles ne se signalent jamais.

⚠️ **Les propriétés Godot 3 ne migrent pas toutes seules, et leur perte est silencieuse.**
Trois cas rencontrés, tous invisibles jusqu'à ce qu'on les cherche :

| propriété | où | conséquence |
|---|---|---|
| `popup(Rect2(...))` | `SuccessPopup` | 🔴 en Godot 4 un `Popup` est un `Window` : l'appel **réduisait la fenêtre à 0 × 0** dès la première image. Ni texte, ni animation |
| `play("\"hide\"")` | `SuccessPopup` | guillemets **dans** la chaîne, artefact de sérialisation : aucune animation de ce nom |
| `anchor_right = 0.0` + `offset_right = -8` | `SuccessPopup` | largeur de **−16** : la carte du succès était écrasée hors cadre |
| `autowrap = true` | `EndingChoice` | le texte des fins ne revenait **pas** à la ligne |
| `autowrap = true` | `LoreEntry` | idem — et l'éditeur l'a **supprimée sans remplacement** en réenregistrant la scène |
| `align = 2` | `LoreEntry` | l'éditeur l'a convertie en `horizontal_alignment = 1`, soit **centré au lieu de droite** |
| `size` / `font_data` sur `FontFile` | `amon_font.tres` et 6 scènes | la police ne porte aucune donnée et **mesure 0** (§8.5) |

Le décompte de cette section a été faux deux fois : « cinq scènes, trois avec `align`/`valign` »
comptait en réalité l'`align` **et** le `valign` d'un même nœud de `left_backer` (archivé
depuis) ; puis « quatre scènes » avait manqué `Sounder`, `bread` et `gauge`.

### 6.5 Les icônes du menu du haut restent masquées — tranché

Décision du 2026-08-12 : **on garde la barre telle quelle et l'action est fermée.** Tout
afficher demanderait ~780 px pour **540 disponibles**.

Le raisonnement : ces icônes sont redondantes. La navigation se fait déjà par balayage et
par les deux flèches latérales, et le type de Billy est écrit **en texte** dans la barre
(`BillyTypeLabel`). Dé-masquer aurait coûté un arbitrage de mise en page pour une
information déjà accessible deux fois.

`$Pages` et `$Billys` restent donc `visible = false`, et `set_page()` reste sans appelant.
⚠️ Ne pas « nettoyer » `set_page()` en la supprimant : les 4 boutons de type de Billy de
`$Billys` sont branchés et fonctionnels, l'ensemble est du code dormant, pas du code mort.

---

## 7. Export / import d'une sauvegarde

### 7.1 Ce que ça vaut

Une sauvegarde complète = **7 fichiers JSON par livre** + `parameters.json`, soit une
quinzaine de fichiers de quelques kilo-octets. **La compression ne sert à rien pour le
poids** : ce qu'on gagne, c'est **un seul fichier déplaçable** (sauvegarde de secours,
changement de téléphone, envoyer sa partie). Le zip est un conteneur, pas un compresseur.

### 7.2 Format : zip, et pas rar

`ZIPPacker` et `ZIPReader` sont **natifs dans Godot 4.7.1** (vérifié) : aucune dépendance.
**Rar est à écarter** : format propriétaire, aucun encodeur disponible.

```
fdcn-save-2026-08-11.zip
├── manifest.json          <- version d'archive, date, livre courant, save_version par livre
├── parameters.json
├── fdcn/  {all_times_already_visited,current_node_id,session_visited_nodes,
│           possessed_item,pv,chance,save_version}.json
└── cdsi/  idem
```

Le **manifeste n'est pas décoratif** : il permet à l'import de *décrire ce qu'il va écraser
avant de l'écraser* et de refuser une archive trop récente avec un message utile.

### 7.3 Le vrai obstacle : sortir du bac à sable

| plateforme | difficulté |
|---|---|
| **Windows / Linux** | 🟢 `FileDialog`, direct |
| **Android** | 🔴 `user://` est **privé à l'app**, invisible du gestionnaire de fichiers ; le *scoped storage* (API 30+) rend l'écriture externe capricieuse |
| **HTML5** | 🔴 `user://` est de l'IndexedDB : export = **téléchargement navigateur** via `JavaScriptBridge`, import = `<input type=file>` |

D'où la contrainte de conception : **un moteur d'archive découplé du transport**.
Empaqueter, valider, appliquer est identique partout ; seul « où poser le fichier » change.
Desktop d'abord.

### 7.4 L'import doit être atomique

Un import à moitié appliqué produit une **sauvegarde Frankenstein** — les objets d'une
partie avec le chapitre d'une autre — bien pire qu'un import raté. Donc :

1. décompresser dans `user://import_tmp/` ;
2. **tout valider** : fichiers attendus, JSON qui parse, `save_version` connue et pas
   supérieure à `CURRENT_SAVE_VERSION` ;
3. **sauvegarder l'état actuel** dans `user://backup-avant-import.zip` — le filet doit être
   automatique, pas un conseil dans une notice ;
4. basculer, puis `Player.do_load()`.

**Gratuit grâce au versionnage existant** : `prepare_save()` applique déjà la chaîne de
migrations et refuse déjà une version future. L'import n'a rien à réimplémenter.

### 7.5 Deux dépendances

- **Confirmation avant écrasement** : `MenuPage.confirm()` existe déjà.
- **Où le mettre** : la page **À propos**, déjà à construire — une scène au lieu de deux.

### 7.6 Pourquoi le faire tôt

C'est **entièrement couvrable par la suite existante** : empaqueter → décompresser →
valider → appliquer est de l'I/O dans `user://`, et le lanceur sandboxe déjà tout. Un
aller-retour complet, une archive tronquée, une archive de version future, une archive d'un
seul livre : tout se teste sans interface et sans appareil.

⚠️ Effet de bord accepté : une sauvegarde exportée est du JSON dans un zip, donc modifiable
à la main. Pour un compagnon de livre-jeu solo, ce n'est pas un problème.

---

## 8. Le thème est en place — 450 surcharges repliées, 41 restent (et c'est voulu)

**`themes/fdcn.tres` est écrit et déclaré** (`project.godot` `[gui] theme/custom`), avec
sa palette documentée dans **`themes/README.md`**. Toutes ses couleurs sont relevées dans
les scènes à la valeur exacte : l'app est censée avoir **le même rendu qu'avant**, le
thème ne fait que centraliser ce qui était recopié.

Ce qu'il change réellement, c'est-à-dire les nœuds qui n'avaient **aucune** surcharge et
tombaient donc sur le thème par défaut de Godot : les **9 boutons** nus (les 2 de
`GenericConfirmationPopup`, 4 de `Combat`, le `LinkButton` du Lore, les 2 interrupteurs du
menu du haut), les **4 boutons `±`** de la feuille de stats qui n'avaient qu'un
`font_size`, et **5 `Label`** sans police. C'est exactement le « telle popup ne suit pas le
style » — ces widgets montraient l'app *sans* habillage.

### 8.1 Le diagnostic d'origine

Le look de l'app venait de **570 `theme_override_*` posés nœud par nœud**. Le décompte a été **affiné** depuis : tous
les `theme_override_*` ne sont pas du style. Les `margin_*` et `separation` des conteneurs
sont de la **mise en page**, ils ont leur place dans la scène et ne partiront jamais dans le
thème. Séparés, au 2026-08-12 :

| | nombre | sort |
|---|---|---|
| **style** — `colors`, `fonts`, `font_sizes`, `styles`, `shadow_*` | **450** | à replier dans le thème (action 5.1) |
| **mise en page** — `separation` (53), `margin_*` (28), `h/v_separation` (4) | **85** | reste dans les scènes |

Dont **165 lignes `shadow_*`** qui ne font rien du tout (voir §8.4) : le vrai reliquat de
style utile est donc de ~284 lignes.

La répartition d'origine, pour mémoire :

| catégorie | nombre |
|---|---|
| `theme_override_constants/*` | 237 |
| `theme_override_fonts/*` | 104 |
| `theme_override_colors/*` | 97 |
| `theme_override_styles/*` | 73 |
| `theme_override_font_sizes/*` | 7 |

Les plus chargées : `popups/sub/Stats.tscn` (155), `Combat.tscn` (119),
`AboutMenu.tscn` (70), `Position.tscn` (50).

### 8.2 Ce que la répétition disait du thème à écrire

| valeur | occurrences | rôle évident |
|---|---|---|
| `theme_override_fonts/font` | **135** (84 `ExtResource`, 49 `SubResource`) | les deux polices `amon_font` / `amon_font_small` |
| `Color(0,0,0,1)` | 85 | couleur de texte par défaut |
| `shadow_offset_x/y = 0` + `shadow_outline_size = 0` | **55 fois chacun** | *le même trio recopié sur 55 `Label`*, juste pour éteindre l'ombre du thème par défaut |
| `#00c2aa` | 27 | couleur d'accent |
| `#313b47` | 14 | fond des en-têtes |
| `#e9eaec` | 14 | fond neutre / état inactif |

Les 49 `SubResource` de police sont des enveloppes `FontFile` **reconstruites scène par
scène** autour du même `.ttf` — `Stats.tscn` en déclare deux à lui seul.

### 8.3 Le repli est fait : 450 → 41

| | avant | après |
|---|---|---|
| surcharges de **style** | 450 | **41** |
| `theme_type_variation` posées | 0 | **99** |
| variations déclarées | 11 | **15** |
| sous-ressources orphelines | — | **52 retirées** |
| poids des scènes | 134 Ko | **105 Ko** |

Ce qui a été fait, par lot :

| lot | nombre | quoi |
|---|---|---|
| `shadow_offset_*` + `shadow_outline_size` | 165 | supprimées — elles ne faisaient rien |
| `fonts/font` | 104 | supprimées : le thème fournit la vraie police |
| `colors/font_color` noir | 62 | supprimées : c'est le défaut du thème |
| `colors/*` colorées | 28 | → `TexteAccent` (10), `TexteAtenue` (9), `TexteAppuye` (5), `TexteAlerte` (3), `TitreHeader` (1) |
| `styles/panel` figées | 50 | → `Carte` (14), `EnTete` (12), `Pastille` (8), `Ligne` (5), `Fond` (4), `Encart` (3), `Voile` (2), `EncartPlat` (2) |

Les 56 styleboxes figées ne formaient que **15 formes distinctes**. Les variations de
panneau ont donc été **redéfinies pour être exactement ces formes**, marges de contenu
comprises — sans quoi le repli aurait ajouté du rembourrage à 50 endroits d'un coup. Un
seul écart assumé : `Combat.tscn/EcartPanel` passe d'un rayon 3 à 2 (1 px), et
`AventureMenu` voit ses `0.9254902…` unifiés sur `0.92549` (écart de 2·10⁻⁷).

### 8.3 bis Les 41 qui restent, et pourquoi

| | nombre | raison de rester |
|---|---|---|
| `styles/panel` **pilotées par du code** | 14 | 🔴 six scripts les lisent par `get('theme_override_styles/panel')` et les **mutent en place** |
| `styles/*` de forme unique | 5 + 6 états | une variation utilisée une fois cache la valeur sans rien mutualiser |
| `font_sizes/*` | 10 | tailles locales délibérées (40 pour « Oups », 24 pour les `±`, 20 pour un nom d'objet) |
| `colors/font_color` orphelines | 4 | `#776c6c`, `#c27200`, `#999fa3`, `#009973` — une occurrence chacune |

⚠️ **Le garde-fou qui a servi.** La liste des nœuds pilotés par du code a d'abord été
écrite à la main, et il en manquait un : `Combat.tscn/IssuePanel`, que `combat.gd` repeint
en vert ou rouge à la fin d'un affrontement. Elle a été **reconstruite en lisant les six
scripts**. Le cas le plus dangereux était `settings_popup.gd:_highlight_tab`, qui mute le
stylebox des trois onglets **sans garde `null`** : retirer leur surcharge aurait planté à
l'ouverture de la popup d'options.

### 8.4 Comment replier, et dans quel ordre

**Rien ne casse tant qu'on n'y touche pas** : une surcharge **gagne** toujours sur le
thème. C'est ce qui rend la suite sûre, scène par scène.

Le mécanisme est la **variation de type** : la scène ne déclare plus qu'un rôle, la couleur
reste dans le thème.

```
theme_type_variation = &"TitreHeader"
```

11 variations sont prêtes (`TitreHeader`, `TexteAccent`, `TexteAtenue`, `TexteAppuye`,
`TexteAlerte`, `Carte`, `Fond`, `EnTete`, `Encart`, `SwitchOui`, `SwitchNon`) — voir
`themes/README.md`.

Les 162 lignes `shadow_offset_x/y` + `shadow_outline_size` peuvent partir **sans
réfléchir** : en Godot 4 `font_shadow_color` est déjà transparent, ces constantes ne
faisaient rien, et le thème pose la transparence explicitement.

Les couleurs vraiment locales (rouge/jaune des jauges, vert/rouge des issues de combat)
restent en code, où elles sont déjà des constantes nommées.

⚠️ **Deux entrées volontairement absentes du thème**, avec leur raison, dans
`themes/README.md` : `Panel/styles/panel` (peindrait un fond sur les deux bandes de
navigation, qui n'ont qu'un `Polygon2D`) et les `separation` de conteneurs (déplacerait la
mise en page des 20 conteneurs qui n'en déclarent aucune).

⚠️ **Ordre par rapport au §6** : les scènes à repasser en conteneurs traînent chacune leur
habillage ; maintenant que le thème est là, leur réécriture **supprime** ces lignes au lieu
de les recopier.

### 8.5 ✅ `amon_font.tres` n'est plus utilisée par personne

**Le problème s'est dissous.** Il déclarait `size` et `font_data`, des noms de propriétés
**Godot 3** que le `FontFile` de Godot 4 n'expose pas : la police ne portait aucune donnée
et **mesurait 0**, si bien que tout widget dimensionné sur son texte le rognait — c'est ce
qui affichait « O » au lieu de « Oui ».

Les 104 surcharges qui la citaient ont été supprimées avec le repli (§8.3) : chacune de ces
nœuds prend maintenant la police du thème, `RobotoCondensed-Regular.ttf`, la vraie. Il ne
restait donc **plus une seule référence vivante**.

Conséquence : `amon_font.tres` et `amon_font_small.tres` n'étaient plus lues que par
l'archive → parties dans `archive/src/`. `Pancis-Regular` (l'`.otf` **et** le `.ttf`), la
police d'origine du projet Godot 3, n'était référencée par **rien du tout** → `archive/unuzed/`.
`fonts/` ne contient plus que RobotoCondensed, la seule réellement utilisée.

Il n'y avait rien à réparer : il y avait à retirer.

---

## 9. Le compilateur Python (`scripts/`, 959 lignes)

`fdcn.py` (405 l.), `node.py` (379), `condition_node.py` (144), `graph.py` (27),
`endings.py` (4).

### 9.1 🔴 Le traitement des fins est du code mort — recompiler perdrait les fins

```python
goto = n.get('goto', [])
if isinstance(goto, int):
    goto = [goto]                        # (1) goto devient TOUJOURS une liste
goto = node.get_all_possibles_goto(goto) # (2) et cette fonction renvoie list(...)

if isinstance(goto, int):                # (3) donc ceci ne peut JAMAIS être vrai
    ...
        node.set_ending(_ending)         # (4) seul appel de set_ending du projet
```

`get_all_possibles_goto()` se termine par `return list(goto)`. La condition (3) est donc
**toujours fausse** et tout le bloc des fins est **inatteignable** — y compris ses deux
`sys.exit(2)` de validation et l'unique `set_ending()` du dépôt.

**L'historique git le confirme** :

| | commit | date |
|---|---|---|
| introduction de `goto = [goto]` | `2c02496` | **2026-08-10** |
| dernière génération des json compilés | `f31b957` | **2026-08-09** |

Les données actuelles ont été produites **la veille** de la régression : elles contiennent
bien 19 fins pour fdcn, mais **ne sont plus reproductibles**. Recompiler viderait
`endings`, `good-endings`, `bad-endings` et mettrait `computed.ending` à faux partout,
**sans un seul message d'erreur**.

Correctif : tester la **liste** (`len(goto) == 1 and goto[0] == 608`), ou mieux, ne pas
mêler « ce nœud est une fin » à « où va-t-il » — le marqueur est déjà dans la source.

### 9.2 Ce qui rend le code difficile à lire

| | constat |
|---|---|
| **Script à plat** | `fdcn.py` n'a **aucune fonction** hors `load_json_file` : 405 lignes de haut en bas, **40 variables globales** mutées au fil du fichier |
| **66 `print()`** | 42 + 15 + 9. Aucun niveau de log : la validation utile est noyée. **C'est pour ça que `critique` est passé inaperçu** (§5.2) |
| **Code commenté laissé en place** | `# goto = n['goto']` juste sous la ligne qui le remplace, `# print(...)` en série |
| **Copié-collé du bloc de lecture** | 10 fois `x = n.get('x', défaut)` / `if x: node.set_x(x)`, avec des défauts incohérents (`{}` pour `stats_cond` alors que `node.py` l'initialise à `None`) |
| **Deux commentaires « Get the combat entry if any »** | à la suite, dont un sur le bloc `secret` |
| **Mélange des responsabilités** | `node.py` fait le modèle, la sérialisation **et** la présentation graphviz (`get_label()` renvoie du HTML coloré) |
| **Annotations de type en commentaire** | `# type: (list) -> list`, style Python 2, alors que le projet est en f-strings |
| **`get_all_stats_keys()` imprime** | une fonction « get » qui écrit sur la sortie standard |

### 9.3 Ce qui est sain, à ne pas casser

- La **séparation `Graph` / `Node` / `ConditionNode`** est correcte, et le parseur de
  conditions produit bien deux sorties (l'arbre pour le moteur, le texte pour l'affichage).
- Les **validations existent** (secrets à deux entrées, fin sans type, objets sans
  chapitre) : elles sont juste invisibles faute de niveaux de log.
- La **sortie est déterministe** (`sort()`, `sort_keys=True`) : les json compilés ne bougent
  pas sans raison, ce qui rend un diff lisible.

---

## 10. Bugs et risques ouverts

| | gravité | quoi |
|---|---|---|
| 10.1 | 🔴 | **Le compilateur perdrait les fins à la prochaine exécution** (§9.1). Ne pas recompiler avant correction |
| 10.2 | 🟡 | **cdsi perd deux compteurs** : `rancune` (18 chapitres) et `respect` (14) tombent dans le `_:` de `apply_chapter_stat`. Cause commune et correctif unique en §5 |
| 10.3 | 🟡 | **4 clés de stats ignorées** — élucidées en §5.3, elles deviennent la liste `ignorees` du vocabulaire |
| 10.4 | 🟡 | **La ligne « Gloire » de la feuille de stats affiche 0 pour toujours sur cdsi** (§5.1) |

---

## 11. Dette et hygiène

| | quoi |
|---|---|
| 11.1 | **`project.godot` garde des clés Godot 3** : `[rendering] quality/driver/driver_name="GLES2"`, `vram_compression/import_etc`. Ignorées par Godot 4, trompeuses |
| 11.2 | **608 objets fuités** à la fin des tests (§2.2) |
| 11.3 | **`archive/` est trié** (voir ci-dessous) : fin de vie à décider quand §3 est terminé. Elle reste la seule source de vérité sur la page Lore et la page À propos |
| 11.4 | **Duplication de décoration de ligne** : `ChapterChoice.update_from_son_node` + `update_when_in_all_chapters` + `success_item.update` refont trois fois la même logique spoil/vu/fin/succès/secret |
| 11.5 | **4 setters quasi identiques dans `Parameters.gd`** : un helper `_set(clé, valeur)` suffirait |
| 11.6 | **`MIGRATION_GUESS`** est du contenu de livre codé dans `autoload/inventory.gd` : sa place est dans `books/<nom>/` |
| 11.7 | **`chapter_data.gd extends Node`** alors que c'est une donnée pure : `RefCounted` conviendrait, et les instances ne sont pas libérées au changement de livre |

### 11.8 Le tri d'`archive/`

Graphe de références reconstruit depuis les vraies racines — `run/main_scene` et les
10 autoloads de `project.godot`, plus `test/all.gd` — en suivant à la fois les chemins
`res://` **et** les `uid://` (une scène peut ne citer que l'uid). Résultat : **71 fichiers
vivants**, et 13 qui ne l'étaient pas.

`archive/src/` — l'ancienne app, cohérente et **toujours ouvrable dans l'éditeur** :

| fichier | pourquoi |
|---|---|
| `main.tscn` + `main.gd` | l'archive elle-même, déplacée pour que `archive/` n'ait plus de fichiers en vrac |
| `left_backer.tscn` + `left_backer.gd` | flèche de navigation de l'ancienne app, instanciée 5× par `main.tscn` **et par personne d'autre**. Remplacée par `ui/NavButon.tscn` |
| `right_nexter.tscn` | même chose côté droit — et elle **partage le script de `left_backer`** |

`archive/unuzed/` — référencé par **rien du tout**, ni vivant ni archive :

| fichier | pourquoi |
|---|---|
| `going_to_line.tscn` + `going_to_line.gd` | ancêtre de `ChapterChoice` : `format=2`, et son script pilote encore un `father` que plus personne ne lui donne |
| `side_buttons_background_style.tres` | l'unique `.tres` de `themes/` (§8.1) |
| `shader_grey.tres` | `ShaderMaterial` vide, `format=2`. Le vrai grisage passe par `shaders/gray.gdshader`, bien vivant |
| `default_env.tres` | seule référence : `[rendering] environment/defaults/default_environment`. Un environnement 3D dans une app **sans un seul nœud 3D** — la ligne a été retirée de `project.godot` |

**Pas de `.gdignore` dans `archive/`, volontairement.** Ce serait cohérent avec
`scripts/.gdignore`, mais Godot cesse alors de voir le dossier : `archive/src/main.tscn`
deviendrait impossible à ouvrir dans l'éditeur, alors que c'est justement le plan de la page
Lore et de la page À propos qu'il reste à porter (§3.1 D et E). À poser quand la catégorie 2
sera finie, pas avant.

**Les assets ne sont pas triés**, et c'est délibéré : `images/` et `sounds/` sont chargés par
noms **construits à l'exécution** (`images/items/%s.svg`, `images/success/%s.png`,
`images/endings/%s.png`, `images/dice/%s-%s.svg`, `sounds/%s`, et `images/<type>/` pour le
Lore), noms qui viennent des json de livres. Aucune analyse statique ne peut donc conclure —
il faut un passage piloté par les données, en croisant les 668 images avec les objets, succès
et fins des deux livres. Seul cas déjà identifié : `images/fight.png`, dont `going_to_line`
était le seul lecteur.

---

## 12. Liste d'actions

Numérotation **catégorie.rang**, les catégories étant dans l'ordre de priorité.

**30 actions en 6 catégories.** La catégorie « Style et flex » a disparu : ses deux
dernières actions sont closes (§8.3, §8.5).

### 1 — Perte de données et angles morts critiques

| # | tag | action | réf |
|---|---|---|---|
| 1.1 | `[bug]` | 🔴 **Réparer la branche des fins de `scripts/fdcn.py`** — **et ne pas recompiler un livre avant** : les json actuels sont bons, une recompilation viderait les 19 fins de fdcn sans un message d'erreur | §9.1 |
| 1.2 | `[test]` | Tester `BookData`, en commençant par `_check_cond_rec` (`$or`/`$and`/`$end`, imbrication, condition absente) | §2.2 |

### 2 — Parité avec l'archive

| # | tag | action | réf |
|---|---|---|---|
| 2.1 | `[feature]` | **Page Lore, petit reste** : un script sur `LoreMenu` pour brancher les 2 `LinkButton` (wiki, Draziel), déclarer l'entrée **`parodikos`** qui manque, et reprendre le pied `LoreAuthor` en conteneurs. Les 17 entrées, elles, marchent déjà. ⚠️ Après **4.7** : le renommage `dieux/<nom>/` change ce que `LoreEntry` va chercher | §3.1 D, §6.1 |
| 2.2 | `[style]` | **Page À propos** : reconstruction en conteneurs. Le branchement est déjà complet | §3.1 E, §6.1 |

### 3 — Export / import d'une sauvegarde

| # | tag | action | réf |
|---|---|---|---|
| 3.1 | `[feature]` | **Moteur d'archive** découplé du transport : 7 clés × chaque livre + `parameters.json` + `manifest.json`, avec `ZIPPacker` | §7.2 |
| 3.2 | `[feature]` | **Import atomique** : dossier temporaire → validation complète → sauvegarde de secours automatique → bascule | §7.4 |
| 3.3 | `[feature]` | Transport par plateforme : `FileDialog` desktop d'abord, Android et HTML5 en chantiers séparés | §7.3 |
| 3.4 | `[test]` | Aller-retour complet, archive tronquée, archive de version future, archive d'un seul livre | §7.6 |

### 4 — Données de livre

| # | tag | action | réf |
|---|---|---|---|
| 4.1 | `[bug]` | **Corriger les orthographes à la source** : `critique`→`crit` (×5), `pv_1_2_max`→`half_pv` dans `cdsi.json` ; unifier `pv_1_4_max`/`1_4_pv_max` dans `fdcn.json`. ⚠️ **Vérifier d'abord dans le livre** si `half_pv` et `pv_1_2_max` sont bien la même règle | §5.2, §5.4 |
| 4.2 | `[bug]` | **Faire échouer `scripts/fdcn.py`** sur une clé de stat hors vocabulaire : il les collecte et les imprime déjà, il manque la liste de référence et un `sys.exit(2)` | §5.2 |
| 4.3 | `[refacto]` | **Notation d'effet** (`"pv": "= max/4"`) : absorbe 6 mots-clés, aucune migration des entrées chiffrées | §5.4 |
| 4.4 | `[feature]` | **`pv_gain`** : modificateur de gain dans la couche chapitres, delta positif seulement, jamais sur une affectation | §5.5 |
| 4.5 | `[refacto]` | **Vocabulaire déclaré par livre** (`compteurs` + `ignorees`) : `PlayerStats` passe à un dictionnaire, la feuille de stats génère ses lignes | §5.6 |
| 4.6 | `[refacto]` | **Registre des livres** (`books/books.json` ou scan) : rend `BookSelection` piloté par les données | §4.6 |
| 4.7 | `[place]` | Trancher `images/dieux/<n>` → `dieux/<nom>/` **avant** d'écrire la page Lore | §4.5 |

### 5 — Compilateur Python

| # | tag | action | réf |
|---|---|---|---|
| 5.1 | `[refacto]` | **Des niveaux de log** (`--verbose`) : 66 `print()` noient les validations utiles | §9.2 |
| 5.2 | `[refacto]` | **Découper `fdcn.py`** : `lire_les_noeuds()` / `taguer_les_arcs()` / `construire_le_graphe()` / `ecrire_les_json()`. Le graphviz est la moitié du fichier et l'app ne s'en sert pas | §9.2 |
| 5.3 | `[refacto]` | Sortir la présentation graphviz de `node.py` (`get_label()`) | §9.2 |
| 5.4 | `[hygiene]` | Nettoyer : code commenté, commentaires dupliqués, annotations Python 2, `get_all_stats_keys()` qui imprime | §9.2 |
| 5.5 | `[hygiene]` | Le cas particulier `goto == 608 and book_number == 1` devra être contourné par un 3ᵉ livre | §4.3 |

### 6 — Tests et hygiène

| # | tag | action | réf |
|---|---|---|---|
| 6.1 | `[test]` | **`test_case.gd` doit savoir `await`** : c'est ce qui bloque *tous* les tests d'interface et de mise en page | §2.2 |
| 6.2 | `[test]` | Libérer les nœuds instanciés par les tests (608 fuites) | §2.2 |
| 6.3 | `[test]` | Tester `ui/menu_page.gd` (navigation bloquée quand une popup est ouverte) et `ui/top_menu.gd` | §2.2 |
| 6.4 | `[hygiene]` | Purger les 2 clés `[rendering]` Godot 3 restantes de `project.godot` (`GLES2`, `vram_compression/import_etc`) | §11.1 |
| 6.5 | `[refacto]` | Unifier les 3 variantes de décoration de ligne. **Elles ont déjà divergé** : le marqueur « Combat » était posé par `update_from_son_node` et pas du tout par `update_when_in_all_chapters` | §11.4 |
| 6.6 | `[refacto]` | Helper `_set()` pour les setters de `Parameters` | §11.5 |
| 6.7 | `[place]` | `MIGRATION_GUESS` → `books/<nom>/` | §11.6 |
| 6.8 | `[refacto]` | `chapter_data.gd` → `RefCounted`, libération au changement de livre | §11.7 |
| 6.9 | `[place]` | Décider la fin de vie d'`archive/` — et poser son `.gdignore` — une fois la catégorie 2 terminée | §11.3, §11.8 |
| 6.10 | `[test]` | **Passage piloté par les données sur `images/` et `sounds/`** : croiser les 668 images avec les objets, succès et fins des deux livres. Aucune analyse statique ne peut le faire | §11.8 |
