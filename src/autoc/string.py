import autoc.std as std
from autoc.map import Map
from autoc.module import Code
from autoc.range import DirectAccess
from autoc.core import inout, Indirection, Callable
from autoc.collection import _Range as CollectionRange


#
class String(Indirection, Map):
  
  def __init__(self, name, *args, **kws):
    super().__init__("char", name, "char", std.size_t, prefix=name, dependencies=(std.string_h, _static_code))
    self.range = Range(self)

  def __setup__(self):
    super().__setup__()
    self.create = self.macro_from("create", lambda target: f"{target} = (char*)_autoc_empty_string")
    self.destroy = self.macro_from("destroy", lambda target: str(self.free(target)))
    self.copy = self.macro_from("copy", lambda target, source: f"{target} = {self.new(source)}")

    with self.method(Callable.Parameter(self), "new", {"source": self}) as f:
      f.inline_code = """
        if(source) {
          #if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
            return strdup(source);
          #elif defined(_MSC_VER)
            return _strdup(source);
          #else
            size_t n;
            char *s;
            n = strlen(source)+1;
            s = (char*)malloc(n); assert(s);
            memcpy(s, source, n);
            return s;
          #endif
        } else return (char*)_autoc_empty_string;
      """
      
    with self.method(None, "free", {"target": inout(self)}) as f:
      f.inline_code = f"""
        assert(target);
        if(target != _autoc_empty_string) free(target);
      """
    
    with self.set as f:
      f.inline_code = f"""
        assert(target);
        target[index] = element;
      """
      
    with self.get as f:
      f.inline_code = f"""
        assert(target);
        return target[index];
      """

    with self.view as f:
      f.inline_code = f"""
        assert(target);
        return &target[index];
      """

    with self.indexed as f:
      f.inline_code = f"""
      assert(target);
        return index < {self.size(f.target)};
      """
      
    with self.size as f:
      f.inline_code = f"""
        assert(target);
        return strlen(target);
      """
      
    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return !strlen(target);
      """
      
    with self.contains as f:
      f.inline_code = f"""
        assert(target);
        return strchr(target, element) != NULL;
      """
      
    with self.method_from("equal") as f:
      f.inline_code = f"""
        assert(left);
        assert(right);
        return strcmp(left, right) == 0;
      """

    with self.method_from("compare") as f:
      f.inline_code = f"""
        assert(left);
        assert(right);
        return strcmp(left, right);
      """
      
    with self.method_from("hash") as f:
      f.code = """
        /* the djb2a algorithm */
        char c;
        size_t hash = 5381;
        assert(target);
        while((c = *target++)) {
          c ^= (c << 5);
          hash = ((hash << 5) + hash) + c;
        }
        return hash;
      """

  @property
  def rvalue_type(self):
    return self

  @property
  def lvalue_type(self):
    return self

  @property
  def view_type(self):
    return Indirection(self.type, constant=True)

  @property
  def destructible(self):
    return True
      
_static_code = Code(interface=f"""
  /** @internal */
  extern const char* _autoc_empty_string;
""", implementation=f"""
  const char* _autoc_empty_string = "";
""")


#
class Range(CollectionRange, DirectAccess):
  
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Indirection(self.iterable.type, constant=True)} iterable; /**< @private */
          {self.iterable.index} front, back; /**< @private */
        }} {self.name};
      """)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable" : self.iterable}) as f:
      f.inline_code = lambda: f"""
        {self} result;
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        result.back = {self.iterable.size("iterable")};
        return result;
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->front >= target->back;
      """

    with self.front as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->front")};
      """

    with self.front_view as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->front")};
      """

    with self.move_front as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        ++target->front;
      """

    with self.back as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->back-1")};
      """

    with self.back_view as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->back-1")};
      """

    with self.move_back as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        --target->back;
      """

    with self.get as f:
      f.inline_code = lambda: f"""
      assert(target);
      return {self.iterable.get("target->iterable", "target->front + index")};
    """

    with self.view as f:
      f.inline_code = lambda: f"""
        assert(target);
        return {self.iterable.view("target->iterable", "target->front + index")};
      """

    with self.size as f:
      f.inline_code = f"""
        assert(target);
        assert(target->back >= target->front);
        return target->back - target->front;
      """  