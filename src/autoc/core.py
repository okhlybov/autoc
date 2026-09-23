import re
import sys
import textwrap
from autoc.module import Entity, Code
from collections.abc import Iterable # substitute for missing iterable()


_type_rxcache = [] # [ (rx, type) ]
_type_cache = {} # { name: type }


def _type2type(obj):
  return obj if isinstance(obj, Type) else None


def _str2type(obj):
  if isinstance(obj, str):
    for rx, type in _type_rxcache:
      if rx.match(obj):
        _type_cache[type.name] = type
        return type
    if obj in _type_cache:
      return _type_cache[obj]
    return Primitive(obj)
  return None


#
def _type(obj):
  for c in (_type2type, _str2type):
    if x := c(obj):
      return x
  raise TypeError(f"{obj} is not convertible to Type")


#
def _value(obj):
  match obj:
    # TODO complex
    case Value(): return obj
    case int(): return Literal("int", obj)
    case float(): return Literal("double", obj)
    case str(): return Literal("int", obj) # FIXME actually this should be borrowing the target's type
  raise TypeError(f"{obj} is not convertible to Value")


#
def _parameter(obj):
  match obj:
    case Callable.Parameter(): return obj
    case _: return Callable.In(obj)


#
def _result(obj):
  match obj:
    case Callable.Parameter(): return obj
    case _: return Callable.Result(_type(obj)) # The result is a value owned by the caller - pairs with the view_type used for borrowing


#
class _MultiphaseConstructible(type):

  def __call__(cls, *args, **kws):
    obj = super().__call__(*args, **kws)
    obj.__setup__()
    obj.__register__()
    return obj


# Mixin for types which support all operations
class _Traitful:
  
  @property
  def constructible(self):
    return True
  
  @property
  def default_constructible(self):
    return self.constructible and self.create is not None and len(self.create.parameters) == 1

  @property
  def destructible(self):
    return True

  # The value traits are derived from the presence of the operation implementations:
  # a type carries whatever operations it has actually defined and nothing else. The
  # optimistic defaults would render the declarations without the bodies crashing the
  # generation or linking for the types which never supplied them
  @property
  def copyable(self):
    return _defined(getattr(self, "copy", None))

  @property
  def moveable(self):
    # A type is movable when it either supplies its own move or when the move is derivable:
    # the default construction manufactures the pristine shell which the swap then exchanges
    # with the source leaving the source in the pristine state as well
    if _defined(getattr(self, "move", None)):
      return True
    return self.default_constructible and self.swappable

  # Swappability is the weaker exchange trait: swapping exchanges the representations of two
  # complete values so both sides remain valid afterwards - unlike move it requires no pristine
  # state to be left behind and is therefore available to some types which are not moveable
  @property
  def swappable(self):
    return True

  @property
  def comparable(self):
    return _defined(getattr(self, "equal", None))

  @property
  def orderable(self):
    return _defined(getattr(self, "compare", None))

  @property
  def hashable(self):
    return _defined(getattr(self, "hash", None))

  # The zero representation of the value is a valid pristine state which makes the bulk
  # default initialization possible through the zeroed allocations alone
  @property
  def zero_initializable(self):
    return False


class _VisibilityManager:

  def __init__(self, *args, visibility="public", **kws):
    super().__init__(*args, **kws)
    self.visibility = visibility

  @property
  def public(self):
    return self.visibility == "public"
  
  @property
  def private(self):
    return self.visibility == "private"

  @property
  def internal(self):
    return self.visibility == "internal"


