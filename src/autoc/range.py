import autoc.std as std
from autoc.core import Composite, _type, inout


#
class Range(Composite):
  
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

  brief = "Forward iterator"

  def __setup__(self):
    super().__setup__()
    self.method("int", "empty", {"target": self}, brief="Check if the range is exhausted",
      description="""
        @param[in] target the range to test
        @return non-zero if the range is exhausted
      """)
    self.method(self.element, "front", {"target": self}, constraint=lambda: self.element.copyable, brief="Get a copy of the front element",
      description="""
        @param[in] target the range to read - must not be exhausted
        @return a copy of the element at the front position
      """)
    self.method(self.element.view_type, ("front", "view"), {"target": self}, brief="Get a constant view of the front element",
      description="""
        @param[in] target the range to read - must not be exhausted
        @return a constant view of the element at the front position, valid until the range is advanced
      """)
    self.method(None, ("move", "front"), {"target": inout(self)}, brief="Advance the range to the next element",
      description="""
        @param[in,out] target the range to advance - must not be exhausted
      """)


#
class Forward(Input):

  brief = "Forward copyable iterator"

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    
  def __setup__(self):
    super().__setup__()

    self.description = f"""
      This iterator allows to traverse the iterable container (@ref {self.iterable}) in forward direction.
    """
    

  @property
  def copyable(self):
    return True


#
class Backward(Input):

  brief = "Backward copyable iterator"

  @property
  def copyable(self):
    return True

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      This iterator allows to traverse the iterable container (@ref {self.iterable}) in backward direction.
    """

    self.method(self.element, "back", {"target": self}, constraint=lambda: self.element.copyable, brief="Get a copy of the back element",
      description="""
        @param[in] target the range to read - must not be exhausted
        @return a copy of the element at the back position
      """)
    self.method(self.element.view_type, ("back", "view"), {"target": self}, brief="Get a constant view of the back element",
      description="""
        @param[in] target the range to read - must not be exhausted
        @return a constant view of the element at the back position, valid until the range is retreated
      """)
    self.method(None, ("move", "back"), {"target": inout(self)}, brief="Retreat the range to the previous element",
      description="""
        @param[in,out] target the range to retreat - must not be exhausted
      """)


#
class Bidirectional(Forward, Backward):
  
  brief = "Bidirectional (forward/backward) copyable iterator"
  
  def __setup__(self):
    super().__setup__()
    
    self.description = f"""
      This iterator allows to traverse the iterable container (@ref {self.iterable}) in both (forward and backward) directions.
    """


#
class DirectAccess(Forward, Backward):

  brief = "Bidirectional (forward/backward) copyable iterator with direct access"

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      This iterator allows to traverse the iterable container (@ref {self.iterable}) in both (forward and backward) directions.
      In addition, it provides a direct (indexed) access to the range of currently accessible range's elements.
    """

    self.method(self.element, "get", {"target": self, "index": std.size_t}, constraint=lambda: self.element.copyable, brief="Get a copy of the element at offset",
      description="""
        @param[in] target the range to read
        @param[in] index the offset from the current position
        @return a copy of the element at the offset
      """)
    self.method(self.element.view_type, "view", {"target": self,  "index": std.size_t}, brief="Get a constant view of the element at offset",
      description="""
        @param[in] target the range to read
        @param[in] index the offset from the current position
        @return a constant view of the element at the offset, valid until the range is advanced
      """)
    self.method(std.size_t, "size", {"target": self}, brief="Get the number of remaining elements",
      description="""
        @param[in] target the range to measure
        @return the number of elements left between the current position and the back one
      """)
