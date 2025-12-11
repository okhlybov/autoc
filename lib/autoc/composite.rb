# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'
require 'autoc/function'
require 'autoc/decorator'


module AutoC


using self


class Composite < Type

  include Entity

  include Decorator

  alias prefix_c name_c

  def self.new(*args, **kws)
    obj = super # Implicitly calls #initialize
    obj.send(:configure)
    obj
  end

  class Constant < Variable
    def declaration_c = "const #{super}"
  end

  def to_in(name) = Constant.new(to_i, name)
  def to_out(name) = Variable.new(to_i, name)
  def to_inout(name) = Variable.new(to_i, name)

  private def method(result, name, parameters = {}, respond_to: nil, abstract: false, visibility: self.visibility, constraint: true)
    method = Function.new(result, decorate(name), parameters, visibility:, abstract:, constraint:)
    self.class.define_method((respond_to.nil? ? name : respond_to).to_s) { |*args, **kws| method }
    method.dependencies << self
    references << method
    method
  end

  private def render_interface(stream)
    super
    render_type_declaration(stream)
  end

  # def render_type_declaration(stream)

  private def configure
    # TODO docs
    method(:void, :create, { target: out(self) }, respond_to: :default_create, constraint: -> { default_constructible? })
    method(:void, :destroy, { target: inout(self) }, constraint: -> { destructible? })
    method(:int, :equal, { lt: self, rt: self }, constraint: -> { comparable? })
    method(:int, :compare, { lt: self, rt: self }, constraint: -> { orderable? })
    method(:size_t, :hash, { target: self }, respond_to: :hash_code, constraint: -> { hashable? })
    method(:void, :copy, { target: out(self), source: self }, constraint: -> { copyable? })
  end

  def method_missing?(meth, *args, **kws) = decorate(meth)

end


end
