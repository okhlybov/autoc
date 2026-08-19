import autoc2.std as std
from autoc2.hash import Xor
from autoc2.memory import Manager
from autoc2.composite import Composite
from autoc2.core import Indirection, _type


class _Range:

  def __init__(self, iterable, *args, **kws):
    super().__init__(iterable.element, iterable._decorate_component("range", abbreviate=not iterable.public), visibility=iterable.visibility, **kws)
    self.iterable = iterable
    self.depends(iterable)
    iterable.references.add(self)
    
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
  
  def __init__(self, name, element, memory=Manager(), hasher=Xor(), dependencies=tuple(), *args, **kws):
    super().__init__(name, dependencies=(*dependencies, std.assert_h, memory, hasher), *args, **kws)
    # self.range=
    self.element = _type(element)
    self.element_view = Indirection(self.element, constant=True)
    self.depends(self.element)
    self.memory = memory
    self.hasher = hasher

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