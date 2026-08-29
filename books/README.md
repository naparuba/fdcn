# books/ — les livres

`books.json` est **la seule liste de livres du dépôt**. Les couvertures du sélecteur, le
livre ouvert par défaut, la conversion des vieilles sauvegardes et le compilateur Python en
sortent tous : aucun nom de livre n'est écrit dans le code.

```json
{ "livres": [ {"nom": "fdcn", "titre": "La Forteresse du Chaudron Noir"} ] }
```

- **`nom`** — le dossier `books/<nom>/`, et le suffixe des fichiers de sauvegarde
  (`possessed_item-fdcn.json`). Il ne change plus une fois publié.
- **`titre`** — en clair, pour l'infobulle de la couverture.

⚠️ **L'ordre compte.** Les sauvegardes d'avant 2026 rangeaient le livre courant sous forme
de **numéro** (1, 2) ; il est traduit par le **rang dans cette liste**. Un nouveau livre
s'ajoute donc **à la fin**, jamais au milieu.

## Ajouter un livre

1. écrire le livre dans **`scripts/src/<nom>/`** : les chapitres, les actes, les sous-arcs,
   les objets et les succès — **tout ce qui s'écrit à la main est là** ;
2. créer `books/<nom>/` avec ses images et ses sons (`img/`, `audio/`), plus `compteurs.json` ;
3. ajouter son bloc à la fin de `books.json` ;
4. compiler : `python3 scripts/generator.py --book <nom>`, qui remplit `books/<nom>/data/`.

Rien d'autre. Aucun script ni aucune scène à rouvrir.

## Remplir un livre à la main

⚠️ **Décrit le format actuel, pas le format visé.** Le plan (`todo.md` 3.8) prévoit de fondre
les six fichiers ci-dessous en un seul `<nom>.livre.json`, à champs nommés. Tant que ce n'est
pas fait, voici comment les remplir tels qu'ils existent.

Tout s'écrit dans **`scripts/src/<nom>/`**, jamais dans `books/<nom>/data/` (une sortie,
écrasée à chaque compilation). Six fichiers :

| fichier | contient |
|---|---|
| `<nom>.json` | un chapitre par clé — voir ci-dessous |
| `<nom>.arcs.json` | le découpage en actes |
| `<nom>.sub_arcs.json`, `<nom>.manual_sub_arcs.json` | le découpage en sous-arcs (détours) |
| `<nom>.all_objects.json` | tout objet/événement/type de personnage cité dans le livre |
| `<nom>.all_success.json` | tous les succès |