class _Documented(Entity, _VisibilityManager):
  
  def __init__(self, *args, brief=None, description=None, **kws):
    super().__init__(*args, **kws)
    self.__manage_attr("brief", brief)
    self.__manage_attr("description", description)

  def __manage_attr(self, attr, value):
    if value:
      setattr(self, attr, value)
    elif not hasattr(self.__class__, attr):
      setattr(self, attr, None)

  # Display name of the type in the rendered documentation. The default is the
  # exact C identifier so the generated markup references the concrete expanded
  # symbols; the generic (template-like) presentation is supplied by the
  # documentation sub-project which overrides this property per type
  @property
  def _doxygen_type(self):
    return getattr(self, "name", str(self))
  
  def _render_documentation(self, stream, header):
    if self.public:
      # If no brief is specified, this means no description as well as the most likely case
      if self.brief:
        stream.append(f"/** @public\n@brief {self.brief}\n")
        self._render_description(stream)
        stream.append("*/\n")
      else:
        stream.append("/** @public\n")
        self._render_description(stream)
        stream.append("*/\n")
    elif header:
      stream.append("/** @private */\n")

  def _render_description(self, stream):
    if self.description:
      # The descriptions are authored nested into the Python source indentation which
      # Doxygen's Markdown would otherwise treat as the indented code blocks relative
      # to the least indented lines of the comment - leaving the embedded commands
      # unrecognized and rendered verbatim - so normalize the common prefix away
      stream.append(textwrap.dedent(self.description))


#
class _GroupRenderer(_Documented):
  __group_counter = 0

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    _GroupRenderer.__group_counter += 1
    self._group_id = _GroupRenderer.__group_counter

  # A documented type owning a doxygen group. The group identifier is the type
  # name so the member @ingroup references and the @defgroup declaration always
  # agree while the group title carries the display name of the type
  def _render_description(self, stream):
    super()._render_description(stream)
    stream.append(f"\n@defgroup {self.name} {self._doxygen_type}\n")


#
class _AliasRenderer(_GroupRenderer):
  
  # Value types which bear no structure of their own (e.g. String wrapping a
  # plain char*) still render their type-level documentation and group once
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      self._render_documentation(stream, header)


#
class Type(_Documented, Entity, _VisibilityManager, metaclass=_MultiphaseConstructible):

  def __setup__(self):
    # Basic methods
    # The descriptions are type-agnostic because every type inherits them through
    # method_from()/macro_from() - the concrete declarations keep the parameter names
    # of these prototypes so the rendered @param entries always match the signatures
    self.create = Callable(None, {"target": out(self)}, constraint=lambda: self.constructible, purpose="Lifetime management", brief="Create the value with default parameters",
      description="""
        Constructs the value in place over the uninitialized target storage. Any previous
        resources held by target must have been destroyed or reset before calling create.
        Every type inherits this operation; the concrete construction semantics are the
        ones of the type.

        @param[out] target the storage area in which to construct the value
      """)
    self.destroy = Callable(None, {"target": self}, constraint=lambda: self.destructible, purpose="Lifetime management", brief="Destroy the value",
      description="""
        Releases the resources held by the value leaving it invalid - it must be reconstructed
        before any further use. Destroying a trivial value-less type is a no-op.

        @param[in] target the value to destroy - the released resources leave the value invalid
      """)
    self.copy = Callable(None, {"target": out(self), "source": self}, constraint=lambda: self.copyable, purpose="Lifetime management", brief="Create a copy of the value",
      description="""
        Constructs the target as an independent copy of the source - the two values do not
        share any resources afterwards. Every type inherits this operation through the
        method_from()/macro_from() forwarding.

        @param[out] target the value to construct as the copy
        @param[in] source the value to copy
      """)
    self.move = Callable(None, {"target": out(self), "source": out(self)}, constraint=lambda: self.moveable, purpose="Lifetime management", brief="Move the value to a new location",
      description="""
        Transfers the source contents to the target leaving the source in a valid empty
        state - typically a cheaper pointer transfer than the copy.

        @param[out] target the value to construct as the destination
        @param[in,out] source the value to move from - left in a valid empty state
      """)
    self.swap = Callable(None, {"left": inout(self), "right": inout(self)}, constraint=lambda: self.swappable, purpose="Lifetime management", brief="Swap two values",
      description="""
        Exchanges the contents of the two values - for the handle-like types it is a constant
        time exchange of the internal pointers requiring no pristine state on either side.

        @param[in,out] left the first value
        @param[in,out] right the second value
      """)
    self.equal = Callable("int", {"left": self, "right": self}, constraint=lambda: self.comparable, purpose="State query", brief="Compare two values by equality",
      description="""
        Checks the two values for equality per the type equality semantics - required to be
        consistent with the hash so the equal values always compare and hash alike.

        @param[in] left the first value
        @param[in] right the second value
        @return non-zero if the values are equal and zero otherwise
      """)
    self.compare = Callable("int", {"left": self, "right": self}, constraint=lambda: self.orderable, purpose="State query", brief="Compute ordering relation of two values",
      description="""
        Establishes the strict weak ordering of the two values per the type ordering
        semantics - the ordering on which ordered containers and sorting rely.

        @param[in] left the first value
        @param[in] right the second value
        @return a negative value, zero or a positive value as the first value is less than, equal to or greater than the second one
      """)
    self.hash = Callable("size_t", {"target": self}, constraint=lambda: self.hashable, purpose="State query", brief="Compute a hash of the value",
      description="""
        Computes a hash of the value over the hasher of the enclosing module - the equal
        values are guaranteed to produce the same hash making it usable by the hash-based
        containers.

        @param[in] target the value to hash
        @return the hash of the value - equal values always hash alike
      """)
    # Methods used by the hash-based containers
    self.hash_lookup_hash = lambda *args: self.hash(*args)
    self.hash_lookup_equal = lambda *args: self.equal(*args)
  
  def __register__(self): pass
  
  def variable(self, name):
    return Variable(self, name)

  @property
  def value_type(self):
    # A value of a type is by default its rvalue - pointer-backed types override this
    return self.rvalue_type


