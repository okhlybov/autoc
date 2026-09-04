import autoc.std as std
from autoc.core import Composite, _type, inout


#
class Range(Composite):
  
  def __init__(self, element, *args, **kws):
    super().__init__(*args, **kws)
    self.element = _type(element)

  def __setup__(self):
    super().__setup__()
    self.create = None
    self.destroy = None
    self.equal = None
    self.compare = None
    self.hash = None


#
class Input(Range):

  def __setup__(self):
    super().__setup__()
    self.method("int", "empty", {"target": self})
    self.method(self.element, "front", {"target": self}, constraint=lambda: self.element.copyable)
    self.method(self.element.view_type, ("front", "view"), {"target": self})
    self.method(None, ("move", "front"), {"target": inout(self)})


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
    self.method(self.element, "back", {"target": self}, constraint=lambda: self.element.copyable)
    self.method(self.element.view_type, ("back", "view"), {"target": self})
    self.method(None, ("move", "back"), {"target": inout(self)})


#
class DirectAccess(Forward, Backward):

  def __setup__(self):
    super().__setup__()
    self.method(self.element, "get", {"target": self, "index": std.size_t}, constraint=lambda: self.element.copyable)
    self.method(self.element.view_type, "view", {"target": self,  "index": std.size_t})
    self.method(std.size_t, "size", {"target": self})
