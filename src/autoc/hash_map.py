from autoc.core import out, inout, Macro
import autoc.std as std
import autoc.record


# Common entry implementation for hash maps backed by the hash-based sets
class _Entry(autoc.record.Record):
  
  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, {"element": element, "index": index}, *args, visibility="PRIVATE", **kws)
    self.element = self.fields["element"]
    self.index = self.fields["index"]
    
  def __setup__(self):
    super().__setup__()
    
    self.create_index = self.method(None, ("create", "index"), {"target": out(self), "index": self.index}, hidden=True, linkage="INLINE")
    self.create_index.code = f"""
      assert(target);
      {self.index.copy(self.variable("target->index"), self.create_index.index)};
    """
    
    self.create = self.method(None, "create", {"target": out(self), "element": self.element, "index": self.index}, hidden=True, linkage="INLINE")
    self.create.code = f"""
      assert(target);
      {self.index.copy(self.variable("target->element"), self.create.element)};
      {self.index.copy(self.variable("target->index"), self.create.index)};
    """

    self._lookup_hash = Macro(std.size_t, {"target": self}, lambda target: str(self.index.hash(f"({target})->index")))
    self._lookup_equal = Macro("int", {"left": self, "right": self}, lambda left, right: str(self.index.equal(f"({left})->index", f"({right})->index")))
  
  @property
  def constructible(self):
    return False