"""Import the package from src/ without needing it installed.

The point of lineage being stdlib-only is that CI can run it before anything
is installed; the tests hold themselves to the same bar, so
`python -m pytest tools/lineage/tests` works from a bare checkout.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
