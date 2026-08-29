class MalformedExpressionError(ValueError):
    """Une expression de condition (`ARC & (CORDE | PIOCHE)`) illisible : parenthèses non
    équilibrées, ou `&`/`|` mélangés au même niveau sans parenthèses pour trancher l'ordre
    (todo 3.2 -- avant cette classe, les deux cas sortaient en code 2 muet, ou pire :
    l'arbre se construisait quand même, faux, en silence)."""
    pass


class ConditionNode(object):
    def __init__(self):
        self.operator = None
        self.sons = []
        self.value = ''
    
    
    def __str__(self):
        if self.operator is None:
            return '<ConditionNode UNKNOWN>'
        if self.operator == 'or':
            return '<OR: %s>' % ', '.join(str(son) for son in self.sons)
        if self.operator == 'and':
            return '<AND: %s>' % ', '.join(str(son) for son in self.sons)
        if self.operator == 'simple':
            return '<END: %s>' % self.value
        return 'WHAT???'
    
    
    def get_all_tokens(self, lst=None):
        if lst is None:  # first one: create the list
            lst = set()
        if self.operator == 'simple':
            lst.add(self.value)
        for son in self.sons:
            son.get_all_tokens(lst=lst)
        return lst
    
    def to_json(self):
        if self.operator == 'or':
            return {'$or': [s.to_json() for s in self.sons]}
        if self.operator == 'and':
            return {'$and': [s.to_json() for s in self.sons]}
        if self.operator == 'simple':
            return {'$end': self.value}
        else:
            raise Exception('<ConditionNode UNKNOWN>')


class ConditionNodeFactory(object):
    
    def parse_expr_complex(self, expr):
        n = ConditionNode()

        stacked_par = 0  # level of parenthese
        stack = ''
        in_par = False
        for c in expr:
            if c == '|':
                # If we are in parenthese, just stack it
                if in_par:
                    stack += c
                else:  # real cut
                    # `&` et `|` mélangés sans parenthèses pour trancher l'ordre :
                    # l'un des deux gagnerait en silence selon lequel est vu en dernier.
                    if n.operator is not None and n.operator != 'or':
                        raise MalformedExpressionError(
                            "'&' et '|' mélangés sans parenthèses dans: %r" % expr)
                    n.operator = 'or'
                    stack = stack.strip()
                    if stack != '':
                        o = self.parse_expr(stack)
                        n.sons.append(o)
                    stack = ''
            elif c == '&':
                # If we are in parenthese, just stack it
                if in_par:
                    stack += c
                else:  # real cut
                    if n.operator is not None and n.operator != 'and':
                        raise MalformedExpressionError(
                            "'&' et '|' mélangés sans parenthèses dans: %r" % expr)
                    n.operator = 'and'
                    stack = stack.strip()
                    if stack != '':
                        o = self.parse_expr(stack)
                        n.sons.append(o)
                    stack = ''

            elif c == '(':
                stacked_par += 1

                in_par = True
                stack = stack.strip()
                # Maybe we just start a par, but we got some things in tmp
                # that should not be good in fact !
                if stacked_par == 1 and stack != '':
                    raise MalformedExpressionError(
                        "'(' inattendue après %r dans: %r" % (stack, expr))

                # If we are already in a par, add this (
                # but not if it's the first one so
                if stacked_par > 1:
                    stack += c
                    o = self.parse_expr(stack)
                    n.sons.append(o)

            elif c == ')':
                stacked_par -= 1

                if stacked_par < 0:
                    raise MalformedExpressionError(
                        "')' sans '(' correspondante dans: %r" % expr)

                if stacked_par == 0:
                    stack = stack.strip()
                    o = self.parse_expr(stack)
                    n.sons.append(o)
                    in_par = False
                    # OK now clean the tmp so we start clean
                    stack = ''
                    continue

                # ok here we are still in a huge par, we just close one sub one
                stack += c
            # Maybe it's a classic character, if so, continue
            else:
                stack += c

        if stacked_par != 0:
            raise MalformedExpressionError("'(' jamais refermée dans: %r" % expr)

        stack = stack.strip()
        if stack:
            o = self.parse_expr(stack)
            n.sons.append(o)

        return n


    def parse_expr_simple(self, expr):
        n = ConditionNode()
        n.operator = 'simple'
        n.value = expr
        return n


    def parse_expr(self, expr):
        if '|' in expr or '&' in expr or '(' in expr or ')' in expr:
            return self.parse_expr_complex(expr)
        else:
            return self.parse_expr_simple(expr)
