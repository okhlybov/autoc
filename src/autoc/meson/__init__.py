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
