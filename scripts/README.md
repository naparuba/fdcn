# scripts/ — le compilateur de livre

**Tout ce qui s'écrit à la main est dans `scripts/src/<nom>/`. Point.** L'app Godot n'y lit
jamais rien : `scripts/` porte un `.gdignore`, elle ne voit même pas le dossier. Elle lit ce
que le générateur dépose dans `books/<nom>/data/`.

```
scripts/src/<nom>/          ──►   generator.py --book <nom>   ──►   books/<nom>/data/
  <nom>.json                                                          3 fichiers calculés
  .arcs / .sub_arcs / .manual_sub_arcs                                 + 2 tables recopiées
  .all_objects / .all_success                                        scripts/graph/*.png
```

`books/<nom>/data/` est donc une **sortie**, à ne pas éditer : la prochaine compilation
l'écrase. La seule exception y est `compteurs.json`, qui n'intéresse que l'app et que le
générateur ne regarde pas.

⚠️ **La distinction qui compte : écrit à la main, ou généré.** Deux fichiers *édités* au
même titre finissent toujours par diverger — c'est ce que faisaient
`-compilated-all-objects.json` et `-compilated-success.json`, qui répétaient des catégories
et des libellés déjà écrits ailleurs (supprimés le 2026-08-13). Une copie **générée**, elle,
ne diverge pas : elle se refait. La règle est « une seule source éditable », pas « un seul
fichier ».

⚠️ **Tant que le générateur n'a pas tourné, rien n'a bougé pour l'app.** Éditer un chapitre,
un objet ou un succès dans `src/` ne change rien avant une compilation.

## Ce que le générateur apporte

Il ne se contente pas de recopier : il **résout le graphe** (qui mène où, quels
chapitres appartiennent à quel acte), **compile les conditions** en arbres que GDScript sait
évaluer, et **refuse de produire** un livre incohérent. C'est le seul endroit où un objet
fantôme ou un `goto` dans le vide est attrapé — l'app, elle, fait confiance.

Il se lance **à la main**, après chaque modification d'un `.json` de livre. Rien ne
l'appelle : ni Godot, ni un hook git.

⚠️ **Il ne valide pas tout, loin de là** : une clé de chapitre qu'il ne connaît pas est
recopiée sans un mot, et une clé de stat inconnue passe jusqu'à l'app. C'est l'étape 1 du
plan de simplification (`todo.md` 3.2), et c'est ce qui a laissé passer quatre fautes
silencieuses jusqu'ici.

## Lancer

```bash
cd <racine du dépôt>            # obligatoire : tous les chemins sont relatifs
python3 scripts/generator.py --book cdsi
```

| | |
|---|---|
| Python | 3.6+ (f-strings) |
| Dépendances | **aucune obligatoire.** `pip install -r scripts/requirements.txt` + le binaire `dot` ajoutent le PNG |
| Répertoire courant | **la racine du dépôt** — `books/books.json`, `books/<nom>/…` et `scripts/graph/` sont écrits en relatif |
| `--book` | le **nom** du dossier (`cdsi`), ou son **rang** dans `books/books.json` (`1`, `2`) — le rang ne survit qu'à la rétro-compatibilité |
| Code de sortie | `0` = compilé ; `2` = refusé, avec un `ERROR:` en clair |

Sans graphviz le script le dit et continue : les `.json` du jeu sont compilés, seul le PNG
manque. Refuser de compiler les données du jeu faute d'une dépendance de confort serait le
mauvais arbitrage — d'où le bouchon `GrapheMuet`.

⚠️ **Une seule erreur laisse le dossier à moitié à jour** : un `success` inconnu de
`<nom>.all_success.json` lève une `Exception` (une trace Python, pas un `ERROR:`) **après**
l'écriture de `-compilated-data.json`, donc les quatre autres sorties restent périmées.
Toutes les autres erreurs surviennent avant la moindre écriture. En cas de trace Python,
**relancer après correction** avant de commiter.

## Les fichiers

