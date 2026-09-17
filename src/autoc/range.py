import autoc.std as std
from autoc.core import Composite, _type, inout


#
class Range(Composite):
  
  brief = "Base type for iterators"
  
  def __init__(self, element, *args, **kws):
    super().__init__(*args, **kws)
    self.element = _type(element)

  @property
  def swappable(self):
    return False # ranges are non-owning cursors - swapping is indistinguishable from copying

  def __setup__(self):
    super().__setup__()
    self.create = None
    self.destroy = None
    self.swap = None
    self.equal = None
    self.compare = None
    self.hash = None


#
class Input(Range):

  def __setup__(self):
    super().__setup__()
    self.method("int", "empty", {"target": self}, brief="Check if the range is exhausted")
    self.method(self.element, "front", {"target": self}, constraint=lambda: self.element.copyable, brief="Get a copy of the front element")
    self.method(self.element.view_type, ("front", "view"), {"target": self}, brief="Get a constant view of the front element")
    self.method(None, ("move", "front"), {"target": inout(self)}, brief="Advance the range to the next element")


#
class Forward(Input):

  @property
  def copyable(self):
    return True


#
class Backward(Input):

  @property
  def copyable(self):
    return True

  def __setup__(self):
    super().__setup__()
    self.method(self.element, "back", {"target": self}, constraint=lambda: self.element.copyable, brief="Get a copy of the back element")
    self.method(self.element.view_type, ("back", "view"), {"target": self}, brief="Get a constant view of the back element")
    self.method(None, ("move", "back"), {"target": inout(self)}, brief="Retreat the range to the previous element")


#
class Bidirectional(Forward, Backward):
  pass


#
class DirectAccess(Forward, Backward):

  def __setup__(self):
    super().__setup__()
    self.method(self.element, "get", {"target": self, "index": std.size_t}, constraint=lambda: self.element.copyable, brief="Get a copy of the element at offset")
    self.method(self.element.view_type, "view", {"target": self,  "index": std.size_t}, brief="Get a constant view of the element at offset")
    self.method(std.size_t, "size", {"target": self}, brief="Get the number of remaining elements")
