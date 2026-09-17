from autoc.core import _type, inout
from autoc.collection import Collection


#
class Map(Collection):
  
  brief = "Abstract base type for the index to element mappings"

  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.index}, {self.element}>"
  
  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, *args, **kws)
    self.index = _type(index)
    self.dependencies.add(self.index)

  def __setup__(self):
    super().__setup__()
    self.method("int", "indexed", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable, brief="Check if index exists")
    self.method(None, "set", {"target": inout(self), "index": self.index, "element": self.element}, constraint=lambda: self.index.comparable and self.element.copyable, brief="Set element at index")
    self.method(self.element, "get", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable and self.element.copyable, brief="Get element at index")
    self.method(self.element.view_type, "view", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable, brief="Get view of element at index")
    
  @property
  def copyable(self):
    return self.element.copyable and self.index.copyable
  
  @property
  def hashable(self):
    return self.element.hashable and self.index.hashable

  @property
  def comparable(self):
    return self.element.comparable and self.index.comparable