| fichier | rôle | taille |
|---|---|---|
| `generator.py` | **le script** : lit, valide, écrit. De haut en bas, sans fonctions. S'appelait `fdcn.py` — un nom de livre pour un outil qui les compile tous | 476 l. |
| `node.py` | `Node` : un chapitre. Porte ses données, ses fils, son arc, se sait dessiner, et décide de ce qui part dans le json (`NEUTRES`) | 407 l. |
| `graph.py` | `Graph` : le dictionnaire `id → Node`, et deux boucles de dessin | 27 l. |
| `condition_node.py` | l'analyseur d'expressions (`ARC & (CORDE \| PIOCHE)`) et sa sortie JSON | 144 l. |
| `endings.py` | `ENDINGS.GOOD = 1`, `ENDINGS.BAD = 2`. C'est tout | 4 l. |
| `requirements.txt` | `graphviz==0.20.1`, **facultatif** | |
| `.gdignore` | vide, et c'est le but : Godot n'importe pas ce dossier — **donc `src/` non plus** | |
| `src/<nom>/` | **tout ce qui s'écrit à la main** : le livre, son découpage en actes, ses objets, ses succès. Déplacés ici le 2026-08-13 — l'app ne lit rien de `scripts/` | ~68 Ko / livre |
| `graph/` | les PNG produits. `fdcn_full*` (2024) sont d'anciens rendus, plus personne ne les régénère sous ce nom | |

## Le pipeline

| # | étape | où | ce qui se passe |
|---|---|---|---|
| 1 | registre | `books/books.json` | `--book` → nom de dossier. Un livre inconnu s'arrête ici |
| 2 | chargement | `<nom>.json` | un `Node` par clé, **avant** tout lien : un chapitre peut sauter vers un chapitre déclaré plus bas |
| 3 | arêtes | `goto` + `conditions` + `secret_jumps` | `get_all_possibles_goto()` fusionne les trois. **Une fin n'a pas de fils** : son `goto` n'est pas suivi |
| 4 | arcs | `.arcs.json`, `.sub_arcs.json`, `.manual_sub_arcs.json` | propagation de proche en proche (voir plus bas) |
| 5 | graphe | graphviz | nœuds, arêtes, `cluster_<arc>` et `cluster_<sous-arc>`. **Zéro effet sur les `.json`** |
| 6 | conditions | `parse_conditions()`, `parse_stats_conditions()` | expressions → arbres `{$and/$or/$end}` + texte lisible |
| 7 | validations | objets, sauts, fins | tout ce qui fait sortir en `2` |
| 8 | écriture | `data/` | 3 fichiers calculés + les 2 tables recopiées |

Les étapes 5 et 6 sont **indépendantes** : le graphe est déjà dessiné quand les conditions
sont analysées. C'est pourquoi supprimer graphviz ne changerait rien aux données.

## Ce qu'on écrit dans un chapitre

Le format complet des dossiers de livre est dans [`books/README.md`](../books/README.md).
Voici les clés que le compilateur lit dans `<nom>.json`, chapitre par chapitre :

| clé | exemple | effet |
|---|---|---|
| `goto` | `144` ou `[119, 91]` | les suites. Un entier seul est accepté |
| `conditions` | `{"119": "FDCN LU"}` | *à quelle condition* ce saut apparaît. **La clé doit être un fils** — mais elle en devient un d'office, même absente de `goto` |
| `secret_jumps` | `[82]` | des sauts cachés : ajoutés au graphe, et exportés pour que l'app les traite à part |
| `secret` | `true` | ce chapitre est un secret (affichage orange, contrôle des sources) |
| `combat` | `{"nom": …, "hab": 5, …}` | **recopié tel quel** : le compilateur ne regarde pas son contenu |
| `ending` | `"good"` / `"bad"` | ce chapitre **termine** l'histoire. Toute autre valeur = erreur |
| `ending_id`, `ending_txt` | `"COUDE"`, `"Oups…"` | l'entrée du tableau des fins. `ending_txt` n'est lu **que si** `ending_id` existe |
| `success` | `"CEST-REPARTI"` | doit exister dans `<nom>.all_success.json`, sinon trace Python |
| `aquire`, `remove` | `["SEAU"]` | objets gagnés/perdus. Tout nom doit exister dans `<nom>.all_objects.json` |
| `stats` | `{"pv": 5}` | modificateurs appliqués en entrant |
| `stats_cond` | `{"PRUDENT": {"hab": 1}}` | modificateurs **conditionnels**, même langage d'expression |
| `label` | `"Jungle"` | nom affiché sur le nœud du graphe |

