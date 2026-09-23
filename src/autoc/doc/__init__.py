import pathlib
from autoc.doc.catalog import *

dir = pathlib.Path(__file__).parent
mainpage = dir / "mainpage.md"
pages = [
  dir / "mainpage.md",
  dir / "tutorial.md",
  dir / "design.md",
  dir / "containers.md",
]
