import os
import sys
import pathlib
import autoc.project
import autoc.test
import autoc.module
import autoc.cmake


def generate(directory=".", project="test"):
  target_path = pathlib.Path(directory).resolve()
  target_path.mkdir(parents=True, exist_ok=True)

  # 1. Leverage existing autoc.project scaffolder
  autoc.project.generate(project, directory=target_path)

  orig_cwd = os.getcwd()
  try:
    os.chdir(target_path)

    # 2. Delete {project}.c since test_auto.c provides main()
    c_file = pathlib.Path(f"{project}.c")
    if c_file.exists():
      c_file.unlink()

    # 3. Modify CMakeLists.txt to remove {project}.c from add_executable
    cmake_lists = pathlib.Path("CMakeLists.txt")
    if cmake_lists.exists():
      content = cmake_lists.read_text(encoding="utf-8")
      content = content.replace(f"${{PROJECT_NAME}}.c", "").replace(f"{project}.c", "")
      cmake_lists.write_text(content, encoding="utf-8")

    # 4. Write test-specific {project}.py
    items = dict(project=project, module=project)
    with open(f"{project}.py", "w", encoding="utf-8") as f:
      f.write(autoc.project.interpolate(_project_py, **items))

    # 5. Write .gitignore
    with open(".gitignore", "w", encoding="utf-8") as f:
      f.write(autoc.project.interpolate(_gitignore, **items))

    # 6. Configure VS Code workspace
    code_workspace = pathlib.Path(f"{project}.code-workspace")
    autoc_workspace = pathlib.Path(f"autoc-{project}.code-workspace")
    if code_workspace.exists():
      code_workspace.unlink()
    with open(autoc_workspace, "w", encoding="utf-8") as f:
      f.write(autoc.project.interpolate(_code_workspace, **items))

    # 7. Bootstrap the test module
    with autoc.module.Module(project) as m:
      autoc.test.configure_module(m)
    autoc.cmake.CMake(m)

  finally:
    os.chdir(orig_cwd)


_project_py = """import sys
import pathlib

src_path = pathlib.Path(__file__).resolve().parent / "../src"
if src_path.is_dir():
  sys.path.insert(0, str(src_path.resolve()))

import autoc.test
import autoc.cmake
import autoc.module

name = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "@module@"

with autoc.module.Module(name) as m:
  autoc.test.configure_module(m)

autoc.cmake.CMake(m)
"""


_gitignore = """build
@module@.cmake
@module@.state
@module@_auto*
*_auto.*
"""


_code_workspace = """{
  "folders": [
    {
      "path": ".",
      "name": "@project@"
    }
  ],
  "settings": {
    "cmake.sourceDirectory": "${workspaceFolder}"
  }
}"""


if __name__ == "__main__":
  generate(sys.argv[1] if len(sys.argv) > 1 else ".")