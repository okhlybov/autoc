import os
import sys
import pathlib


def interpolate(template, **items):
  s = template
  for name, value in items.items():
    s = s.replace(f"@{name}@", str(value))
  return s


def generate(project, directory=".", build_system="cmake"):
  if build_system == "meson":
    return generate_meson(project, directory=directory)
  return generate_cmake(project, directory=directory)


def generate_cmake(project, directory="."):
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


def generate_meson(project, directory="."):
  target_path = pathlib.Path(directory).resolve()
  target_path.mkdir(parents=True, exist_ok=True)
  orig_cwd = os.getcwd()
  try:
    os.chdir(target_path)
    items = dict(project=project, module=project)
    pathlib.Path(".vscode").mkdir(parents=True, exist_ok=True)
    for file, template in {
      "meson.build": _meson_build,
      "meson_options.txt": _meson_options,
      f"{project}.c": _project_c,
      f"{project}.py": _project_py_meson,
      f"{project}.code-workspace": _code_workspace,
      ".vscode/launch.json": _launch_json_meson,
      ".gitignore": _gitignore_meson,
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
target_link_libraries(${PROJECT_NAME} ${AUTOC_MODULE_NAME}-auto)
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
  if(TARGET ${module}-auto)
    add_dependencies(${module}-auto ${module_target})
  endif()
endfunction()
"""


_project_py_meson = """
import sys
import autoc.module
import autoc.string


with autoc.module.Module(sys.argv[1]) as m:
  m.add(autoc.string.String("Str"))
"""


_meson_options = """option('regenerate',
  type: 'feature',
  value: 'auto',
  description: 'Regenerate AutoC sources using Python (auto: only if missing)'
)
"""


_meson_build = """project('@project@', 'c',
  version: '0.1.0',
  default_options: ['warning_level=2']
)

fs = import('fs')

module_name = '@module@'
gen_h = module_name + '_auto.h'
gen_c = module_name + '_auto.c'
has_bundled = fs.exists(gen_h) and fs.exists(gen_c)

regen_opt = get_option('regenerate')
need_generator = regen_opt.enabled() or (regen_opt.auto() and not has_bundled)

if need_generator
  py = import('python').find_installation('python3', required: true)
  autoc_sources = custom_target(
    module_name + '-auto',
    input: module_name + '.py',
    output: [gen_h, gen_c],
    command: [py, '@INPUT@', module_name]
  )
else
  message('AutoC: Using pre-generated sources (@module@_auto.{h,c})')
  autoc_sources = files(gen_h, gen_c)
endif

autoc_dep = declare_dependency(
  sources: autoc_sources,
  include_directories: include_directories('.')
)

executable('@project@',
  sources: ['@project@.c'],
  dependencies: [autoc_dep]
)
"""


_launch_json_meson = """{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Meson Debug",
      "type": "cppdbg",
      "request": "launch",
      "program": "${command:mesonbuild.buildDir}/@project@",
      "args": [],
      "cwd": "${workspaceFolder}"
    }
  ]
}"""


_gitignore_meson = """
build/
builddir/
subprojects/
"""


if __name__ == "__main__":
  import argparse
  parser = argparse.ArgumentParser(description="Scaffold an AutoC project")
  parser.add_argument("project", help="Project and module name")
  parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: .)")
  parser.add_argument("-b", "--build", choices=["cmake", "meson"], default="cmake", help="Build system (default: cmake)")
  parser.add_argument("--meson", action="store_true", help="Shortcut for --build=meson")
  args = parser.parse_args()
  build_system = "meson" if args.meson else args.build
  generate(args.project, directory=args.directory, build_system=build_system)