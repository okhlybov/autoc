from autoc.composite import Mapping
from autoc.intrusive_hash_set import Set
from autoc.hash_map import _SetEntry


#
class Map(Mapping):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self.set = Set(f"{self.decorate(None, hidden=True)}s", _SetEntry(f"{self.decorate(None, hidden=True)}e", self.element, self.index))