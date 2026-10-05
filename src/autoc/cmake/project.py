from autoc.cmake import *


if __name__ == "__main__":
  import argparse
  parser = argparse.ArgumentParser(description="Scaffold an AutoC CMake project")
  parser.add_argument("project", help="Project and module name")
  parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: .)")
  args = parser.parse_args()
  Scaffolder(
    {"@module@.py": template_reader, "@module@.c": template_reader},
    dict(project=args.project, module=args.project)
  ).generate(args.directory)
