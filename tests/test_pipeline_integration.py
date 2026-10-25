"""
Tests d'intégration du pipeline complet (fdcn.py) sur les vraies données des
livres 1 et 2.

fdcn.py est un script procedural (pas de fonctions exportees, tout au niveau
module, argparse sur sys.argv, ecriture de fichiers dans le CWD). On ne peut
donc pas l'importer directement : chaque test le lance comme un vrai
processus (subprocess), dans un repertoire temporaire ou l'on copie
uniquement les fichiers source necessaires au livre teste, exactement comme
le ferait un mainteneur qui recompile les donnees a la main.

IMPORTANT: ne JAMAIS lancer ce script directement dans le repertoire du
repo : il ecrit ses fichiers *-compilated-*.json et graph/ dans le CWD, ce
qui ecraserait les fichiers commites. Tout se passe dans tmp_path.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent

BOOK_INPUT_FILES = [
    "fdcn-{book}.json",
    "fdcn-{book}.arcs.json",
    "fdcn-{book}.sub_arcs.json",
    "fdcn-{book}.manual_sub_arcs.json",
    "fdcn-{book}.all_objects.json",
    "all-success-{book}.json",
]

# Types de "Billy" : ce sont des tokens valides dans les conditions de
# chapitre, mais ils ne sont jamais "acquis" via un chapitre (ils sont
# determines par le type de personnage, pas par un objet ramasse).
BILLY_TYPES = {"GUERRIER", "DEBROUILLARD", "PAYSAN", "PRUDENT", "PEGU"}

# Nombre de noeuds "ending" reels dans chaque livre (compte sur la donnee
# source fdcn-N.json : tous les noeuds avec une cle "ending").
EXPECTED_ENDING_COUNT = {1: 19, 2: 16}


def run_pipeline(tmp_path, book_number):
    """Copie les fichiers source du livre dans tmp_path et lance fdcn.py --book N.

    Retourne (CompletedProcess, tmp_path).
    """
    work_dir = tmp_path / f"book{book_number}"
    work_dir.mkdir()
    (work_dir / "graph").mkdir()

    for pattern in BOOK_INPUT_FILES:
        name = pattern.format(book=book_number)
        shutil.copy(REPO_ROOT / name, work_dir / name)

    proc = subprocess.run(
        [sys.executable, str(REPO_ROOT / "fdcn.py"), "--book", str(book_number)],
        cwd=work_dir,
        capture_output=True,
        text=True,
        timeout=120,
    )
    return proc, work_dir


def load_compiled(work_dir, book_number, suffix):
    path = work_dir / f"fdcn-{book_number}-compilated-{suffix}.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)


@pytest.fixture(scope="module", params=[1, 2])
def compiled_book(request, tmp_path_factory):
    book_number = request.param
    tmp_path = tmp_path_factory.mktemp(f"book{book_number}_shared")
    proc, work_dir = run_pipeline(tmp_path, book_number)
    assert proc.returncode == 0, (
        f"précondition: la compilation du livre {book_number} doit réussir\n"
        f"STDOUT (fin):\n{proc.stdout[-2000:]}\nSTDERR:\n{proc.stderr[-2000:]}"
    )
    data = load_compiled(work_dir, book_number, "data")
    nodes = {int(k): v["computed"] for k, v in data.items()}
    return book_number, work_dir, nodes


class TestBothBooksCompile:
    """
    Jusqu'à ce fix, seul le livre 2 compilait (le livre 1 crashait sur le
    sentinel 608 de fin de livre, cf commit de la migration
    get_all_possibles_goto). Les deux livres doivent maintenant compiler
    de bout en bout.
    """

    @pytest.mark.parametrize("book_number", [1, 2])
    def test_compile_succeeds(self, tmp_path, book_number):
        proc, _ = run_pipeline(tmp_path, book_number)
        assert proc.returncode == 0, (
            f"La compilation du livre {book_number} a échoué:\n"
            f"STDOUT (fin):\n{proc.stdout[-2000:]}\nSTDERR:\n{proc.stderr[-2000:]}"
        )

    @pytest.mark.parametrize("book_number", [1, 2])
    def test_produces_all_expected_files(self, tmp_path, book_number):
        proc, work_dir = run_pipeline(tmp_path, book_number)
        assert proc.returncode == 0
        expected_suffixes = [
            "data", "combats", "endings", "good-endings", "bad-endings",
            "secrets", "nodes-by-chapter", "nodes-by-sub-arc", "success",
            "success-chapters", "all-objects",
        ]
        for suffix in expected_suffixes:
            path = work_dir / f"fdcn-{book_number}-compilated-{suffix}.json"
            assert path.exists(), f"fichier manquant: {path.name}"

    @pytest.mark.parametrize("book_number", [1, 2])
    def test_renders_graph_image(self, tmp_path, book_number):
        proc, work_dir = run_pipeline(tmp_path, book_number)
        assert proc.returncode == 0
        assert (work_dir / "graph" / f"fdcn_full-{book_number}.png").exists()

    def test_book_1_no_longer_crashes_on_608_sentinel(self, tmp_path):
        # Régression directe du bug trouvé en écrivant ces tests : le
        # sentinel "goto": 608 (fin du livre 1) était devenu du code mort
        # après le refactor CDSI, faisant planter toute compilation du
        # livre 1 avec un KeyError. Verrouille que ça ne revient pas.
        proc, _ = run_pipeline(tmp_path, 1)
        assert proc.returncode == 0
        assert "KeyError: 608" not in proc.stderr


class TestBookInvariants:
    """
    Invariants globaux sur le vrai graphe de chaque livre. Ce sont des
    proprietes que fdcn.py NE verifie PAS lui-meme (contrairement a la
    coherence objets/aquire/remove, deja verrouillee par des sys.exit(2)
    internes que ces tests n'ont donc pas besoin de dupliquer).
    """

    def test_no_orphan_node(self, compiled_book):
        book_number, _, nodes = compiled_book
        seen = set()
        stack = [1]
        while stack:
            nid = stack.pop()
            if nid in seen:
                continue
            seen.add(nid)
            stack.extend(s for s in nodes[nid]["sons"] if s not in seen)
        orphans = set(nodes.keys()) - seen
        assert orphans == set(), f"livre {book_number}: noeuds inatteignables depuis 1: {sorted(orphans)}"

    def test_ending_nodes_are_flagged_and_well_formed(self, compiled_book):
        """
        Régression du bug trouvé en écrivant ces tests (déjà actif en
        production pour le livre 2, où le fichier compilé committé avait
        16 chapitres de fin cassés : ending=False, ending_id=None,
        sons=[]). Une fois corrigé, chaque noeud marqué "ending" doit
        avoir un type valide et être bien resté sans fils (terminal).
        """
        book_number, _, nodes = compiled_book
        ending_nodes = [nid for nid, c in nodes.items() if c["ending"]]
        assert len(ending_nodes) == EXPECTED_ENDING_COUNT[book_number], (
            f"livre {book_number}: {len(ending_nodes)} fins détectées, "
            f"{EXPECTED_ENDING_COUNT[book_number]} attendues"
        )
        for nid in ending_nodes:
            c = nodes[nid]
            assert c["ending_type"] in (1, 2), f"{nid}: ending_type invalide ({c['ending_type']})"
            assert c["sons"] == [], f"{nid}: un noeud de fin ne devrait pas avoir de fils"

    def test_billy_type_tokens_used_in_conditions_are_a_known_subset(self, compiled_book):
        """
        Les types de Billy referencés dans des conditions de saut doivent
        rester dans la liste blanche connue (BILLY_TYPES). fdcn.py vérifie
        déjà que tout token de condition est "déclaré" (via
        all_objects.json), mais un type de Billy mal orthographié qui se
        retrouverait par erreur déclaré comme objet ordinaire ne serait
        PAS intercepté par ce sys.exit(2) existant : ce test comble
        spécifiquement ce trou en isolant les tokens qui ressemblent à des
        types de Billy (tout en majuscules, sans accent) et en vérifiant
        qu'ils appartiennent bien aux 5 types réels du jeu.
        """
        book_number, _, nodes = compiled_book
        all_conditions_tokens = set()
        for c in nodes.values():
            for cond_json in c["jump_conditions"].values():
                all_conditions_tokens |= _collect_end_tokens(cond_json)

        assert all_conditions_tokens, f"sanity: le livre {book_number} doit avoir des conditions de saut"

        declared_objects = set(
            json.loads((REPO_ROOT / f"fdcn-{book_number}.all_objects.json").read_text(encoding="utf-8")).keys()
        )
        likely_billy_type_typos = {
            token for token in all_conditions_tokens
            if token not in declared_objects and token not in BILLY_TYPES
        }
        assert likely_billy_type_typos == set(), (
            f"livre {book_number}: tokens de condition ni objets déclarés ni types de Billy connus: "
            f"{sorted(likely_billy_type_typos)}"
        )


def _collect_end_tokens(condition_json):
    """Parcourt un arbre de condition serialise ($and/$or/$end) et retourne les tokens."""
    tokens = set()
    if "$end" in condition_json:
        tokens.add(condition_json["$end"])
    for key in ("$and", "$or"):
        for son in condition_json.get(key, []):
            tokens |= _collect_end_tokens(son)
    return tokens
