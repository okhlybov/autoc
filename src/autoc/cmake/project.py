import os
import sys
import pathlib


def interpolate(template, **items):
  s = template
  for name, value in items.items():
    s = s.replace(f"@{name}@", str(value))
  return s


def generate(project, directory="."):
  target_path = pathlib.Path(directory).resolve()
  target_path.mkdir(parents=True, exist_ok=True)
  orig_cwd = os.getcwd()
  try:
    os.chdir(target_path)
    items = dict(project=project, module=project)
    pathlib.Path("cmake").mkdir(parents=True, exist_ok=True)
    pathlib.Path(".vscode").mkdir(parents=True, exist_ok=True)
    for file, template in {
      "cmake/AutoC.cmake": _autoc_cmake,
      "CMakeLists.txt": _cmakelists_txt,
      "CMakePresets.json": _cmakepresets_json,
      f"{project}.c": _project_c,
      f"{project}.py": _project_py,
      f"{project}.code-workspace": _code_workspace,
      ".vscode/launch.json": _launch_json,
      ".gitignore": _gitignore,
    }.items():
      with open(file, "w") as f:
        f.write(interpolate(template, **items))
  finally:
    os.chdir(orig_cwd)


_project_py = """
import sys
import autoc.module
import autoc.cmake
import autoc.string


with autoc.module.Module(sys.argv[1]) as m:
  m.add(autoc.string.String("Str"))


autoc.cmake.CMake(m)
"""


_project_c = """
#include <stdio.h>
#include "@module@_auto.h"


int main(int argc, char** argv) {
  char* s = StrNew("@project@");
  printf("Hello, %s!\\n", s);
  StrFree(s);
  return 0;
}
"""


_code_workspace = """{
  "folders": [
    {
      "path": "."
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


_gitignore = """
build
"""


_cmakepresets_json = """{
  "version": 3,
  "configurePresets": [
    {
      "name": "Common",
      "hidden": true,
      "binaryDir": "${sourceDir}/build/${presetName}"
    },
    {
      "name": "Debug",
      "inherits": "Common",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug"
      }
    },
    {
      "name": "Release",
      "inherits": "Common",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Release"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "Debug",
      "configurePreset": "Debug"
    },
    {
      "name": "Release",
      "configurePreset": "Release"
    }
  ]
}"""


_cmakelists_txt = """
cmake_minimum_required(VERSION 3.21)

project(@project@)

set(AUTOC_MODULE_NAME ${PROJECT_NAME})
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
target_link_libraries(${PROJECT_NAME} ${AUTOC_MODULE_NAME}-autoc)
"""


_autoc_cmake = """
cmake_minimum_required(VERSION 3.15)

if(NOT DEFINED AUTOC)
  if(DEFINED AUTOC_MODULE_SOURCE AND EXISTS "${AUTOC_MODULE_SOURCE}")
    set(_autoc_default ON)
  elseif(DEFINED PROJECT_NAME AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.py")
    set(_autoc_default ON)
  else()
    set(_autoc_default OFF)
  endif()
  option(AUTOC "Enable AutoC code generation" ${_autoc_default})
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
  set(module_cmake ${key_DIRECTORY}/${module}.cmake)
  set(module_target ${module}-generate)

  if(AUTOC)
    if(NOT key_MAIN_DEPENDENCY)
      set(key_MAIN_DEPENDENCY ${key_DIRECTORY}/${module}.py)
    endif()
    if(NOT key_COMMAND)
      set(key_COMMAND ${Python_EXECUTABLE} ${key_MAIN_DEPENDENCY} ${module})
    endif()

    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${key_MAIN_DEPENDENCY} ${key_DEPENDS})

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
      message(FATAL_ERROR "AutoC generator failed for '${module}':\\n${gen_err}\\n${gen_out}")
    else()
      message(CHECK_PASS "done")
    endif()

    include(${module_cmake})
    if(NOT TARGET ${module_target})
      add_custom_target(${module_target})
    endif()
    if(TARGET ${module}-autoc)
      add_dependencies(${module}-autoc ${module_target})
    elseif(TARGET ${module}-auto)
      add_dependencies(${module}-auto ${module_target})
    endif()
  else()
    if(NOT EXISTS ${module_cmake})
      message(FATAL_ERROR "AutoC: Pre-generated file '${module_cmake}' not found and AUTOC code generation is disabled.")
    endif()
    include(${module_cmake})
    if(NOT TARGET ${module_target})
      add_custom_target(${module_target})
    endif()
  endif()
endfunction()
"""


if __name__ == "__main__":
  import argparse
  parser = argparse.ArgumentParser(description="Scaffold an AutoC CMake project")
  parser.add_argument("project", help="Project and module name")
  parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: .)")
  args = parser.parse_args()
  generate(args.project, directory=args.directory)
