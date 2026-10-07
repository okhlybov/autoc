import sys
import pathlib


def Meson(module, stamp=None):
  meson = f"{module.name}.meson"
  files = [module.header.file_name] + [s.file_name for s in module.sources]
  contents = "\n".join(files) + "\n"
  try:
    with open(meson, "r") as f:
      if not f.read() == contents:
        raise Exception()
  except Exception:
    with open(meson, "w") as f:
      f.write(contents)
  if stamp:
    pathlib.Path(stamp).touch()
  elif len(sys.argv) > 2 and not sys.argv[2].startswith("-"):
    try:
      pathlib.Path(sys.argv[2]).touch()
    except OSError:
      pass


import os
from autoc.scaffolder import *
import autoc.sample

reader = make_template_reader(__package__)


def _python_paths():
  import autoc
  autoc_dir = pathlib.Path(autoc.__file__).resolve().parent.parent.as_posix()

  paths = [autoc_dir]
  if os.environ.get("PYTHONPATH"):
    for p in os.environ["PYTHONPATH"].split(os.pathsep):
      if p:
        p_str = pathlib.Path(p).resolve().as_posix()
        if p_str not in paths:
          paths.append(p_str)
  return paths


def _site_config():
  lines = ["# Site-local AutoC configuration - DO NOT COMMIT\n"]

  import shutil
  python_cmd = shutil.which("python3") or shutil.which("python")
  cmd_path = pathlib.Path(python_cmd) if python_cmd else None
  sys_path = pathlib.Path(sys.executable)
  is_on_path = bool(
    cmd_path
    and cmd_path.resolve() == sys_path.resolve()
    and cmd_path.parent == sys_path.parent
  )
  if not is_on_path:
    python_exe = sys_path.as_posix()
    lines.append(f'PYTHON = "{python_exe}"\n')

  paths = _python_paths()
  sep = ";" if sys.platform == "win32" else ":"
  pythonpath_str = sep.join(paths)
  lines.append(f'AUTOC_PYTHONPATH = "{pythonpath_str}"\n')

  return "".join(lines)


class Scaffolder(autoc.sample.Scaffolder):

  def __init__(self, resources=None, parameters=None):

    import autoc
    autoc_dir = pathlib.Path(autoc.__file__).resolve().parent.parent.as_posix()

    super().__init__(
      resources={
        ".autoc/meson.site": _site_config(),
        "meson.build": reader,
        "meson.options": reader,
        "@project@.code-workspace": reader,
        ".vscode/launch.json": reader,
        ".gitignore": reader,
      } | (resources or {}),
      parameters=dict(generator="autoc.meson.Meson", autoc_path=autoc_dir) | dict(parameters or {})
    )

  def generate(self, target="."):
    target_path = pathlib.Path(target).resolve()
    import autoc
    autoc_source = pathlib.Path(autoc.__file__).resolve().parent.parent
    try:
      common = os.path.commonpath([str(autoc_source), str(target_path)])
      if common in ("/", "\\", ""):
        self.parameters["autoc_path"] = autoc_source.as_posix()
      else:
        relative = os.path.relpath(autoc_source, target_path)
        posix = pathlib.Path(relative).as_posix()
        self.parameters["autoc_path"] = "${workspaceFolder}" if posix == "." else f"${{workspaceFolder}}/{posix}"
    except ValueError:
      self.parameters["autoc_path"] = autoc_source.as_posix()

    super().generate(target)

