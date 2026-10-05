import sys
import pathlib

src_path = (pathlib.Path(__file__).resolve().parent / "@src_path@").resolve()
if src_path.is_dir():
  sys.path.insert(0, str(src_path))

import autoc
import autoc.doc
import autoc.cmake
import autoc.module

name = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "@module@"

with autoc.module.Module(name, source_count=0) as m:
  autoc.doc.configure_module(m)

pages_list = ";".join(p.resolve().as_posix() for p in autoc.doc.pages)
contents = f"""
    set({name}_HEADER ${{CMAKE_CURRENT_SOURCE_DIR}}/{m.header.file_name})
    set({name}_SOURCES )
    set({name}_DOC_PAGES "{pages_list}")
    set({name}_DOC_MAINPAGE "{autoc.doc.mainpage.resolve().as_posix()}")
    set({name}_VERSION "{autoc.__version__}")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
      ${{{name}_HEADER}}
    )
"""
cmake_file = f"{name}.cmake"
try:
  with open(cmake_file, "r", encoding="utf-8") as f:
    if f.read() != contents:
      raise Exception()
except Exception:
  with open(cmake_file, "w", encoding="utf-8") as f:
    f.write(contents)
