import os
import sys
import pathlib
import autoc.doc
import autoc.module
import autoc.cmake


def interpolate(template, **items):
  s = template
  for name, value in items.items():
    s = s.replace(f"@{name}@", str(value))
  return s


def generate(directory=".", project="doc"):
  target_path = pathlib.Path(directory).resolve()
  target_path.mkdir(parents=True, exist_ok=True)

  orig_cwd = os.getcwd()
  try:
    os.chdir(target_path)
    import autoc
    doc_pages_str = " ".join(p.resolve().as_posix() for p in autoc.doc.pages)
    doc_mainpage_str = autoc.doc.mainpage.resolve().as_posix()

    autoc_source = pathlib.Path(autoc.__file__).resolve().parent.parent
    try:
      rel_path = os.path.relpath(autoc_source, target_path)
      common = os.path.commonpath([str(autoc_source), str(target_path)])
      if common in ("/", "\\", ""):
        src_path_str = pathlib.Path(autoc_source).as_posix()
      else:
        src_path_str = pathlib.Path(rel_path).as_posix()
    except ValueError:
      src_path_str = pathlib.Path(autoc_source).as_posix()

    items = dict(
      project=project,
      module=project,
      version=autoc.__version__,
      doc_pages=doc_pages_str,
      doc_mainpage=doc_mainpage_str,
      src_path=src_path_str,
    )

    pathlib.Path("cmake").mkdir(parents=True, exist_ok=True)
    pathlib.Path(".vscode").mkdir(parents=True, exist_ok=True)

    for file, template in {
      "cmake/AutoC.cmake": _autoc_cmake,
      "CMakeLists.txt": _cmakelists_txt,
      f"{project}.py": _project_py,
      "Doxyfile": _doxyfile,
      f"autoc-{project}.code-workspace": _code_workspace,
      ".vscode/launch.json": _launch_json,
      ".gitignore": _gitignore,
    }.items():
      with open(file, "w", encoding="utf-8") as f:
        f.write(interpolate(template, **items))

    # Compatibility file if project is 'doc'
    if project == "doc":
      with open("catalog.py", "w", encoding="utf-8") as f:
        f.write("from autoc.doc.catalog import *\n")

    with autoc.module.Module(project, source_count=0) as m:
      autoc.doc.configure_module(m)

    pages_list = ";".join(p.resolve().as_posix() for p in autoc.doc.pages)
    cmake_contents = f"""
    set({project}_HEADER ${{CMAKE_CURRENT_SOURCE_DIR}}/{m.header.file_name})
    set({project}_SOURCES )
    set({project}_DOC_PAGES "{pages_list}")
    set({project}_DOC_MAINPAGE "{autoc.doc.mainpage.resolve().as_posix()}")
    set({project}_VERSION "{autoc.__version__}")
"""
    cmake_file = f"{project}.cmake"
    try:
      with open(cmake_file, "r", encoding="utf-8") as f:
        if f.read() != cmake_contents:
          raise Exception()
    except Exception:
      with open(cmake_file, "w", encoding="utf-8") as f:
        f.write(cmake_contents)

  finally:
    os.chdir(orig_cwd)


_project_py = """import sys
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
contents = f\"\"\"
    set({name}_HEADER ${{CMAKE_CURRENT_SOURCE_DIR}}/{m.header.file_name})
    set({name}_SOURCES )
    set({name}_DOC_PAGES "{pages_list}")
    set({name}_DOC_MAINPAGE "{autoc.doc.mainpage.resolve().as_posix()}")
    set({name}_VERSION "{autoc.__version__}")
\"\"\"
cmake_file = f"{name}.cmake"
try:
  with open(cmake_file, "r", encoding="utf-8") as f:
    if f.read() != contents:
      raise Exception()
except Exception:
  with open(cmake_file, "w", encoding="utf-8") as f:
    f.write(contents)
"""


