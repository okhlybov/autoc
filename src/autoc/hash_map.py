import autoc.std as std
from autoc.record import Record
from autoc.core import inout, Macro, Callable


# Common entry implementation for hash maps backed by the hash-based sets
class _Entry(Record):
  
  def __init__(self, name, element, index, visibility, *args, **kws):
    super().__init__(name, {"element": element, "index": index}, *args, visibility=visibility, **kws)
    self.index = self.fields["index"]
    self.element = self.fields["element"]
    self.element_p = self.element.view_type
    self.index_p = self.index.view_type

  def __setup__(self):
    super().__setup__()

    _index = self.index.variable("target->index")
    _element = self.element.variable("target->element")

    with self.method(Callable.Parameter(self.element_p), ("element", "view"), {"target": self}, hidden=True, visibility="internal") as f:
      f.code = f"""
        assert(target);
        return {self.element.variable("target->element").bind(f.result)};
      """

    with self.method(Callable.Parameter(self.index_p), ("index", "view"), {"target": self}, hidden=True, visibility="internal") as f:
      f.code = f"""
        assert(target);
        return {self.index.variable("target->index").bind(f.result)};
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

    self.hash_lookup_hash = Macro(std.size_t, {"target": self}, lambda target: str(self.index.hash( self.index.variable(f"(({target}).index)") )))
    self.hash_lookup_equal = Macro("int", {"left": self, "right": self}, lambda left, right: str(self.index.equal( self.index.variable(f"(({left}).index)"), self.index.variable(f"(({right}).index)") )))
  
  @property
  def constructible(self):
    return False