def _hidden_prefix(s, hidden):
  m = re.match("^(_*)(.*)", s)
  u = m.group(1)
  if not u and hidden:
    u = "_" # Prepend single underscore for a symbol marked hidden that is not already underscored
  return u + m.group(2)


# _snake_case identifier decorator
def snake_decorator(type, identifier, hidden=False):
  ids = []
  if identifier:
    ids = [identifier] if isinstance(identifier, str) else [*identifier]
  return _hidden_prefix("_".join([str(type.prefix)] + ids), hidden)


# CamelCase identifier decorator
def camel_decorator(type, identifier, hidden=False):
  ids = []
  if identifier:
    ids = [identifier] if isinstance(identifier, str) else [*identifier]
  return _hidden_prefix("".join([str(type.prefix)] + [s[0].upper()+s[1:] for s in ids]), hidden)


# Global decorator used by all named type descentants unless overridden locally
decorator = camel_decorator


def _infer_purpose(identifier):
  if isinstance(identifier, (list, tuple)):
    name = "_".join(str(x) for x in identifier).lower()
  elif isinstance(identifier, str):
    name = identifier.lower()
  else:
    return None

  # 1. Iteration
  if name in ("next",) or name.startswith(("move_front", "move_back")):
    return "Iteration"

  # 2. Lifetime management
  if (
    name in ("new", "move", "free", "share", "take")
    or name.startswith(("create", "destroy", "copy", "swap", "allocate"))
  ):
    return "Lifetime management"

  # 3. State query
  if (
    name in ("empty", "size", "capacity", "contains", "indexed", "equal", "compare", "hash", "count", "any", "none", "test")
    or name.startswith((
      "empty_", "size_", "capacity_", "contains_", "indexed_",
      "equal_", "compare_", "hash_", "count_", "any_", "none_",
      "test_", "is_", "binary_search", "find_first"
    ))
  ):
    return "State query"

  # 4. Modifiers
  if (
    name in ("push", "pop", "put", "remove", "clear", "enqueue", "dequeue", "set", "flip", "insert", "delete",
             "union", "intersection", "difference", "symmetric_difference", "compact", "extend")
    or name.startswith((
      "push_", "pop_", "put_", "remove_", "clear_", "enqueue_", "dequeue_",
      "set_", "flip_", "insert_", "delete_", "assign_", "discard_",
      "union_", "intersection_", "difference_", "symmetric_difference_",
      "compact_", "extend_", "emplace_", "ensure_", "flush_", "replace_"
    ))
  ):
    return "Modifiers"

  # 5. Element access
  if (
    name in ("front", "back", "top", "get", "view", "at", "data", "first", "second")
    or name.endswith("_view")
    or name.startswith((
      "front_", "back_", "top_", "get_", "view_", "at_", "find_view",
      "data_", "lower_bound", "upper_bound", "first_", "second_",
      "index_front", "index_back", "index_view", "locate_"
    ))
  ):
    return "Element access"

  # 6. Operations
  if (
    name in ("sort", "reverse", "format", "fill", "resize", "link")
    or name.startswith((
      "sort_", "reverse_", "format_", "fill_", "resize_",
      "rotate_", "sift_", "merge_", "split_"
    ))
  ):
    return "Operations"

  return None


