import sys
sys.path.insert(0, "../src")

import autoc.test
import autoc.cmake
import autoc.module

with autoc.module.Module("test", stateful=False) as m:
  autoc.test.configure_module(m)

autoc.cmake.CMake(m)
