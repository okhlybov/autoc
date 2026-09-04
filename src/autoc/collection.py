import autoc.std as std
from autoc.hash import Xor
from autoc.core import _type
from autoc.memory import Manager
from autoc.core import Composite


class Range:

  def __init__(self, iterable, *args, **kws):
    super().__init__(iterable.element, iterable._decorate_component("range", abbreviate=not iterable.public), visibility=iterable.visibility, **kws)
    self.iterable = iterable
    iterable.references.add(self)
    self.dependencies.add(iterable)
    
  def __setup__(self):
    super().__setup__()
    with self.copy as f:
      f.inline_code = f"""
        assert(target);
        assert(source);
        *target = *source;
      """


#
class Collection(Composite):
  
  def __init__(self, name, element, *args, memory=Manager(), hasher=Xor(), dependencies=(), **kws):
    super().__init__(name, *args, dependencies=(*dependencies, std.assert_h, memory, hasher), **kws)
    # self.range=
    self.element = _type(element)
    self.memory = memory
    self.hasher = hasher
    self.dependencies.add(self.element)

  def __setup__(self):
    super().__setup__()
    self.method("int", "empty", {"target": self})
    self.method(std.size_t, "size", {"target": self})
    self.method("int", "contains", {"target": self, "element": self.element}, constraint=lambda: self.element.comparable)

  @property
  def copyable(self):
    return self.element.copyable
  
  @property
  def hashable(self):
    return self.element.hashable

  @property
  def comparable(self):
    return self.element.comparable