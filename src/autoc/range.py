import autoc.std as std
from autoc.core import _type, inout, Pointer, Traitless
from autoc.composite import Composite


#
class Range(Composite, Traitless):
  
  def __init__(self, element, *args, **kws):
    super().__init__(*args, **kws)
    self.element = _type(element)
    self.element_view = Pointer(self.element, constant=True)
  

#
class Input(Range):

  def __setup__(self):
    super().__setup__()
    self.method("int", "empty", {"target": self})
    self.method(self.element, "front", {"target": self})
    self.method(self.element_view, ("front", "view"), {"target": self})
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
    self.method(self.element, "back", {"target": self})
    self.method(self.element_view, ("back", "view"), {"target": self})
    self.method(None, ("move", "back"), {"target": inout(self)})


#
class DirectAccess(Forward, Backward):

  def __setup__(self):
    super().__setup__()
    self.method(self.element, "get", {"target": self, "index": std.size_t})
    self.method(self.element_view, "view", {"target": self,  "index": std.size_t})
    self.method(std.size_t, "size", {"target": self})
