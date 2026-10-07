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
import pathlib
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
    lines.append(f'set(Python_EXECUTABLE "{python_exe}" CACHE FILEPATH "Python interpreter for AutoC" FORCE)\n')

  paths = _python_paths()
  sep = ";" if sys.platform == "win32" else ":"
  pythonpath_str = sep.join(paths)
  lines.append(f'set(AUTOC_PYTHONPATH "{pythonpath_str}" CACHE STRING "Python path for AutoC generator")\n')

  return "".join(lines)


class Scaffolder(autoc.sample.Scaffolder):

  def __init__(self, resources=None, parameters=None):

    import autoc
    autoc_dir = pathlib.Path(autoc.__file__).resolve().parent.parent.as_posix()

    super().__init__(
      resources={
        ".autoc/cmake.site": _site_config(),
        "cmake/AutoC.cmake": reader,
        "CMakeLists.txt": reader,
        "CMakePresets.json": reader,
        "@project@.code-workspace": reader,
        ".vscode/launch.json": reader,
        ".gitignore": reader,
      } | (resources or {}),
      parameters=dict(generator="autoc.cmake.CMake", autoc_path=autoc_dir) | dict(parameters or {})
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


