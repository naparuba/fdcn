# TODO livre 3 (La lance de Valkar)

Choses volontairement ignorees par `valkar_to_json.py` pour l'instant.

## A traiter plus tard
- **Fins 803 et 878** : mises `good` par defaut, a revalider (good / bad).
- **Objets de objets.txt** (BRASSARD, PROTEGE-GENOUX, PEAUFINAGE DE VOTRE ARME,
  FLECHES EN ACIER ARKADIE, REGIME RICHE EN PRETEINES, RAPIERE-ARBALETE) : "definis en 633",
  mais le chapitre 633 n'a que `go 721, 229` ; comment les obtient-on ?
- **Succes sans chapitre** : "Un jour sans fin" (succes meta : tous les autres debloques, declencheur a definir dans l'appli). Son texte est dans `valkar/succes.txt`, son picto est fait.

## Combats (livre 3)
Syntaxe dans les chapitres : `COMBAT "Nom" HAB 16 PV 12 ARM 2 DEG 2 PYRO 10` (stats absentes = 0).
- Aucune regle speciale de combat n'est definie pour le livre 3 (cf combat_modificateurs_par_node.gd).

## Ignores pour l'instant (decision : on skip)
- Jets de de : 44, 65, 78, 126, 149, 212, 216, 225 (JET ADDRESSE / CHANCE / ENDURANCE, `DE:<=3`,
  `si LUCIDITE >= 8: ok=…`). Les liens de destination, eux, sont bien dans le graphe.
- Clauses conditionnelles : 5 (`si ARME: +2 CRITIQUES`), 11 (`MOD: si PV<50% PV MAX => +1 POINT ADDRESSE`),
  84 (`si ARMURE==0 => ARMURE +1, sinon +1 ENDURANCE`).
