from autoc.avl_set import Set as AVLSet
from autoc.tree_map import Map as TreeMap


#
class Map(TreeMap):

  brief = "Ordered map from index to element implemented as an AVL tree - iterates in index order"

  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, index, AVLSet, *args, **kws)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the index type (@ref {self.index}) to be *Orderable* and the element type (@ref {self.element}) to be *Copyable*.
      Supports one way traversal over the indices and elements via the corresponding @ref {self.range} iterator - the entries are yielded in index order.

      Implemented as an AVL tree over the internal entry set.
      The closest C++ equivalent is [std::map<>](https://cppreference.com/cpp/container/map).
    """
