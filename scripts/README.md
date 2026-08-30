# scripts/ — le compilateur de livre

**Tout ce qui s'écrit à la main est dans `scripts/src/<nom>/`. Point.** L'app Godot n'y lit
jamais rien : `scripts/` porte un `.gdignore`, elle ne voit même pas le dossier dans
l'éditeur. Elle lit ce que le générateur dépose dans `books/<nom>/data/`.

```
scripts/src/<nom>/      ──►   scripts/gen/<nom>/data/   ──►   books/<nom>/data/
  <nom>.json                    <nom>-compilated.json          <nom>-compilated.json
  <nom>.livre.json               (gitignore, jetable)           (commité, LIVRÉ)
                          generator.py --book <nom>, en deux étapes (todo 3.13) :
                          GÉNÉRATION puis LIVRAISON — chacune vérifiable séparément.
```

`books/<nom>/data/` est donc une **sortie**, à ne pas éditer : la prochaine compilation
l'écrase — plus aucune exception depuis que `compteurs.json` a rejoint `<nom>.livre.json`
(todo 3.8, 2026-08-29).

⚠️ **`.gdignore` ne protège que l'éditeur, pas l'export.** Les 4 presets
d'`export_presets.cfg` embarquaient `scripts/src/<nom>/*.json` malgré lui : leur
`include_filter="*.json, …"` est un glob qui matche n'importe quel `.json` du dépôt,
`.gdignore` ou pas — objets et succès partaient donc deux fois dans l'APK, une fois écrits
à la main, une fois compilés. `exclude_filter="scripts/*"` (todo 3.13, 2026-08-29) retire
tout le dossier, `gen/` compris. **Non vérifié par un vrai export** dans cet environnement
(pas de SDK Android/templates ici) — à confirmer par un build avant la prochaine sortie.

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

✅ **Depuis le 2026-08-29 (todo 3.2)**, une clé de chapitre qu'il ne connaît pas ou une clé
de stat hors vocabulaire refusent la compilation en code 2 plutôt que d'être recopiées sans
un mot — c'était l'étape 1 du plan de simplification, et ce qui avait laissé passer quatre
fautes silencieuses (voir « Les refus » plus bas).

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
| `--nouveau NOM` | crée `scripts/src/NOM/` avec un chapitre 1 valide et ajoute `NOM` à la fin de `books/books.json` — **ne compile pas**, enchaîner avec `--book NOM` (todo 3.9, 2026-08-29) |
| Code de sortie | `0` = compilé (ou livre créé) ; `2` = refusé, avec un `ERROR:` en clair |

Sans graphviz le script le dit et continue : les `.json` du jeu sont compilés, seul le PNG
manque. Refuser de compiler les données du jeu faute d'une dépendance de confort serait le
mauvais arbitrage — d'où le bouchon `GrapheMuet`.

✅ **Toutes les validations passent avant la moindre écriture** (2026-08-29, todo 3.6) : la
sortie tient dans un seul fichier (`<nom>-compilated.json`), écrit une fois toutes les
vérifications faites. Une compilation refusée ne laisse donc plus le dossier de sortie à
moitié à jour, contrairement à avant quand les 3 sorties calculées s'écrivaient une par une.

## Les fichiers

