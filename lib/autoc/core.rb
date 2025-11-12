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
      def to_value = StringLiteral.new(self)
      def to_variable(name) = to_type.to_variable(name)
    end
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

  def initialize(name)
    @name_c = name.to_s
  end

  def to_s = name_c

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
    @type = type.to_type
  end

  def to_value = self

  # Per parameter's kind indirection levels for the value
  attr_reader :in_i, :out_i, :inout_i

  # Parameter type declarations
  def in_type_c = type_c(in_i)
  def out_type_c = type_c(out_i)
  def inout_type_c = type_c(inout_i)

  # Code to render variable's type declaration
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


# C side function representation
class Function

  # C side function name
  attr_reader :name_c

  # Function return parameter
  # nil is returned for the void C side functions
  attr_reader :return

  # A hash of named formal parameters
  attr_reader :parameters

  def initialize(result, name, parameters = {})
    @name_c = name.to_s
    @return = (result.nil? || result.to_s == 'void') ? nil : result.to_parameter
    @parameters = parameters.map { |v, t| [v.to_s, t.to_parameter] }.to_h
  end

  def call(*arguments) = Call.new(self, arguments)

  def signature_c = '%s(%s)' % [return_c, parameters.values.map { |p| p.type_c }.join(', ') ]

  def declaration_c = '%s %s(%s)' % [return_c, name_c, parameters.map { |v, p| p.declaration_c(v) }.join(', ') ]

  private def return_c = self.return.nil? ? :void : self.return.type_c

  # @private
  # Function formal parameter
  # The parameter is used for both function inputs and function return
  # allowing the function calls to be chained
  class Parameter

    # Base type for the parameter with the value semantics
    attr_reader :type

    def initialize(type)
      @type = type.to_type
    end

    def to_parameter = self

    def to_value = type.to_value

    def to_variable(name) = type.to_variable(name)

    def declaration_c(variable) = "#{type_c} #{variable}"

    # Input parameter treated as constant object
    class In < Parameter
      def i = to_value.in_i
      def type_c = to_value.in_type_c
      def bind_c(value) = value.to_value.bind_in_c(self)
    end

    # Output parameter which represents an uninitialized storage which is expected to be set
    class Out < Parameter
      def i = to_value.out_i
      def type_c = to_value.out_type_c
      def bind_c(value) = value.to_value.bind_out_c(self)
    end

    # Modifiable input parameter
    class InOut < Parameter
      def i = to_value.inout_i
      def type_c = to_value.inout_type_c
      def bind_c(value) = value.to_value.bind_inout_c(self)
    end

  end

  # Result of a function call
  # This is itself a value of the function's return type
  class Call

    # Function being called
    attr_reader :function

    # List of values passed to the function
    attr_reader :arguments

    # Value representing the result of the function call
    # nil is returned for the void function
    attr_reader :to_value

    def initialize(function, arguments = [])
      @function = function
      @to_value = Result.new(self) unless function.return.nil?
      @arguments = arguments.map(&:to_value)
    end

    def to_s = '%s(%s)' % [function.name_c, function.parameters.values.zip(arguments).map { |p, v| p.bind_c(v) }.join(', ')]

    # Represents a value returned by a function call
    # This is a facade for the function's return value which
    # renders the function call code in place of the value
    class Result

      include Bindable

      def bind_value_c = @call.to_s

      def to_value = self

      def initialize(call)
        @value = (@call = call).function.return.to_value
      end

      def method_missing(method, *args)
        @value.send(method, *args)
      end

    end

  end

end


module Coercions

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

  class CharLiteral < Literal
    def initialize(value) = super('char', %{'#{value[0]}'})
  end

  class StringLiteral < Literal
    def initialize(value) = super('const char*', %{"#{value}"})
  end

end


end