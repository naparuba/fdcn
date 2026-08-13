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
| `<nom>-compilated-data.json` | les chapitres, calculés : fils, acte, sous-arc, arbres de conditions | ✅ |
| `<nom>-compilated-nodes-by-chapter.json`, `-by-sub-arc.json` | les chapitres de chaque acte et sous-arc, pour les barres de complétion | ✅ |
| `<nom>.all_objects.json`, `<nom>.all_success.json` | objets et succès, **écrits à la main** et complétés au chargement (`in_chapters`, `chapter`) | ✅ |
| `compteurs.json` | les compteurs propres au livre, affichés par la feuille de stats | facultatif |

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