| fichier | rôle | taille |
|---|---|---|
| `generator.py` | **le script** : `lire_les_noeuds()` / `taguer_les_arcs()` / `construire_le_graphe()` / `ecrire_les_json()` / `main()`. S'appelait `fdcn.py` — un nom de livre pour un outil qui les compile tous | 430 l. |
| `node.py` | `Node` : un chapitre. Porte ses données, ses fils, son arc, et décide de ce qui part dans le json (`NEUTRES`) — plus aucune notion de graphviz depuis le 2026-08-22 | 304 l. |
| `graph_render.py` | la présentation graphviz (`get_label()`, couleurs, ajout au graphe), sortie de `Node` le 2026-08-22 : le modèle de données ne sait plus rien du dessin | 115 l. |
| `condition_node.py` | l'analyseur d'expressions (`ARC & (CORDE \| PIOCHE)`) et sa sortie JSON | 131 l. |
| `graph.py` | `Graph` : le dictionnaire `id → Node`, délègue le dessin à `graph_render.py` | 26 l. |
| `logger.py` | `trace()` / `info()` derrière `--verbose`, depuis le 2026-08-22 | 18 l. |
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
| 4 | arcs | `actes`, `sous_arcs`, `sous_arcs_manuels` de `<nom>.livre.json` | propagation de proche en proche (voir plus bas) |
| 5 | graphe | graphviz | nœuds, arêtes, `cluster_<arc>` et `cluster_<sous-arc>`. **Zéro effet sur les `.json`** |
| 6 | conditions | `parse_conditions()`, `parse_stats_conditions()` | expressions → arbres `{$and/$or/$end}` + texte lisible |
| 7 | validations | objets, sauts, fins | tout ce qui fait sortir en `2` |
| 8 | écriture | `data/` | un seul fichier compilé (todo 3.6) |

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
| `success` | `"CEST-REPARTI"` | doit exister dans `succes` de `<nom>.livre.json`, sinon refus en code 2 |
| `aquire`, `remove` | `["SEAU"]` | objets gagnés/perdus. Tout nom doit exister dans `objets` de `<nom>.livre.json` |
| `stats` | `{"pv": 5}` | modificateurs appliqués en entrant |
| `stats_cond` | `{"PRUDENT": {"hab": 1}}` | modificateurs **conditionnels**, même langage d'expression |
| `label` | `"Jungle"` | nom affiché sur le nœud du graphe |

Ces 14 clés sont les **seules** acceptées (todo 3.2, `CHAPTER_ALLOWED_KEYS`) : toute autre —
un `_comment` de notes de travail, une faute de frappe comme `cond` — arrête la compilation
en code 2 plutôt que d'être recopiée en silence.

## Les sorties

```
scripts/src/<nom>/            ──►   books/<nom>/data/<nom>-compilated.json
2 fichiers écrits à la main         1 fichier, 7 clés
```

| clé | ce que c'est | lu par |
|---|---|---|
| `chapters` | **calculé** : les chapitres, fils résolus, actes propagés, conditions en arbres | `BookData.do_load_book()` → un `chapter_data` par chapitre |
| `nodes_by_chapter` | **calculé** : les chapitres de chaque acte | `BookData.chapters_by_arc` |
| `nodes_by_sub_arc` | **calculé** : ceux de chaque sous-arc | `BookData.chapters_by_sub_arc` |
| `objects` | **recopié** depuis `objets` de `<nom>.livre.json`, tel quel | `BookData.all_objects`, complété au chargement |
| `success` | **recopié** depuis `succes` de `<nom>.livre.json`, tel quel | `BookData.all_success`, complété au chargement |
| `counters` | **recopié** depuis `compteurs` de `<nom>.livre.json`, tel quel | `BookData.counters`/`is_counter()` |
| `ignored` | **recopié** depuis `ignorees` de `<nom>.livre.json`, tel quel | `BookData.is_ignored()` |

Plus, à part : `scripts/graph/fdcn_full-<nom>.png`, le graphe du livre, pour un humain qui
relit la structure.

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

**Actes** (`actes` de `<nom>.livre.json`, `[{"depart": 1, "nom": "Nouvelle-Nouvelle-Azur"}, …]`
— named fields depuis todo 3.8, un tableau positionnel `[[1, "…"], …]` avant le
2026-08-29) — chaque entrée donne un chapitre de départ ; le nom se propage à tous ses
descendants, et s'arrête dès qu'il rencontre un chapitre **déjà tagué** (ou une fin, qui n'a
pas de fils).

⚠️ La liste est parcourue **à l'envers** (`reversed(arcs)`), malgré le commentaire du code
qui prétend l'inverse. Conséquence : quand plusieurs actes peuvent atteindre un chapitre,
c'est **le dernier déclaré qui gagne**. Ce n'est pas une bizarrerie sans effet — dans cdsi,
le chapitre 32 est rangé dans « Violence Vraie » (départ 340), pas dans le premier acte.
Réordonner `actes` **redécoupe le livre**.

**Sous-arcs** (`sous_arcs` de `<nom>.livre.json`,
`{"acte": …, "depart": …, "nom": …, "fins": [...]}` — même changement de format) — même
propagation, avec deux différences :

- elle **s'arrête** sur les chapitres listés dans `fins` (le point de convergence où le
  détour rejoint l'histoire principale) ;