# Mixin for named types which can have methods/components/attributes etc.
class _Named(Type):
  
  def __init__(self, name, *args, prefix=None, decorator=None, **kws):
    super().__init__(*args, **kws)
    self.name = str(name)
    self.prefix = prefix if prefix else self.name
    self.decorator = decorator if decorator else sys.modules[__name__].decorator
    self.__attributes = set()

  #
  def method(self, result, identifier, parameters, *args, hidden=False, attribute=None, abstract=None, purpose=None, **kws):
    # The owning type is recorded so the rendered documentation groups the member
    # under its type - the explicitly attributed method_from() calls take precedence
    kws.setdefault("type", self)
    if purpose is None:
      purpose = _infer_purpose(identifier)
    x = Function(
      result,
      self.decorate(identifier, hidden=hidden),
      parameters,
      *args,
      abstract=abstract if abstract else False,
      purpose=purpose,
      **kws
    )
    # Method by itself does not depend on its owning type - only though explicit parameters
    attribute = self._decorate_attribute(attribute if attribute else identifier)
    self.__attributes.add(attribute) # Record attribute name which holds the method object
    setattr(self, attribute, x)
    return x

  #
  def macro(self, attribute, *args, **kws):
    self.__attributes.add(attribute) # Record attribute name which holds the method object
    setattr(self, attribute, x := Macro(*args, **kws))
    return x
  
  #
  def macro_from(self, attribute, *args, **kws):
    m = getattr(self, attribute)
    kws.setdefault("variadic", getattr(m, "variadic", False))
    kws.setdefault("purpose", getattr(m, "purpose", None))
    return self.macro(attribute, m._result, m._parameters, *args, brief=m.brief, description=m.description, **kws)
    
  #
  def method_from(self, identifier, *args, attribute=None, **kws):
    m = getattr(self, attribute := self._decorate_attribute(attribute if attribute else identifier))
    kws.setdefault("variadic", getattr(m, "variadic", False))
    kws.setdefault("purpose", getattr(m, "purpose", None))
    return self.method(m._result, identifier, m._parameters, *args, constraint=m.constraint, attribute=attribute, brief=m.brief, description=m.description, type=self, **kws)
  
  #
  def decorate(self, *args, **kws):
    identifier = args if len(args) > 1 else args[0]
    return self.decorator(self, identifier, **kws)

  def _decorate_component(self, suffix, abbreviate=True):
    if abbreviate:
      if isinstance(suffix, str):
        x = suffix[0]
      else:
        x = "".join([x[0] for x in suffix])
      return f"{self.decorate(None, hidden=True)}{x}"
    else:
      return self.decorate(suffix)
  
  def _decorate_attribute(self, identifier):
    match identifier:
      case str(): return identifier
      case list() | tuple(): return "_".join(identifier)

  # 
  def __str__(self):
    return self.name
  
  def __register__(self):
    # By recording the attribute names instead of real method objects makes it possible to
    # disable object emitting by setting the respective attribute to None
    # prior entering this method (__setup__ is a perfect place for this)
    self.references.update( [t for x in self.__attributes if hasattr(self, x) and not (t := getattr(self, x)) is None] )


#
class Primitive(_Named, _Traitful):

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    if not self.name in _type_cache:
      _type_cache[self.name] = self

  def __setup__(self):
    super().__setup__()
    self.macro_from("create", lambda target: f"{target} = 0")
    self.macro_from("copy", lambda target, source: f"{target} = {source}")
    self.macro_from("move", lambda target, source: f"{target} = {source}")
    self.macro_from("swap", lambda left, right: f"{{ {self} _ = {left}; {left} = {right}; {right} = _; }}")
    self.macro_from("equal", lambda left, right: f"({left} == {right})")
    self.macro_from("compare", lambda left, right: f"({left} == {right} ? 0 : ({left} < {right} ? -1 : +1))")
    self.macro_from("hash", lambda target: f"(size_t)({target})")
    
  @property
  def destructible(self):
    # Primitive types almost always bear no destructor
    return False

  @property
  def zero_initializable(self):
    # The zero representation of a primitive is a valid pristine shell - the destructor
    # bearing descendants must override this along with declaring their empty state
    return True

  @property
  def rvalue_type(self):
    return self

  @property
  def lvalue_type(self):
    return self

  @property
  def in_type(self):
    return self

  @property
  def out_type(self):
    return Indirection(self)

  @property
  def inout_type(self):
    return Indirection(self)

  @property
  def view_type(self):
    return Indirection(self, constant=True)


