from node import Node

class Graph(object):
    def __init__(self):
        self._nodes = {}
    
    
    def create_node(self, nid):
        nid = int(nid)
        node = Node(nid)
        self._nodes[nid] = node
        # print(' - %s created' % nid)
    
    
    def get_node(self, node_id):
        # type: (int) -> Node
        return self._nodes[node_id]
    
    
    def add_nodes_to_display_graph(self, display_graph):
        for node in self._nodes.values():
            node.add_node_to_display_graph(display_graph)
    
    
    def add_edges_to_display_graph(self, arc_graphs):
        for node in self._nodes.values():
            node.add_edges_to_display_graph(arc_graphs)