- au-delà de **60 chapitres** elle lève une exception : un sous-arc de cette taille est
  toujours un `fins` oublié, et sans ce garde-fou il avalerait la moitié du livre.

Le **champ `acte` n'est pas utilisé** par le code : il documente, rien de plus. Le premier
sous-arc déclaré qui atteint un chapitre le garde.

**`sous_arcs_manuels`** (`{"nom": [12, 13]}`, inchangé) tague **sans propagation**, pour les
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

Pas de négation, pas de comparaison de stat. Chaque nom doit exister dans `objets` de
`<nom>.livre.json`.

Résultat compilé (`{$end}` = feuille, évalué par `BookData._check_cond_rec()`) :

| expression | compilé |
|---|---|
| `ARC` | `{"$end": "ARC"}` |
| `ARC & CORDE` | `{"$and": [{"$end": "ARC"}, {"$end": "CORDE"}]}` |
| `(ARC \| CORDE) & SEAU` | `{"$and": [{"$or": […]}, {"$end": "SEAU"}]}` |

### Trois pièges

1. ✅ **Mélanger `&` et `|` sans parenthèses est refusé** (2026-08-29, todo 3.2). `A & B | C`
   levait silencieusement `$or[A, B, C]` (le `&` perdu, un seul opérateur par niveau, écrasé
   par le dernier rencontré) ; ça sort maintenant en code 2 avec un message qui nomme
   l'expression. **Toujours parenthéser** dès qu'on mélange les deux.
2. **Les parenthèses imbriquées cassent toujours.** `((A|B)&C)|D` lève
   `Exception: <ConditionNode UNKNOWN>` au moment d'écrire le JSON. Un seul niveau — pas
   couvert par le todo 3.2, qui ne change aucun format.
3. ✅ **Une expression malformée sort en code 2 avec un message** (2026-08-29, todo 3.2) :
   parenthèse non ouverte/non fermée, ou `&`/`|` mélangés (point 1). Avant, `X(A|B)` ou une
   `)` en trop sortaient en code 2 muet.

✅ **Un objet cité uniquement dans un `stats_cond` compte comme utilisé** (2026-08-22,
`Node.get_all_stats_cond_tokens()`) — ce n'était pas le cas avant, et ça faisait échouer la
compilation à tort en « DECLARED but not used ».

## Les refus (code 2)

| message | cause | correction |
|---|---|---|
| `Missing --book parameter` | pas d'argument | `--book <nom>` |
| `unknown book: X` / `no book number N` | absent de `books/books.json` | déclarer le livre |
| `node X jumps to Y, which is not a chapter` | `goto` vers un chapitre inexistant | soit le chapitre manque, soit c'est une fin : lui mettre `ending` |
| `node X have an unknown ending string` | `ending` ≠ `good`/`bad` | corriger |
| `[X] The condition: K is not in our sons` | une clé de `conditions` qui n'est pas un fils. Deux cas seulement : le chapitre est **une fin** (une fin n'a pas de fils), ou la clé n'est pas un nombre (précédé alors d'un `ERROR: invalid condition jump`) | retirer la condition, retirer la fin, ou corriger la clé |
| `some objects are USED but not declared` | un `aquire`/`remove`/condition inconnu d'`objets` | déclarer l'objet (ou corriger la faute de frappe) |
| `some objects are DECLARED but not used` | l'inverse | supprimer la déclaration, ou l'utiliser |
| `Remove but NOT add` | un objet retiré que rien ne donne | ajouter un `aquire` quelque part |
| `node X uses unknown chapter key(s)` | une clé hors des 14 de `CHAPTER_ALLOWED_KEYS` (`cond` au lieu de `stats_cond`, par ex.) | corriger la clé |
| `unknown stat key(s)` | une clé de `stats`/`stats_cond` hors du vocabulaire moteur + `compteurs`/`ignorees` du livre (`critique` au lieu de `crit`, par ex.) | corriger la clé, ou la déclarer dans `<nom>.livre.json` (`compteurs` ou `ignorees`) |
| `success X is not declared` | `success` absent de `succes` | le déclarer |
| `'(' inattendue`, `')' sans '(' correspondante`, `'(' jamais refermée`, `'&' et '\|' mélangés` | expression de condition malformée | corriger l'expression citée dans le message |
| `The sub arc is too big` | > 60 chapitres | compléter les `[arrêts]` du sous-arc |

