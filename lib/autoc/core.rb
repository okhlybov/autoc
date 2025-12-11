# frozen_string_literal: true


module AutoC


VERSION = '3.0.0'


refine Integer do
  def to_type = Type::Primitive[:int]
  def to_value = Value::Literal.new(to_type, self)
end

refine Float do
  def to_type = Type::Primitive[:double]
  def to_value = Value::Literal.new(to_type, self)
end

[String, Symbol].each do |c|
  refine c do
    def to_type = Type::Primitive[self]
    def to_parameter = to_type.to_parameter
    def to_value = Verbatim.new(self)
  end
end


refine Kernel do

  def out(x) = Callable::Parameter::Out.new(x)
  def inout(x) = Callable::Parameter::InOut.new(x)

  def chr(x) = Value::Literal::Char.new(x)
  def str(x) = Value::Literal::String.new(x)

end


using self


class Type

  attr_reader :name_c

  attr_reader :visibility

  def initialize(name, visibility: :public)
    @name_c = name.to_s
    @visibility = visibility
  end

  def i = 0

  def to_type = self

  def to_parameter = Callable::Parameter::In.new(self)

  def inspect = "#{name_c} <#{self.class}>"

  def to_s = name_c

  def to_i(i = 1) = Indirection.new(self, i).to_type

  def to_value = Value.new(self)

  def to_variable(name) = Variable.new(self, name)

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
  def public? = visibility == :public

  # A private type is declared in the interface header but marked private to hide it from documentation extractors
  def private? = visibility == :private

    # An internal type is declared in forward declaration sections of the respective translation units
  def internal? = visibility == :internal

end


class Value

  attr_reader :type

  def initialize(type)
    @type = type.to_type
  end

  def to_value = self

  def rvalue_c = to_s

  def bind_c(target)
    xi = type.i - target.type.i
    if xi >= 0
      '*'*xi + to_s
    else
      raise("can not obtain address of the value #{self} with &")
    end
  end

  class Literal < Value

    def initialize(type, value)
      super(type)
      @value = value.to_s
    end

    def to_s = @value

    def inspect = "#{self} :: #{type} <#{self.class}>"

    def bind_c(target)
      xi = type.i - target.type.i
      xi == 0 ? to_s : raise("can not obtain address of the literal value #{self} with &")
    end

    class Char < Literal

      def initialize(value)
        super('char', value)
      end

      def to_s = %{'#{@value[0]}'}

    end

    class String < Literal

      def initialize(value)
        super('const char*', value)
      end

      def to_s = %{"#{@value}"}

    end

  end

end


class Variable < Value

  attr_reader :name_c

  def initialize(type, name)
    super(type)
    @name_c = name.to_s
  end

  def to_s = name_c

  def declaration_c = "#{type.name_c} #{name_c}"

  def lvalue_c = to_s

  def bind_c(target)
    xi = type.i - target.type.i
    if xi >= 0
      '*'*xi + name_c
    elsif xi == -1
      "&#{name_c}"
    else
      raise
    end
  end

end


class Verbatim < String

  def to_value = self

  def inspect = "#{self} <#{self.class}>"

  def rvalue_c = to_s

  def lvalue_c = to_s

end


end
