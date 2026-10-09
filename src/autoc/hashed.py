from autoc.core import TraitError
from autoc.properties import Property


# Property mixin for containers whose storage is hash-addressed - the element (or index)
# identity is resolved through the hash and the equality of the hashing subject, so the
# hash families have no ordering-based operations and their iteration order is layout-
# incidental. Claimed by the bucket-chaining and open-addressing families, and by the
# map families keyed over them. The property owns its invariant: every claiming container
# has the hashability of its hashing subject enforced here, in one place.
class Hashed(Property):

  brief = "Abstract hashed container - resolves its elements or indices through their hash"

  _diagnostics = "Hashed"

  @classmethod
  def require(cls, component, inquirer, role="component"):
    # The requirement application of the property: a composite demanding a hashed
    # component checks the class here, at its own construction time
    target = component if isinstance(component, type) else type(component)
    if not issubclass(target, cls):
      raise TraitError(f"{inquirer._diagnostic_context} requires a hashed {role} - one claiming the Hashed property (hash-addressed); got {target.__name__}")
    return component

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    subject, role = self._hashing()
    self._enforce(subject, "require_hashable", role)

  def _hashing(self):
    # The hashing subject - the type whose hashability the hash-addressed lookup rests on.
    # Element-keyed containers take the element; the keyed containers override to their index
    return self.element, "element type"
