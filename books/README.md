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

1. créer `books/<nom>/` et y déposer les fichiers ci-dessous ;
2. ajouter son bloc à la fin de `books.json` ;
3. compiler : `python3 scripts/fdcn.py --book <nom>`.

Rien d'autre. Aucun script ni aucune scène à rouvrir.

## Ce qu'un dossier de livre contient

Quatre dossiers, et rien à la racine :

```
books/<nom>/
    data/      ce que l'app et le compilateur ouvrent
    img/       logo.png, title.png, cover.jpg
    audio/     intro.mp3, <chapitre>.mp3
    archive/   produit par le compilateur, lu par personne
```

### `data/`

| fichier | rôle | obligatoire |
|---|---|---|
| `<nom>.json` | le livre : un chapitre par entrée | ✅ |
| `<nom>.arcs.json`, `<nom>.sub_arcs.json`, `<nom>.manual_sub_arcs.json` | le découpage en actes, pour le compilateur | ✅ |
| `<nom>.all_objects.json`, `<nom>.all_success.json` | objets et succès, pour le compilateur | ✅ |
| `<nom>-compilated-*.json` | **produits par le compilateur**, jamais édités à la main | ✅ |
| `<nom>.migration_items.json` | l'équipement *deviné* d'une sauvegarde trop ancienne pour l'avoir enregistré | facultatif |
| `compteurs.json` | les compteurs propres au livre, affichés par la feuille de stats | facultatif |

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

### `archive/`

Le compilateur produit **cinq fichiers que personne ne charge**, et il continue — ils
coûtent quelques kilo-octets et documentent le livre — mais rangés à part pour que `data/`
ne contienne que ce que l'app ouvre vraiment :

| fichier | pourquoi il ne sert pas |
|---|---|
| `-compilated-combats.json` | la liste des chapitres de combat ; l'app lit `computed.combat`, chapitre par chapitre |
| `-compilated-secrets.json` | idem avec `computed.secret` |
| `-compilated-endings.json`, `-good-endings`, `-bad-endings` | idem avec `computed.ending` |

Si l'un d'eux redevient utile — un écran « fins découvertes », par exemple — il remonte
dans `data/` et `BookData` le charge.

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
formes marchent, et aucun numéro n'est écrit dans le compilateur.