#
class Composite(_Named, _Traitful):

  def __setup__(self):
    super().__setup__()
    self.method_from("create")
    self.method_from("destroy")
    self.method_from("copy")
    self.method_from("move")
    # The swap is hidden into the translation unit - primitives themselves do not expose it publicly
    self.method_from("swap", hidden=True, visibility="internal")
    with self.swap as f:
      # Exchanging the whole representations keeps both values valid - for the containers
      # this is the O(1) bookkeeping exchange regardless of the element type
      f.code = f"""
        {self} temp;
        temp = *left;
        *left = *right;
        *right = temp;
      """

    # The move is derived for the types capable of manufacturing the pristine shell by the
    # default construction and exchanging the contents by swapping - the explicit move
    # definitions of the concrete types take precedence
    if self.default_constructible and self.swappable:
      with self.move as f:
        f.code = f"""
          {self.create(f.target)};
          {self.swap(f.target, f.source)};
        """

    self.method_from("equal")
    self.method_from("compare")
    self.method_from("hash")

  @property
  def rvalue_type(self):
    return self

  @property
  def lvalue_type(self):
    return self

  @property
  def in_type(self):
    return Indirection(self, constant=True)

  @property
  def out_type(self):
    return Indirection(self)

  @property
  def inout_type(self):
    return Indirection(self)

  @property
  def view_type(self):
    return Indirection(self, constant=True)


class _StructRenderer(_GroupRenderer):

  opaque = True # Structs are opaque by default

  def _render_struct(self, stream, header):
    self._render_documentation(stream, header)
    if not isinstance(self, Indirection):
      if self.public:
        stream.append(f"/** @ingroup {self.name} */\n")
      else:
        stream.append("/** @private */\n")
      stream.append(f"typedef struct {self.name} {self.name};\n")
      if self.public:
        if getattr(self, "opaque", True):
          stream.append(f"/**\n  @ingroup {self.name}\n  @brief The opaque handle representing @ref {self} value.\n*/\n")
        else:
          stream.append(f"/** @ingroup {self.name} */\n")
      else:
        stream.append("/** @private */\n")

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    # Structures are expected to be rendered in the interface header
    # even for internal types since they can be a part of more acessible structures
    # treated by the public inline code
    if header:
      self._render_struct(stream, header)


# Abstract class for renderable contents, basically a str-like type
class Statement:

  def __init__(self, contents, *args, **kws):
    super().__init__(*args, **kws)
    self.contents = str(contents)

  def __str__(self):
    return self.contents


def _indirection(obj):
  return t.indirection if isinstance(t := _type(obj), Indirection) else 0


def _indifference(lt, rt):
  return _indirection(lt) - _indirection(rt)


# Abstract class representing a typed value of unspecified contents which can be passed to callable
class Value:
  
  def __init__(self, type, *args, **kws):
    super().__init__(*args, **kws)
    self.type = _type(type)

  def bind(self, type):
    if (i := _indifference(self.type, type)) < 0:
      raise ValueError(f"can not dereference value {self} with & operator")
    return "*"*i


# Class representing a typed value with generic renderable contents
class Expression(Value, Statement):

  def bind(self, type):
    return super().bind(type) + self.contents


#
class Literal(Expression):
  
  def bind(self, type):
    return self.contents


#
def string(value):
  return StringLiteral(value)


#
class StringLiteral(Literal):

  def __init__(self, value, *args, **kws):
    super().__init__(Indirection("char", constant=True), f"\"{value}\"")


#
def char(obj):
  return CharacterLiteral(obj)


#
class CharacterLiteral(Literal):

  def __init__(self, value, *args, **kws):
    super().__init__("char", f"'{str(value)[0]}'")


