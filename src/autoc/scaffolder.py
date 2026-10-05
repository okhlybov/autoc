import os
import pathlib
import inspect
import importlib.resources


#
def template_reader(resource, directory="template"):
  # Read resource from location relative to this function's caller
  caller = inspect.currentframe().f_back
  try:
      package = caller.f_globals["__package__"]
      return importlib.resources.files(package).joinpath(directory, resource).read_text(encoding="utf-8")
  finally:
      del caller


#
class Scaffolder:
  
  def __init__(self, resources={}, parameters={}):
    self.resources = resources
    self.parameters = parameters
    
  def generate(self, target="."):
    path = pathlib.Path(target).resolve()
    path.mkdir(parents=True, exist_ok=True)
    wd = os.getcwd()
    try:
      os.chdir(path)
      for file, reader in self.resources.items():
        f = self.interpolate(file, self.parameters)
        pathlib.Path(f).parent.mkdir(parents=True, exist_ok=True)
        with open(f, "w") as f:
          f.write(self.interpolate(reader(file), self.parameters))
    finally:
      os.chdir(wd)
      
  def interpolate(self, template, parameters={}):
    x = template
    for placeholder, value in (self.parameters | parameters).items():
      x = x.replace(f"@{placeholder}@", value, -1)
    return x