_cmakelists_txt = """cmake_minimum_required(VERSION 3.21)

project(@project@)

set(AUTOC_MODULE_NAME ${PROJECT_NAME})
set(AUTOC_MODULE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.py)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

find_package(Doxygen REQUIRED)

include(AutoC)

# The documentation module is regenerated from @project@.py whenever definitions change
add_autoc_module(
  ${AUTOC_MODULE_NAME}
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  MAIN_DEPENDENCY ${AUTOC_MODULE_SOURCE}
  COMMAND ${Python_EXECUTABLE} ${AUTOC_MODULE_SOURCE} ${AUTOC_MODULE_NAME}
)

include(${CMAKE_CURRENT_SOURCE_DIR}/${AUTOC_MODULE_NAME}.cmake)

set(PROJECT_VERSION "${${AUTOC_MODULE_NAME}_VERSION}")
set(AUTOC_VERSION "${${AUTOC_MODULE_NAME}_VERSION}")

# Filter documentation pages on consumption for @@ variable substitution
set(DOC_FILTERED_PAGES "")
foreach(page IN LISTS ${AUTOC_MODULE_NAME}_DOC_PAGES)
  get_filename_component(page_name "${page}" NAME)
  set(filtered_page "${CMAKE_CURRENT_BINARY_DIR}/${page_name}")
  configure_file("${page}" "${filtered_page}" @ONLY)
  list(APPEND DOC_FILTERED_PAGES "${filtered_page}")
endforeach()

get_filename_component(mainpage_name "${${AUTOC_MODULE_NAME}_DOC_MAINPAGE}" NAME)
set(DOC_FILTERED_MAINPAGE "${CMAKE_CURRENT_BINARY_DIR}/${mainpage_name}")

set(DOXYGEN_PROJECT_NAME "autoc")
set(DOXYGEN_PROJECT_NUMBER "${${AUTOC_MODULE_NAME}_VERSION}")
set(DOXYGEN_PROJECT_BRIEF "C source code generation from Python")
set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "${DOC_FILTERED_MAINPAGE}")
set(DOXYGEN_OPTIMIZE_OUTPUT_FOR_C YES)
set(DOXYGEN_EXTRACT_ALL NO)
set(DOXYGEN_EXTRACT_STATIC YES)
# The manual documents groups and members; the raw C compounds (and the internal
# container components) are not its subject so their undoc warnings are silenced
set(DOXYGEN_WARN_IF_UNDOCUMENTED NO)
set(DOXYGEN_WARN_IF_INCOMPLETE_DOC NO)
set(DOXYGEN_FILE_PATTERNS "*.h" "*.md")
set(DOXYGEN_INPUT_ENCODING UTF-8)
set(DOXYGEN_GENERATE_TREEVIEW YES)
#set(DOXYGEN_GENERATE_LATEX YES)
set(DOXYGEN_GENERATE_PDF YES)
set(DOXYGEN_SHOW_FILES NO)
set(DOXYGEN_SORT_MEMBER_DOCS YES)
set(DOXYGEN_SORT_BRIEF_DOCS YES)
set(DOXYGEN_SORT_GROUP_NAMES YES)

doxygen_add_docs(generate
  ${CMAKE_CURRENT_SOURCE_DIR}/@module@_auto.h
  ${DOC_FILTERED_PAGES}
  ALL
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  COMMENT "Generating the autoc reference manual"
)

# The generated header must be up to date before Doxygen parses it
add_dependencies(generate @module@-generate)

add_custom_target(@project@ DEPENDS generate)
add_custom_target(autoc-generate DEPENDS @module@-generate)
"""


_autoc_cmake = """cmake_minimum_required(VERSION 3.15)

find_package(Python 3.13 REQUIRED)

function(add_autoc_module module)
  set(args DIRECTORY MAIN_DEPENDENCY)
  set(listArgs COMMAND DEPENDS)
  cmake_parse_arguments(key "${flags}" "${args}" "${listArgs}" ${ARGN})
  if(NOT key_DIRECTORY)
    set(key_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  endif()
  if(NOT key_MAIN_DEPENDENCY)
    set(key_MAIN_DEPENDENCY ${key_DIRECTORY}/${module}.py)
  endif()
  set(module_state ${key_DIRECTORY}/${module}.state)
  set(module_cmake ${key_DIRECTORY}/${module}.cmake)
  set(module_target ${module}-generate)
  if(NOT EXISTS ${module_state} OR NOT EXISTS ${module_cmake})
    message(CHECK_START "Bootstrapping AutoC module " ${module})
    execute_process(WORKING_DIRECTORY ${key_DIRECTORY} COMMAND ${key_COMMAND} VERBATIM)
  endif()
  include(${module_cmake})
  add_custom_command(
    OUTPUT ${module_state}
    BYPRODUCTS ${module_cmake}
    MAIN_DEPENDENCY ${key_MAIN_DEPENDENCY}
    DEPENDS ${key_DEPENDS}
    WORKING_DIRECTORY ${key_DIRECTORY}
    COMMAND ${key_COMMAND}
    VERBATIM
  )
  add_custom_target(${module_target} DEPENDS ${module_state})
  # A documentation-only module declares no library to depend on the generation target
  if(TARGET ${module}-auto)
    add_dependencies(${module}-auto ${module_target})
  endif()
endfunction()
"""


_doxyfile = """# Doxygen configuration for the autoc reference manual.
# Usage: python @project@.py && doxygen Doxyfile
PROJECT_NAME           = "autoc"
PROJECT_NUMBER         = @version@
PROJECT_BRIEF          = "Template engine for C source code generation"
INPUT                  = @module@_auto.h @doc_pages@
USE_MDFILE_AS_MAINPAGE = @doc_mainpage@
OUTPUT_DIRECTORY       = reference
GENERATE_HTML          = YES
HTML_OUTPUT            = html
GENERATE_LATEX         = NO
EXTRACT_ALL            = YES
EXTRACT_STATIC         = YES
OPTIMIZE_OUTPUT_FOR_C  = YES
MAX_INITIALIZER_LINES  = 0
QUIET                  = YES
WARNINGS               = YES
WARN_IF_UNDOCUMENTED   = NO
SHOW_INCLUDE_FILES     = NO
SORT_MEMBER_DOCS       = YES
SORT_BRIEF_DOCS        = YES
SORT_GROUP_NAMES       = YES
"""


_code_workspace = """{
  "settings": {
    "cmake.configureOnOpen": false,
    "cmake.autoSelectActiveFolder": false,
    "cmake.sourceDirectory": "${workspaceFolder}"
  },
  "folders": [
    {
      "path": ".",
      "name": "@project@"
    }
  ]
}"""


_launch_json = """{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "CMake Debug",
      "type": "cppdbg",
      "request": "launch",
      "program": "${command:cmake.launchTargetPath}",
      "args": [],
      "cwd": "${workspaceFolder}"
    }
  ]
}"""


_gitignore = """build
reference
html
latex
@module@.cmake
@module@.state
@module@_auto*
*_auto.*
"""


if __name__ == "__main__":
  target = sys.argv[1] if len(sys.argv) > 1 else "."
  generate(target)
