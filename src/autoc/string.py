import autoc.std as std
from autoc.module import Code
from autoc.core import inout, Pointer, Macro
from autoc.map import Map
from functools import cached_property
from autoc.collection import _Range as _CollectionRange
from autoc.range import DirectAccess


#
class String(Pointer, Map):
  
  def __init__(self, name, *args, **kws):
    super().__init__("char", "char", std.size_t, prefix=name, dependencies=[std.string_h, String.__static])
    self.range = Range(self)

  def __setup__(self):
    super().__setup__()

    self.create = Macro.implement(self.create, lambda target: f"{target} = (char*)_autoc_empty_string")
    self.destroy = Macro.implement(self.destroy, lambda target: str(self.free(target)))
    self.copy = Macro.implement(self.copy, lambda target, source: f"{target} = {self.new(source)}")

    with self.method(self, "new", {"source": self}) as f:
      f.inline = """
        if(source) {
          #ifdef _MSC_VER
            return _strdup(source);
          #else
            return strdup(source);
          #endif
        } else return (char*)_autoc_empty_string;
      """
      
    with self.method(None, "free", {"target": inout(self)}) as f:
      f.inline = f"""
        assert(target);
        if(target != _autoc_empty_string) free(target);
      """
    
    with self.set as f:
      f.inline = f"""
        assert(target);
        target[index] = element;
      """
      
    with self.get as f:
      f.inline = f"""
        assert(target);
        return target[index];
      """

    with self.view as f:
      f.inline = f"""
        assert(target);
        return &target[index];
      """

    with self.indexed as f:
      f.inline = f"""
      assert(target);
        return index < {self.size(f.target)};
      """
      
    with self.size as f:
      f.inline = f"""
        assert(target);
        return strlen(target);
      """
      
    with self.empty as f:
      f.inline = f"""
        assert(target);
        return !strlen(target);
      """
      
    with self.contains as f:
      f.inline = f"""
        assert(target);
        return strchr(target, element) != NULL;
      """
      
    with self.implement(self.equal, "equal") as f:
      f.inline = f"""
        assert(left);
        assert(right);
        return !strcmp(left, right);
      """

    with self.implement(self.compare, "compare") as f:
      f.inline = f"""
        assert(left);
        assert(right);
        return strcmp(left, right);
      """
      
    with self.implement(self.hash, "hash") as f:
      f.external = """
        /* the djb2a algorithm */
        char c;
        size_t hash = 5381;
        assert(target);
        while(c = *target++) {
          c ^= (c << 5);
          hash = ((hash << 5) + hash) + c;
        }
        return hash;
      """
      
      
  @cached_property
  def in_type(self):
    return Pointer(self.base, constant=True)

  __static = Code(interface=f"""
    /** @internal */
    extern const char* _autoc_empty_string;
  """, implementation=f"""
    const char* _autoc_empty_string = "";
  """)


#
class Range(_CollectionRange, DirectAccess):
  
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Pointer(self.iterable.base, constant=True)} iterable; /**< @private */
          {self.iterable.index} front, back; /**< @private */
        }} {self.name};
      """)

  def _copy(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  def __setup__(self):
    super().__setup__()

    with self.method(self, "new", {"iterable" : self.iterable}) as f:
      f.inline = lambda: f"""
        {self} result;
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        result.back = {self.iterable.size("iterable")};
        return result;
      """

    with self.empty as f:
      f.inline = f"""
        assert(target);
        return target->front >= target->back;
      """

    with self.front as f:
      f.inline = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->front")};
      """

    with self.front_view as f:
      f.inline = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->front")};
      """

    with self.move_front as f:
      f.inline = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        ++target->front;
      """

    with self.back as f:
      f.inline = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->back-1")};
      """

    with self.back_view as f:
      f.inline = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->back-1")};
      """

    with self.move_back as f:
      f.inline = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        --target->back;
      """

    with self.get as f:
      f.inline = lambda: f"""
      assert(target);
      return {self.iterable.get("target->iterable", "target->front + index")};
    """

    with self.view as f:
      f.inline = lambda: f"""
        assert(target);
        return {self.iterable.view("target->iterable", "target->front + index")};
      """

    with self.size as f:
      f.inline = f"""
        assert(target);
        assert(target->back >= target->front);
        return target->back - target->front;
      """  