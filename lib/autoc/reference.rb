# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'
require 'autoc/decorator'
require 'autoc/callable'


module AutoC


using Coercions


# Dynamically allocated shared reference to the value type backed by the C side raw pointer
class Reference < Type
  
  include Entity

  include Decorator

  attr_reader :type

  def prefix_c = @prefix_c ||= type.prefix_c

  def initialize(type, prefix: nil, visibility: nil)
    @type = type.to_type
    super("#{self.type.name_c}*", visibility: (visibility.nil? ? type.visibility : visibility))
    @prefix_c = prefix&.to_s
    dependencies << self.type
    method(self.inout, :new, {}, respond_to: :init, abstract: true, constraint: -> { default_constructible? })
    method(:void, :free, { target: self.inout }, respond_to: :destroy, abstract: true)
  end

  private def method(result, name, parameters = {}, respond_to: nil, abstract: false, visibility: self.visibility, constraint: true)
    method = Function.new(result, decorate(name), parameters, visibility:, abstract:, constraint:)
    self.class.define_method((respond_to.nil? ? name : respond_to).to_sym) { |*args, **kws| method }
    references << method
    method
  end

  class Create < Callable
    def initialize(type)
      super(nil, { target: type.out })
      @type = type
    end
    def call(*arguments) = Call.new(@type, self, arguments)
    class Call < Callable::Call
      def initialize(type, callable, args)
        super(callable, args)
        @type = type
      end
      def to_s = "#{arguments_a.first} = #{@type.init.()}"
    end
  end

  def default_constructible? = type.default_constructible?

  def default_create = @default_create ||= Create.new(self)

  class Copy < Callable
    def initialize(type) = super(nil, { target: type.out, source: type })
    def call(*arguments) = Call.new(self, arguments)
    class Call < Callable::Call
      def to_s = "#{arguments_a.first} = #{arguments_a.last}"
    end
  end

  def copy = @copy ||= Copy.new(self)

  def to_value = Value.new(self)

  def to_variable(name) = Variable.new(self, name)

  class Value

    include Typed

    def initialize(type)
      typed_initialize(type, 0, -1, 0)
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


end