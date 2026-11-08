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
    
    
    def add_nodes_to_display_graph(self, display_graph, hidden=(), unreachable=(), arc_colors=None, arc_starts=()):
        # hidden: node ids not drawn (drawing only, the data is untouched)
        from_hidden = set()
        for h in hidden:
            for son in self.get_node(h).get_sons():
                from_hidden.add(son.get_id())
        for node in self._nodes.values():
            if node.get_id() in hidden:
                continue
            to_hidden = any(son.get_id() in hidden for son in node.get_sons())
            node.add_node_to_display_graph(display_graph, to_hidden=to_hidden,
                                           from_hidden=node.get_id() in from_hidden,
                                           unreachable=node.get_id() in unreachable,
                                           arc_fill=(arc_colors or {}).get(node.get_arc()),
                                           big=node.get_id() in arc_starts)
    
    
    def add_edges_to_display_graph(self, arc_graphs, hidden=()):
        for node in self._nodes.values():
            if node.get_id() in hidden:
                continue
            node.add_edges_to_display_graph(arc_graphs, hidden)
