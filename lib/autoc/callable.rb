# frozen_string_literal: true


require 'autoc/core'


module AutoC


using Coercions


# C side generic callable code representation
# Think of this as an unnamed function
class Callable

  # Function return parameter
  # nil is returned for the void C side functions
  attr_reader :return

  # A hash of named formal parameters
  attr_reader :parameters

  def initialize(result, parameters = {})
    @return = (result.nil? || result.to_s == 'void') ? nil : result.to_parameter
    @parameters = parameters.map { |v, t| [v.to_s, t.to_parameter] }.to_h
  end

  def call(*arguments) = Call.new(self, arguments)

  def signature_c = '%s(%s)' % [return_c, parameters_c]

  def parameters_c = parameters.map { |v, p| p.declaration_c(v) }.join(', ')

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

  # Result of a callable call
  # This is itself a value of the callable's return type
  class Call

    # callable being called
    attr_reader :callable

    # List of values passed to the callable
    attr_reader :arguments

    # Value representing the result of the callable call
    # nil is returned for the void callable
    attr_reader :to_value

    def initialize(callable, arguments = [])
      @callable = callable
      @to_value = Result.new(self) unless callable.return.nil?
      @arguments = arguments.map(&:to_value)
    end

    # Instantiate Call whatever effective class defines
    # def call(*arguments) = self.class.Call.new(self, arguments)

    def arguments_a = callable.parameters.values.zip(arguments).map { |p, v| p.bind_c(v) }

    def arguments_c = arguments_a.join(', ')

    # Represents a value returned by a callable call
    # This is a facade for the callable's return value which
    # renders the callable call code in place of the value
    class Result

      include Bindable

      def bind_value_c = @call.to_s

      def to_value = self

      def initialize(call)
        @value = (@call = call).callable.return.to_value
      end

      def method_missing(method, *args)
        @value.send(method, *args)
      end

    end

  end

end


end
