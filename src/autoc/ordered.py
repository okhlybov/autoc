from autoc.traversable import Traversable


# Property mixin for containers whose iteration order is born sorted - the ascending
# element (or index) order is an invariant of the structure itself, not a user-maintained
# state (that is Sortable's regime), so backward traversal is available unconditionally.
# Claimed by the tree and flat sets, and by the map families keyed over them. Unordered
# containers (the hash-based families) do not claim it; their iteration order is layout-
# incidental. Unlike the ability mixins (the -able family) a property is also the shape
# of a requirement: a composite keyed over such a component demands the property of it
# and validates the demand at its own construction time via require().
class Ordered(Traversable):

  brief = "Abstract ordered container - iterates in ascending element or index order"

  @classmethod
  def require(cls, component, context):
    # The requirement application of the property: a composite demanding an ordered
    # component checks the class here, at its own construction time
    if not issubclass(component, cls):
      raise ValueError(f"{context} requires an ordered component - one claiming the Ordered property (ascending iteration); got {component.__name__}")

  def __setup__(self):
    super().__setup__()
