"""Tests unitaires de graph.py (conteneur id -> Node)."""
import pytest

from graph import Graph
from node import Node


class TestGraph:
    def test_create_node_registers_it(self):
        g = Graph()
        g.create_node("5")
        assert isinstance(g.get_node(5), Node)
        assert g.get_node(5).get_id() == 5

    def test_create_node_accepts_int_or_str_id(self):
        g = Graph()
        g.create_node(7)
        assert g.get_node(7).get_id() == 7

    def test_get_node_unknown_id_raises_key_error(self):
        g = Graph()
        with pytest.raises(KeyError):
            g.get_node(999)

    def test_add_nodes_to_display_graph_calls_each_node(self):
        g = Graph()
        g.create_node(1)
        g.create_node(2)
        calls = []

        class FakeDisplayGraph:
            def node(self, *args, **kwargs):
                calls.append((args, kwargs))

        g.add_nodes_to_display_graph(FakeDisplayGraph())
        assert len(calls) == 2

    def test_add_edges_to_display_graph_calls_each_node(self):
        g = Graph()
        g.create_node(1)
        g.create_node(2)
        g.get_node(1).add_son(g.get_node(2))
        arc_graphs = {None: []}
        g.add_edges_to_display_graph(arc_graphs)
        assert (str(1), str(2)) in arc_graphs[None]
