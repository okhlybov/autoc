import autoc.std as std
from autoc.core import _type, inout
from autoc.container import Container


# Base abstract class for collections whose elements can be indexed by a key or offset
class Indexed(Container):
  
  def __init__(self, name, element, index, *args, **kws):
    self.index = _type(index)
    super().__init__(name, element, *args, **kws)
    self.dependencies.add(self.index)

  def __setup__(self):
    super().__setup__()
    
    valid_index = lambda: self.index.comparable or self.index.orderable
    
    self.method("int", "indexed", {"target": self, "index": self.index}, constraint=valid_index, brief="Check if the collection holds the index",
      description="""
        Looks the index up per the collection lookup mechanics without modifying the collection.
        The cost matches the underlying implementation: expected O(1) for hash-based and direct-indexed
        containers, expected O(log n) for tree-based containers.

        @param[in] target the collection to check
        @param[in] index the index to look for
        @return non-zero if the collection holds an element at the index
      """)
    
    self.method(None, "set", {"target": inout(self), "index": self.index, "element": self.element}, constraint=lambda: valid_index() and self.element.copyable, brief="Set the element at index",
      description="""
        Associates the element with the index - either storing it at the brand new entry
        or replacing the contents of the element already held at the index in place.
        The cost matches the underlying implementation: expected O(1) for hash-based and direct-indexed
        containers, expected O(log n) for tree-based containers.

        @param[in,out] target the collection to update
        @param[in] index the index to assign the element at
        @param[in] element the element to store - the element previously held at the index is destroyed
      """)
    
    self.method(self.element, "get", {"target": self, "index": self.index}, constraint=lambda: valid_index() and self.element.copyable, brief="Get a copy of the element at index",
      description="""
        Returns an owned copy of the element associated with the index - use `view` when
        the copy is not needed. The cost matches the underlying implementation: expected
        O(1) for hash-based and direct-indexed containers, expected O(log n) for tree-based containers.

        @param[in] target the collection to read from
        @param[in] index the index to read the element at - must be present in the collection
        @return a copy of the element held at the index
      """)
    
    self.method(self.element.view_type, "view", {"target": self, "index": self.index}, constraint=valid_index, brief="Get a constant view of the element at index",
      description="""
        Returns a pointer to the element associated with the index without copying it.
        The view is valid while the entry is held by the collection - removing it or overwriting
        the element at the index invalidates the view. The cost matches the underlying
        implementation: expected O(1) for hash-based and direct-indexed containers, expected O(log n) for tree-based containers.

        @param[in] target the collection to read from
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
