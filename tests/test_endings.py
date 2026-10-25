"""Tests unitaires de endings.py (constantes)."""
from endings import ENDINGS


class TestEndings:
    def test_good_and_bad_are_distinct(self):
        assert ENDINGS.GOOD != ENDINGS.BAD

    def test_values_are_the_ones_node_py_relies_on(self):
        # node.py::is_good_ending / is_bad_ending comparent directement a
        # ces valeurs -- si elles changent sans que node.py soit mis a
        # jour en meme temps, ce test le detecte.
        assert ENDINGS.GOOD == 1
        assert ENDINGS.BAD == 2
