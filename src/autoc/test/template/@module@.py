import sys
import autoc.test
import autoc.cmake
import autoc.module

name = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "test"

with autoc.cmake.CMake():
  with autoc.module.Module(name) as m:
    autoc.test.configure_module(m)