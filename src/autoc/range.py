import autoc.core
import autoc.composite
import autoc.std as std
from autoc.core import inout, Pointer


#
class Range(autoc.composite.Composite, autoc.core._NoTraits):
  
  def __init__(self, element, *args, **kws):
    super().__init__(*args, **kws)
    self.element = autoc.core._type(element)
    self.element_view = Pointer(self.element, constant=True)
  

#
class Input(Range):

  def __setup__(self):
    super().__setup__()
    self.empty = self.method("int", "empty", {"target": self})
    self.front = self.method(self.element, "front", {"target": self})
    self.view_front = self.method(self.element_view, ("view", "front"), {"target": self})
    self.pop_front = self.method(None, ("pop", "front"), {"target": inout(self)})


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
    self.back = self.method(self.element, "back", {"target": self})
    self.view_back = self.method(self.element_view, ("view", "back"), {"target": self})
    self.pop_back = self.method(None, ("pop", "back"), {"target": inout(self)})


#
class DirectAccess(Forward, Backward):

  def __setup__(self):
    super().__setup__()
    self.get = self.method(self.element, "get", {"target": self, "index": std.size_t})
    self.view = self.method(self.element_view, "view", {"target": self,  "index": std.size_t})
    self.size = self.method(std.size_t, "size", {"target": self})
