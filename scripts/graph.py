import graph_render
from node import Node

class Graph(object):
    def __init__(self):
        self._nodes = {}


    def create_node(self, nid):
        nid = int(nid)
        node = Node(nid)
        self._nodes[nid] = node


    def get_node(self, node_id: int) -> Node:
        return self._nodes[node_id]


    def add_nodes_to_display_graph(self, display_graph):
        for node in self._nodes.values():
            graph_render.add_node_to_display_graph(node, display_graph)


    def add_edges_to_display_graph(self, arc_graphs):
        for node in self._nodes.values():
            graph_render.add_edges_to_display_graph(node, arc_graphs)
