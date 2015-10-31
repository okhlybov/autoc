require "autoc/code"
require "autoc/type"


module AutoC


=begin

== Implemented types

- {AutoC::UserDefinedType} user-defined custom type

- {AutoC::Reference} counted reference type

== Implemented collections

- {AutoC::Vector} resizable array

- {AutoC::List} single linked list

- {AutoC::Queue} double linked list

- {AutoC::HashSet} hash-based set

- {AutoC::HashMap} hash-based map

== Ruby side operation

.Complete example for generation of a list of integers collection:
[source,ruby]
----
require "autoc"
AutoC::Module.generate!(:Test) do |c|
  c << AutoC::List.new(:IntList, :int)
end
----
In the above example a C module Test represented by the C header +test_auto.h+ and the C source +test_auto.c+ is generated.
The C++ counterpart of the generated collection is +std::forward_list<int>+.

== C interface

=== Element types: values, references

Collections may contain both value and reference types, including other collections.

=== Thread safety

WARNING: In its current state the implemented collections are *not* thread-safe.

=== Iteration

At the moment a fairly simple iteration functionality is implemented.
The iterators are modeled after the C# language.
All implemented iterators do not require destruction after use.

.Basic iterator usage example:
[source,c]
----
MyVector c;
MyVectorIt it;
...
MyVectorItCtor(&it, &c);
while(MyVectorItMove(&it)) {
  Element e = MyVectorItGet(&it);
  ...
  ElementDtor(e);
}
----

WARNING: the collection being iterated *must not* be modified in any way otherwise the iterator behavior is undefined.
=end
class Collection < Type

  include Redirecting
  
  attr_reader :element, :it_ref
  
  def hash; super ^ element.hash end
  
  def ==(other) super && element == other.element end
  
  alias :eql? :==

  def entities; super << element end
  
  def initialize(type_name, element_type, visibility = :public)
    super(type_name, visibility)
    @it_ref = "#{it}*"
    @element = Type.coerce(element_type)
    initialize_redirectors
    element_requirement(element)
  end
  
  # Normally all collections are expected to provide all special functions
  # If a collection does not provide specific function it should override the respective method
  
  # Collection always has default constructor
  def constructible?; true end

  # Collection always has constructor
  def initializable?; true end

  # Collection always has destructor but the element is required to be destructible on its own
  # because collection destruction incurs destruction of all contained elements
  def destructible?; true && element.destructible? end

  # Collection always has copy constructor but the element is required to be copyable on its own
  # because collection copying incurs copying of all contained elements
  def copyable?; true && element.copyable? end

  # Collection always has equality tester but the element is required to be comparable on its own
  # because collection comparison incurs comparison of all contained elements
  def comparable?; true && element.comparable? end

  # So far there are no orderable collections therefore inherit false-returning #orderable? 

  # Collection always has hash calculation function but the element is required to be hashable on its own
  # because collection comparison incurs hash calculation for all contained elements
  def hashable?
    # Since using collection as an element of a hash-based container also requires it to be comparable as well 
    comparable? && element.hashable?
  end

  def write_intf_decls(stream, declare, define)
    write_redirectors(stream, declare, define)
  end
  
  private
  
  def element_requirement(obj)
    raise "type #{obj.type} (#{obj}) must be destructible" unless obj.destructible?
    raise "type #{obj.type} (#{obj}) must be copyable" unless obj.copyable?
  end
  
end # Collection


end # AutoC