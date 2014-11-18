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
  
  def write_intf_decls(stream, declare, define)
    # Emit default redirection macros
    # Unlike other special methods the constructors may have extra arguments
    # Assume the constructor's first parameter is always a target
    ctor_ex = ctor.parameters.names[1..-1]
    ctor_lt = ["self"].concat(ctor_ex).join(',')
    ctor_rt = ["&self"].concat(ctor_ex).join(',')
    stream << %$
      #define _#{ctor}(#{ctor_lt}) #{ctor}(#{ctor_rt})
      #define _#{dtor}(self) #{dtor}(&self)
      #define _#{identify}(self) #{identify}(&self)
      #define _#{copy}(dst,src) #{copy}(&dst,&src)
      #define _#{equal}(lt,rt) #{equal}(&lt,&rt)
      #define _#{less}(lt,rt) #{less}(&lt,&rt)
    $
  end

  private
  
  # @private
  class Redirector < Function
    # Redirect call to the specific macro
    def call(*params)
      "_#{name}(" + params.join(',') + ")"
    end
  end # Redirector
  
  def external_function(name, signature)
    Redirector.new(method_missing(name), signature)
  end
  
end # Collection


end # AutoC