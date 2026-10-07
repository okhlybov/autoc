from autoc.cmake import *


reader = make_template_reader(__package__)


if __name__ == "__main__":
  import argparse
  parser = argparse.ArgumentParser(description="Generate CMake project for the AutoC programmatic test suite")
  parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: .)")
  args = parser.parse_args()
  Scaffolder(
    {"@module@.py": reader, "CMakeLists.txt": reader, "@module@.c": None},
    dict(project="autoc-autotest", module="autotest")
  ).generate(args.directory)
