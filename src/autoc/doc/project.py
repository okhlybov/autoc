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
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
      ${{{project}_HEADER}}
    )
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
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
      ${{{name}_HEADER}}
    )
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
set(DOXYGEN_SORT_MEMBER_DOCS YES)
set(DOXYGEN_SORT_BRIEF_DOCS YES)
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

doxygen_add_docs(generate
  ${CMAKE_CURRENT_SOURCE_DIR}/@module@_auto.h
  ${DOC_FILTERED_PAGES}
  ALL
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  COMMENT "Generating the autoc reference manual"
)

add_custom_target(@project@ DEPENDS generate)
add_custom_target(autoc-generate DEPENDS generate)
"""


_autoc_cmake = r"""cmake_minimum_required(VERSION 3.15)

if(NOT DEFINED AUTOC)
  if(DEFINED AUTOC_MODULE_SOURCE AND EXISTS "${AUTOC_MODULE_SOURCE}")
    set(_autoc_default AUTO)
  elseif(DEFINED PROJECT_NAME AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.py")
    set(_autoc_default AUTO)
  else()
    set(_autoc_default OFF)
  endif()
  set(AUTOC ${_autoc_default} CACHE STRING "AutoC code generation mode: ON (unconditional), AUTO (incremental), OFF (disabled)")
endif()

if(AUTOC)
  find_package(Python 3.10 REQUIRED)
endif()

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
  set(module_cmake ${key_DIRECTORY}/${module}.cmake)
  set(module_state ${key_DIRECTORY}/${module}.state)

  set(_generate OFF)

  if(AUTOC)
    if(NOT key_COMMAND)
      set(key_COMMAND ${Python_EXECUTABLE} ${key_MAIN_DEPENDENCY} ${module})
    endif()
    if(EXISTS ${key_MAIN_DEPENDENCY})
      set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${key_MAIN_DEPENDENCY} ${key_DEPENDS} ${module_cmake} ${module_state})
      if(AUTOC STREQUAL "AUTO")
        if(NOT EXISTS ${module_state} OR NOT EXISTS ${module_cmake})
          set(_generate ON)
        elseif(${key_MAIN_DEPENDENCY} IS_NEWER_THAN ${module_state})
          set(_generate ON)
        else()
          file(STRINGS ${module_state} _state_lines)
          foreach(_line IN LISTS _state_lines)
            string(REGEX MATCH "\\*([^\r\n]+)$" _match "${_line}")
            if(CMAKE_MATCH_1 AND NOT EXISTS "${key_DIRECTORY}/${CMAKE_MATCH_1}")
              set(_generate ON)
              break()
            endif()
          endforeach()
          if(NOT _generate)
            foreach(dep IN LISTS key_DEPENDS)
              if(dep IS_NEWER_THAN ${module_state})
                set(_generate ON)
                break()
              endif()
            endforeach()
          endif()
        endif()
      else()
        set(_generate ON)
      endif()
    elseif(NOT AUTOC STREQUAL "AUTO")
      message(FATAL_ERROR "AutoC: Generation script '${key_MAIN_DEPENDENCY}' not found for module '${module}'.")
    endif()
  endif()

  if(_generate)
    message(CHECK_START "Generating AutoC module " ${module})
    execute_process(
      WORKING_DIRECTORY ${key_DIRECTORY}
      COMMAND ${key_COMMAND}
      RESULT_VARIABLE gen_res
      OUTPUT_VARIABLE gen_out
      ERROR_VARIABLE gen_err
    )
    if(NOT gen_res EQUAL 0)
      message(CHECK_FAIL "failed")
      message(FATAL_ERROR "AutoC generator failed for '${module}':\n${gen_err}\n${gen_out}")
    else()
      message(CHECK_PASS "done")
      if(NOT EXISTS ${module_state} AND EXISTS ${module_cmake})
        file(TOUCH ${module_cmake})
      endif()
    endif()
  endif()

  if(NOT EXISTS ${module_cmake})
    message(FATAL_ERROR "AutoC: Pre-generated file '${module_cmake}' not found and AUTOC code generation is disabled.")
  endif()
  include(${module_cmake})

  if(AUTOC AND NOT AUTOC STREQUAL "AUTO")
    set(module_target ${module}-generate)
    add_custom_target(${module_target}
      COMMAND ${key_COMMAND}
      WORKING_DIRECTORY ${key_DIRECTORY}
    )
    if(TARGET ${module}-autoc)
      add_dependencies(${module}-autoc ${module_target})
    elseif(TARGET ${module}-auto)
      add_dependencies(${module}-auto ${module_target})
    endif()
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
