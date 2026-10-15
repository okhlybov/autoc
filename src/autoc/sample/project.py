from autoc.project import *

if __name__ == "__main__":
  import sys
  import argparse
  from autoc.scaffolder import BACKENDS
  parser = argparse.ArgumentParser(description="Scaffold an AutoC sample project")
  parser.add_argument("project", help="Project and module name")
  parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: .)")
  parser.add_argument("--backend", "-b", choices=BACKENDS, default="cmake", help="Build backend (default: cmake)")
  args = parser.parse_args()
  generate(args.project, directory=args.directory, backend=args.backend)