# Class for representing the C variable
class Variable(Value):
  
  def __init__(self, type, name, **kws):
    super().__init__(type, **kws)
    self.name = str(name)

  def bind(self, type):
    i = _indifference(self.type, type)
    if i < -1:
      raise ValueError(f"too many & addressing operations requested for {self}")
    return f"&{self.name}" if i == -1 else "*"*i + self.name
    
  @property
  def definition(self):
    return f"{self.type} {self.name}"
  
  def __str__(self):
    return self.name
  

#
class Indirection(Type):

  def __init__(self, type, *args, indirection=1, constant=None, **kws):
    super().__init__(*args, **kws)
    if isinstance(t := _type(type), Indirection):
      self.type = t.type
      self.indirection = indirection + t.indirection
      self.constant = t.constant if constant is None else constant
    else:
      self.type = t
      self.indirection = indirection
      self.constant = True if constant is True else False
    self.dependencies.add(self.type)
      
  def __str__(self):
    return (f"const {self.type}" if self.constant else str(self.type)) + "*"*self.indirection

  #
  def constness(self, value):
    return Indirection(self.type, indirection=self.indirection, constant=value)
  
  #
  def variable(self, name):
    return Indirection.Variable(self, name)

  class Variable(Variable):

    def __init__(self, obj, name):
    # It makes little to no sense to define variable of const type so drop constness qualifier if it is set
      super().__init__(obj.constness(False), name)

    @property
    def definition(self):
      return f"{super().definition} = 0"
  
  @property
  def rvalue_type(self):
    return self.type

  @property
  def value_type(self):
    # A value of a pointer-backed type is the pointer itself - it must not be dereferenced
    return self

  @property
  def lvalue_type(self):
    return self.type

  @property
  def in_type(self):
    return Indirection(self.type, constant=True)

  @property
  def out_type(self):
    return Indirection(self.type, indirection=2)

  @property
  def inout_type(self):
    return self

  @property
  def view_type(self):
    # A view of a pointer-backed type is the pointer itself with const data - no extra indirection
    return self.constness(True)


#
def out(obj):
  return Callable.Out(obj)


#
def inout(obj):
  return Callable.InOut(obj)


# Basic callable descriptor
class Callable(_Documented):
  
  def __init__(self, result, parameters, *args, constraint=lambda: True, variadic=False, purpose=None, **kws):
    super().__init__(*args, **kws)
    # Capture raw parameter description to be used in modeling of the descendant types
    self._result = result
    self._parameters = parameters
    self.constraint = constraint
    self.variadic = bool(variadic)
    self.purpose = purpose
    
  @property
  def active(self):
    return self.constraint() is True

  @property
  def _result_c(self):
    return "void" if self.result is None else str(self.result)

  @property
  def signature(self):
    params = [str(t) for t in self.parameters.values()]
    if self.variadic:
      params.append("...")
    return "%s(%s)" % (self._result_c, ", ".join(params))

  def contents(self, contents):
    if self.result is None:
      return Statement(contents)
    else:
      return Expression(self.result, contents)

  # Create function type borrowing the signature
  def functional(self, name):
    return Functional.of(name, self, brief=self.brief, description=self.description, variadic=self.variadic)
  
  class Parameter:
    def __init__(self, type):
      self.type = _type(type)
    def resolve(self, callable):
      return self.type
      
      
  class In(Parameter):
    def resolve(self, callable):
      return callable.resolve_in(self.type)
    
  class Out(Parameter):
    def resolve(self, callable):
      return callable.resolve_out(self.type)
  
  class InOut(Parameter):
    def resolve(self, callable):
      return callable.resolve_inout(self.type)

  class Result(Parameter):
    def resolve(self, callable):
      return callable.resolve_result(self.type)


