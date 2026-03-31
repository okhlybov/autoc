import sys
import pathlib


def interpolate(template, **items):
  s = template
  for name, value in items.items():
    s = s.replace(f"@{name}@", str(value))
  return s


def generate(project):
  items = dict(project=project, module=f"_{project}")
  pathlib.Path("cmake").mkdir(parents=True, exist_ok=True)
  for file, template in {
    "cmake/AutoC.cmake": _autoc_cmake,
    f"CMakeLists.txt": _cmakelists_txt,
    f"{project}.c": _project_c,
    f"{project}.py": _project_py,
    f"{project}.code-workspace": _code_workspace,
    ".gitignore": _gitignore,
  }.items():
    with open(file, "w") as f:
      f.write(interpolate(template, **items))


_project_py = """
import sys
import autoc.module
import autoc.cmake


with autoc.module.Module(sys.argv[1]) as m:
  pass


autoc.cmake.CMake(m)
"""


_project_c = """
#include "@module@_auto.h"


int main(int argc, char** argv) {
  return 0;
}
"""


_code_workspace = """
{
  "folders": [
    {
      "path": "."
    }
  ],
  "settings": {
    "cmake.sourceDirectory": "${workspaceFolder}",
    "cmake.buildDirectory": "${workspaceFolder}/build"
  }
}
"""


_gitignore = """
build
"""

_cmakelists_txt = """
cmake_minimum_required(VERSION 3.15)

project(@project@)

set(AUTOC_MODULE_NAME _${PROJECT_NAME})
set(AUTOC_MODULE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.py)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

include(AutoC)

add_autoc_module(
  ${AUTOC_MODULE_NAME}
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  MAIN_DEPENDENCY ${AUTOC_MODULE_SOURCE}
  COMMAND ${Python_EXECUTABLE} ${AUTOC_MODULE_SOURCE} ${AUTOC_MODULE_NAME}
)

add_executable(${PROJECT_NAME} ${PROJECT_NAME}.c)
target_link_libraries(${PROJECT_NAME} ${AUTOC_MODULE_NAME})
"""


_autoc_cmake = """
cmake_minimum_required(VERSION 3.15)

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
  add_dependencies(${module} ${module_target})
endfunction()
"""

if __name__ == "__main__":
  generate(sys.argv[1])