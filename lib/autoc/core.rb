# frozen_string_literal: true


module AutoC


VERSION = '3.0.0'


module Coercions

  module Parameters
    def to_parameter = self.in
    def in = Function::Parameter::In.new(self)
    def out = Function::Parameter::Out.new(self)
    def inout = Function::Parameter::InOut.new(self)
  end

  refine Integer do
    def to_value = Literal.new('int', self)
  end

  refine Float do
    def to_value = Literal.new('double', self)
  end

  [String, Symbol].each do |c|
    refine c do
      import_methods Parameters
      def to_type = Primitive.new(self)
      def to_value = Verbatim.new(to_s)
      def ~@ = StringLiteral.new(self) # Construct a string literal, ex. "string", to be used as ~'str' or ~:str
      def to_variable(name) = to_type.to_variable(name)
    end
  end

  refine Kernel do
    def str(obj) = StringLiteral.new(obj) # Construct a string literal for obj, ex. "string", same as ~obj, to be used as str(:zzz)
    def char(obj) = CharLiteral.new(obj) # Construct a char literal for obj, ex. 'c'
  end

end


using Coercions


# @abstract
# C side type descriptor
class Type

  include Coercions::Parameters

  def to_type = self

  # C side type signature
  attr_reader :name_c

  attr_reader :visibility

  def initialize(name, visibility: :public)
    @name_c = name.to_s
    @visibility = visibility
  end

  def inspect = "#{name_c} <#{self.class}>"

  def to_s = name_c

  # Test whether the type has a default (parameterless) constructor.
  # This implementation looks up the {#default_create} method.
  def default_constructible? = respond_to?(:default_create)

  # Test whether the type has a custom constructor which accepts a number of parameters.
  # This implementation looks up the {#custom_create} method.
  def custom_constructible? = respond_to?(:custom_create)

  # Test whether the type can be constructed, with either default or parametrized initialization.
  # This implementation queries {#custom_constructible?} and {#default_constructible?}.
  def constructible? = custom_constructible? || default_constructible?

  # Test whether the type has a non-trivial destructor.
  # This implementation looks up the {#destroy} method.
  def destructible? = respond_to?(:destroy)

  # Test whether the type can be created from an instance of the same type (cloned).
  # This implementation looks up the {#copy} method.
  def copyable? = respond_to?(:copy)

  # Test whether the type has a well-defined test for content equality against another value of the same type.
  # This implementation looks up the {#equal} method.
  def comparable? = respond_to?(:equal)

  # Test whether the type can be compared for less-equal-more against another value of the same type.
  # Orderable type's values can be sorted and put into tree-based containers.
  # For the type to be comparable this implementation looks up the {#compare} method.
  def orderable? = respond_to?(:compare)

  # Test whether the type's values which can be the elements of hash-based containers.
  def hashable? = comparable? && respond_to?(:hash_code)

  # A public type is declared & documented in the interface header
  def public? = @visibility == :public

  # A private type is declared in the interface header but marked private to hide it from documentation extractors
  def private? = @visibility == :private

    # An internal type is declared in forward declaration sections of the respective translation units
  def internal? = @visibility == :internal

end



# @private
# A mixin for typed values
module Typed

  # Value type
  attr_reader :type

  private def typed_initialize(type, in_i, out_i, inout_i)
    @in_i = in_i
    @out_i = out_i
    @inout_i = inout_i
    @type = type&.to_type
  end

  def to_value = self

  # Per parameter's kind indirection levels for the value
  attr_reader :in_i, :out_i, :inout_i

  # Parameter type declarations
  def in_type_c = type_c(in_i)
  def out_type_c = type_c(out_i)
  def inout_type_c = type_c(inout_i)

  # Code to render values's type declaration
  private def type_c(level)
    case level
    when  0 then type.name_c
    when -1 then "#{type.name_c}*"
    else raise "bad indirection level #{level}"
    end
  end

  # Code to render the value passed to parameter
  private def pass_value_c(parameter, value, value_i)
    case (parameter.i - value_i)
    when  0 then value.to_s
    when -1 then "&#{value}"
    when +1 then "*#{value}"
    else raise "bad indirection level #{level}"
    end
  end

end


# @private
# A mixin for types which represent entities bindable to paramaters
# Implies Typed mixin in effect
module Bindable

  # def bind_value_c

  def bind_in_c(parameter) = pass_value_c(parameter, bind_value_c, in_i)
  def bind_out_c(parameter) = pass_value_c(parameter, bind_value_c, out_i)
  def bind_inout_c(parameter) = pass_value_c(parameter, bind_value_c, inout_i)

end


# @private
# A mixin for named variables
# C side variable representing a value of the specified type
# A variable is a lvalue in the C/C++ terms
# Implies Typed mixin in effect
module Named

  # C side variable name
  attr_reader :name_c

  private def named_initialize(name)
    @name_c = name.to_s
  end

  def to_s = name_c

  include Bindable

  def bind_value_c = name_c

  def declaration_c = "#{type.name_c} #{name_c}"

end


# Type descriptor for primitive C side types, such as int, char
# The type's values are normally passed by value
class Primitive < Type

  def to_value = Value.new(self)

  def to_variable(name) = Variable.new(self, name)

  class Value

    include Typed

    def initialize(type)
      typed_initialize(type, 0, -1, -1)
    end

  end

  class Variable < Value

    include Named

    def initialize(type, name)
      super(type)
      named_initialize(name)
    end

  end

end


# Type descriptor for C side types which have a definite internal structure
# (usually aggregates) such as struct, union etc.
# The type's values are normally passed by a reference to const object
# even though the type bears the value semantics
class Composite < Type

  def to_value = Value.new(self)

  def to_variable(name) = Variable.new(self, name)

  class Value

    include Typed

    def initialize(type)
      typed_initialize(type, -1, -1, -1)
    end

    def in_type_c = "const #{super}"

  end

  class Variable < Value

    include Named

    def initialize(type, name)
      super(type)
      named_initialize(name)
    end

  end

end


module Coercions

  # A code block passed verbatim
  class Verbatim < String

    def to_value = self

    def bind_in_c(parameter) = to_s
    def bind_out_c(parameter) = to_s
    def bind_inout_c(parameter) = to_s

  end

  # Literal value (such as numeric)
  class Literal < Primitive::Value

    def initialize(type, value)
      super(type)
      @value_c = value.to_s
    end

    def to_s = @value_c

    # A literal value can only be bound to the in parameter
    def bind_in_c(parameter)
      raise "literal value #{to_s} is not addressable" unless parameter.i == 0
      to_s
    end

  end

  # Single character value in single quotes
  class CharLiteral < Literal
    def initialize(value) = super('char', %{'#{value[0]}'})
  end

  # C string literal in double quotes
  class StringLiteral < Literal
    def initialize(value) = super('const char*', %{"#{value}"})
  end

end


end
