from autoc.core import TraitError
from autoc.properties import Property


# Property mixin for containers whose iteration order is born sorted - the ascending
# element (or index) order is an invariant of the structure itself, not a user-maintained
# state (that is Sortable's regime), so backward traversal is available unconditionally.
# Claimed by the tree and flat sets, and by the map families keyed over them. Unordered
# containers (the hash-based families) do not claim it; their iteration order is layout-
# incidental. Unlike the ability mixins (the -able family) a property is also the shape
# of a requirement: a composite keyed over such a component demands the property of it
# and validates the demand at its own construction time via require(). The property owns
# its invariant: every claiming container has the orderability of its ordering subject
# enforced here, in one place.
class Ordered(Property):

  brief = "Abstract ordered container - iterates in ascending element or index order"

  _diagnostics = "Ordered"

  @classmethod
  def require(cls, other, inquirer=None, role="component"):
    # The requirement application of the property: a composite demanding an ordered
    # component checks the class here, at its own construction time
    from autoc.core import dispatch_require
    return dispatch_require(cls, other, inquirer=inquirer, role=role)

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    subject, role = self._ordering()
    self._enforce(subject, "require_orderable", role)

  def _ordering(self):
    # The ordering subject - the type whose orderability backs the ascending iteration
    # promise. Element-ordered containers take the element; the keyed containers override to their index
    return self.element, "element type"
