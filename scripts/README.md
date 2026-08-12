# scripts/ — le compilateur de livre

Un livre s'écrit à la main dans `books/<nom>/data/<nom>.json` : un chapitre par entrée, des
`goto`, des objets, des conditions. **L'app Godot ne lit jamais ce fichier.** Elle lit les
`<nom>-compilated-*.json`, que ces scripts produisent.

```
books/<nom>/data/<nom>.json  ──►  python3 scripts/fdcn.py --book <nom>  ──►  <nom>-compilated-*.json
   (+ arcs, objets, succès)                                              (+ scripts/graph/*.png)
```

Le compilateur ne se contente pas de recopier : il **résout le graphe** (qui mène où, quels
chapitres appartiennent à quel acte), **compile les conditions** en arbres que GDScript sait
évaluer, et **refuse de produire** un livre incohérent. C'est le seul endroit où un objet
fantôme ou un `goto` dans le vide est attrapé — l'app, elle, fait confiance.

Il se lance **à la main**, après chaque modification d'un `.json` de livre. Rien ne
l'appelle : ni Godot, ni un hook git.

## Lancer

```bash
cd <racine du dépôt>            # obligatoire : tous les chemins sont relatifs
python3 scripts/fdcn.py --book cdsi
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
l'écriture de `-compilated-data.json`, donc les neuf autres sorties restent périmées.
Toutes les autres erreurs surviennent avant la moindre écriture. En cas de trace Python,
**relancer après correction** avant de commiter.

## Les fichiers

| fichier | rôle | taille |
|---|---|---|
| `fdcn.py` | **le script** : lit, valide, écrit. De haut en bas, sans fonctions | 475 l. |
| `node.py` | `Node` : un chapitre. Porte ses données, ses fils, son arc, et se sait dessiner | 379 l. |
| `graph.py` | `Graph` : le dictionnaire `id → Node`, et deux boucles de dessin | 27 l. |
| `condition_node.py` | l'analyseur d'expressions (`ARC & (CORDE \| PIOCHE)`) et sa sortie JSON | 144 l. |
| `endings.py` | `ENDINGS.GOOD = 1`, `ENDINGS.BAD = 2`. C'est tout | 4 l. |
| `requirements.txt` | `graphviz==0.20.1`, **facultatif** | |
| `.gdignore` | vide, et c'est le but : Godot n'importe pas ce dossier | |
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
| 8 | écriture | `data/` et `archive/` | `computed` injecté dans chaque chapitre + 9 fichiers de synthèse |

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

| fichier | dossier | lu par |
|---|---|---|
| `<nom>-compilated-data.json` | `data/` | `BookData.do_load_book()` → un `chapter_data` par chapitre |
| `-compilated-nodes-by-chapter.json` | `data/` | `BookData.chapters_by_arc` |
| `-compilated-nodes-by-sub-arc.json` | `data/` | `BookData.chapters_by_sub_arc` |
| `-compilated-success.json` | `data/` | `BookData.all_success` |
| `-compilated-success-chapters.json` | `data/` | `BookData.all_success_chapters` |
| `-compilated-all-objects.json` | `data/` | `BookData.all_objects` |
| `-compilated-combats.json`, `-endings`, `-good-endings`, `-bad-endings`, `-secrets` | `archive/` | **personne** — l'app lit ces états chapitre par chapitre dans `computed` |
| `scripts/graph/fdcn_full-<nom>.png` | — | un humain, pour relire la structure du livre |

Tous sont commités : l'app d'un joueur ne compile rien.

### `-compilated-all-objects.json`

C'est `<nom>.all_objects.json` **enrichi** : chaque objet reçoit la liste `in_chapters` des
chapitres qui le donnent ou le retirent, et un `stats: {}` par défaut. Un objet qui
n'apparaît nulle part reçoit `in_chapters: [1]` — « connu depuis le début », donc toujours
affichable.

## Le contrat `computed`

Les clés produites par `Node.get_computed()`, consommées par `entities/chapter_data.gd`.
**Y toucher casse l'app en silence** : GDScript indexe le dictionnaire sans vérifier.

| clé | contenu |
|---|---|
| `id` | l'entier du chapitre |
| `sons` | les suites **triées** (tri = diff stable d'un run à l'autre) |
| `chapter` | ⚠️ le nom de l'**arc** (l'acte : « L'Exode ») |
| `arc` | ⚠️ le nom du **sous-arc** (« Jungle ») |
| `ending` | booléen — est-ce une fin ? |
| `ending_type` | `1` (bonne) / `2` (mauvaise) / `null` |
| `ending_id`, `ending_txt` | l'entrée du tableau des fins |
| `is_combat` / `combat` | booléen / le bloc brut |
| `success` | l'identifiant du succès, ou `null` |
| `secret`, `secret_jumps` | le chapitre est caché / les sauts cachés qu'il émet |
| `label` | le libellé du graphe |
| `jump_conditions` | `{ "<fils>": <arbre $and/$or/$end> }` |
| `jump_conditions_txts` | la même chose en français (`«  ARC et CORDE  »`), pour l'affichage |
| `aquire`, `remove`, `stats` | recopiés du source |
| `stats_cond` | `[{condition, stats, txt}, …]` |

**Les deux noms sont inversés par rapport à l'intuition** : `computed.chapter` est l'acte,
`computed.arc` est le sous-arc. Le renommer demanderait de reprendre `chapter_data.gd`,
`BookData` et les écrans en même temps — tant que ce n'est pas fait, se fier à ce tableau.

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
   scripts/fdcn.py` muet qui rend `2` juste après la ligne `Conditions parsing:` = une
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
| ajoutez une clé à `computed` | `entities/chapter_data.gd` (un accesseur), et **recompiler les deux livres** — un livre non recompilé n'aura pas la clé, et GDScript plantera à l'indexation |
| renommez une sortie `-compilated-*` | `autoload/BookData.gd:do_load_book()`, et le tableau `ARCHIVEES` |
| ajoutez une clé de chapitre | la lire dans la boucle principale de `fdcn.py`, la stocker dans `Node`, l'exporter dans `get_computed()`, l'exposer dans `chapter_data.gd` — les quatre, sinon elle disparaît en silence |
| touchez à `condition_node.py` | vérifier contre `BookData._check_cond_rec()` : les deux moitiés du même langage, dans deux langages différents. Trois opérateurs, et trois seulement |
| ajoutez une validation | la placer **avant** l'écriture de `-compilated-data.json` (sinon elle laisse le dossier à moitié à jour) |
| modifiez l'ordre de `arcs.json` | c'est un **redécoupage du livre**, pas un détail de présentation (voir plus haut) |

Après toute modification : **recompiler les deux livres** et lire le `git diff` des
`-compilated-*.json`. C'est la seule vérification qui existe — il n'y a pas de test.

### Dette connue

Recensée dans [`review.md`](../review.md) et [`todo.md`](../todo.md), à ne pas
redécouvrir :

- **`fdcn.py` n'a aucune fonction** hors `load_json_file` : 475 lignes de haut en bas et une
  quarantaine de variables globales mutées au fil du fichier. Découpage prévu (`todo.md` 4.2).
- **Les clés de stat ne sont pas validées** : le script les collecte et les imprime déjà
  (`Checking all stats keys`), il manque la comparaison avec le vocabulaire du livre
  (`data/compteurs.json` + les stats du moteur) et un `sys.exit(2)` (`todo.md` 3.2). Une
  faute de frappe dans un `stats` passe donc jusqu'à l'app.
- `node_created` (`fdcn.py`) ne sert à rien.
- Dans le dessin des clusters, le `print` « skipping not related edge » affiche un
  `sub_arc_name` hérité de la boucle précédente : le libellé du log est faux, le graphe non.
- `Node` expose des accesseurs que personne n'appelle (`get_ending_id`, `is_bad_ending`…).
