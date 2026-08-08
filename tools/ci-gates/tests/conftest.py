"""Import the package from src/ without needing it installed.

ci-gates is stdlib-only so CI's smart-ci job can run the selector before
anything is installed; the tests hold to the same bar, so
`python -m pytest tools/ci-gates/tests` works from a bare checkout.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