Tout le reste (`_comment`, notes de travail…) est **conservé tel quel** dans
`-compilated-data.json` : le compilateur ajoute une clé `computed` à l'entrée existante, il
ne la remplace pas.

## Les sorties

```
scripts/src/<nom>/            ──►   books/<nom>/data/
6 fichiers écrits à la main         3 calculés + 2 recopiés
```

| fichier | ce que c'est | lu par |
|---|---|---|
| `<nom>-compilated-data.json` | **calculé** : les chapitres, fils résolus, actes propagés, conditions en arbres | `BookData.do_load_book()` → un `chapter_data` par chapitre |
| `<nom>-compilated-nodes-by-chapter.json` | **calculé** : les chapitres de chaque acte | `BookData.chapters_by_arc` |
| `<nom>-compilated-nodes-by-sub-arc.json` | **calculé** : ceux de chaque sous-arc | `BookData.chapters_by_sub_arc` |
| `<nom>.all_objects.json` | **recopié** depuis `src/`, tel quel | `BookData.all_objects`, complété au chargement |
| `<nom>.all_success.json` | **recopié** depuis `src/`, tel quel | `BookData.all_success`, complété au chargement |
| `scripts/graph/fdcn_full-<nom>.png` | le graphe du livre | un humain, pour relire la structure |

Tout est commité : l'app d'un joueur ne compile rien.

**Sept sorties ont disparu le 2026-08-13.** Cinq que personne ne chargeait — la liste des
combats, celle des secrets, les trois listes de fins : tout ça se lit chapitre par chapitre
dans `-compilated-data.json`. Et deux copies enrichies, `-compilated-success.json` et
`-compilated-all-objects.json`, qui répétaient les libellés, catégories et textes déjà
écrits à la main, pour un champ ajouté chacune — `BookData` lit les tables et calcule
`in_chapters`, `chapter` et l'index chapitre → succès au chargement.

**Ce que l'app complète elle-même, à partir de ce qu'elle a déjà :**

| champ | comment |
|---|---|
| `in_chapters` d'un objet | balayage des `aquire`/`remove` de tous les chapitres. Un objet cité nulle part reçoit `[1]` — « connu depuis le début », donc toujours affichable : c'est l'équipement choisi avant le chapitre 1 |
| `chapter` d'un succès | le premier chapitre qui le déclare |
| chapitre → succès | l'index inverse, **tous** les chapitres compris — un succès peut se gagner à deux endroits |

## Le contrat `computed`

Chaque entrée de `-compilated-data.json` ne porte **que ce qui n'est pas neutre**. Un
chapitre ordinaire tient en une ligne :

```json
"273": {"id": 273, "chapter": "Tour des mages", "sons": [423], "stats": {"chance": 3}}
"1":   {"id": 1, "chapter": "Plante-Citrouille", "sons": [2]}
```

`Node.NEUTRES` (dans `node.py`) liste les 17 clés et leur valeur neutre ; `get_computed()`
n'écrit que ce qui en diffère, plus `id`, toujours présent. Sur fdcn, **9 538 des 12 120
clés** ne disaient rien d'autre que « rien à signaler » : le fichier est passé de 391 à
149 Ko, **−62 %** (cdsi : 442 → 173 Ko).

⚠️ **`Node.NEUTRES` et les `.get(clé, défaut)` de `entities/chapter_data.gd` sont les deux
moitiés d'un seul contrat.** Une clé absente veut dire « rien à signaler », jamais « donnée
manquante » — si les deux listes divergent, l'app lira un défaut que le générateur n'a pas
voulu dire. `test_book_data.gd` garde ce contrat : il prend un chapitre dépouillé et vérifie
les 16 valeurs neutres une par une.

**Deux clés ont disparu**, `ending` et `is_combat` : des booléens dérivés de `ending_type`
et `combat`, vérifiés identiques sur les 1 297 chapitres des deux livres. L'app les
recalcule (`get_ending()`, `is_combat()`).

