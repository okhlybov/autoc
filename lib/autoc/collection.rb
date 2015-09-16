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
    element_type_check(element)
  end
  
  def copyable?; super && element.copyable? end
  
  def comparable?; super && element.comparable? end
  
  def hashable?; super && element.hashable? end
  
  def write_intf_decls(stream, declare, define)
    write_redirectors(stream, declare, define)
  end
  
  private
  
  def element_type_check(obj)
    raise "type #{obj.type} (#{obj}) must be destructible" unless obj.destructible?
    raise "type #{obj.type} (#{obj}) must be copyable" unless obj.copyable?
    raise "type #{obj.type} (#{obj}) must be comparable" unless obj.comparable?
    raise "type #{obj.type} (#{obj}) must be hashable" unless obj.hashable?
  end
  
end # Collection


end # AutoC