import autoc.module


#
class CMake:
  
  module = None

  def __init__(self, module=None):
    if module is not None:
      self._generate(module)

  def _generate(self, module):
    cmake = f"{module.name}.cmake"
    sorted_sources = sorted(module.sources, key=lambda s: s.index)
    sources = " ".join([f"${{CMAKE_CURRENT_SOURCE_DIR}}/{s.file_name}" for s in sorted_sources])
    # A documentation-only module (source_count = 0) emits no translation units and
    # therefore declares no library - only the header the documentation is built from
    library = f"""
      add_library({module.name}-autoc OBJECT ${{{module.name}_SOURCES}})
      target_include_directories({module.name}-autoc INTERFACE $<BUILD_INTERFACE:${{CMAKE_CURRENT_SOURCE_DIR}}>)
    """ if sources else str()
    contents = f"""
      set({module.name}_HEADER ${{CMAKE_CURRENT_SOURCE_DIR}}/{module.header.file_name})
      set({module.name}_SOURCES {sources})
      set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        ${{{module.name}_HEADER}}
        ${{{module.name}_SOURCES}}
      ){library}
    """
    try:
      with open(cmake, "r") as f:
        if not f.read() == contents:
          raise Exception()
    except:
      with open(cmake, "w") as f:
        f.write(contents)

  def __enter__(self):
    self.__context = autoc.module._build_context
    autoc.module._build_context = self
    return self
  
  def __exit__(self, exc_type, exc_value, traceback):
    if self.module:
      self._generate(self.module)
    autoc.module._build_context = self.__context
    return False


### On code generation vs. CMake

# https://here-be-braces.com/integrating-a-flexible-code-generator-into-cmake/
# https://blog.kangz.net/posts/2016/05/26/integrating-a-code-generator-with-cmake/


### On code packaging

# https://www.youtube.com/watch?v=sBP17HQAQjk
# https://www.youtube.com/watch?v=_5weX5mx8hc

# https://alexreinking.com/blog/how-to-use-cmake-without-the-agonizing-pain-part-1.html
# https://alexreinking.com/blog/how-to-use-cmake-without-the-agonizing-pain-part-2.html


import os
import sys
import site
import shutil
import pathlib
from autoc.scaffolder import *


reader = make_template_reader(__package__)


def _detect_site():
  lines = []

  # Python interpreter: only record if non-default (e.g. virtual environment or not on default PATH)
  is_venv = (
    sys.prefix != getattr(sys, "base_prefix", sys.prefix)
    or hasattr(sys, "real_prefix")
  )
  default_python = shutil.which("python3") or shutil.which("python")
  is_default_python = (
    not is_venv
    and default_python is not None
    and pathlib.Path(default_python).resolve() == pathlib.Path(sys.executable).resolve()
  )
  if not is_default_python:
    python_exe = pathlib.Path(sys.executable).as_posix()
    lines.append(f'set(Python_EXECUTABLE "{python_exe}" CACHE FILEPATH "Python interpreter for AutoC" FORCE)\n')

  # Python path: only record if custom AutoC checkout or non-standard paths
  standard_paths = set()
  try:
    if hasattr(site, "getsitepackages"):
      for sp in site.getsitepackages():
        standard_paths.add(pathlib.Path(sp).resolve())
    user_sp = site.getusersitepackages() if hasattr(site, "getusersitepackages") else None
    if user_sp:
      standard_paths.add(pathlib.Path(user_sp).resolve())
  except Exception:
    pass

  import autoc
  autoc_dir = pathlib.Path(autoc.__file__).resolve().parent.parent
  is_custom_autoc = not any(autoc_dir == sp or sp in autoc_dir.parents for sp in standard_paths)

  resolved_paths = []
  if is_custom_autoc:
    resolved_paths.append(autoc_dir.resolve())

  env_pythonpath = os.environ.get("PYTHONPATH", "")
  if env_pythonpath:
    for p in env_pythonpath.split(os.pathsep):
      p_path = pathlib.Path(p).resolve() if p else None
      if p_path and p_path not in resolved_paths:
        resolved_paths.append(p_path)

  extra_paths = [p.as_posix() for p in resolved_paths]
  if extra_paths:
    pythonpath_str = ";".join(extra_paths) if sys.platform == "win32" else ":".join(extra_paths)
    lines.append(f'set(AUTOC_PYTHONPATH "{pythonpath_str}" CACHE STRING "Python path for AutoC generator")\n')

  if not lines:
    return None

  return "# Site-local AutoC configuration - DO NOT COMMIT\n" + "".join(lines)


class Scaffolder(Scaffolder):

  def __init__(self, resources=None, parameters=None):

    site = _detect_site()
    site_resources = {"@module@.cmake.site": site} if site is not None else {}

    super().__init__(
      resources={
        "cmake/AutoC.cmake": reader,
        "CMakeLists.txt": reader,
        "CMakePresets.json": reader,
        "@project@.code-workspace": reader,
        ".vscode/launch.json": reader,
        ".gitignore": reader,
      } | site_resources | (resources or {}),
      parameters=dict(parameters or {})
    )

