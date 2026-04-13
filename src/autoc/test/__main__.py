from autoc.test import *
import pkgutil
import importlib

def import_modules(package):
    for importer, module_name, is_pkg in pkgutil.walk_packages(package.__path__, package.__name__ + "."):
      importlib.import_module(module_name)

if __name__ == "__main__":
  import_modules(autoc.test)
  with autoc.module.Module("test") as m:
    code = []
    code.append("void run_codes() {\n")
    for c in codes:
      m.add(c)
      code.append(f"run_code({c.name});\n")
    code.append("}")
    m.add(autoc.module.Code(definitions="".join(code)))