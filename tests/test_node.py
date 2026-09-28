"""
Tests unitaires de node.py (unité métier du graphe de chapitres).
"""
import pytest

from node import Node


def chain(n):
    """Construit une chaine lineaire de n Node, chacun fils du precedent."""
    nodes = [Node(i) for i in range(n)]
    for i in range(n - 1):
        nodes[i].add_son(nodes[i + 1])
    return nodes


class TestBasicAccessors:
    def test_have_combat_false_by_default(self):
        assert Node(1).have_combat() is False

    def test_have_combat_true_when_set(self):
        n = Node(1)
        n.set_combat({"foo": "bar"})
        assert n.have_combat() is True

    def test_have_ending_false_by_default(self):
        assert Node(1).have_ending() is False

    def test_ending_good_bad(self):
        n = Node(1)
        n.set_ending(1)  # ENDINGS.GOOD
        assert n.have_ending() is True
        assert n.is_good_ending() is True
        assert n.is_bad_ending() is False

        n2 = Node(2)
        n2.set_ending(2)  # ENDINGS.BAD
        assert n2.is_bad_ending() is True
        assert n2.is_good_ending() is False

    def test_ending_id_roundtrip(self):
        n = Node(1)
        n.set_ending_id(42)
        assert n.get_ending_id() == 42

    def test_aquire_remove_roundtrip(self):
        n = Node(1)
        n.set_aquire(["EPEE"])
        n.set_remove(["COUTEAU"])
        assert n.get_aquire() == ["EPEE"]
        assert n.get_remove() == ["COUTEAU"]

    def test_success_roundtrip(self):
        n = Node(1)
        n.set_sucess("SOME_SUCCESS")
        assert n.get_success() == "SOME_SUCCESS"

    def test_secret_default_false(self):
        n = Node(1)
        assert n.is_secret() is False
        n.set_secret()
        assert n.is_secret() is True


class TestLabel:
    def test_plain_label_is_just_id(self):
        n = Node(7)
        assert n.get_label() == "7"

    def test_custom_label_wins_over_everything(self):
        n = Node(7)
        n.set_secret()
        n.set_combat({"x": "y"})
        n.set_label("Cave secrete")
        assert "Cave secrete" in n.get_label()

    def test_secret_label_when_no_custom_label(self):
        n = Node(7)
        n.set_secret()
        assert "FONT COLOR=\"orange\"" in n.get_label()

    def test_combat_label_when_no_custom_label_nor_secret(self):
        n = Node(7)
        n.set_combat({"x": "y"})
        assert "FONT COLOR=\"red\"" in n.get_label()


class TestSonsAndComputed:
    def test_add_son_and_get_sons(self):
        parent = Node(1)
        child = Node(2)
        parent.add_son(child)
        assert parent.get_sons() == [child]

    def test_get_computed_sorts_son_ids(self):
        n = Node(1)
        n.add_son(Node(9))
        n.add_son(Node(3))
        computed = n.get_computed()
        assert computed["sons"] == [3, 9]

    def test_get_computed_ending_flag_is_boolean(self):
        n = Node(1)
        assert n.get_computed()["ending"] is False
        n.set_ending(1)
        assert n.get_computed()["ending"] is True

    def test_get_computed_exposes_all_expected_keys(self):
        n = Node(1)
        computed = n.get_computed()
        for key in ("id", "ending", "success", "sons", "chapter", "arc",
                    "is_combat", "combat", "label", "secret", "secret_jumps",
                    "ending_id", "ending_txt", "ending_type",
                    "jump_conditions", "jump_conditions_txts",
                    "aquire", "remove", "stats", "stats_cond"):
            assert key in computed


