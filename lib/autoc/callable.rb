# frozen_string_literal: true
 

require 'autoc/core'


module AutoC


using self


class Callable

  attr_reader :result

  attr_reader :parameters

  def initialize(result, parameters = {})
    @result = (result.nil? || result.to_s == 'void') ? nil : result.to_type
    @parameters = parameters.map { |name, type| [name.to_sym, type.to_parameter.to_variable(name)] }.to_h
  end

  def signature_c = '%s(%s)' % [result.name_c, parameters.values.map { |v| v.type.name_c }.join(', ')]

  def inspect = "#{signature_c} <#{self.class}>"
      
  class Parameter

    attr_reader :type

    def to_parameter = self

    def to_type = type

    def initialize(type)
      @type = type.to_type
    end

    def call(*arguments) = Call.new(self, *arguments)

    class In < Parameter
      def to_variable(name) = type.to_in(name)
    end

    class Out < Parameter
      def to_variable(name) = type.to_out(name)
    end

    class InOut < Parameter
      def to_variable(name) = type.to_inout(name)
    end

  end

  class Call

    attr_reader :arguments

    attr_reader :callable

    def to_value = @result

    def initialize(callable, arguments)
      @callable = callable
      @arguments = arguments.map { |x| x.to_value }
      @result = self.callable.result.nil? ? nil : Result.new(self)
    end

    class Result < Value

      attr_reader :call

      def initialize(call)
        super((@call = call).callable.result)
      end

      def to_s = call.to_s

    end

  end

end


end
