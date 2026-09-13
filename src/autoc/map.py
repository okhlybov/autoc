from autoc.core import _type, inout
from autoc.collection import Collection


#
class Map(Collection):
  
  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, *args, **kws)
    self.index = _type(index)
    self.dependencies.add(self.index)

  def __setup__(self):
    super().__setup__()
    self.method("int", "indexed", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable, brief="Checks whether an element is held at the index.")
    self.method(None, "set", {"target": inout(self), "index": self.index, "element": self.element}, constraint=lambda: self.index.comparable and self.element.copyable, brief="Sets the element at the index replacing the existing one, if any.")
    self.method(self.element, "get", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable and self.element.copyable, brief="Returns the element at the index, aborting when absent.")
    self.method(self.element.view_type, "view", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable, brief="Returns the constant view of the element at the index, or NULL when absent.")
    
  @property
  def copyable(self):
    return self.element.copyable and self.index.copyable
  
  @property
  def hashable(self):
    return self.element.hashable and self.index.hashable

  @property
  def comparable(self):
    return self.element.comparable and self.index.comparable