class TestGetAllPossiblesGoto:
    def test_plain_goto_untouched(self):
        n = Node(1)
        assert sorted(n.get_all_possibles_goto([2, 3])) == [2, 3]

    def test_conditions_add_destinations(self):
        n = Node(1)
        n._conditions_raw = {"7": "SOME_ITEM"}
        assert sorted(n.get_all_possibles_goto([6])) == [6, 7]

    def test_secret_jumps_add_destinations(self):
        n = Node(1)
        n.set_secret_jumps([8])
        assert sorted(n.get_all_possibles_goto([6])) == [6, 8]

    def test_all_three_sources_merge_and_dedup(self):
        n = Node(1)
        n._conditions_raw = {"7": "SOME_ITEM"}
        n.set_secret_jumps([7, 8])  # 7 overlaps with the condition destination
        result = sorted(n.get_all_possibles_goto([6, 7]))
        assert result == [6, 7, 8]

    def test_non_integer_condition_key_is_skipped_not_crashed(self):
        # Comportement actuel: une cle de condition non numerique est
        # silencieusement ignoree (juste un print d'erreur), le calcul
        # continue sans lever d'exception.
        n = Node(1)
        n._conditions_raw = {"not-a-number": "X"}
        assert sorted(n.get_all_possibles_goto([1, 2])) == [1, 2]


class TestParseConditions:
    def test_empty_conditions_raw_gives_empty_dict(self):
        n = Node(1)
        n.set_conditions("")
        n.parse_conditions()
        assert n._conditions == {}

    def test_condition_key_not_a_real_son_exits(self):
        n = Node(20)
        n.add_son(Node(21))
        n.set_conditions({"99": "ITEM"})  # 99 n'est pas un fils de 20
        with pytest.raises(SystemExit) as exc_info:
            n.parse_conditions()
        assert exc_info.value.code == 2

    def test_valid_condition_produces_tree_and_readable_text(self):
        n = Node(30)
        n.add_son(Node(31))
        n.set_conditions({"31": "A&B"})
        n.parse_conditions()
        assert n._conditions == {"31": {"$and": [{"$end": "A"}, {"$end": "B"}]}}
        assert n._conditions_txts == {"31": "A et B"}

    def test_or_condition_readable_text_uses_ou(self):
        n = Node(30)
        n.add_son(Node(31))
        n.set_conditions({"31": "A|B"})
        n.parse_conditions()
        assert n._conditions_txts == {"31": "A ou B"}


class TestParseStatsConditions:
    def test_none_raw_gives_empty_list(self):
        n = Node(1)
        n.set_stats_cond(None)
        n.parse_stats_conditions()
        assert n._stats_cond == []

    def test_empty_dict_raw_gives_empty_list(self):
        n = Node(1)
        n.set_stats_cond({})
        n.parse_stats_conditions()
        assert n._stats_cond == []

    def test_valid_stats_condition(self):
        n = Node(1)
        n.set_stats_cond({"GUERRIER": {"deg": 3}})
        n.parse_stats_conditions()
        assert n._stats_cond == [
            {"condition": {"$end": "GUERRIER"}, "stats": {"deg": 3}, "txt": "GUERRIER"}
        ]


class TestGetAllStatsKeys:
    def test_collects_direct_and_conditional_stats_keys(self):
        n = Node(1)
        n.set_stats({"deg": 1})
        n.set_stats_cond({"GUERRIER": {"arm": 2}})
        n.parse_stats_conditions()
        assert n.get_all_stats_keys() == {"deg", "arm"}


