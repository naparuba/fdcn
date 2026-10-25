"""
Tests unitaires du parseur d'expressions de conditions (condition_node.py).

Ce module est le plus petit et le plus mécanique de la chaîne de compilation,
mais toute régression ici fausse silencieusement toutes les conditions du jeu
(qui contrôlent l'accès aux chapitres et l'application des stats).
"""
import pytest

from condition_node import ConditionNode, ConditionNodeFactory


def parse(expr):
    return ConditionNodeFactory().parse_expr(expr)


class TestSimpleToken:
    def test_single_token_is_simple(self):
        n = parse("EPEE")
        assert n.operator == "simple"
        assert n.value == "EPEE"

    def test_to_json_simple(self):
        n = parse("EPEE")
        assert n.to_json() == {"$end": "EPEE"}

    def test_get_all_tokens_simple(self):
        n = parse("EPEE")
        assert n.get_all_tokens() == {"EPEE"}


class TestAndOr:
    def test_and_two_terms(self):
        n = parse("A&B")
        assert n.operator == "and"
        assert [s.value for s in n.sons] == ["A", "B"]
        assert n.to_json() == {"$and": [{"$end": "A"}, {"$end": "B"}]}

    def test_and_three_terms_stays_flat(self):
        n = parse("A&B&C")
        assert n.operator == "and"
        assert [s.value for s in n.sons] == ["A", "B", "C"]

    def test_or_two_terms(self):
        n = parse("A|B")
        assert n.operator == "or"
        assert n.to_json() == {"$or": [{"$end": "A"}, {"$end": "B"}]}

    def test_or_three_terms_stays_flat(self):
        n = parse("A|B|C")
        assert n.operator == "or"
        assert [s.value for s in n.sons] == ["A", "B", "C"]

    def test_get_all_tokens_and(self):
        n = parse("A&B")
        assert n.get_all_tokens() == {"A", "B"}


class TestParentheses:
    def test_and_of_or_group(self):
        # (A|B)&C
        n = parse("(A|B)&C")
        assert n.operator == "and"
        assert n.to_json() == {
            "$and": [
                {"$or": [{"$end": "A"}, {"$end": "B"}]},
                {"$end": "C"},
            ]
        }

    def test_or_of_and_group(self):
        # (A&B)|C
        n = parse("(A&B)|C")
        assert n.operator == "or"
        assert n.to_json() == {
            "$or": [
                {"$and": [{"$end": "A"}, {"$end": "B"}]},
                {"$end": "C"},
            ]
        }

    def test_and_with_trailing_or_group(self):
        # A&(B|C)
        n = parse("A&(B|C)")
        assert n.operator == "and"
        assert n.to_json() == {
            "$and": [
                {"$end": "A"},
                {"$or": [{"$end": "B"}, {"$end": "C"}]},
            ]
        }

    def test_two_parenthesized_groups(self):
        # (A|B)&(C|D) -- exactly one level of nesting on each side, no
        # parenthesis wraps the whole expression: this is the one shape of
        # "double group" the parser supports correctly.
        n = parse("(A|B)&(C|D)")
        assert n.operator == "and"
        assert n.to_json() == {
            "$and": [
                {"$or": [{"$end": "A"}, {"$end": "B"}]},
                {"$or": [{"$end": "C"}, {"$end": "D"}]},
            ]
        }


class TestKnownParserLimitations:
    """
    Ces tests documentent (et verrouillent) des comportements RÉELS et
    SURPRENANTS du parseur actuel, découverts en l'exécutant directement
    plutôt que supposés. Ce ne sont pas les comportements qu'on voudrait
    idéalement, mais si quelqu'un les changes, ça doit être une décision
    consciente (le test casse et documente pourquoi), pas une régression
    silencieuse.
    """

    def test_mixing_and_or_without_parens_silently_drops_the_and(self):
        # A&B|C : on s'attendrait à AND(A,B) puis OR(.., C), mais
        # l'opérateur du noeud est simplement écrasé par le dernier
        # opérateur rencontré : le résultat réel est OR(A, B, C), le '&'
        # est perdu. Si les données du livre contiennent une expression de
        # ce type sans parenthèses explicites, la condition réelle appliquée
        # est FAUSSE par rapport à l'intention. C'est un vrai risque de bug
        # de contenu (voir fdcn-N.json), pas juste un détail d'implémentation.
        n = parse("A&B|C")
        assert n.operator == "or"
        assert [s.value for s in n.sons] == ["A", "B", "C"]

    @pytest.mark.parametrize("expr", [
        "((A|B)&(C|D))",   # parenthese englobant toute l'expression
        "A&((B|C)&D)",     # vraie imbrication a 2 niveaux, meme partielle
        "((A|B)&C)&D",
        "((A)",
        "()",
    ])
    def test_nesting_beyond_one_level_raises(self, expr):
        # Le parseur ne supporte qu'UN seul niveau de parenthese à la fois.
        # Dès qu'on imbrique une parenthèse dans une autre (peu importe la
        # profondeur), il produit un ConditionNode dont l'opérateur reste
        # None, et to_json() lève une Exception générique et peu parlante.
        # Ce n'est PAS la limite "empirique de 60" documentée dans le code
        # de set_in_sub_arc: ça casse déjà au niveau 2. Le parsing en
        # lui-même ne lève pas toujours (l'arbre reste corrompu, avec un
        # noeud d'operateur None), l'exception n'apparait qu'a la
        # serialisation JSON -- comme le fait le pipeline reel (node.py
        # appelle to_json() juste apres parse_expr()).
        with pytest.raises(Exception):
            parse(expr).to_json()

    def test_missing_operand_after_operator_is_silently_ignored(self):
        # "A&B&" : le '&' final n'a pas d'operande a droite, mais aucune
        # erreur n'est levee, le terme vide est juste ignore.
        n = parse("A&B&")
        assert [s.value for s in n.sons] == ["A", "B"]

    def test_leading_operator_is_silently_ignored(self):
        n = parse("&A")
        assert n.operator == "and"
        assert [s.value for s in n.sons] == ["A"]

    def test_doubled_operator_is_silently_tolerated(self):
        n = parse("A||B")
        assert [s.value for s in n.sons] == ["A", "B"]


class TestUnbalancedParentheses:
    def test_extra_closing_paren_exits(self):
        with pytest.raises(SystemExit) as exc_info:
            parse("(A))")
        assert exc_info.value.code == 2

    def test_unclosed_paren_raises(self):
        # Le compteur ne redescend jamais a 0: la lecture se termine avec
        # stacked_par > 0 sans erreur explicite de "parenthese non fermee",
        # mais l'etat interne produit un noeud invalide qui casse a la
        # serialisation.
        with pytest.raises(Exception):
            parse("((A)").to_json()


class TestConditionNodeDirect:
    def test_str_unknown_operator(self):
        n = ConditionNode()
        assert str(n) == "<ConditionNode UNKNOWN>"

    def test_to_json_unknown_operator_raises(self):
        n = ConditionNode()
        with pytest.raises(Exception):
            n.to_json()

    def test_get_all_tokens_nested(self):
        n = parse("(A|B)&(C|D)")
        assert n.get_all_tokens() == {"A", "B", "C", "D"}
