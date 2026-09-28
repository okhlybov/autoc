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
    pathlib.Path(".vscode").mkdir(parents=True, exist_ok=True)
    for file, template in {
      "meson.build": _meson_build,
      "meson.options": _meson_options,
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
import os
import pathlib
import autoc.module
import autoc.meson
import autoc.string

output_stamp = pathlib.Path(sys.argv[2]).resolve() if len(sys.argv) > 2 and not sys.argv[2].startswith("-") else None
os.chdir(pathlib.Path(__file__).resolve().parent)

name = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "@module@"

with autoc.module.Module(name) as m:
  m.add(autoc.string.String("Str"))

autoc.meson.Meson(m, stamp=output_stamp)
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


_meson_options = """option('regenerate',
  type: 'feature',
  value: 'auto',
  description: 'Regenerate AutoC sources using Python (auto: only if missing or Python found)'
)
"""


_meson_build = """project('@project@', 'c',
  version: '0.1.0',
  meson_version: '>= 1.1',
  default_options: ['warning_level=2']
)

fs = import('fs')
py = import('python').find_installation('python3', required: false)

module_name = '@module@'
meson_file = module_name + '.meson'

regen_opt = get_option('regenerate')
has_meson_file = fs.exists(meson_file)

if not has_meson_file
  if not py.found()
    error('AutoC generator requires Python 3, but Python was not found and ' + meson_file + ' is missing.')
  endif
  message('Bootstrapping AutoC module ' + module_name)
  run_command(py, module_name + '.py', module_name, check: true)
endif

autoc_sources = files(fs.read(meson_file).strip().split())

need_generator = regen_opt.enabled() or (regen_opt.auto() and py.found())

if need_generator
  module_gen = custom_target(
    module_name + '-generate',
    input: module_name + '.py',
    output: module_name + '.stamp',
    command: [py, '@INPUT@', module_name, '@OUTPUT@'],
    build_by_default: true,
  )
  autoc_dep = declare_dependency(
    sources: [autoc_sources, module_gen],
    include_directories: include_directories('.')
  )
else
  autoc_dep = declare_dependency(
    sources: autoc_sources,
    include_directories: include_directories('.')
  )
endif

executable('@project@',
  sources: ['@project@.c'],
  dependencies: [autoc_dep]
)
"""


_launch_json = """{
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


_gitignore = """
build/
builddir/
subprojects/
"""


if __name__ == "__main__":
  import argparse
  parser = argparse.ArgumentParser(description="Scaffold an AutoC Meson project")
  parser.add_argument("project", help="Project and module name")
  parser.add_argument("directory", nargs="?", default=".", help="Target directory (default: .)")
  args = parser.parse_args()
  generate(args.project, directory=args.directory)