Après chaque modification : `python3 scripts/generator.py --book <nom>`, code `0` = compilé,
`2` = refusé avec un `ERROR:` en clair (liste complète dans
[`scripts/README.md`](../scripts/README.md#les-refus-code-2)).

### Le format d'un chapitre (`<nom>.json`)

Une clé absente veut dire « rien à signaler » — n'écrire **que** ce qui s'écarte du défaut.
Exemples réels, tirés de `fdcn.json` :

| clé | exemple réel | effet |
|---|---|---|
| `goto` | `234: {"goto": [146, 155, 76]}` | les suites. Un entier seul est accepté (`"goto": 168`) |
| `conditions` | `234: {"conditions": {"146": "LANCE\|FOURCHE"}}` | à quelle condition ce saut apparaît. **La clé doit être un fils** — mais elle en devient un d'office, même absente de `goto` |
| `secret_jumps` | `234: {"secret_jumps": [76]}` | des sauts cachés vers 76, en plus des sauts visibles |
| `secret` | `13: {"secret": true}` | ce chapitre est un secret (affichage orange dans le graphe de relecture) |
| `combat` | `274: {"combat": [{"nom": "GUARDES CORROMPUS", "hab": 6, "pv": 8, "arm": 0, "deg": 0, "pyro": 0}, {"nom": "TROLESSE", ...}]}` | un adversaire en dictionnaire, plusieurs en tableau — **l'ordre du tableau est l'ordre du combat**, on abat le premier avant que le suivant n'arrive |
| `ending`, `ending_id`, `ending_txt` | `163: {"ending": "bad", "ending_id": "TULIPES", "ending_txt": "Elles avaient faim, très faim ^^"}` | ce chapitre **termine** l'histoire. `ending_txt` n'est lu **que si** `ending_id` existe. Une fin n'a pas de suite : un `goto` éventuel n'est pas suivi |
| `success` | `26: {"success": "POLIR-LANCE"}` | doit exister dans `<nom>.all_success.json` |
| `aquire`, `remove` | `119: {"aquire": ["PETITE BOUTEILLE D'ACIDE"]}` | objets gagnés/perdus. Chaque nom doit exister dans `<nom>.all_objects.json` |
| `stats` | `273: {"stats": {"chance": 3}}` | modificateurs appliqués en entrant. Nombre = `+=` ; chaîne = expression (`"= max"`, `"+ max/2"`, `"- moi/4"` — voir `scripts/README.md`) |
| `stats_cond` | `35: {"stats_cond": {"PRUDENT": {"gloire": 1}}}` | même chose, mais **conditionnel** : ici, +1 gloire seulement si le joueur est Prudent |
| `label` | `10: {"label": "Tour nord"}` | nom affiché sur le nœud, dans le graphe de relecture uniquement |

⚠️ **`combat` n'est pas relu par le compilateur** : ni les six champs, ni leurs valeurs, il
recopie tel quel. C'est le seul endroit du livre où une faute de saisie ne peut être
attrapée que par une relecture humaine contre le livre papier — deux fautes y ont été
trouvées le 2026-08-13 en ne vérifiant qu'un seul des 85 combats des deux livres (`todo.md`
1.4).

### Le langage des conditions

Utilisé dans `conditions` (quels sauts sont visibles) et `stats_cond` (quels bonus
s'appliquent) — même syntaxe. Une expression relie des **noms** (objet, événement, type de
personnage — chacun doit exister dans `<nom>.all_objects.json`) avec `&` (et), `|` (ou), et
`( )` pour grouper, **un seul niveau**.

**Trois pièges, tous silencieux :**

1. **Mélanger `&` et `|` sans parenthèses donne un résultat faux.** `A & B | C` compile en
   `A ou B ou C` : le `&` est perdu. **Toujours parenthéser** dès qu'on mélange les deux —
   `(A & B) | C`.
2. **Les parenthèses imbriquées cassent.** `((A|B)&C)|D` fait planter la compilation. Un
   seul niveau de parenthèses, sans exception.
3. **Une expression malformée sort en code 2 sans aucun message.** Une compilation muette
   qui rend `2` juste après la ligne `Conditions parsing:` = une expression cassée quelque
   part — relire les `conditions`/`stats_cond` ajoutés dans le lot.

### La propagation des actes

Aucun chapitre ne déclare son acte à la main : `<nom>.arcs.json` donne juste un chapitre de
départ par acte, et le nom se propage à tous ses descendants en suivant les sauts —
**8 déclarations couvrent les 606 chapitres de fdcn, 10 les 691 de cdsi.**

```json
[[1, "Plante-Citrouille"], [100, "Lenonia"], [193, "Cathedrale"]]
```

⚠️ **La liste se parcourt à l'envers** : si deux actes peuvent atteindre le même chapitre,
**le dernier déclaré dans le fichier gagne**. Réordonner ce fichier redécoupe le livre, ce
n'est jamais un détail cosmétique.

`<nom>.sub_arcs.json` fait la même chose pour les détours, avec un point d'arrêt
(`[arc, départ, nom, [arrêts]]`) où la propagation s'arrête au lieu de continuer jusqu'à la
fin de l'acte ; au-delà de 60 chapitres elle refuse — c'est presque toujours un `[arrêts]`
oublié. `<nom>.manual_sub_arcs.json` tague une liste de chapitres **sans** propagation, pour
les cas qu'aucune règle n'attrape ; il ne peut que combler des trous, jamais reprendre un
chapitre déjà tagué par les deux fichiers précédents.

### Avant de compiler pour la première fois

- chaque nom cité dans `aquire`, `remove`, `conditions` ou `stats_cond` existe dans
  `<nom>.all_objects.json` (sinon : `some objects are USED but not declared`) ;
- inversement, chaque entrée de `<nom>.all_objects.json` est utilisée quelque part (sinon :
  `some objects are DECLARED but not used`) ;
- chaque `success` existe dans `<nom>.all_success.json` (sinon : une trace Python plutôt
  qu'un `ERROR:` propre — et le dossier de sortie reste à moitié à jour, il faut recompiler
  après correction) ;
- chaque clé de `<nom>.arcs.json` est un chapitre qui existe réellement ;
- les combats sont relus contre le livre papier — le compilateur ne le fait pas.

## Ce qu'un dossier de livre contient

Trois dossiers, et rien à la racine :

```
books/<nom>/
    data/      ce que l'app et le compilateur ouvrent
    img/       logo.png, title.png, cover.jpg
    audio/     intro.mp3, <chapitre>.mp3
```

### `data/` — **uniquement ce que l'app ouvre**

| fichier | rôle | obligatoire |
|---|---|---|
| `<nom>-compilated.json` | **un seul fichier** (todo 3.6), 5 clés : `chapters` (les chapitres calculés : fils, acte, sous-arc, arbres de conditions), `nodes_by_chapter`/`nodes_by_sub_arc` (pour les barres de complétion), `objects`/`success` (écrits à la main, recopiés tels quels, complétés au chargement — `in_chapters`, `chapter`) | ✅ |
| `compteurs.json` | les compteurs propres au livre, affichés par la feuille de stats, et les clés de stat de chapitre sans effet (`ignorees`) | facultatif |

⚠️ **Ce dossier est une sortie, pas une source.** Tout ce qu'il contient est produit ou
recopié par `python3 scripts/generator.py --book <nom>`, à partir de `scripts/src/<nom>/`. Les
objets et les succès y sont **recopiés tels quels** — ils s'écrivent à la main, mais l'app
ne peut pas aller les lire dans `scripts/`, que Godot ignore. **Ne rien éditer ici** : la
prochaine compilation l'écraserait.

⚠️ **Le livre lui-même n'est plus ici.** Chapitres, actes, sous-arcs, objets et succès
s'écrivent dans **`scripts/src/<nom>/`** depuis le 2026-08-13. Les objets et les succès
reviennent ici **par copie**, parce que l'app les lit et ne peut pas ouvrir `scripts/`, que
Godot ignore ; les autres n'ont jamais servi qu'à compiler et partaient dans l'APK pour
rien.

⚠️ **Une entrée compilée ne porte que ce qui n'est pas neutre.** Un chapitre sans combat n'a
pas de clé `combat`, un chapitre sans objet pas d'`aquire` :

```json
"1":   {"id": 1, "chapter": "Plante-Citrouille", "sons": [2]}
"273": {"id": 273, "chapter": "Tour des mages", "sons": [423], "stats": {"chance": 3}}
```

Une clé absente veut dire « rien à signaler », **jamais** « donnée manquante » : c'est
61 % du fichier qui ne s'écrit plus. La liste des valeurs neutres est en double —
`Node.NEUTRES` côté générateur, les `.get(clé, défaut)` de `entities/chapter_data.gd` côté
app — et les deux moitiés doivent rester d'accord.

### `img/` et `audio/`

| fichier | rôle |
|---|---|
| `img/logo.png`, `img/title.png` | la barre du haut |
| `img/cover.jpg` | la couverture dans le sélecteur de livre |
| `audio/intro.mp3` | joué en arrivant sur le livre |
| `audio/<chapitre>.mp3` | la narration de ce chapitre (`audio/27.mp3`) |

**Tous facultatifs, et vraiment** : pas de fichier, pas de son, pas d'image — mais un livre
jouable. Rien n'est à déclarer nulle part : c'est le fichier lui-même qui, en existant,
active la fonctionnalité.

### Ce qui a disparu le 2026-08-13, et pourquoi

| | pourquoi |
|---|---|
| 5 sorties compilées : combats, secrets, et les trois listes de fins | **personne ne les chargeait**. L'app lit tout ça chapitre par chapitre |
| `-compilated-success.json`, `-compilated-all-objects.json`, `-compilated-success-chapters.json` | des **valeurs en double** : catégories, libellés et textes déjà écrits à la main, pour un champ ajouté. L'app lit les tables de l'auteur et les complète au chargement. Vérifié avant suppression : les 146 objets et 103 succès retrouvent exactement les mêmes valeurs |
| la source recopiée dans `-compilated-data.json` | le chapitre écrit à la main vit dans `scripts/src/`, un seul exemplaire suffit |
| les valeurs neutres de chaque chapitre | 9 538 clés sur 12 120, pour fdcn, ne disaient rien |
| `<nom>.migration_items.json` | une table `type de Billy → 3 objets` qui **inventait** ce que la sauvegarde n'avait jamais su. Une sauvegarde sans liste d'objets rejoue maintenant ses chapitres, prévient le joueur et ouvre son inventaire — lui seul connaît son équipement de départ |

### Et le 2026-08-29 (todo 3.6)

Les 3 sorties calculées (`-compilated-data.json`, `-compilated-nodes-by-chapter.json`,
`-compilated-nodes-by-sub-arc.json`) et les 2 tables recopiées (`<nom>.all_objects.json`,
`<nom>.all_success.json`) — cinq fichiers dans `data/` — ont été réunies en un seul
`<nom>-compilated.json`, à 5 clés. Effet de bord : une compilation refusée n'écrit plus
rien du tout, là où elle pouvait avant laisser 1 sortie calculée à jour et 4 périmées.

**Les json des livres sont passés de 1 340 à 388 Ko**, à contenu strictement identique pour
l'app — vérifié clé par clé sur les 1 297 chapitres des deux livres.

### `data/compteurs.json`

Les compteurs que le livre accumule au fil des chapitres, dans l'ordre d'affichage :

```json
{ "compteurs": [ {"cle": "rancune", "libelle": "Rancune"} ] }
```

`cle` est la clé écrite dans les `stats` des chapitres. **`richesse` n'y figure pas** :
commune à tous les livres, elle est câblée dans `PlayerStats`. Une clé de stat qui n'est ni
connue du moteur ni déclarée ici est signalée comme une faute de saisie — c'est ce qui
sépare `rancune` de `critique`.

### Les fins

Une fin est un chapitre qui porte `"ending": "good"` ou `"ending": "bad"`, et **une fin n'a
pas de suite** : son `goto` éventuel n'est pas suivi. fdcn fait pointer les siennes sur un
chapitre 608 qui n'existe pas dans le livre ; cdsi n'écrit pas de `goto` du tout. Les deux
formes marchent, et aucun numéro n'est écrit dans le générateur.

### Les combats

Un adversaire s'écrit en dictionnaire, plusieurs en tableau — et **l'ordre du tableau est
l'ordre du combat** : on abat le premier, le suivant arrive avec ses pv pleins. Un seul
chapitre s'en sert, fdcn ch274 (GUARDES CORROMPUS puis TROLESSE).

⚠️ Le générateur **recopie le bloc `combat` sans le regarder** : ni les six champs, ni leurs
valeurs. C'est le seul endroit du livre où une faute de saisie ne peut être attrapée que par
une relecture humaine — deux l'ont été le 2026-08-13, dont un bouche-trou `XXXX` avec tous
ses chiffres à 1 qui partait dans l'application.
