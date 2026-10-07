import sys
import autoc.autotest
import autoc.cmake
import autoc.module

if __name__ == "__main__":
  with autoc.cmake.CMake():
    with autoc.module.Module("autotest", source_threshold=200*1024) as m:
      autoc.autotest.configure_module(m)
