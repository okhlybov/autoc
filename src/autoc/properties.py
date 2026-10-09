from autoc.container import Container


# Base of the property mixins (the -ed family): a property claims a structural invariant
# of the container and, as the requirement application of that claim, enforces the trait
# it demands of its subject at the claiming container's construction time.
# The demand face pairs with the bool trait query face - see _Traitful.
class Property(Container):

  brief = "Abstract property mixin - claims a structural invariant and enforces the trait it demands of its subject"

  # The naming of the property in the requirement diagnostics
  _diagnostics = "property"

  def _enforce(self, subject, enforcer, role):
    getattr(subject, enforcer)(f"{self._diagnostics} container '{self.name}'", role)
