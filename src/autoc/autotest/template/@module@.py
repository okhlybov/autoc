import sys
import autoc.autotest
import autoc.cmake
import autoc.module

name = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "autotest"

with autoc.cmake.CMake():
  with autoc.module.Module(name) as m:
    autoc.autotest.configure_module(m)
