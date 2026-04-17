import autoc.module


#
class StaticSeed(autoc.module.Entity):
  
  def __init__(self, value=0):
    super().__init__()
    self.value = value
    
  def __str__(self):
    return str(self.value)