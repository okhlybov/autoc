from autoc.core import out, inout
import autoc.composite


class Set(autoc.composite.Collection):
  
  def __setup__(self):
    super().__setup__()
    
    self.put = self.method("int", "put", {"target": inout(self)})