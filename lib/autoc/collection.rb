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

  attr_reader :element, :it_ref
  
  def hash; super ^ element.hash end
  
  def ==(other) super && element == other.element end
  
  alias :eql? :==

  def entities; super << element end
  
  def initialize(type_name, element_type, visibility = :public)
    super(type_name, visibility)
    @it_ref = "#{it}*"
    @element = Type.coerce(element_type)
    @ctor = define_function(:ctor, Function::Signature.new([type_ref^:self]))
    @dtor = define_function(:dtor, Function::Signature.new([type_ref^:self]))
    @copy = define_function(:copy, Function::Signature.new([type_ref^:dst, type_ref^:src]))
    @equal = define_function(:equal, Function::Signature.new([type_ref^:lt, type_ref^:rt], :int))
    @identify = define_function(:identify, Function::Signature.new([type_ref^:self], :size_t))
    @less = define_function(:less, Function::Signature.new([type_ref^:lt, type_ref^:rt], :int))
    element_type_check(element)
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

  def copyable?; super && element.copyable? end
  
  def comparable?; super && element.comparable? end
  
  def hashable?; super && element.hashable? end
  
  private
  
  def element_type_check(obj)
    raise "type #{obj.type} (#{obj}) must be destructible" unless obj.destructible?
    raise "type #{obj.type} (#{obj}) must be copyable" unless obj.copyable?
    raise "type #{obj.type} (#{obj}) must be comparable" unless obj.comparable?
    raise "type #{obj.type} (#{obj}) must be hashable" unless obj.hashable?
  end
  
  # @private
  class Redirector < Function
    # Redirect call to the specific macro
    def call(*params) "_#{name}(" + params.join(',') + ')' end
  end # Redirector
  
  def define_function(name, signature)
    Redirector.new(method_missing(name), signature)
  end
  
end # Collection


end # AutoC