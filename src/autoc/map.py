from autoc.core import _type, inout
from autoc.collection import Collection


#
class Map(Collection):
  
  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, *args, **kws)
    self.index = _type(index)
    self.dependencies.add(self.index)

  def __setup__(self):
    super().__setup__()
    self.method("int", "indexed", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable, brief="Check if the map holds the index",
      description="""
        Looks the index up per the map lookup mechanics without modifying the map.
        The cost matches the underlying implementation: expected O(1) for hash-based
        maps, expected O(log n) for tree-based maps.

        @param[in] target the map to check
        @param[in] index the index to look for
        @return non-zero if the map holds an element at the index
      """)
    self.method(None, "set", {"target": inout(self), "index": self.index, "element": self.element}, constraint=lambda: self.index.comparable and self.element.copyable, brief="Set the element at index",
      description="""
        Associates the element with the index - either storing it at the brand new entry
        or replacing the contents of the element already held at the index in place.
        The cost matches the underlying implementation: expected O(1) for hash-based
        maps, expected O(log n) for tree-based maps.

        @param[in,out] target the map to update
        @param[in] index the index to assign the element at
        @param[in] element the element to store - the element previously held at the index is destroyed
      """)
    self.method(self.element, "get", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable and self.element.copyable, brief="Get a copy of the element at index",
      description="""
        Returns an owned copy of the element associated with the index - use `view` when
        the copy is not needed. The cost matches the underlying implementation: expected
        O(1) for hash-based maps, expected O(log n) for tree-based maps.

        @param[in] target the map to read from
        @param[in] index the index to read the element at - must be present in the map
        @return a copy of the element held at the index
      """)
    self.method(self.element.view_type, "view", {"target": self, "index": self.index}, constraint=lambda: self.index.comparable, brief="Get a constant view of the element at index",
      description="""
        Returns a pointer to the element associated with the index without copying it.
        The view is valid while the entry is held by the map - removing it or overwriting
        the element at the index invalidates the view. The cost matches the underlying
        implementation: expected O(1) for hash-based maps, expected O(log n) for tree-based maps.

        @param[in] target the map to read from
        @param[in] index the index to read the element at
        @return a constant view of the element held at the index or a null view if the index is absent
      """)
    
  @property
  def copyable(self):
    return self.element.copyable and self.index.copyable
  
  @property
  def hashable(self):
    return self.element.hashable and self.index.hashable

  @property
  def comparable(self):
    return self.element.comparable and self.index.comparable