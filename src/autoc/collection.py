import autoc.memory
import autoc.hash
import autoc.std as std
from autoc.core import Pointer
from autoc.composite import Composite


class _Range:

  def __init__(self, iterable, *args, **kws):
    super().__init__(iterable.element, iterable._decorate_component("range", abbreviate=not(iterable.public)), visibility=iterable.visibility, **kws)
    self.iterable = iterable
    self.depends(iterable)
    iterable.references.add(self)
    
  def __setup__(self):
    super().__setup__()
    with self.copy as f:
      f.code = f"""
        assert(target);
        assert(source);
        *target = *source;
      """


#
class Collection(Composite):
  
  def __init__(self, name, element, memory=autoc.memory.Manager(), hasher=autoc.hash.Xor(), dependencies=[], *args, **kws):
    super().__init__(name, dependencies=[*dependencies, std.assert_h, memory, hasher], *args, **kws)
    self.element = autoc.core._type(element)
    self.element_view = Pointer(self.element, constant=True)
    self.depends(self.element)
    self.memory = memory
    self.hasher = hasher

  def __setup__(self):
    super().__setup__()
    self.method("int", "empty", {"target": self})
    self.method(std.size_t, "size", {"target": self})
    self.method("int", "contains", {"target": self, "element": self.element})

  @property
  def constructible(self):
    return True
  
  @property
  def destructible(self):
    return True

  @property
  def copyable(self):
    return self.element.copyable
  
  @property
  def hashable(self):
    return self.element.hashable

  @property
  def comparable(self):
    return self.element.comparable
  
  @property
  def orderable(self):
    return False