## Arcs et sous-arcs

Aucun chapitre ne déclare son acte : le compilateur le **déduit en suivant les sauts**.

**Arcs** (`<nom>.arcs.json`, `[[1, "Nouvelle-Nouvelle-Azur"], …]`) — chaque entrée donne un
chapitre de départ ; le nom se propage à tous ses descendants, et s'arrête dès qu'il
rencontre un chapitre **déjà tagué** (ou une fin, qui n'a pas de fils).

⚠️ La liste est parcourue **à l'envers** (`reversed(arcs)`), malgré le commentaire du code
qui prétend l'inverse. Conséquence : quand plusieurs actes peuvent atteindre un chapitre,
c'est **le dernier déclaré qui gagne**. Ce n'est pas une bizarrerie sans effet — dans cdsi,
le chapitre 32 est rangé dans « Violence Vraie » (départ 340), pas dans le premier acte.
Réordonner `arcs.json` **redécoupe le livre**.

**Sous-arcs** (`<nom>.sub_arcs.json`, `[arc, départ, nom, [arrêts]]`) — même propagation,
avec deux différences :

- elle **s'arrête** sur les chapitres listés dans `[arrêts]` (le point de convergence où le
  détour rejoint l'histoire principale) ;
- au-delà de **60 chapitres** elle lève une exception : un sous-arc de cette taille est
  toujours un `[arrêts]` oublié, et sans ce garde-fou il avalerait la moitié du livre.

Le **premier champ (`arc`) n'est pas utilisé** par le code : il documente, rien de plus.
Le premier sous-arc déclaré qui atteint un chapitre le garde.

**`<nom>.manual_sub_arcs.json`** (`{"nom": [12, 13]}`) tague **sans propagation**, pour les
chapitres qu'aucune règle n'attrape. Il passe en dernier : il ne peut que combler des trous,
jamais reprendre un chapitre déjà tagué.

## Le langage des conditions

Le même dans `conditions` (quels sauts sont visibles) et dans `stats_cond` (quels bonus
s'appliquent). Une expression est faite de **noms d'objets** — au sens large : un objet, un
événement (`FDCN LU`), un type de personnage (`PRUDENT`) — reliés par :

| | |
|---|---|
| `&` | et |
| `\|` | ou |
| `( )` | groupement, **un seul niveau** |

Pas de négation, pas de comparaison de stat. Chaque nom doit exister dans
`<nom>.all_objects.json`.

Résultat compilé (`{$end}` = feuille, évalué par `BookData._check_cond_rec()`) :

| expression | compilé |
|---|---|
| `ARC` | `{"$end": "ARC"}` |
| `ARC & CORDE` | `{"$and": [{"$end": "ARC"}, {"$end": "CORDE"}]}` |
| `(ARC \| CORDE) & SEAU` | `{"$and": [{"$or": […]}, {"$end": "SEAU"}]}` |

### Trois pièges, tous silencieux

1. **Mélanger `&` et `|` sans parenthèses donne un résultat faux.**
   `A & B | C` compile en `$or[A, B, C]` : le `&` est perdu. L'analyseur garde **un seul
   opérateur** par niveau, écrasé par le dernier rencontré. **Toujours parenthéser** dès
   qu'on mélange les deux.
2. **Les parenthèses imbriquées cassent.** `((A|B)&C)|D` lève
   `Exception: <ConditionNode UNKNOWN>` au moment d'écrire le JSON. Un seul niveau.
3. **Une expression malformée sort en code 2 sans le moindre message** (`X(A|B)`, une `)`
   en trop) : les `print` d'erreur de `condition_node.py` sont commentés. Un `python3
   scripts/generator.py` muet qui rend `2` juste après la ligne `Conditions parsing:` = une
   expression cassée dans un chapitre.

⚠️ Les objets cités **uniquement** dans un `stats_cond` ne comptent pas comme utilisés :
`get_all_conditions_token()` ne collecte que les conditions de saut. Un objet dont c'est le
seul usage fera échouer la compilation en « DECLARED but not used ».

## Les refus (code 2)

| message | cause | correction |
|---|---|---|
| `Missing --book parameter` | pas d'argument | `--book <nom>` |
| `unknown book: X` / `no book number N` | absent de `books/books.json` | déclarer le livre |
| `node X jumps to Y, which is not a chapter` | `goto` vers un chapitre inexistant | soit le chapitre manque, soit c'est une fin : lui mettre `ending` |
| `node X have an unknown ending string` | `ending` ≠ `good`/`bad` | corriger |
| `[X] The condition: K is not in our sons` | une clé de `conditions` qui n'est pas un fils. Deux cas seulement : le chapitre est **une fin** (une fin n'a pas de fils), ou la clé n'est pas un nombre (précédé alors d'un `ERROR: invalid condition jump`) | retirer la condition, retirer la fin, ou corriger la clé |
| `some objects are USED but not declared` | un `aquire`/`remove`/condition inconnu de `all_objects.json` | déclarer l'objet (ou corriger la faute de frappe) |
| `some objects are DECLARED but not used` | l'inverse — **y compris** un objet cité seulement en `stats_cond` | supprimer la déclaration, ou l'utiliser |
| `Remove but NOT add` | un objet retiré que rien ne donne | ajouter un `aquire` quelque part |
| `Exception: Success: X not found` | `success` absent de `all_success.json` | le déclarer, **puis relancer** (des sorties sont déjà écrites) |
| `The sub arc is too big` | > 60 chapitres | compléter les `[arrêts]` du sous-arc |

Et un **avertissement non bloquant** : `!!! WARNING => 76 <- 234, 512` signale un chapitre
secret atteignable par plusieurs chemins. Le script ne vérifie **pas** que ces chemins sont
de vrais `secret_jumps` — il pose la question, c'est à l'humain de relire.

## Mettre à jour ces scripts

Les points de contact à ne pas oublier, selon ce qu'on touche :

| si vous… | pensez à |
|---|---|
| ajoutez une clé à `computed` | la déclarer dans `Node.NEUTRES` avec sa valeur neutre, l'exposer dans `entities/chapter_data.gd` **avec le même défaut**, et recompiler les deux livres |
| renommez une sortie `-compilated-*` | `autoload/BookData.gd:do_load_book()` |
| ajoutez une clé de chapitre | la lire dans la boucle principale de `generator.py`, la stocker dans `Node`, l'exporter dans `get_computed()`, l'exposer dans `chapter_data.gd` — les quatre, sinon elle disparaît en silence |
| touchez à `condition_node.py` | vérifier contre `BookData._check_cond_rec()` : les deux moitiés du même langage, dans deux langages différents. Trois opérateurs, et trois seulement |
| ajoutez une validation | la placer **avant** l'écriture de `-compilated-data.json` (sinon elle laisse le dossier à moitié à jour) |
| modifiez l'ordre de `arcs.json` | c'est un **redécoupage du livre**, pas un détail de présentation (voir plus haut) |

Après toute modification : **recompiler les deux livres** et lire le `git diff` des
`-compilated-*.json`. C'est la seule vérification qui existe — il n'y a pas de test.

### Dette connue

Recensée dans [`review.md`](../review.md) et [`todo.md`](../todo.md), à ne pas
redécouvrir :

- **`generator.py` n'a aucune fonction** hors `load_json_file` : 476 lignes de haut en bas et une
  quarantaine de variables globales mutées au fil du fichier. Découpage prévu (`todo.md` 4.2).
- **Les clés de stat ne sont pas validées** : le script les collecte et les imprime déjà
  (`Checking all stats keys`), il manque la comparaison avec le vocabulaire du livre
  (`data/compteurs.json` + les stats du moteur) et un `sys.exit(2)` (`todo.md` 3.2). Une
  faute de frappe dans un `stats` passe donc jusqu'à l'app.
- `node_created` (`generator.py`) ne sert à rien.
- Dans le dessin des clusters, le `print` « skipping not related edge » affiche un
  `sub_arc_name` hérité de la boucle précédente : le libellé du log est faux, le graphe non.
- `Node` expose des accesseurs que personne n'appelle (`get_ending_id`, `is_bad_ending`…).
