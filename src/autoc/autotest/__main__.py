import autoc.autotest
import autoc.cmake
import autoc.module

if __name__ == "__main__":
  with autoc.cmake.CMake():
    with autoc.module.Module("autotest") as m:
      autoc.autotest.configure_module(m)
