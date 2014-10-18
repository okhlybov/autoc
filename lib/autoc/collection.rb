require "autoc/code"
require "autoc/type"


module AutoC


=begin

== Implemented collections

- {AutoC::Vector} a fixed-sized array

- {AutoC::List} a single linked list

- {AutoC::Queue} a double linked list

- {AutoC::HashSet} a hash-based set

- {AutoC::HashMap} a hash-based map

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

  attr_reader :element, :it_ref
  
  def hash; super ^ element.hash end
  
  alias :eql? :==

  def ==(other)
    super && element == other.element
  end
  
  def entities; super << element end
  
  def initialize(type_name, element_type, visibility = :public)
    super(type_name, visibility)
    @element = Type.coerce(element_type)
    @it_ref = "#{it}*"
  end
  
  private
  
  # @private
  class Dereferer < AutoC::Function
    def call(*args)
      super(*args.collect {|x| "&#{x}"})
    end
  end
  
  def method(name, params = [], result = nil)
    Dereferer.new(method_missing(name), Signature.new(params, result))
  end
  
end # Collection


end # AutoC