class TestSetInArc:
    def test_propagates_to_all_sons(self):
        parent = Node(1)
        child = Node(2)
        grandchild = Node(3)
        parent.add_son(child)
        child.add_son(grandchild)
        parent.set_in_arc("arc1")
        assert parent.get_arc() == child.get_arc() == grandchild.get_arc() == "arc1"

    def test_diamond_shape_tagged_once_from_single_entry(self):
        # a -> b, a -> c, b -> d, c -> d (losange), une seule propagation
        a, b, c, d = Node(1), Node(2), Node(3), Node(4)
        a.add_son(b)
        a.add_son(c)
        b.add_son(d)
        c.add_son(d)
        a.set_in_arc("arc1")
        assert d.get_arc() == "arc1"

    def test_already_tagged_node_is_not_overwritten(self):
        n = Node(1)
        n.set_in_arc("first")
        n.set_in_arc("second")
        assert n.get_arc() == "first"

    def test_cycle_does_not_infinite_loop(self):
        # a -> b -> a : le garde-fou (arc deja pose) doit stopper la recursion
        a, b = Node(1), Node(2)
        a.add_son(b)
        b.add_son(a)
        a.set_in_arc("arc1")  # ne doit pas lever RecursionError / boucler
        assert a.get_arc() == "arc1"
        assert b.get_arc() == "arc1"


class TestSetInSubArc:
    def test_propagates_and_returns_count(self):
        nodes = chain(3)
        nb = nodes[0].set_in_sub_arc("sub1", [], 0)
        assert nb == 3
        assert all(n.get_sub_arc() == "sub1" for n in nodes)

    def test_already_tagged_short_circuits(self):
        n = Node(1)
        n.set_in_sub_arc("first", [], 0)
        nb = n.set_in_sub_arc("second", [], 5)
        assert n.get_sub_arc() == "first"
        assert nb == 5  # inchange, on est sorti immediatement

    def test_stop_point_halts_propagation_without_tagging_the_stop_node(self):
        # Comportement actuel: le noeud listé en sub_arc_stops N'EST PAS
        # tagué lui-même, et ses propres fils ne sont jamais atteints par
        # cette propagation.
        c1, c2, c3 = Node(10), Node(11), Node(12)
        c1.add_son(c2)
        c2.add_son(c3)
        c1.set_in_sub_arc("myarc", [11], 0)
        assert c1.get_sub_arc() == "myarc"
        assert c2.get_sub_arc() is None
        assert c3.get_sub_arc() is None

    def test_cycle_does_not_infinite_loop(self):
        a, b = Node(1), Node(2)
        a.add_son(b)
        b.add_son(a)
        nb = a.set_in_sub_arc("sub1", [], 0)
        assert nb == 2
        assert a.get_sub_arc() == b.get_sub_arc() == "sub1"

    def test_chain_of_61_nodes_succeeds(self):
        # Verifie la borne exacte de la garde-fou de securite: une chaine de
        # 61 noeuds passe (nb retourne = 61).
        nodes = chain(61)
        nb = nodes[0].set_in_sub_arc("sub1", [], 0)
        assert nb == 61
        assert all(n.get_sub_arc() == "sub1" for n in nodes)

    def test_chain_of_62_nodes_raises(self):
        # Le 62e noeud voit nb=61 (>60) et leve avant d'etre tague: seuls
        # les 61 premiers noeuds de la chaine restent tagues.
        nodes = chain(62)
        with pytest.raises(Exception, match="too big"):
            nodes[0].set_in_sub_arc("sub1", [], 0)
        tagged = [n for n in nodes if n.get_sub_arc() is not None]
        assert len(tagged) == 61


class TestSetInSubArcNotRecursive:
    def test_tags_only_this_node(self):
        n = Node(1)
        son = Node(2)
        n.add_son(son)
        n.set_in_sub_arc_not_recursive("manual_arc")
        assert n.get_sub_arc() == "manual_arc"
        assert son.get_sub_arc() is None

    def test_does_not_overwrite_existing_tag(self):
        n = Node(1)
        n.set_in_sub_arc_not_recursive("first")
        n.set_in_sub_arc_not_recursive("second")
        assert n.get_sub_arc() == "first"


class TestGetAllConditionsToken:
    def test_collects_tokens_across_conditions(self):
        n = Node(30)
        n.add_son(Node(31))
        n.add_son(Node(32))
        n.set_conditions({"31": "A&B", "32": "C"})
        n.parse_conditions()
        assert n.get_all_conditions_token() == {"A", "B", "C"}