#
class _Parametrized(Callable, Entity):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self.result = None if self._result is None or self._result == "void" else _result(self._result).resolve(self)
    self.parameters = {str(n): _parameter(t).resolve(self) for n, t in self._parameters.items()}
    self.dependencies.update(self.parameters.values())
    if not self.result is None:
      self.dependencies.add(self.result)

  def __call__(self, *arguments):
    if not self.active:
      raise ValueError(f"attempt to call disabled function {self}")
    if self.variadic:
      np = len(self.parameters)
      if (na := len(arguments)) < np:
        raise TypeError(f"{self} takes at least {np} parameter(s) but {na} given")
      fixed = [_value(argument).bind(type) for argument, type in zip(arguments[:np], self.parameters.values())]
      var = [str(argument) for argument in arguments[np:]]
      return [*fixed, *var]
    else:
      if (na := len(arguments)) != (np := len(self.parameters)):
        raise TypeError(f"{self} takes {np} parameter(s) but {na} given")
      return [_value(argument).bind(type) for argument, type in zip(arguments, self.parameters.values())]


class _Functional:

  def resolve_in(self, type):
    return type.in_type
  
  def resolve_out(self, type):
    return type.out_type
  
  def resolve_inout(self, type):
    return type.inout_type

  def resolve_result(self, type):
    return type.value_type

  def __str__(self):
    return self.name


# Pointer-to-function type
class Functional(Primitive, _Functional, _Parametrized, _VisibilityManager):

  @classmethod
  def of(self, name, callable, *args, **kws):
    kws.setdefault("variadic", getattr(callable, "variadic", False))
    return self(callable._result, name, callable._parameters, *args, **kws)

  def __init__(self, result, name, parameters, *args, **kws):
    super().__init__(name, result, parameters, *args, **kws)

  def __setup__(self):
    super().__setup__()
    self.compare = None # Function pointers are not orderable

  #
  def render_declarations(self, stream, header):
    if self.active:
      super().render_declarations(stream, header)
      if (header and not self.internal) or (not header and self.internal):
        self._render_documentation(stream, header)
        params = [str(t) for t in self.parameters.values()]
        if self.variadic:
          params.append("...")
        params_str = ", ".join(params)
        stream.append(f"typedef {self._result_c} (*{self.name})({params_str});\n")

  @property
  def orderable(self):
    return False

  def variable(self, name):
    return Functional.Variable(self, name)

  class Variable(Variable):

    def __call__(self, *arguments):
      return self.type.contents(f"{self.name}(" + ", ".join(self.type(*arguments)) + ")")


#  
class Macro(_Parametrized):
  
  @classmethod
  def of(self, callable, emitter, constraint=None, **kws):
    kws.setdefault("variadic", getattr(callable, "variadic", False))
    return self(callable._result, callable._parameters, emitter, constraint=callable.constraint if not constraint else constraint, brief=callable.brief, description=callable.description, **kws)
  
  def __init__(self, result, parameters, emitter, **kws):
    super().__init__(result, parameters, **kws)
    self.emitter = emitter

 
  def resolve_in(self, type):
    return type.rvalue_type
  
  def resolve_out(self, type):
    return type.lvalue_type
  
  def resolve_inout(self, type):
    return type.lvalue_type

  def resolve_result(self, type):
    return type.value_type

  def __call__(self, *arguments):
    return self.contents(self.emitter(*super().__call__(*arguments)))
  
  def __str__(self):
    return "->"


def _defined(operation):
  # An operation is defined when it carries its implementation - either the macro emitter
  # or the function body
  return isinstance(operation, Macro) or (isinstance(operation, Function) and hasattr(operation, "code"))


