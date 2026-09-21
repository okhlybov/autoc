import autoc.std as std
from autoc.hash import Xor
from autoc.range import Range
from autoc.memory import Manager
from autoc.core import Composite, _StructRenderer, _type


#
class _Range(_StructRenderer, Range):

  def __init__(self, iterable, *args, **kws):
    super().__init__(iterable.element, iterable._decorate_component("range", abbreviate=not iterable.public), visibility=iterable.visibility, **kws)
    self.iterable = iterable
    iterable.references.add(self)
    self.dependencies.add(iterable)

  # A range is a non-owning cursor whose display name is its own identifier and
  # which belongs to the group of the container it spans
  def _render_description(self, stream):
    super()._render_description(stream)
    stream.append(f"\n@ingroup {self.iterable.name}\n")
    
  def __setup__(self):
    super().__setup__()
    
    self.description1 = f"""
      The opaque value representing @ref {self} value.
    """
    
    with self.copy as f:
      f.inline_code = f"""
        assert(target);
        assert(source);
        *target = *source;
      """

    with self.move as f:
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
    self.method("int", "empty", {"target": self}, brief="Check if the container holds no elements",
      description="""
        @param[in] target the container to check
        @return non-zero if the container holds no elements
      """)
    self.method(std.size_t, "size", {"target": self}, brief="Get the number of elements in the container",
      description="""
        @param[in] target the container to measure
        @return the number of elements held by the container
      """)
    self.method("int", "contains", {"target": self, "element": self.element}, constraint=lambda: self.element.comparable, brief="Check if the container holds the element",
      description="""
        @param[in] target the container to search
        @param[in] element the element to look for
        @return non-zero if the container holds an element equal to the given one
      """)

  @property
  def copyable(self):
    return self.element.copyable

  @property
  def hashable(self):
    return self.element.hashable

  @property
  def comparable(self):
    return self.element.comparable