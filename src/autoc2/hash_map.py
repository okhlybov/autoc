import autoc2.std as std
from autoc2.record import Record
from autoc2.core import inout, Macro, Indirection


# Common entry implementation for hash maps backed by the hash-based sets
class _Entry(Record):
  
  def __init__(self, name, element, index, *args, visibility, **kws):
    super().__init__(name, {"element": element, "index": index}, *args, visibility=visibility, **kws)
    self.index = self.fields["index"]
    self.element = self.fields["element"]
    self.element_p = Indirection(self.element, constant=True)
    
  def __setup__(self):
    super().__setup__()
    
    _index = self.index.variable("target->index")
    _element = self.element.variable("target->element")
    
    with self.method(self.element_p, ("element", "view"), {"target": self}, hidden=True, visibility="internal") as f:
      f.code = f"""
        assert(target);
        return &target->element;
      """
    
    with self.method(None, ("emplace", "index"), {"target": inout(self), "index": self.index}, hidden=True, visibility="internal", constraint=lambda: self.index.copyable) as f:
      f.code = f"""
        assert(target);
        {self.index.copy(_index, f.index)};
      """

    with self.method(None, ("destroy", "index"), {"target": inout(self)}, hidden=True, visibility="internal") as f:
      if self.index.destructible:
        f.code = f"""
          assert(target);
          {self.index.destroy(_index)};
        """
      else:
        f.code = f"""
          assert(target);
        """
      
    with self.method(None, ("emplace", "element"), {"target": inout(self), "element": self.element}, hidden=True, visibility="internal", constraint=lambda: self.element.copyable) as f:
      f.code = f"""
        assert(target);
        {self.element.copy(_element, f.element)};
      """

    with self.method(None, ("destroy", "element"), {"target": inout(self)}, hidden=True, visibility="internal") as f:
      if self.element.destructible:
        f.code = f"""
          assert(target);
          {self.element.destroy(_element)};
        """
      else:
        f.code = f"""
          assert(target);
        """

    with self.method(None, ("replace", "element"), {"target": inout(self), "element": self.element}, hidden=True, visibility="internal", constraint=lambda: self.element.copyable and self.element.comparable) as f:
      f.code = f"""
        assert(target);
        {self.destroy_element(f.target)};
        {self.element.copy(_element, f.element)};
      """

    self.hash_lookup_hash = Macro(std.size_t, {"target": self}, lambda target: str(self.index.hash( self.variable(f"(({target}).index)") )))
    self.hash_lookup_equal = Macro("int", {"left": self, "right": self}, lambda left, right: str(self.index.equal( self.variable(f"(({left}).index)"), self.variable(f"(({right}).index)") )))
  
  @property
  def constructible(self):
    return False