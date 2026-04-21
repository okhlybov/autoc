from autoc.core import inout, Macro
from autoc.composite import _StructRenderer
from autoc.intrusive_hash_set import Set
from autoc.hash_map import _Entry
from autoc.map import Map


class _Entry(_Entry):
  
  def __init__(self, *args, is_empty, is_deleted, mark_empty, mark_deleted, **kws):
    super().__init__(*args, **kws)
    self.is_empty = Macro("int", {"entry": self}, is_empty)
    self.is_deleted = Macro("int", {"entry": self}, is_deleted)
    self.mark_empty = Macro(None, {"entry": inout(self)}, mark_empty)
    self.mark_deleted = Macro(None, {"entry": inout(self)}, mark_deleted)
    

#
class Map(_StructRenderer, Map):
  
  def __init__(self, name, element, index, *args, is_empty, is_deleted, mark_empty, mark_deleted, **kws):
    super().__init__(name, element, index, *args, **kws)
    self.set = Set(self._decorate_component("set"), _Entry(self._decorate_component("entry"), self.element, self.index,
      is_empty=is_empty,
      is_deleted=is_deleted,
      mark_empty=mark_empty,
      mark_deleted=mark_deleted
    )
    )
    self.depends(self.set)

  def __setup__(self):
    super().__setup__()

    _target = self.variable("target->set")
    _source = self.variable("source->set")
    _left = self.variable("left->set")
    _right = self.variable("right->set")
    
    self.create.code = f"""
      assert(target);
      {self.set.create(_target)};
    """
    
    self.destroy.code = f"""
      assert(target);
      {self.set.destroy(_target)};
    """
    
    self.copy.code = f"""
      assert(target);
      assert(source);
      {self.set.copy(_target, _source)};
    """
        
    self.equal.code = f"""
      assert(left);
      assert(right);
      return {self.set.equal(_left, _right)};
    """
    
    self.hash.code = f"""
      assert(target);
      return {self.set.hash(_target)};
    """
    
    self.empty.code = f"""
      assert(target);
      return {self.set.empty(_target)};
    """
    
    self.size.code = f"""
      assert(target);
      return {self.set.size(_target)};
    """

    #_element = self.element.variable("element")
    
    self.contains.code = f"""
      assert(target);
    """
    
  def _render_struct(self, stream):
    if self.public:
      stream.append("/** @public */\n")
    if self.private:
      stream.append("/** @private */\n")
    stream.append(f"""typedef struct {{
      {self.set.variable("set").definition}; /**< @private */
    }} {self.name};
    """)
