from autoc2.core import _type, inout
from autoc2.collection import Collection


#
class Map(Collection):
  
  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, *args, **kws)
    self.index = _type(index)
    self.depends(self.index)

  def __setup__(self):
    super().__setup__()
    self.method("int", "indexed", {"target": self, "index": self.index})
    self.method(None, "set", {"target": inout(self), "index": self.index, "element": self.element})
    self.method(self.element, "get", {"target": self, "index": self.index})
    self.method(self.element_view, "view", {"target": self, "index": self.index})
    
  @property
  def copyable(self):
    return self.element.copyable and self.index.copyable
  
  @property
  def hashable(self):
    return self.element.hashable and self.index.hashable

  @property
  def comparable(self):
    return self.element.comparable and self.index.comparable