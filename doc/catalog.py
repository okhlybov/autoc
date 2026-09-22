# The catalog of the AutoC containers as they are presented in the reference manual.
#
# The base library renders the markup with the exact generated identifiers so the
# documentation of a concrete module references the concrete expanded code. This
# catalog instantiates each container once with the generic value types and overrides
# the display name only, which turns the same declarations into a C++-flavoured
# reference: List<T>, Map<K, T>, List<T>::Range and so on while every operation keeps
# its generated C identifier so an entry in the manual matches the generated code.

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "src"))

import autoc.core
import autoc.list
import autoc.deque
import autoc.vector
import autoc.tiered_vector
import autoc.stack
import autoc.queue
import autoc.priority_queue
import autoc.string
import autoc.string_buffer
import autoc.chained_hash_set
import autoc.chained_hash_map
import autoc.intrusive_hash_set
import autoc.intrusive_hash_map
import autoc.treap_set
import autoc.treap_map
import autoc.record
import autoc.variant
import autoc.reference
import autoc.static_vector
import autoc.bitset


# The manual is written with the default CamelCase identifiers
autoc.core.decorator = autoc.core.camel_decorator


class Placeholder(autoc.core._AliasRenderer, autoc.core.Primitive):

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        /**
         * @ingroup {self.name}
         * @brief {self.brief if self.brief else self.name}
         */
        typedef struct {self.name} {self.name};
      """)


# Generic value types standing for the concrete element, key and mapped types
T = Placeholder(
  "T",
  brief="Generic element type placeholder",
  description="""
    Stands for the element type of a sequence, set, stack, queue or priority queue —
    and the mapped value type of a map.
  """,
)
K = Placeholder(
  "K",
  brief="Generic index type placeholder",
  description="""
    Stands for the index (key) type of a map.
  """,
)


# The sentinel operations the intrusive containers need are left symbolic - the manual
# declares the generic API and is never compiled, so the sentinels stay abstract
_sentinels = {
  "is_empty": lambda element: f"{element} == T_EMPTY",
  "mark_empty": lambda element: f"{element} = T_EMPTY",
  "is_deleted": lambda element: f"{element} == T_DELETED",
  "mark_deleted": lambda element: f"{element} = T_DELETED",
}


def _nested_range(module, name):
  # The range class is selected by the container's own module at construction time,
  # so specializing the module attribute is enough to present the range as the
  # nested List<T>::Range style type of its container
  base = module.Range

  class Range(base):
    @property
    def _doxygen_type(self):
      return f"{self.iterable._doxygen_type}::Range"

  Range.__name__ = name
  Range.__qualname__ = name
  module.Range = Range
  return Range


# Generic element sequences
class List(autoc.list.List):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class Deque(autoc.deque.Deque):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


# The index type of the direct access containers is an implementation detail
class Vector(autoc.vector.Vector):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class StaticVector(autoc.static_vector.StaticVector):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}, N>"


class TieredVector(autoc.tiered_vector.TieredVector):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


# Adapters
class Stack(autoc.stack.Stack):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class Queue(autoc.queue.Queue):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class PriorityQueue(autoc.priority_queue.PriorityQueue):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class String(autoc.string.String):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class StringBuffer(autoc.string_buffer.StringBuffer):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class BitSet(autoc.bitset.BitSet):
  @property
  def _doxygen_type(self):
    return f"{self.name}<N>"


# Sets
class ChainedHashSet(autoc.chained_hash_set.Set):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class IntrusiveHashSet(autoc.intrusive_hash_set.Set):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


class TreapSet(autoc.treap_set.Set):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.element}>"


# Maps - the index (key) comes first in the C++-flavoured presentation
class ChainedHashMap(autoc.chained_hash_map.Map):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.index}, {self.element}>"


class IntrusiveHashMap(autoc.intrusive_hash_map.Map):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.index}, {self.element}>"


class TreapMap(autoc.treap_map.Map):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.index}, {self.element}>"


# References
class Counted(autoc.reference.Counted):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.type}>"


class Arc(Counted):
  pass


class Raw(autoc.reference.Raw):
  @property
  def _doxygen_type(self):
    return f"{self.name}<{self.type}>"


# Specialize the ranges of every container before any of them is instantiated
_nested_range(autoc.list, "ListRange")
_nested_range(autoc.deque, "DequeRange")
_nested_range(autoc.vector, "VectorRange")
_nested_range(autoc.static_vector, "StaticVectorRange")
_nested_range(autoc.tiered_vector, "TieredVectorRange")
_nested_range(autoc.stack, "StackRange")
_nested_range(autoc.queue, "QueueRange")
_nested_range(autoc.string, "StringRange")
_nested_range(autoc.chained_hash_set, "ChainedHashSetRange")
_nested_range(autoc.intrusive_hash_set, "IntrusiveHashSetRange")
_nested_range(autoc.treap_set, "TreapSetRange")
_nested_range(autoc.chained_hash_map, "ChainedHashMapRange")
_nested_range(autoc.intrusive_hash_map, "IntrusiveHashMapRange")
_nested_range(autoc.treap_map, "TreapMapRange")


def configure_module(module):
  module.add(T)
  module.add(K)

  module.add(String("String"))
  module.add(StringBuffer("StringBuffer"))

  module.add(List("List", T))
  module.add(Deque("Deque", T))
  module.add(Vector("Vector", T))
  module.add(StaticVector("StaticVector", T, 4))
  module.add(TieredVector("TieredVector", T))
  module.add(Stack("Stack", T))
  module.add(Queue("Queue", T))
  module.add(PriorityQueue("PriorityQueue", T))

  module.add(ChainedHashSet("ChainedHashSet", T))
  module.add(IntrusiveHashSet("IntrusiveHashSet", T, **_sentinels))
  module.add(TreapSet("TreapSet", T))

  module.add(ChainedHashMap("ChainedHashMap", T, K))
  module.add(IntrusiveHashMap("IntrusiveHashMap", T, K, **_sentinels))
  module.add(TreapMap("TreapMap", T, K))

  module.add(BitSet("BitSet", 64))
  module.add(autoc.record.Record("Record", {"first": T, "second": K}))
  module.add(autoc.variant.Variant("Variant", {"first": T, "second": K}))

  module.add(Counted(T, name="Counted"))
  module.add(Raw(T, name="Raw"))

  return module

