# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'
require 'autoc/decorator'


module AutoC


class Composite

  include Entity

  include Decorator

  alias prefix_c name_c

  def self.new(*args, **kws)
    obj = super # Implicitly calls #initialize
    obj.send(:configure)
    obj
  end

  def method(result, name, parameters = {}, respond_to: nil, abstract: false, visibility: self.visibility, constraint: true)
    method = Function.new(result, decorate(name), parameters, visibility:, abstract:, constraint:)
    self.class.define_method((respond_to.nil? ? name : respond_to).to_sym) { |*args, **kws| method }
    references << method
    method
  end

  private def render_interface(stream)
    super
    render_type_declaration(stream)
  end

  # def render_type_declaration(stream)

  private def configure
    method(:void, :create, { target: self.out }, respond_to: :default_create, constraint: -> { default_constructible? })
    method(:void, :destroy, { target: self.inout }, constraint: -> { destructible? })
    method(:int, :equal, { lt: self, rt: self }, constraint: -> { comparable? })
    method(:size_t, :hash, { target: self }, respond_to: :hash_code, constraint: -> { hashable? })
    method(:void, :copy, { target: self.out, source: self }, constraint: -> { copyable? })
  end

  def method_missing?(meth, *args, **kws) = decorate(meth)

end


end
