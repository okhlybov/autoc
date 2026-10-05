import sys
import autoc.module
import autoc.cmake
import autoc.string


with autoc.module.Module(sys.argv[1]) as m:
  m.add(autoc.string.String("String"))


autoc.cmake.CMake(m)