import os
import sys
import pathlib
import autoc
import autoc.doc
import autoc.cmake
from autoc.scaffolder import make_template_reader


reader = make_template_reader(__package__)


class Scaffolder(autoc.cmake.Scaffolder):
  
  def __init__(self, resources={}, parameters={}):
    project = parameters.get("project", "doc")
    module = parameters.get("module", project)

    doc_pages_str = " ".join(p.resolve().as_posix() for p in autoc.doc.pages)
    doc_mainpage_str = autoc.doc.mainpage.resolve().as_posix()

    autoc_source = pathlib.Path(autoc.__file__).resolve().parent.parent

    doc_parameters = dict(
      project=project,
      module=module,
      version=autoc.__version__,
      doc_pages=doc_pages_str,
      doc_mainpage=doc_mainpage_str,
      src_path=autoc_source.as_posix(),
    )

    super().__init__(
      resources={
        "CMakeLists.txt": reader,
        "Doxyfile": reader,
        "@module@.py": reader,
        "catalog.py": reader,
        "@module@.c": None,
        ".gitignore": reader,
      } | resources,
      parameters=doc_parameters | parameters
    )

  def generate(self, target="."):
    target_path = pathlib.Path(target).resolve()
    autoc_source = pathlib.Path(autoc.__file__).resolve().parent.parent
    try:
      rel_path = os.path.relpath(autoc_source, target_path)
      common = os.path.commonpath([str(autoc_source), str(target_path)])
      if common in ("/", "\\", ""):
        self.parameters["src_path"] = autoc_source.as_posix()
      else:
        self.parameters["src_path"] = pathlib.Path(rel_path).as_posix()
    except ValueError:
      self.parameters["src_path"] = autoc_source.as_posix()

    super().generate(target)


def generate(directory=".", project="doc"):
  Scaffolder(parameters=dict(project=project, module=project)).generate(directory)


if __name__ == "__main__":
  target = sys.argv[1] if len(sys.argv) > 1 else "."
  generate(target)
