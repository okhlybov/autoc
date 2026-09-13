import sys

sys.path.insert(0, "../src")

from autoc.module import Module
from autoc.module import Code
import autoc.std as std
from autoc.vector import Vector
from autoc.tiered_vector import TieredVector
from autoc.list import List
from autoc.deque import Deque
from autoc.queue import Queue
from autoc.stack import Stack
from autoc.priority_queue import PriorityQueue
from autoc.chained_hash_set import Set as ChainedSet
from autoc.chained_hash_map import Map as ChainedMap
from autoc.intrusive_hash_set import Set as IntrusiveSet
from autoc.intrusive_hash_map import Map as IntrusiveMap
from autoc.treap_set import Set as TreapSet
from autoc.treap_map import Map as TreapMap
from autoc.string import String
from autoc.record import Record
from autoc.variant import Variant
from autoc.reference import Raw, Arc
from autoc.core import Functional


# The reference manual type set: the containers act on the abstract element type T
# and, for the associative containers, on the abstract index type K
with Module("doc") as m:
  m.source_count = 0 # the manual is generated from the interface alone

  m.add(Code(interface="""
    /** @brief The abstract element type the sequences and the sets operate on. */
    typedef int T;
    /** @brief The abstract index type the associative containers are keyed by. */
    typedef size_t K;
  """))

  # sequences
  vector = Vector("vector", "T",
    description="The storage is allocated upfront for the given number of elements and never reallocated; the sort, the reversal and the binary search operate in place. The element type must be orderable for the sorting and the binary search.")
  m.add(vector)
  m.add(TieredVector("tiered_vector", "T",
    description="The elements are stored in the fixed size chunks addressed through the chunk table giving the amortized constant time append, the stable element addresses and the teardown proportional to the chunk count rather than the element count. Suitable for the transient buffers holding a very large number of the destructor-less values."))
  m.add(List("list", "T"))
  m.add(Deque("deque", "T"))
  m.add(Queue("queue", "T"))
  m.add(Stack("stack", "T"))
  m.add(PriorityQueue("priority_queue", "T"))

  # sets and maps
  m.add(ChainedSet("set", "T"))
  m.add(ChainedMap("map", "T", "K"))
  m.add(IntrusiveSet("intrusive_set", "T",
    is_empty=lambda element: f"({element} == (T)0)",
    mark_empty=lambda element: f"({element} = (T)0)",
    is_deleted=lambda element: f"({element} == (T)1)",
    mark_deleted=lambda element: f"({element} = (T)1)"))
  m.add(IntrusiveMap("intrusive_map", "T", "K",
    is_empty=lambda entry: f"({entry}.index == (K)0)",
    mark_empty=lambda entry: f"({entry}.index = (K)0)",
    is_deleted=lambda entry: f"({entry}.index == (K)1)",
    mark_deleted=lambda entry: f"({entry}.index = (K)1)"))
  m.add(TreapSet("treap_set", "T"))
  m.add(TreapMap("treap_map", "T", "K"))

  # strings, records, variants, references and the function pointers
  m.add(String("string"))
  record = Record("record", {"element": "T", "index": "K"})
  m.add(record)
  m.add(Variant("variant", {"empty": "T", "key": "K"}))
  m.add(Raw(record, name="raw"))
  m.add(Arc(record, name="arc"))
  m.add(Functional("function", "int", {"value": "T"}))