#
class Function(_Functional, _Parametrized, _VisibilityManager):
  
  @classmethod
  def of(self, callable, name, constraint=None, purpose=None, **kws):
    kws.setdefault("variadic", getattr(callable, "variadic", False))
    kws.setdefault("purpose", getattr(callable, "purpose", None) if purpose is None else purpose)
    return self(callable._result, name, callable._parameters, constraint=callable.constraint if not constraint else constraint, **kws)

  def __init__(self, result, name, parameters, linkage="external", abstract=None, dependencies=(), type=None, purpose=None, **kws):
    super().__init__(result, parameters, dependencies=(*dependencies, _linkage_code), purpose=purpose, **kws)
    self.name = str(name)
    self.linkage = linkage
    self.__abstract = abstract
    self.type = type # Object this function is attached to
    self.purpose = purpose
    self.arguments = [Variable(t, n) for n, t in self.parameters.items()] # Local variables deduced from function's formal parameters
    for x in self.arguments:
      setattr(self, x.name, x)

  def __call__(self, *arguments):
    return self.contents(f"{self.name}(" + ", ".join(super().__call__(*arguments)) + ")")

  def __repr__(self):
    return f"{self.name} {super().__repr__()}"

  @property
  def abstract(self):
    return not hasattr(self, "code") if self.__abstract is None else self.__abstract is True

  def _declaration_c(self, render_names):
    if render_names:
      params = [f"{t} {n}" for n, t in self.parameters.items()]
    else:
      params = [str(t) for t in self.parameters.values()]
    if self.variadic:
      params.append("...")
    return "%s %s(%s)" % (self._result_c, self.name, ", ".join(params))

  @property
  def _body_c(self):
    if self.abstract:
      raise ValueError(f"attempt to render definition for abstract function {self}")
    if not hasattr(self, "code"):
      raise ValueError(f"missing body of non-abstract function {self}")
    match self.code:
      case Iterable(): cs = [str(x) for x in self.code]
      case _ if callable(self.code): cs = [str(self.code())]
      case _: cs = [str(self.code)]
    return str().join(("{", *cs, "}\n"))

  @property
  def declaration(self):
    return self._declaration_c(False)

  @property
  def definition(self):
    return self._declaration_c(True) + self._body_c

  def __enter__(self):
    return self
  
  def __exit__(self, *args):
    return False

  def __inline_code(self, obj):
    self.linkage = "inline"
    self.code = obj
    
  inline_code = property(fset=__inline_code)
  
  def __external_code(self, obj):
    self.linkage = "external"
    self.code = obj

  external_code = property(fset=__external_code)
  
  @property
  def external(self):
    return self.linkage == "external"

  @property
  def inline(self):
    return self.linkage == "inline"

  @property
  def declaration(self):
    return self._declaration_c(self.public)
  
  #
  def render_declarations(self, stream, header):
    if self.active:
      super().render_declarations(stream, header)
      if (header and not self.internal) or (not header and self.internal):
        if header and self.public and self.type and getattr(self.type, "public", False) and getattr(self, "purpose", None):
          disc = chr(0x200b) * getattr(self.type, "_group_id", 1)
          stream.append(f"/** @name {self.purpose}{disc}\n *  @{{\n */\n")
          self._render_documentation(stream, header)
          self._render_declaration(stream)
          stream.append("/** @} */\n")
        else:
          self._render_documentation(stream, header)
          self._render_declaration(stream)

  #
  def render_definitions(self, stream, header):
    if self.active:
      super().render_definitions(stream, header)
      if self.inline:
        if (header and not self.internal) or (not header and self.internal):
          self._render_definition(stream)
      else:
        if not header:
          self._render_definition(stream)

  #  
  def _render_definition(self, stream):
    if not self.abstract:
      stream.append(self.definition)

  #
  def _render_declaration(self, stream):
    self._render_decorator(stream)
    stream.append(self.declaration)
    stream.append(";\n")

  #
  def _render_decorator(self, stream):
    stream.append(_linkage_spec_c[self.linkage])

  def _render_description(self, stream):
    super()._render_description(stream)
    # The group of the member is addressed by its identifier which is the
    # owning type name - the display name is reserved for the group title.
    # Only the public owners declare a group so the internal ones (the hidden
    # container components) must not reference a group which does not exist
    if self.type and self.type.public:
      stream.append(f"\n@ingroup {self.type.name}\n")
      
      
_linkage_spec_c = {"external": "AUTOC_EXTERN ", "inline": "AUTOC_STATIC_INLINE "}


_linkage_code = Code(interface="""
  #ifndef AUTOC_EXTERN
    #ifdef __cplusplus
      #define AUTOC_EXTERN extern "C"
    #else
      #define AUTOC_EXTERN extern
    #endif
  #endif
  #ifndef AUTOC_STATIC_INLINE
    #if defined(__cplusplus) || (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L)
      #define AUTOC_STATIC_INLINE static inline
    #elif !defined(__STRICT_ANSI__) && (defined(__GNUC__) || defined(__clang__) || defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER) || defined(__POCC__) || defined(__ARMCC_VERSION) || defined(__ARMCC_COMPILER_VERSION))
      #define AUTOC_STATIC_INLINE static inline
    #else
      #define AUTOC_STATIC_INLINE static
    #endif
  #endif
""")
