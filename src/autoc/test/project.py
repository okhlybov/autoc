import argparse
from autoc.scaffolder import get_backend_scaffolder, make_template_reader, BACKENDS

reader = make_template_reader(__package__)


class Scaffolder:

  def __new__(cls, resources=None, parameters=None, backend="cmake"):
    backend = (parameters or {}).get("backend") or backend
    base_cls = get_backend_scaffolder(backend)

    build_file = {
      "cmake": "CMakeLists.txt",
      "meson": "meson.build",
      "scons": "SConstruct",
    }[backend.lower()]

    custom_resources = {
      "@project@.code-workspace": reader,
      "@module@.py": reader,
      build_file: reader,
      "@module@.c": None,
    } | dict(resources or {})

    params = dict(project="autoc-test", module="test") | dict(parameters or {})
    return base_cls(resources=custom_resources, parameters=params)


def generate(directory=".", backend="cmake"):
  Scaffolder(backend=backend).generate(directory)


if __name__ == "__main__":
  parser = argparse.ArgumentParser(description="Generate project for the AutoC test suite")
  parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: .)")
  parser.add_argument("--backend", "-b", choices=BACKENDS, default="cmake", help="Build backend (default: cmake)")
  args = parser.parse_args()
  generate(directory=args.directory, backend=args.backend)
