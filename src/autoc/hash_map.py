from autoc.core import inout, Macro, Pointer
import autoc.std as std
import autoc.record


# Common entry implementation for hash maps backed by the hash-based sets
class _Entry(autoc.record.Record):
  
  def __init__(self, name, element, index, *args, visibility, **kws):
    super().__init__(name, {"element": element, "index": index}, *args, visibility=visibility, **kws)
    self.element = self.fields["element"]
    self.element_p = Pointer(self.element, constant=True)
    self.index = self.fields["index"]
    
  def __setup__(self):
    super().__setup__()
    
    _index = self.index.variable("target->index")
    _element = self.element.variable("target->element")
    
    with self.method(self.element_p, ("element", "view"), {"target": self}, hidden=True, visibility="INTERNAL") as f:
      f.external = f"""
        assert(target);
        return &target->element;
      """
    
    with self.method(None, ("emplace", "index"), {"target": inout(self), "index": self.index}, hidden=True, visibility="INTERNAL") as f:
      f.external = f"""
        assert(target);
        {self.index.copy(_index, f.index)};
      """

    with self.method(None, ("destroy", "index"), {"target": inout(self)}, hidden=True, visibility="INTERNAL") as f:
      if self.index.destructible:
        f.external = f"""
          assert(target);
          {self.index.destroy(_index)};
        """
      else:
        f.external = f"""
          assert(target);
        """
      
    with self.method(None, ("emplace", "element"), {"target": inout(self), "element": self.element}, hidden=True, visibility="INTERNAL") as f:
      f.external = f"""
        assert(target);
        {self.element.copy(_element, f.element)};
      """

    with self.method(None, ("destroy", "element"), {"target": inout(self)}, hidden=True, visibility="INTERNAL") as f:
      if self.element.destructible:
        f.external = f"""
          assert(target);
          {self.element.destroy(_element)};
        """
      else:
        f.external = f"""
          assert(target);
        """

    with self.method(None, ("replace", "element"), {"target": inout(self), "element": self.element}, hidden=True, visibility="INTERNAL") as f:
      f.external = f"""
        assert(target);
        {self.destroy_element(f.target)};
        {self.element.copy(_element, f.element)};
      """

    self._lookup_hash = Macro(std.size_t, {"target": self}, lambda target: str(self.index.hash(f"({target})->index")))
    self._lookup_equal = Macro("int", {"left": self, "right": self}, lambda left, right: str(self.index.equal(f"({left})->index", f"({right})->index")))
  
  @property
  def constructible(self):
    return False