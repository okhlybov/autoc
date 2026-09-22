import autoc.core
import autoc.std as std
from autoc.map import Map
from autoc.module import Code
from autoc.range import DirectAccess
from autoc.collection import _Range
from autoc.core import inout, Indirection, Callable, _AliasRenderer


#
class String(_AliasRenderer, Indirection, Map):
  
  brief = "Value type wrapper of the C char* string"
  
  def __init__(self, name, *args, **kws):
    super().__init__("char", name, "char", std.size_t, prefix=name, dependencies=(std.stdio_h, std.string_h, std.stdarg_h, std.stdlib_h, _static_code, _va_copy_code))
    self.range = Range(self)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires no constraints on the element type - the element type is fixed to `char`.
      Supports two way character traversal via the corresponding @ref {self.range} iterator
      as well as subranging with direct indexed access to the subrange's characters.

      Implemented as the dynamically sized null terminated char buffer carrying the embedded length.
      The closest C++ equivalent is [std::string<>](https://cppreference.com/cpp/string/basic_string).
    """

    self.create = self.macro_from("create", lambda target: f"{target} = (char*)_autoc_empty_string")
    self.destroy = self.macro_from("destroy", lambda target: str(self.free(target)))
    self.copy = self.macro_from("copy", lambda target, source: f"{target} = {self.new(source)}")
    self.move = self.macro_from("move", lambda target, source: f"{target} = {source}, {source} = (char*)_autoc_empty_string")
    self.swap = self.method(None, "swap", {"left": inout(Indirection(self)), "right": inout(Indirection(self))}, brief="Swap two strings",
      description="""
        Swaps the string buffers in O(1) by exchanging the pointers - no character copying.
        Neither string is modified content-wise beyond taking over the other's buffer.

        @param[in,out] left the first string
        @param[in,out] right the second string
      """)
    with self.swap as f:
      f.inline_code = """
        char* temp;
        temp = *left;
        *left = *right;
        *right = temp;
      """

    with self.method(Callable.Parameter(self), "new", {"source": self}, brief="Duplicate string",
      description="""
        Duplicates the string into a freshly allocated NUL-terminated buffer in O(n)
        where n is the string length, using `strdup` where available and an explicit
        `malloc`+`memcpy` fallback otherwise. A null string duplicates into the shared
        empty string which needs no release.

        @param[in] source the string to duplicate - a null string duplicates into the empty one
        @return the newly allocated copy of the string
      """) as f:
      f.code = """
        if(source) {
          #if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
            return strdup(source);
          #elif defined(__POCC__)
            /* Pelles C check must come before _MSC_VER — Pelles C may define _MSC_VER */
            return strdup(source);
          #elif defined(_MSC_VER) && !(defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER))
            return _strdup(source);
          #elif defined(__MINGW32__) || defined(__MINGW64__)
            return strdup(source);
          #elif defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 200809L || defined(_GNU_SOURCE)
            return strdup(source);
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
      
    with self.method(None, "free", {"target": inout(self)}, brief="Free string memory",
      description="""
        Releases the buffer of a string created by `new` or assigned an owned copy.
        The empty string sentinel is never freed; the target is left pointing at it
        so the string stays usable.

        @param[in,out] target the string to release - reset to the empty string
      """) as f:
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

    with self.method("int", ("format", "args"), {"target": inout(Indirection(self)), "format": Indirection("char", constant=True), "args": std.va_list}, brief="Format output into string from va_list",
      description="""
        Formats the output according to the format string and variable arguments list,
        replacing the previous contents of target. The target string buffer is allocated
        dynamically to fit the formatted output. Any previous buffer held by target is freed.

        @param[in,out] target the string to format into
        @param[in] format the format string
        @param[in] args the variable arguments list
        @return number of characters written, or negative on encoding error
        
        @note This function relies on the C library `vsnprintf()` function and unconditionally returns -1 when it is missing.
      """) as f:
      f.code = """
        int len;
        char* buf;
        va_list args_copy;
        assert(target);
        assert(format);
        #if defined(__POCC__)
          /* Pelles C check must come before _MSC_VER — Pelles C may define _MSC_VER */
          va_copy(args_copy, args);
          len = vsnprintf(NULL, 0, format, args_copy);
          va_end(args_copy);
        #elif defined(_MSC_VER) && !defined(__clang__)
          va_copy(args_copy, args);
          len = _vscprintf(format, args_copy);
          va_end(args_copy);
        #elif (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L) || defined(__GNUC__) || defined(__clang__)
          va_copy(args_copy, args);
          len = vsnprintf(NULL, 0, format, args_copy);
          va_end(args_copy);
        #else
          (void)args_copy;
          assert(0 && "string formatting requires vsnprintf support");
          return -1;
        #endif
        if(len < 0) return len;
        buf = (char*)malloc((size_t)len + 1);
        assert(buf);
        #if (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L) || defined(__POCC__) || defined(__GNUC__) || defined(__clang__)
          vsnprintf(buf, (size_t)len + 1, format, args);
        #elif defined(_MSC_VER) && !defined(__clang__)
          vsprintf(buf, format, args);
        #else
          (void)buf;
          (void)args;
          return -1;
        #endif
        if(*target && *target != _autoc_empty_string) {
          free(*target);
        }
        *target = buf;
        return len;
      """

    with self.method("int", "format", {"target": inout(Indirection(self)), "format": Indirection("char", constant=True)}, variadic=True, brief="Format output into string",
      description="""
        Formats the output according to the format string and variable arguments,
        replacing the previous contents of target. The target string buffer is allocated
        dynamically to fit the formatted output. Any previous buffer held by target is freed.

        @param[in,out] target the string to format into
        @param[in] format the format string
        @return number of characters written, or negative on encoding error

        @note This function relies on the C library `vsnprintf()` function and unconditionally returns -1 when it is missing.
      """) as f:
      f.code = lambda: f"""
        int len;
        va_list args;
        assert(target);
        assert(format);
        va_start(args, format);
        len = {self.format_args("target", "format", "args")};
        va_end(args);
        return len;
      """

  @property
  def rvalue_type(self):
    return self

  @property
  def lvalue_type(self):
    return self

  @property
  def destructible(self):
    return True
  
  
_static_code = Code(dependencies=(autoc.core._linkage_code,), interface=f"""
  /** @private */
  AUTOC_EXTERN const char* _autoc_empty_string;
""", implementation=f"""
  const char* _autoc_empty_string = "";
""")


_va_copy_code = Code(dependencies=(std.stdarg_h, std.stdio_h, std.string_h), definitions="""
  #ifndef va_copy
    #if defined(__GNUC__) || defined(__clang__)
      #define va_copy(d, s) __builtin_va_copy(d, s)
    #elif defined(__POCC__)
      #define va_copy(d, s) ((d) = (s))
    #elif defined(_MSC_VER)
      #define va_copy(d, s) ((d) = (s))
    #else
      #define va_copy(d, s) memcpy(&(d), &(s), sizeof(va_list))
    #endif
  #endif
""")


#
class Range(_Range, DirectAccess):
  brief = "Direct access range over the string characters"

  
  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      typedef struct {{
        {Indirection(self.iterable.type, constant=True)} iterable; /**< @private */
        {self.iterable.index} front, back; /**< @private */
      }} {self.name};
    """)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable" : self.iterable}, brief="Create the range spanning the whole string",
      description="""
        Creates the range over the characters up to but not including the terminator.
        The range must not outlive the string buffer.

        @param[in] iterable the string to span
        @return the range covering the whole string
      """) as f:
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