⚠️ Aucun de ces refus n'écrit plus rien depuis le 2026-08-29 (todo 3.6, sortie unique en fin
de fonction) : pas besoin de nettoyer un dossier à moitié à jour avant de relancer.

Et un **avertissement non bloquant** : `!!! WARNING => 76 <- 234, 512` signale un chapitre
secret atteignable par plusieurs chemins. Le script ne vérifie **pas** que ces chemins sont
de vrais `secret_jumps` — il pose la question, c'est à l'humain de relire.

## Mettre à jour ces scripts

Les points de contact à ne pas oublier, selon ce qu'on touche :

| si vous… | pensez à |
|---|---|
| ajoutez une clé à `computed` | la déclarer dans `Node.NEUTRES` avec sa valeur neutre, l'exposer dans `entities/chapter_data.gd` **avec le même défaut**, et recompiler les deux livres |
| renommez une clé du fichier compilé (`chapters`/`nodes_by_chapter`/`nodes_by_sub_arc`/`objects`/`success`) | `autoload/book_data.gd:do_load_book()` |
| ajoutez une clé de **chapitre** (lue dans `<nom>.json`) | la déclarer dans `CHAPTER_ALLOWED_KEYS` (`generator.py`), la lire dans la boucle principale, la stocker dans `Node`, l'exporter dans `get_computed()`, l'exposer dans `chapter_data.gd` — les cinq, sinon elle est soit rejetée (todo 3.2), soit disparaît en silence |
| ajoutez une clé de **stat** (chapitre ou objet) | la déclarer dans `ENGINE_STATS_VOCABULARY` (`generator.py`) **et** dans `PlayerStats` (`_CHAPTER_LAYERED_KEYS` ou le `match` d'`apply_chapter_stat()`) — les deux moitiés du même contrat, comme `Node.NEUTRES`/`chapter_data.gd` |
| touchez à `condition_node.py` | vérifier contre `BookData._check_cond_rec()` : les deux moitiés du même langage, dans deux langages différents. Trois opérateurs, et trois seulement |
| ajoutez une validation | n'importe où avant la fin de `ecrire_les_json()` : une seule écriture, à la fin, depuis le 2026-08-29 (todo 3.6) — plus besoin de doser son emplacement |
| modifiez l'ordre d'`actes` dans `<nom>.livre.json` | c'est un **redécoupage du livre**, pas un détail de présentation (voir plus haut) |
| ajoutez un fichier sous `scripts/` qui ne doit **jamais** partir dans l'APK | rien à faire : `exclude_filter="scripts/*"` (`export_presets.cfg`, todo 3.13) couvre tout le dossier. Vérifier après un vrai export si vous touchez ce filtre lui-même |

Après toute modification : **recompiler les deux livres** et lire le `git diff` de
`books/<nom>/data/<nom>-compilated.json`. C'est la seule vérification qui existe — il n'y a
pas de test.

### Dette connue

Rien d'ouvert dans le générateur à ce jour — l'historique complet de ce qui a été trouvé et
réglé est dans `git log`. Le seul point encore à vérifier : `exclude_filter="scripts/*"`
dans `export_presets.cfg` (todo 3.13) n'a jamais été confirmé par un vrai build Android,
faute de SDK/templates dans l'environnement qui l'a écrit.

✅ **Découpage de `generator.py` (2026-08-22)** : le fichier est découpé en fonctions
(`lire_les_noeuds` / `taguer_les_arcs` / `construire_le_graphe` / `ecrire_les_json`) plutôt
que 476 lignes à plat ; `--verbose` sépare la trace par nœud/arc (silencieuse par défaut) des
validations qui comptent ; la présentation graphviz (`get_label()` et les méthodes
d'affichage) a quitté `Node` pour `graph_render.py`, qui ne modélise rien, seulement du
rendu ; `node_created`, les accesseurs `get_ending_id`/`have_combat`/`is_good_ending`/
`is_bad_ending`/`have_ending` (morts depuis la suppression des accumulateurs le 2026-08-13),
et le code commenté (`condition_node.py`, `graph.py`) sont partis. Le bug du `sub_arc_name`
hérité dans « skipping not related edge » est corrigé au passage — recompilation des deux
livres vérifiée **octet pour octet identique** avant/après.
