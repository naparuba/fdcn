# TODO livre 3 (La lance de Valkar)

Choses volontairement ignorees par `valkar_to_json.py` pour l'instant.

## A traiter plus tard
- **Fins 803 et 878** : mises `good` par defaut, a revalider (good / bad).
- **Objets de objets.txt** (BRASSARD, PROTEGE-GENOUX, PEAUFINAGE DE VOTRE ARME,
  FLECHES EN ACIER ARKADIE, REGIME RICHE EN PRETEINES, RAPIERE-ARBALETE) : "definis en 633",
  mais le chapitre 633 n'a que `go 721, 229` ; comment les obtient-on ?
- **Succes sans chapitre** : "Redressage de manche", "Yeet le Yeti" (chapitre a donner) et "Un jour sans fin" (succes meta : tous les autres debloques, declencheur a definir). Leurs textes sont deja dans `valkar/succes.txt`, les 51 succes des chapitres ont tous un texte.

## Ignores pour l'instant (decision : on skip)
- Jets de de : 44, 65, 78, 126, 149, 212, 216, 225 (JET ADDRESSE / CHANCE / ENDURANCE, `DE:<=3`,
  `si LUCIDITE >= 8: ok=…`). Les liens de destination, eux, sont bien dans le graphe.
- Clauses conditionnelles : 5 (`si ARME: +2 CRITIQUES`), 11 (`MOD: si PV<50% PV MAX => +1 POINT ADDRESSE`),
  84 (`si ARMURE==0 => ARMURE +1, sinon +1 ENDURANCE`).
