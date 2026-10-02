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
    pathlib.Path("site_scons/site_tools").mkdir(parents=True, exist_ok=True)
    pathlib.Path(".vscode").mkdir(parents=True, exist_ok=True)
    for file, template in {
      "site_scons/site_tools/autoc.py": _autoc_tool,
      "SConstruct": _sconstruct,
      f"{project}.c": _project_c,
      f"{project}.py": _project_py,
      f"{project}.code-workspace": _code_workspace,
      ".vscode/launch.json": _launch_json,
      ".vscode/tasks.json": _tasks_json,
      ".gitignore": _gitignore,
    }.items():
      with open(file, "w") as f:
        f.write(interpolate(template, **items))
  finally:
    os.chdir(orig_cwd)


_project_py = """import sys
import autoc.module
import autoc.scons
import autoc.string


name = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "@module@"

with autoc.scons.SCons():
  with autoc.module.Module(name) as m:
    m.add(autoc.string.String("Str"))
"""


_project_c = """#include <stdio.h>
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
      "name": "SCons Debug",
      "type": "cppdbg",
      "request": "launch",
      "program": "${workspaceFolder}/@project@",
      "args": [],
      "cwd": "${workspaceFolder}",
      "preLaunchTask": "SCons: Build (Debug)"
    }
  ]
}"""


_tasks_json = """{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "SCons: Build (Debug)",
      "type": "shell",
      "command": "scons BUILD_TYPE=Debug",
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "problemMatcher": ["$gcc"]
    },
    {
      "label": "SCons: Build (Release)",
      "type": "shell",
      "command": "scons BUILD_TYPE=Release",
      "group": "build",
      "problemMatcher": ["$gcc"]
    },
    {
      "label": "SCons: Clean",
      "type": "shell",
      "command": "scons -c",
      "problemMatcher": []
    }
  ]
}"""


_gitignore = """.sconsign.dblite
.sconf_temp/
*.o
*.obj
*.so
*.dylib
*.dll
build/
@project@
@project@.exe
"""


_sconstruct = """import os
import sys

# Ensure site_tools and autoc tool are loaded
env = Environment(tools=["default", "autoc"], toolpath=["site_scons/site_tools"])

vars = Variables()
vars.Add(EnumVariable("AUTOC", "AutoC code generation mode: ON (unconditional), AUTO (incremental), OFF (disabled)", "auto", allowed_values=("auto", "on", "off"), ignorecase=2))
vars.Add(EnumVariable("BUILD_TYPE", "Build configuration type", "debug", allowed_values=("debug", "release"), ignorecase=2))
vars.Update(env)
Help(vars.GenerateHelpText(env))

# Compiler configuration based on build type
if env["BUILD_TYPE"].lower() == "debug":
  if env.get("PLATFORM") == "win32" and env.get("CC") in ("cl", "msvc"):
    env.Append(CCFLAGS=["/Od", "/Zi", "/MDd"])
  else:
    env.Append(CCFLAGS=["-g", "-O0"])
else:
  if env.get("PLATFORM") == "win32" and env.get("CC") in ("cl", "msvc"):
    env.Append(CCFLAGS=["/O2", "/DNDEBUG", "/MD"])
  else:
    env.Append(CCFLAGS=["-O3", "-DNDEBUG"])

project = "@project@"

autoc_mod = env.AutoCModule(
  project,
  directory=".",
  main_dependency=f"{project}.py",
)

app = env.Program(target=project, source=[f"{project}.c"] + autoc_mod.sources)
Default(app)
"""


_autoc_tool = """import os
import sys
import subprocess
import SCons.Script
import SCons.Errors


class AutoCModuleResult(list):

  def __init__(self, name, directory, header, sources, objects=None):
    super().__init__(sources)
    self.name = name
    self.directory = directory
    self.header = header
    self.sources = sources
    self.objects = objects or []


def add_autoc_module(env, module, directory=".", main_dependency=None, command=None, depends=None):
  if not main_dependency:
    main_dependency = os.path.join(directory, f"{module}.py")
  if depends is None:
    depends = []

  # Determine code generation mode: AUTO, ON, or OFF
  autoc_mode = env.get("AUTOC") or SCons.Script.ARGUMENTS.get("AUTOC") or os.environ.get("AUTOC")
  if not autoc_mode:
    autoc_mode = "AUTO" if os.path.exists(main_dependency) else "OFF"
  autoc_mode = str(autoc_mode).upper()

  module_scons = os.path.join(directory, f"{module}.scons")
  module_state = os.path.join(directory, f"{module}.state")
  py_exec = env.get("PYTHON", sys.executable)
  if not command:
    command = [py_exec, os.path.abspath(main_dependency), module]

  if autoc_mode == "OFF":
    if not os.path.exists(module_scons):
      raise SCons.Errors.UserError(f"AutoC: Pre-generated file '{module_scons}' not found and AUTOC code generation is disabled.")
  elif autoc_mode in ("AUTO", "ON"):
    if not os.path.exists(main_dependency):
      if autoc_mode == "AUTO" and os.path.exists(module_scons):
        pass
      else:
        raise SCons.Errors.UserError(f"AutoC: Generation script '{main_dependency}' not found for module '{module}'.")

    need_gen = (autoc_mode == "ON") or (not os.path.exists(module_scons)) or (not os.path.exists(module_state))
    if not need_gen:
      state_mtime = os.path.getmtime(module_state)
      if os.path.getmtime(main_dependency) > state_mtime:
        need_gen = True
      else:
        for dep in depends:
          if os.path.getmtime(dep) > state_mtime:
            need_gen = True
            break

    if need_gen:
      print(f"-- Generating AutoC module {module}")
      env_vars = os.environ.copy()
      res = subprocess.run(command, cwd=directory, capture_output=True, text=True, env=env_vars)
      if res.returncode != 0:
        raise SCons.Errors.UserError(f"AutoC generator failed for '{module}':\\n{res.stderr}\\n{res.stdout}")

  loc = {"env": env}
  with open(module_scons, "r") as f:
    exec(f.read(), loc)
  header = loc.get("HEADER")
  sources = loc.get("SOURCES", [])
  header_path = os.path.join(directory, header) if directory != "." else header
  source_paths = [os.path.join(directory, s) if directory != "." else s for s in sources]

  env.AppendUnique(CPPPATH=[directory])
  objs = env.Object(source_paths) if source_paths else []
  return AutoCModuleResult(module, directory, header_path, source_paths, objs)


def generate(env):
  env.AddMethod(add_autoc_module, "AutoCModule")
  env.AddMethod(add_autoc_module, "add_autoc_module")


def exists(env):
  return True
"""


if __name__ == "__main__":
  import argparse
  parser = argparse.ArgumentParser(description="Scaffold an AutoC SCons project")
  parser.add_argument("project", help="Project and module name")
  parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: .)")
  args = parser.parse_args()
  generate(args.project, directory=args.directory)
