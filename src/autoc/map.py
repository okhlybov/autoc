from autoc.core import _type, Pointer
from autoc.collection import Collection


#
class Map(Collection):
  
  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, *args, **kws)
    self.index = _type(index)
    self.index_view = Pointer(self.index, constant=True)
    self.depends(self.index)

  @property
  def copyable(self):
    return self.element.copyable and self.index.copyable
  
  @property
  def hashable(self):
    return self.element.hashable and self.index.hashable

  @property
  def comparable(self):
    return self.element.comparable and self.index.comparable