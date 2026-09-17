import catalog
import autoc.module
import autoc.cmake


# The manual is a documentation-only module: no sources are generated and the
# output is not tracked by a state file since it is always regenerated
with autoc.module.Module("autoc", source_count=0, stateful=False) as m:
  catalog.configure_module(m)


autoc.cmake.CMake(m)
