from autoc.core import _binder, enforced, Hashable
from autoc.properties import Property


# Property mixin for containers whose storage is hash-addressed - the element (or index)
# identity is resolved through the hash and the equality of the hashing subject, so the
# hash families have no ordering-based operations and their iteration order is layout-
# incidental. Claimed by the bucket-chaining and open-addressing families, and by the
# map families keyed over them. The property owns its invariant: every claiming container
# has the hashability of its hashing subject enforced here, in one place.
class Hashed(Property):

  brief = "Abstract hashed container - resolves its elements or indices through their hash"

  @_binder
  def require(self_or_cls, other, *args, **kwargs):
    from autoc.core import require
    if self_or_cls is Hashed:
      return require(other, self_or_cls)
    return require(self_or_cls, other)

  @enforced
  def _enforce_hashing(self, subject: Hashable):
    return subject

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self._enforce_hashing(self._hashing())

  def _hashing(self):
    # The hashing subject - the type whose hashability the hash-addressed lookup rests on.
    # Element-keyed containers take the element; the keyed containers override to their index
    return self.element
